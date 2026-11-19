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
import '../chat_outbox.dart';
import '../../../core/utils/safe_notifier.dart';

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
/// A message that can't be sent (e.g. no connection) stays in the chat as
/// "Not sent" and is resent automatically, or when the user taps it
/// (NF-REL-02, see [ChatOutbox]).
///
/// Push notifications are NOT sent from here: a database trigger calls the
/// send-push Edge Function (FCM) when a Message row is inserted.
class ChatRoomController extends ChangeNotifier with SafeNotifier {
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
  final ChatOutbox _outbox = ChatOutbox(); // sent by this user, not confirmed yet
  final Set<String> _inFlight = {}; // outbox messages being sent right now
  Timer? _retryTimer;
  DateTime? _retryAt; // when [_retryTimer] fires
  int _retryRound = 0; // automatic resend rounds in a row that still failed
  bool _resending = false;
  bool _hasOlder = false;
  bool _isLoadingOlder = false;
  String? _olderError;
  bool _isLoading = true;
  String? _error;
  ChatBlockState _blockState = ChatBlockState.none;
  bool _isChangingBlock = false;
  StreamSubscription<List<MessageModel>>? _subscription;
  Timer? _readDebounce;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// A photo, file or voice note is being uploaded.
  bool get isUploading => _outbox.isUploading;

