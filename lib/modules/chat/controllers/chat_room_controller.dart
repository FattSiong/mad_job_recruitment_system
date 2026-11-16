import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/file_picker_helper.dart';
import '../../../core/utils/session_helper.dart';
import '../../../core/utils/storage_url_helper.dart';
import '../../../models/call_model.dart';
import '../../../models/chat_room_model.dart';
import '../../../models/message_model.dart';
import '../../../services/call_service.dart';
import '../../../services/push_service.dart';
import '../../../services/user_directory.dart';

/// Who has blocked whom in this chat.
enum ChatBlockState {
  none,

  /// The current user blocked the other person.
  blockedByMe,

  /// The other person blocked the current user.
  blockedMe,
}

/// Data for one conversation: live messages, sending text / files / voice,
/// read receipts, deleting, shared attachments, blocking and starting a call.
///
/// Push notifications are NOT sent from here: a database trigger calls the
/// send-push Edge Function (FCM) when a Message row is inserted.
class ChatRoomController extends ChangeNotifier {
  static const String attachmentsBucket = 'chat_attachments';
  static const int maxAttachmentMB = 10;

  /// The live stream keeps the newest [pageSize] messages; older ones are
  /// fetched [olderPageSize] at a time when the user scrolls up.
  static const int pageSize = 50;
  static const int olderPageSize = 50;

  final String roomID;
  final ChatParticipant otherUser;

  ChatRoomController({required this.roomID, required this.otherUser});

  final _supabase = Supabase.instance.client;
  late final String currentUserID = SessionHelper.requireUserId();

  List<MessageModel> _messages = []; // live window, newest first
  List<MessageModel> _older = []; // loaded on scroll, newest first, all older than _messages
  final List<MessageModel> _pending = []; // sent, waiting for the server echo
  bool _hasOlder = false;
  bool _isLoadingOlder = false;
  String? _olderError;
  bool _isLoading = true;
  String? _error;
  bool _isUploading = false;
  ChatBlockState _blockState = ChatBlockState.none;
  bool _isChangingBlock = false;
  StreamSubscription<List<MessageModel>>? _subscription;
  Timer? _readDebounce;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isUploading => _isUploading;

  /// While either person has blocked the other, nobody can send or call.
  ChatBlockState get blockState => _blockState;
  bool get isBlocked => _blockState != ChatBlockState.none;
  bool get isChangingBlock => _isChangingBlock;

  static const String blockedMessage = 'You can\'t send messages in this chat.';

  /// More messages exist before the oldest one shown.
  bool get hasOlder => _hasOlder;
  bool get isLoadingOlder => _isLoadingOlder;

  /// Set when loading older messages failed (the screen offers a retry).
  String? get olderError => _olderError;

  /// Newest first (for a reversed ListView), including messages still sending
  /// and older messages loaded by [loadOlder].
  List<MessageModel> get messages {
    final serverIds = _messages.map((m) => m.messageID).toSet();
    final stillPending = _pending.where((m) => !serverIds.contains(m.messageID)).toList();
    final older = _older.where((m) => !serverIds.contains(m.messageID));
    return [...stillPending.reversed, ..._messages, ...older];
  }

  bool isPending(MessageModel message) =>
      _pending.any((m) => m.messageID == message.messageID) &&
      !_messages.any((m) => m.messageID == message.messageID);

  bool isMine(MessageModel message) => message.senderID == currentUserID;

  // ---------------------------------------------------------------------
  // Live messages
  // ---------------------------------------------------------------------

  void start() {
    PushService.activeChatRoomID = roomID; // no pop-ups for this chat while open
    refreshBlockState();
    _subscription?.cancel();
    _isLoading = _messages.isEmpty;
    _error = null;
    _notify();

    _subscription = _supabase
        .from(TableConstants.message)
        .stream(primaryKey: ['messageID'])
        .eq('roomID', roomID)
        .order('sentAt', ascending: false)
        .limit(pageSize)
        .map((rows) => rows.map(MessageModel.fromJson).toList())
        .listen(
          (rows) {
            _keepMessagesLeavingWindow(rows);
            _messages = rows;
            // A full page means there may be more before it (unless already loaded).
            if (_older.isEmpty) _hasOlder = rows.length >= pageSize;
            _pending.removeWhere((p) => rows.any((m) => m.messageID == p.messageID));
            _isLoading = false;
            _error = null;
            _notify();
            _scheduleMarkAsRead();
          },
          onError: (Object e) {
            debugPrint('Chat stream error: $e');
            _isLoading = false;
            _error = 'Unable to load messages. Please check your connection.';
            _notify();
          },
        );
  }

