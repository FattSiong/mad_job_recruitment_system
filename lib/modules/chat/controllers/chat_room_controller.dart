import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/file_picker_helper.dart';
import '../../../core/utils/session_helper.dart';
import '../../../core/utils/storage_url_helper.dart';
import '../../../models/call_model.dart';
import '../../../models/chat_room_model.dart';
import '../../../models/message_model.dart';
import '../../../services/call_service.dart';
import '../../../services/push_service.dart';
import '../../../services/user_directory.dart';

/// Data for one conversation: live messages, sending text / files / voice,
/// read receipts, deleting, shared attachments and starting a call.
///
/// Push notifications are NOT sent from here: the server sends them when a
/// Message row is inserted (FCM, set up later).
class ChatRoomController extends ChangeNotifier {
  static const String attachmentsBucket = 'chat_attachments';
  static const int maxAttachmentMB = 10;
  static const int pageSize = 200;

  final String roomID;
  final ChatParticipant otherUser;

  ChatRoomController({required this.roomID, required this.otherUser});

  final _supabase = Supabase.instance.client;
  late final String currentUserID = SessionHelper.requireUserId();

  List<MessageModel> _messages = [];
  final List<MessageModel> _pending = []; // sent, waiting for the server echo
  bool _isLoading = true;
  String? _error;
  bool _isUploading = false;
  StreamSubscription<List<MessageModel>>? _subscription;
  Timer? _readDebounce;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isUploading => _isUploading;

  /// Newest first (for a reversed ListView), including messages still sending.
  List<MessageModel> get messages {
    if (_pending.isEmpty) return _messages;
    final serverIds = _messages.map((m) => m.messageID).toSet();
    final stillPending = _pending.where((m) => !serverIds.contains(m.messageID)).toList();
    return [...stillPending.reversed, ..._messages];
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
            _messages = rows;
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
      return 'Message not sent. Please check your connection and try again.';
    }
  }

  /// Image or document. Returns null on success, otherwise a message to show.
  Future<String?> sendAttachment(File file, String fileName) async {
    final sizeError = await FilePickerHelper.checkSize(file, maxAttachmentMB);
    if (sizeError != null) return sizeError;

    final ext = fileName.split('.').last.toLowerCase();
    final isImage = const ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext);

    return _withUpload(() async {
      final url = await _upload(file, fileName);
      await _insert(_newMessage(
        content: fileName,
        mediaType: isImage ? 'image' : 'file',
        mediaURL: url,
      ));
    }, failure: 'Failed to send the file. Please try again.');
  }

  /// Voice note recorded by [VoiceRecorderController].
  Future<String?> sendVoice(File file, int seconds) {
    return _withUpload(() async {
      final url = await _upload(file, 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await _insert(_newMessage(
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
      return [];
    }
  }

  /// Creates the call row; the server then rings the other phone (FCM)
  /// and the screen opens the call screen.
  Future<CallModel> startCall() => CallService().initiateCall(currentUserID, otherUser.userID);

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
