import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/session_helper.dart';
import '../../../models/call_model.dart';
import '../../../models/chat_room_model.dart';
import '../../../models/message_model.dart';
import '../../../services/call_service.dart';
import '../../../services/incoming_call_service.dart';
import '../../../services/user_directory.dart';
import '../../../core/utils/safe_notifier.dart';

/// Data for the chat list (inbox): rooms, latest message, unread counts,
/// search, and live updates while the list is open.
class ChatListController extends ChangeNotifier with SafeNotifier {
  final _supabase = Supabase.instance.client;
  final CallService _callService = CallService();

  List<ChatRoomModel> _rooms = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  Set<String> _blockedIds = {}; // people the current user has blocked

  RealtimeChannel? _channel;
  List<String> _subscribedRoomIds = [];
  Timer? _refreshDebounce;
  StreamSubscription<List<CallModel>>? _callSubscription;

  late final String currentUserID = SessionHelper.requireUserId();

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  bool get hasRooms => _rooms.isNotEmpty;

  /// The current user has blocked [userID] (the list shows a "Blocked" tag).
  bool isBlocked(String userID) => _blockedIds.contains(userID);

  /// Rooms matching the search box (name or last message).
  List<ChatRoomModel> get visibleRooms {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _rooms;
    return _rooms.where((room) {
      return room.otherUser.displayName.toLowerCase().contains(query) ||
          room.previewText(currentUserID).toLowerCase().contains(query);
    }).toList();
  }

  /// Filters the list by name or last message (done on the phone).
  void setSearchQuery(String value) {
    _searchQuery = value;
    notifySafely();
  }

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  /// First load, or a reload after returning from a chat. Shows the spinner
  /// only when there is nothing to show yet.
  Future<void> load() async {
    _isLoading = _rooms.isEmpty;
    _error = null;
    notifySafely();
    await _refresh();
  }

  /// Fetches the rooms again and listens to changes in them. On an error the
  /// last list stays on screen.
  Future<void> _refresh() async {
    try {
      final rooms = await _fetchRooms();
      _rooms = rooms;
      _error = null;
      _subscribeToChanges(rooms.map((r) => r.roomID).toList());
    } catch (e) {
      debugPrint('Error loading chats: $e');
      _error = e is SessionExpiredException
          ? e.message
          : 'Unable to load your chats. Please check your connection and try again.';
    } finally {
      _isLoading = false;
      notifySafely();
    }
  }

  /// The user's rooms with the other person, latest message and unread count.
  Future<List<ChatRoomModel>> _fetchRooms() async {
    final me = currentUserID;

    // Rooms with only their latest message (one query).
    final roomRows = await _supabase
        .from(TableConstants.chatRoom)
        .select('''
          roomID, user1_ID, user2_ID,
          Message(messageID, roomID, senderID, content, isRead, sentAt, mediaURL, mediaType, isDeleted)
        ''')
        .or('user1_ID.eq.$me,user2_ID.eq.$me')
        .order('sentAt', referencedTable: 'Message', ascending: false)
        .limit(1, referencedTable: 'Message');

    final rows = List<Map<String, dynamic>>.from(roomRows);
    if (rows.isEmpty) return [];

    final roomIds = rows.map((r) => r['roomID'].toString()).toList();
    final otherIds = rows.map((r) {
      final user1 = r['user1_ID'].toString();
      return user1 == me ? r['user2_ID'].toString() : user1;
    }).toList();

    final results = await Future.wait([
      UserDirectory.fetch(otherIds),
      _fetchUnreadCounts(roomIds),
      _fetchBlockedIds(),
    ]);
    final participants = results[0] as Map<String, ChatParticipant>;
    final unread = results[1] as Map<String, int>;
    _blockedIds = results[2] as Set<String>;

    final rooms = <ChatRoomModel>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final messages = (row['Message'] as List?) ?? const [];
      final otherId = otherIds[i];
      rooms.add(ChatRoomModel(
        roomID: roomIds[i],
        otherUser: participants[otherId] ??
            ChatParticipant(userID: otherId, displayName: 'Unknown user', role: 'member'),
        lastMessage: messages.isEmpty
            ? null
            : MessageModel.fromJson(Map<String, dynamic>.from(messages.first as Map)),
        unreadCount: unread[roomIds[i]] ?? 0,
      ));
    }