  /// When a new message arrives, the oldest one drops out of the live window
  /// (it only holds [pageSize] rows). Keep it in [_older] so nothing the user
  /// has already seen disappears from the screen.
  void _keepMessagesLeavingWindow(List<MessageModel> rows) {
    if (_messages.isEmpty || rows.isEmpty) return;
    final newIds = rows.map((m) => m.messageID).toSet();
    final oldestInWindow = rows.last.sentAt;
    final leaving = _messages
        .where((m) => !newIds.contains(m.messageID) && !m.sentAt.isAfter(oldestInWindow))
        .toList();
    if (leaving.isEmpty) return;
    final olderIds = _older.map((m) => m.messageID).toSet();
    _older = [...leaving.where((m) => !olderIds.contains(m.messageID)), ..._older]
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    _hasOlder = true;
  }

  /// Loads the next [olderPageSize] messages before the oldest one shown.
  /// Called when the user scrolls near the top. A failure sets [olderError].
  Future<void> loadOlder() async {
    if (_isLoadingOlder || !_hasOlder) return;
    final shown = [..._messages, ..._older];
    if (shown.isEmpty) return;
    final oldest = shown.map((m) => m.sentAt).reduce((a, b) => a.isBefore(b) ? a : b);

    _isLoadingOlder = true;
    _olderError = null;
    _notify();
    try {
      final rows = await _supabase
          .from(TableConstants.message)
          .select()
          .eq('roomID', roomID)
          .lt('sentAt', oldest.toUtc().toIso8601String())
          .order('sentAt', ascending: false)
          .limit(olderPageSize);
      final loaded = rows.map(MessageModel.fromJson).toList();
      final known = shown.map((m) => m.messageID).toSet();
      _older = [..._older, ...loaded.where((m) => !known.contains(m.messageID))];
      _hasOlder = loaded.length >= olderPageSize;
    } catch (e) {
      debugPrint('Error loading older messages: $e');
      _olderError = 'Unable to load older messages.';
    } finally {
      _isLoadingOlder = false;
      _notify();
    }
  }

