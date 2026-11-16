/// One chat message ("Message").
class MessageModel {
  /// How long after sending the sender may still edit a text message
  /// (the database checks this too).
  static const Duration editWindow = Duration(minutes: 2);

  final String messageID;
  final String roomID;
  final String senderID;
  final String content;
  final bool isRead;
  final DateTime sentAt;
  final String? mediaURL;
  final String? mediaType; // 'text', 'image', 'file', 'audio' or 'call_log'
  final bool isDeleted;

  /// When the sender last changed the text (null = never). Set by the database.
  final DateTime? editedAt;

  MessageModel({
    required this.messageID,
    required this.roomID,
    required this.senderID,
    required this.content,
    required this.isRead,
    required this.sentAt,
    this.mediaURL,
    this.mediaType,
    this.isDeleted = false,
    this.editedAt,
  });

  /// The text was changed after sending (shows "Edited").
  bool get isEdited => editedAt != null && !isDeleted;

  /// [userID] may still edit this message at [now]: their own text message,
  /// not deleted, sent less than [editWindow] ago.
  bool canBeEditedBy(String userID, {DateTime? now}) =>
      senderID == userID &&
      !isDeleted &&
      (mediaType ?? 'text') == 'text' &&
      (now ?? DateTime.now()).difference(sentAt) < editWindow;

  /// A copy with new text (and edit time) or marked as deleted.
  MessageModel copyWith({String? content, DateTime? editedAt, bool? isDeleted, bool clearMedia = false}) =>
      MessageModel(
        messageID: messageID,
        roomID: roomID,
        senderID: senderID,
        content: content ?? this.content,
        isRead: isRead,
        sentAt: sentAt,
        mediaURL: clearMedia ? null : mediaURL,
        mediaType: mediaType,
        isDeleted: isDeleted ?? this.isDeleted,
        editedAt: editedAt ?? this.editedAt,
      );

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      messageID: json['messageID'],
      roomID: json['roomID'],
      senderID: json['senderID'],
      content: json['content']?.toString() ?? '',
      isRead: json['isRead'] ?? false,
      sentAt: DateTime.parse(json['sentAt']),
      mediaURL: json['mediaURL'],
      mediaType: json['mediaType'] ?? 'text',
      isDeleted: json['isDeleted'] ?? false,
      editedAt: json['editedAt'] == null ? null : DateTime.tryParse(json['editedAt'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // Made on the phone, so a resend can never create the message twice
      // (Supabase makes one if it is empty).
      if (messageID.isNotEmpty) 'messageID': messageID,
      'roomID': roomID,
      'senderID': senderID,
      'content': content,
      'isRead': isRead,
      'mediaURL': mediaURL,
      'mediaType': mediaType,
    };
  }
}