    // Newest activity first; rooms without messages at the bottom.
    rooms.sort((a, b) {
      final aTime = a.lastActivity, bTime = b.lastActivity;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return rooms;
  }

  /// Only the user's own blocks are visible (row-level security). On an
  /// error the last known list is kept.
  Future<Set<String>> _fetchBlockedIds() async {
    try {
      final rows = await _supabase
          .from(TableConstants.userBlock)
          .select('blockedID')
          .eq('blockerID', currentUserID);
      return rows.map((r) => r['blockedID'].toString()).toSet();
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
      return _blockedIds;
    }
  }

  /// Unread messages from the other person, per room (empty on an error).
  Future<Map<String, int>> _fetchUnreadCounts(List<String> roomIds) async {
    try {
      final rows = await _supabase
          .from(TableConstants.message)
          .select('roomID')
          .inFilter('roomID', roomIds)
          .eq('isRead', false)
          .neq('senderID', currentUserID)
          .or('isDeleted.is.null,isDeleted.eq.false');

      final counts = <String, int>{};
      for (final row in rows) {
        final id = row['roomID'].toString();
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugPrint('Error counting unread messages: $e');
      return {};
    }
  }

  // ---------------------------------------------------------------------
  // Live updates
  // ---------------------------------------------------------------------

  /// Listens only to this user's rooms (plus new rooms created with them),
  /// and refreshes the list shortly after a change.
  void _subscribeToChanges(List<String> roomIds) {
    final sameRooms = _channel != null &&
        roomIds.length == _subscribedRoomIds.length &&
        roomIds.toSet().containsAll(_subscribedRoomIds);
    if (sameRooms) return;

    _unsubscribe();
    _subscribedRoomIds = roomIds;

    final channel = _supabase.channel('chat-inbox-$currentUserID-${DateTime.now().millisecondsSinceEpoch}');

    // Postgres "in" filters allow up to 100 values; above that we rely on
    // the Message access rules to only deliver this user's rows.
    final messageFilter = (roomIds.isNotEmpty && roomIds.length <= 100)
        ? PostgresChangeFilter(
            type: PostgresChangeFilterType.inFilter,
            column: 'roomID',
            value: roomIds,
          )
        : null;

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: TableConstants.message,
          filter: messageFilter,
          callback: (_) => _scheduleRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: TableConstants.chatRoom,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user2_ID',
            value: currentUserID,
          ),
          callback: (_) => _scheduleRefresh(),
        )
        .subscribe();

    _channel = channel;
  }

  /// Reloads once, 400 ms after the last change (a burst of messages causes one reload).
  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!isDisposed) _refresh();
    });
  }

  /// Stops the live updates.
  void _unsubscribe() {
    final channel = _channel;
    _channel = null;
    if (channel != null) _supabase.removeChannel(channel);
  }

  // ---------------------------------------------------------------------
  // Calls (incoming calls ring while the chat list is open)
  // ---------------------------------------------------------------------

  /// Shows the incoming-call screen while the chat list is open.
  /// Shared with push notifications, so the same call never opens twice.
  void watchIncomingCalls() {
    _callSubscription?.cancel();
    _callSubscription = _callService.listenForIncomingCalls(currentUserID).listen(
      (calls) async {
        if (calls.isEmpty || isDisposed) return;
        final call = calls.first;
        final caller = await UserDirectory.fetchOne(call.callerID);
        if (isDisposed) return;
        await IncomingCallService.show(
          callID: call.callID,
          roomCode: call.roomCode,
          callerName: caller.displayName,
          callerPhoto: caller.photoUrl,
        );
      },
      onError: (Object e) => debugPrint('Incoming call stream error: $e'),
    );
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _callSubscription?.cancel();
    _unsubscribe();
    super.dispose();
  }
}
