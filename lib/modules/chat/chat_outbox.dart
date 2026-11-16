import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/message_model.dart';

/// Where an unconfirmed message is.
enum OutboxStatus {
  /// Being uploaded / saved right now.
  sending,

  /// Saved; waiting for it to arrive in the live stream.
  sent,

  /// Could not be sent (e.g. no connection). Shown as "Not sent" and resent
  /// automatically or by tapping it.
  failed,
}

/// A message the user sent that the server hasn't confirmed yet.
class OutboxItem {
  /// What the chat shows. Its ID is made on the phone, so a resend reuses it
  /// and can never create the message twice.
  MessageModel message;

  /// The photo, file or voice note on the phone (null for text).
  final File? file;

  /// Original file name (used for the stored file name).
  final String? fileName;

  /// The file is the app's own temporary copy (a voice note), so it is
  /// deleted once the message is sent.
  final bool deleteFileWhenSent;

  /// Stored link once the file is uploaded, so a resend doesn't upload it again.
  String? uploadedURL;

  OutboxStatus status = OutboxStatus.sending;

  /// Failed attempts so far.
  int failures = 0;

  OutboxItem(
    this.message, {
    this.file,
    this.fileName,
    this.deleteFileWhenSent = false,
  });

  String get id => message.messageID;
  bool get hasFile => file != null;

  /// The file was uploaded: the message now carries its link (and the bubble
  /// can show the real photo / voice note).
  void markUploaded(String url) {
    uploadedURL = url;
    final m = message;
    message = MessageModel(
      messageID: m.messageID,
      roomID: m.roomID,
      senderID: m.senderID,
      content: m.content,
      isRead: m.isRead,
      sentAt: m.sentAt,
      mediaType: m.mediaType,
      mediaURL: url,
      isDeleted: m.isDeleted,
    );
  }
}

/// Unsent messages of one chat (NF-REL-02): a message that fails to send is
/// kept on screen as "Not sent" and resent, instead of being dropped.
/// Kept in memory while the chat is open. Pure Dart, so it can be unit tested.
class ChatOutbox {
  final Map<String, OutboxItem> _items = {}; // keeps the order they were sent in

  /// Oldest first.
  List<OutboxItem> get items => List.unmodifiable(_items.values);

  /// The unconfirmed message with [id], or null.
  OutboxItem? operator [](String id) => _items[id];

  /// True if the message with [id] is still unconfirmed.
  bool contains(String id) => _items.containsKey(id);

  /// A message the user just sent.
  void add(OutboxItem item) => _items[item.id] = item;

  /// Takes a message out (discarded or refused). Returns it, or null.
  OutboxItem? remove(String id) => _items.remove(id);

  /// Removes the messages that have arrived from the server.
  void removeConfirmed(Iterable<String> serverIds) {
    for (final id in serverIds) {
      _items.remove(id);
    }
  }

  /// Failed messages, oldest first (resent in this order).
  List<OutboxItem> get failed =>
      _items.values.where((i) => i.status == OutboxStatus.failed).toList();

  bool get hasFailed => _items.values.any((i) => i.status == OutboxStatus.failed);

  /// True if the message with [id] is "Not sent".
  bool isFailed(String id) => _items[id]?.status == OutboxStatus.failed;

  /// A photo, file or voice note is being uploaded right now.
  bool get isUploading => _items.values
      .any((i) => i.hasFile && i.uploadedURL == null && i.status == OutboxStatus.sending);

  /// Wait before the next automatic resend after [round] rounds that still
  /// failed: 5 s, 10 s, 20 s, 40 s, then every 60 s.
  static Duration retryDelay(int round) {
    if (round <= 0) return const Duration(seconds: 5);
    if (round >= 4) return const Duration(seconds: 60);
    return Duration(seconds: 5 * (1 << round));
  }

  /// True for a failure that may work later (no connection, timeout, server
  /// busy). False when the server refused the message itself (bad data,
  /// no permission, file too large): sending it again would fail again.
  static bool isRetryable(Object error) {
    // The photo / recording is no longer on the phone: it can never be sent.
    if (error is FileSystemException) return false;
    if (error is SocketException || error is TimeoutException || error is HttpException) {
      return true;
    }
    if (error is PostgrestException) {
      final code = error.code ?? '';
      // 22xxx bad data, 23xxx rule broken, 42xxx no permission / unknown column
      return !(code.startsWith('22') || code.startsWith('23') || code.startsWith('42'));
    }
    if (error is StorageException) {
      final status = int.tryParse(error.statusCode ?? '');
      // 4xx (except 408 timeout / 429 too many requests) = refused
      return status == null || status >= 500 || status == 408 || status == 429;
    }
    return true; // unknown network / client errors: worth another try
  }

  /// An earlier try did save the message (the reply was lost), so the
  /// resend finds its ID already there: it counts as sent.
  static bool isAlreadySaved(Object error) =>
      error is PostgrestException && error.code == '23505';
}