  /// Marks the other person's messages as read (shortly after they arrive).
  void _scheduleMarkAsRead() {
    final hasUnread = _messages.any((m) => !m.isRead && m.senderID != currentUserID);
    if (!hasUnread) return;
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 500), markAsRead);
  }

  Future<void> markAsRead() async {
    try {
      await _supabase
          .from(TableConstants.message)
          .update({'isRead': true})
          .eq('roomID', roomID)
          .neq('senderID', currentUserID)
          .eq('isRead', false);
    } catch (e) {
      debugPrint('Error marking messages read: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Sending
  // ---------------------------------------------------------------------

  /// Returns null on success, otherwise a message to show.
  Future<String?> sendText(String text) async {
    final content = text.trim();
    if (content.isEmpty) return null;
    if (isBlocked) return blockedMessage;
    if (content.length > 4000) return 'Messages can be up to 4000 characters.';

    final message = _newMessage(content: content, mediaType: 'text');
    _pending.add(message);
    _notify();

    try {
      await _insert(message);
      return null;
    } catch (e) {
      debugPrint('Error sending message: $e');
      _pending.removeWhere((m) => m.messageID == message.messageID);
      _notify();
      if (await _blockedJustNow(e)) return blockedMessage;
      return 'Message not sent. Please check your connection and try again.';
    }
  }

  /// Image or document. Returns null on success, otherwise a message to show.
  Future<String?> sendAttachment(File file, String fileName) async {
    if (isBlocked) return blockedMessage;
    final sizeError = await FilePickerHelper.checkSize(file, maxAttachmentMB);
    if (sizeError != null) return sizeError;

    final ext = fileName.split('.').last.toLowerCase();
    final isImage = const ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext);

    return _withUpload(() async {
      final url = await _upload(file, fileName);
      await _insertWithFile(_newMessage(
        content: fileName,
        mediaType: isImage ? 'image' : 'file',
        mediaURL: url,
      ));
    }, failure: 'Failed to send the file. Please try again.');
  }

  /// Voice note recorded by [VoiceRecorderController].
  Future<String?> sendVoice(File file, int seconds) async {
    if (isBlocked) return blockedMessage;
    return _withUpload(() async {
      final url = await _upload(file, 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await _insertWithFile(_newMessage(
        // The "(12s)" part is read by older app versions to show the length.
        content: 'Voice Message (${seconds}s)',
        mediaType: 'audio',
        mediaURL: url,
      ));
    }, failure: 'Failed to send the voice message. Please try again.');
  }

  Future<String?> _withUpload(Future<void> Function() action, {required String failure}) async {
    _isUploading = true;
    _notify();
    try {
      await action();
      return null;
    } catch (e) {
      debugPrint('Chat upload error: $e');
      if (await _blockedJustNow(e)) return blockedMessage;
      return failure;
    } finally {
      _isUploading = false;
      _notify();
    }
  }

  Future<String> _upload(File file, String fileName) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = 'chats/$roomID/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await _supabase.storage.from(attachmentsBucket).upload(path, file);
    // The bucket is private: this link only identifies the file. The app opens
    // it through a signed link (StorageUrlHelper), and only chat members may.
    return _supabase.storage.from(attachmentsBucket).getPublicUrl(path);
  }

  Future<void> _insert(MessageModel message) async {
    await _supabase.from(TableConstants.message).insert(message.toJson());
  }

  /// Saves a message whose file is already uploaded. If that fails, the file
  /// is removed again, so no unused upload is left in storage.
  Future<void> _insertWithFile(MessageModel message) async {
    try {
      await _insert(message);
    } catch (_) {
      await _deleteAttachmentFile(message.mediaURL);
      rethrow;
    }
  }

  MessageModel _newMessage({
    required String content,
    required String mediaType,
    String? mediaURL,
  }) {
    return MessageModel(
      messageID: _newMessageId(),
      roomID: roomID,
      senderID: currentUserID,
      content: content,
      isRead: false,
      sentAt: DateTime.now(),
      mediaType: mediaType,
      mediaURL: mediaURL,
    );
  }

  /// Client-side UUID v4, so the message can be shown before the server confirms it.
  static String _newMessageId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // ---------------------------------------------------------------------
  // Other actions
  // ---------------------------------------------------------------------

  /// Deletes one of your own messages for everyone (kept as "deleted").
  /// A photo, file or voice note is also removed from storage, so its old
  /// link stops working.
  Future<bool> deleteMessage(MessageModel message) async {
    if (!isMine(message)) return false;
    try {
      await _supabase
          .from(TableConstants.message)
          .update({
            'isDeleted': true,
            'content': 'This message was deleted',
            'mediaURL': null,
          })
          .eq('messageID', message.messageID)
          .eq('senderID', currentUserID);
    } catch (e) {
      debugPrint('Error deleting message: $e');
      return false;
    }
    await _deleteAttachmentFile(message.mediaURL);
    // Older messages are not in the live stream, so update the copy shown.
    final i = _older.indexWhere((m) => m.messageID == message.messageID);
    if (i != -1) {
      final m = _older[i];
      _older[i] = MessageModel(
        messageID: m.messageID,
        roomID: m.roomID,
        senderID: m.senderID,
        content: 'This message was deleted',
        isRead: m.isRead,
        sentAt: m.sentAt,
        mediaType: m.mediaType,
        mediaURL: null,
        isDeleted: true,
      );
      _notify();
    }
    return true;
  }

  /// Removes a chat file from storage. Failure is only logged: the message is
  /// already deleted and the private bucket keeps the file hidden anyway.
  Future<void> _deleteAttachmentFile(String? mediaURL) async {
    if (mediaURL == null || mediaURL.isEmpty) return;
    final file = StorageUrlHelper.parse(mediaURL);
    if (file == null || file.bucket != attachmentsBucket) return;
    try {
      await _supabase.storage.from(attachmentsBucket).remove([file.path]);
    } catch (e) {
      debugPrint('Could not delete chat file ${file.path}: $e');
    }
  }

  /// Photos and files shared in this chat, newest first.
  /// Throws [DataLoadException] if they can't be loaded.
  Future<List<MessageModel>> fetchSharedAttachments() async {
    try {
      final rows = await _supabase
          .from(TableConstants.message)
          .select()
          .eq('roomID', roomID)
          .or('isDeleted.is.null,isDeleted.eq.false')
          .inFilter('mediaType', ['image', 'file'])
          .not('mediaURL', 'is', null)
          .order('sentAt', ascending: false);
      return rows.map(MessageModel.fromJson).toList();
    } catch (e) {
      debugPrint('Error loading shared attachments: $e');
      throw DataLoadException(
        'Unable to load shared photos and files. Please check your connection and try again.',
      );
    }
  }

  /// Creates the call row; the server then rings the other phone (FCM)
  /// and the screen opens the call screen.
  Future<CallModel> startCall() {
    if (isBlocked) throw StateError(blockedMessage);
    return CallService().initiateCall(currentUserID, otherUser.userID);
  }

  // ---------------------------------------------------------------------
  // Blocking
  // ---------------------------------------------------------------------

  /// Asks the server who (if anyone) has blocked whom. On a network error
  /// the last known state is kept.
  Future<void> refreshBlockState() async {
    try {
      final status = await _supabase.rpc(
        'chat_block_status',
        params: {'p_other': otherUser.userID},
      );
      _blockState = switch (status?.toString()) {
        'you_blocked' => ChatBlockState.blockedByMe,
        'blocked_you' => ChatBlockState.blockedMe,
        _ => ChatBlockState.none,
      };
      _notify();
    } catch (e) {
      debugPrint('Error checking block status: $e');
    }
  }

  /// A send was refused by the database (42501 = row-level security): the
  /// other person may have blocked us meanwhile. Re-checks and says so.
  Future<bool> _blockedJustNow(Object error) async {
    if (error is! PostgrestException || error.code != '42501') return false;
    await refreshBlockState();
    return isBlocked;
  }

  /// Blocks the other person. Returns null on success, otherwise a message.
  Future<String?> block() async {
    if (_isChangingBlock) return null;
    _isChangingBlock = true;
    _notify();
    try {
      await _supabase.from(TableConstants.userBlock).insert({
        'blockerID': currentUserID,
        'blockedID': otherUser.userID,
      });
      _blockState = ChatBlockState.blockedByMe;
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        _blockState = ChatBlockState.blockedByMe; // already blocked
        return null;
      }
      debugPrint('Error blocking user: ${e.code} ${e.message}');
      return 'Unable to block ${otherUser.displayName}. Please try again.';
    } catch (e) {
      debugPrint('Error blocking user: $e');
      return 'Unable to block ${otherUser.displayName}. Please try again.';
    } finally {
      _isChangingBlock = false;
      _notify();
    }
  }

  /// Removes the current user's block. Returns null on success, otherwise a message.
  Future<String?> unblock() async {
    if (_isChangingBlock) return null;
    _isChangingBlock = true;
    _notify();
    try {
      await _supabase
          .from(TableConstants.userBlock)
          .delete()
          .eq('blockerID', currentUserID)
          .eq('blockedID', otherUser.userID);
      _blockState = ChatBlockState.none;
      await refreshBlockState(); // the other person may also have blocked us
      return null;
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      return 'Unable to unblock ${otherUser.displayName}. Please try again.';
    } finally {
      _isChangingBlock = false;
      _notify();
    }
  }

  // ---------------------------------------------------------------------
  // Opening a chat from anywhere in the app
  // ---------------------------------------------------------------------

  /// Finds the one-to-one room with [otherUserID], or creates it.
  static Future<String> getOrCreateRoomId(String otherUserID) async {
    final supabase = Supabase.instance.client;
    final me = SessionHelper.requireUserId();
    if (me == otherUserID) throw ArgumentError('You cannot chat with yourself.');

    final existing = await supabase
        .from(TableConstants.chatRoom)
        .select('roomID')
        .or('and(user1_ID.eq.$me,user2_ID.eq.$otherUserID),and(user1_ID.eq.$otherUserID,user2_ID.eq.$me)')
        .limit(1);
    if (existing.isNotEmpty) return existing.first['roomID'].toString();

    try {
      final created = await supabase
          .from(TableConstants.chatRoom)
          .insert({'user1_ID': me, 'user2_ID': otherUserID})
          .select('roomID')
          .single();
      return created['roomID'].toString();
    } on PostgrestException catch (e) {
      // 23505: the other person created the room at the same moment.
      if (e.code != '23505') rethrow;
      final again = await supabase
          .from(TableConstants.chatRoom)
          .select('roomID')
          .or('and(user1_ID.eq.$me,user2_ID.eq.$otherUserID),and(user1_ID.eq.$otherUserID,user2_ID.eq.$me)')
          .limit(1);
      return again.first['roomID'].toString();
    }
  }

  static Future<ChatParticipant> fetchParticipant(String userID) =>
      UserDirectory.fetchOne(userID);

  // ---------------------------------------------------------------------

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (PushService.activeChatRoomID == roomID) PushService.activeChatRoomID = null;
    _readDebounce?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
