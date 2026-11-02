import 'message_model.dart';

/// The other person in a one-to-one chat.
class ChatParticipant {
  final String userID;
  final String displayName;
  final String role; // 'job_seeker', 'employer', 'admin'
  final String? photoUrl;

  const ChatParticipant({
    required this.userID,
    required this.displayName,
    required this.role,
    this.photoUrl,
  });

  String get initial =>
      displayName.trim().isEmpty ? 'U' : displayName.trim()[0].toUpperCase();

  /// "Job Seeker", "Employer", ...
  String get roleLabel {
    switch (role) {
      case 'job_seeker':
        return 'Job Seeker';
      case 'employer':
        return 'Employer';
      case 'admin':
        return 'Admin';
      default:
        return 'Member';
    }
  }
}

/// One row on the chat list: the room, who it's with, the latest message
/// and how many messages the current user hasn't read yet.
class ChatRoomModel {
  final String roomID;
  final ChatParticipant otherUser;
  final MessageModel? lastMessage;
  final int unreadCount;

  const ChatRoomModel({
    required this.roomID,
    required this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
  });

  DateTime? get lastActivity => lastMessage?.sentAt;

  /// Text for the list preview ("📷 Photo", "🎤 Voice message", ...).
  String previewText(String currentUserID) {
    final message = lastMessage;
    if (message == null) return 'Started a chat';
    final prefix = message.senderID == currentUserID ? 'You: ' : '';
    if (message.isDeleted) return '${prefix}Message deleted';
    switch (message.mediaType) {
      case 'image':
        return '$prefix📷 Photo';
      case 'audio':
        return '$prefix🎤 Voice message';
      case 'file':
        return '$prefix📎 ${message.content}';
      case 'call_log':
        return '📞 ${message.content.split('\n').join(' · ')}';
      default:
        return '$prefix${message.content}';
    }
  }

  ChatRoomModel copyWith({MessageModel? lastMessage, int? unreadCount}) {
    return ChatRoomModel(
      roomID: roomID,
      otherUser: otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