  /// Messages that could not be sent and are waiting to be resent.
  int get unsentCount => _outbox.failed.length;

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
    final unconfirmed = _outbox.items
        .where((i) => !serverIds.contains(i.id))
        .map((i) => i.message)
        .toList();
    final older = _older.where((m) => !serverIds.contains(m.messageID));
    return [...unconfirmed.reversed, ..._messages, ...older];
  }

  /// True while [message] is being sent or waits for the server to confirm it.
  bool isPending(MessageModel message) =>
      _outbox.contains(message.messageID) &&
      !_outbox.isFailed(message.messageID) &&
      !_messages.any((m) => m.messageID == message.messageID);

  /// True if [message] could not be sent (shown as "Not sent · Tap to retry").
  bool isFailed(MessageModel message) => _outbox.isFailed(message.messageID);

  /// The photo / file / voice note on the phone for a message that isn't
  /// uploaded yet (the bubble shows it from there).
  File? localFileOf(MessageModel message) {
    final item = _outbox[message.messageID];
    return item?.uploadedURL == null ? item?.file : null;
  }

  /// True if the current user sent [message].
  bool isMine(MessageModel message) => message.senderID == currentUserID;

  // ---------------------------------------------------------------------
  // Live messages
  // ---------------------------------------------------------------------

  /// Opens the chat: checks blocking and starts the live message stream.
  /// Call once when the screen opens.
  void start() {
    PushService.activeChatRoomID = roomID; // no pop-ups for this chat while open
    refreshBlockState();
    _subscription?.cancel();
    _isLoading = _messages.isEmpty;
    _error = null;
    notifySafely();

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
            _outbox.removeConfirmed(rows.map((m) => m.messageID));
            _isLoading = false;
            _error = null;
            notifySafely();
            _scheduleMarkAsRead();
            // Messages arriving again: the connection works, so resend soon.
            if (_outbox.hasFailed) _scheduleResend(const Duration(seconds: 1));
          },
          onError: (Object e) {
            debugPrint('Chat stream error: $e');
            _isLoading = false;
            _error = 'Unable to load messages. Please check your connection.';
            notifySafely();
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
    notifySafely();
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
      notifySafely();
    }
  }

  /// Marks the other person's messages as read (shortly after they arrive).
  void _scheduleMarkAsRead() {
    final hasUnread = _messages.any((m) => !m.isRead && m.senderID != currentUserID);
    if (!hasUnread) return;
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 500), markAsRead);
  }

  /// Marks the other person's unread messages in this chat as read.
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

  /// Sends a text message (shown straight away, before the server confirms it).
  /// Returns a message to show when it can't be sent at all (blocked, too
  /// long, refused). A connection problem returns null: the message stays in
  /// the chat as "Not sent" and is resent.
  Future<String?> sendText(String text) async {
    final content = text.trim();
    if (content.isEmpty) return null;
    if (isBlocked) return blockedMessage;
    if (content.length > 4000) return 'Messages can be up to 4000 characters.';

    final item = OutboxItem(_newMessage(content: content, mediaType: 'text'));
    _outbox.add(item);
    notifySafely();
    return _deliver(item.id);
  }

  /// Image or document. Returns a message to show when it can't be sent at
  /// all; null when sent or kept as "Not sent" to resend.
  Future<String?> sendAttachment(File file, String fileName) async {
    if (isBlocked) return blockedMessage;
    final sizeError = await FilePickerHelper.checkSize(file, maxAttachmentMB);
    if (sizeError != null) return sizeError;

    final ext = fileName.split('.').last.toLowerCase();
    final isImage = const ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext);
    final item = OutboxItem(
      _newMessage(content: fileName, mediaType: isImage ? 'image' : 'file'),
      file: file,
      fileName: fileName,
    );
    _outbox.add(item);
    notifySafely();
    return _deliver(item.id);
  }

  /// Voice note recorded by [VoiceRecorderController]. Same results as
  /// [sendAttachment]; the recording is kept until it is sent.
  Future<String?> sendVoice(File file, int seconds) async {
    if (isBlocked) return blockedMessage;
    final item = OutboxItem(
      // The "(12s)" part is read by older app versions to show the length.
      _newMessage(content: 'Voice Message (${seconds}s)', mediaType: 'audio'),
      file: file,
      fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      deleteFileWhenSent: true,
    );
    _outbox.add(item);
    notifySafely();
    return _deliver(item.id);
  }

  /// Uploads the file (once) and saves the message. On a connection problem
  /// the message is marked "Not sent" and a resend is scheduled (returns
  /// null). When the server refuses it, it is removed and a message to show
  /// is returned.
  Future<String?> _deliver(String id) async {
    final item = _outbox[id];
    if (item == null || !_inFlight.add(id)) return null;
    item.status = OutboxStatus.sending;
    notifySafely();
    try {
      if (item.hasFile && item.uploadedURL == null) {
        item.markUploaded(await _upload(item.file!, item.fileName ?? 'file'));
        notifySafely();
      }
      try {
        await _insert(item.message);
      } catch (e) {
        if (!ChatOutbox.isAlreadySaved(e)) rethrow; // an earlier try got through
      }
      item.status = OutboxStatus.sent; // stays shown until the live stream has it
      _retryRound = 0;
      if (item.deleteFileWhenSent) _deleteLocalFile(item.file);
      return null;
    } catch (e) {
      debugPrint('Send failed (${item.message.mediaType}): $e');
      if (await _blockedJustNow(e)) {
        await _discard(item);
        return blockedMessage;
      }
      if (!ChatOutbox.isRetryable(e)) {
        await _discard(item);
        return switch (item.message.mediaType) {
          'audio' => 'Failed to send the voice message. Please try again.',
          'image' || 'file' => 'Failed to send the file. Please try again.',
          _ => 'Message not sent. Please try again.',
        };
      }
      item.status = OutboxStatus.failed;
      item.failures++;
      if (!_resending) _scheduleResend(ChatOutbox.retryDelay(_retryRound));
      return null;
    } finally {
      _inFlight.remove(id);
      notifySafely();
    }
  }

  /// "Not sent" message tapped: try again now.
  /// Returns a message to show if it can't be sent at all.
  Future<String?> retry(MessageModel message) async {
    if (!_outbox.isFailed(message.messageID)) return null;
    if (isBlocked) return blockedMessage;
    _retryRound = 0;
    return _deliver(message.messageID);
  }

  /// Removes a "Not sent" message without sending it.
  Future<void> discard(MessageModel message) async {
    final item = _outbox[message.messageID];
    if (item == null || item.status != OutboxStatus.failed) return;
    await _discard(item);
    notifySafely();
  }

  /// Takes [item] out of the chat; an upload it no longer needs is deleted.
  Future<void> _discard(OutboxItem item) async {
    _outbox.remove(item.id);
    await _deleteAttachmentFile(item.uploadedURL);
    if (item.deleteFileWhenSent) _deleteLocalFile(item.file);
  }

  /// Resends every "Not sent" message, oldest first. Called automatically
  /// (with a growing wait), when messages arrive again, and when the app
  /// comes back to the foreground. Stops at the first one that still fails.
  Future<void> resendFailed() async {
    _retryTimer?.cancel();
    if (isDisposed || _resending || isBlocked || !_outbox.hasFailed) return;
    _resending = true;
    try {
      for (final item in _outbox.failed) {
        if (isDisposed || isBlocked) return;
        await _deliver(item.id);
        if (_outbox.isFailed(item.id)) break; // still no connection
      }
    } finally {
      _resending = false;
    }
    if (_outbox.hasFailed && !isDisposed) {
      _retryRound++;
      _scheduleResend(ChatOutbox.retryDelay(_retryRound));
    }
  }

  /// Runs [resendFailed] after [delay], unless a resend is already due sooner.
  void _scheduleResend(Duration delay) {
    if (isDisposed) return;
    final at = DateTime.now().add(delay);
    if ((_retryTimer?.isActive ?? false) && !_retryAt!.isAfter(at)) return;
    _retryTimer?.cancel();
    _retryAt = at;
    _retryTimer = Timer(delay, resendFailed);
  }

  /// Deletes the app's own temporary file (a sent or discarded voice note).
  void _deleteLocalFile(File? file) {
    if (file == null) return;
    file.delete().catchError((_) => file);
  }

  /// Uploads a chat file to "chats/<roomID>/..." and returns its stored link.
  Future<String> _upload(File file, String fileName) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = 'chats/$roomID/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await _supabase.storage.from(attachmentsBucket).upload(path, file);
    // The bucket is private: this link only identifies the file. The app opens
    // it through a signed link (StorageUrlHelper), and only chat members may.
    return _supabase.storage.from(attachmentsBucket).getPublicUrl(path);
  }

  /// Saves [message] in the database.
  Future<void> _insert(MessageModel message) async {
    await _supabase.from(TableConstants.message).insert(message.toJson());
  }

  /// A new message from the current user in this room, with a fresh ID.
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
    _replaceShown(message.messageID,
        (m) => m.copyWith(content: 'This message was deleted', isDeleted: true, clearMedia: true));
    return true;
  }

  /// True if the user may still edit [message]: their own text message,
  /// sent and confirmed less than 2 minutes ago, in a chat that isn't blocked.
  bool canEdit(MessageModel message) =>
      !isBlocked &&
      !_outbox.contains(message.messageID) &&
      message.canBeEditedBy(currentUserID);

  /// Changes the text of one of the user's messages (within 2 minutes of
  /// sending). Returns null when saved, otherwise a message to show.
  Future<String?> editMessage(MessageModel message, String text) async {
    final content = text.trim();
    if (content == message.content.trim()) return null; // nothing changed
    if (content.isEmpty) return 'A message can\'t be empty.';
    if (content.length > 4000) return 'Messages can be up to 4000 characters.';
    if (!canEdit(message)) return isBlocked ? blockedMessage : editClosedMessage;
    try {
      final rows = await _supabase
          .from(TableConstants.message)
          .update({'content': content})
          .eq('messageID', message.messageID)
          .eq('senderID', currentUserID)
          .select('editedAt');
      if (rows.isEmpty) return editClosedMessage;
      final editedAt = DateTime.tryParse(rows.first['editedAt']?.toString() ?? '') ?? DateTime.now();
      // The live stream also brings the change; show it straight away.
      _replaceShown(message.messageID, (m) => m.copyWith(content: content, editedAt: editedAt));
      return null;
    } on PostgrestException catch (e) {
      debugPrint('Edit message failed: ${e.code} ${e.message}');
      if (e.message.contains('edit_window_closed')) return editClosedMessage;
      if (e.message.contains('chat_blocked')) {
        await refreshBlockState();
        return blockedMessage;
      }
      return 'Unable to edit the message. Please try again.';
    } catch (e) {
      debugPrint('Edit message failed: $e');
      return 'Unable to edit the message. Please check your connection and try again.';
    }
  }

  static const String editClosedMessage = 'Messages can only be edited within 2 minutes of sending.';

  /// Updates the copy of a message on screen (older messages are not in the
  /// live stream, so they would otherwise keep the old version).
  void _replaceShown(String messageID, MessageModel Function(MessageModel) change) {
    var changed = false;
    final i = _messages.indexWhere((m) => m.messageID == messageID);
    if (i != -1) {
      _messages = [..._messages]..[i] = change(_messages[i]);
      changed = true;
    }
    final j = _older.indexWhere((m) => m.messageID == messageID);
    if (j != -1) {
      _older[j] = change(_older[j]);
      changed = true;
    }
    if (changed) notifySafely();
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
      notifySafely();
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
    notifySafely();
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
      notifySafely();
    }
  }

  /// Removes the current user's block. Returns null on success, otherwise a message.
  Future<String?> unblock() async {
    if (_isChangingBlock) return null;
    _isChangingBlock = true;
    notifySafely();
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
      notifySafely();
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

  /// Name, role and photo of [userID] (cached by UserDirectory).
  static Future<ChatParticipant> fetchParticipant(String userID) =>
      UserDirectory.fetchOne(userID);

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  @override
  void dispose() {
    if (PushService.activeChatRoomID == roomID) PushService.activeChatRoomID = null;
    _readDebounce?.cancel();
    _retryTimer?.cancel();
    _subscription?.cancel();
    // Leaving discards the "Not sent" messages (the screen asked first):
    // remove the files they had uploaded and their temporary voice recordings.
    for (final item in _outbox.failed) {
      _deleteAttachmentFile(item.uploadedURL);
      if (item.deleteFileWhenSent) _deleteLocalFile(item.file);
    }
    super.dispose();
  }
}
