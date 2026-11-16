/// One message in an AI Career Advisor conversation ("AdvisorMessage").
class AdvisorMessageModel {
  final String messageID;
  final String conversationID;
  final String role; // 'user' or 'model'
  final String content;
  final DateTime createdAt;

  AdvisorMessageModel({
    required this.messageID,
    required this.conversationID,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  bool get isUser => role == 'user';

  factory AdvisorMessageModel.fromJson(Map<String, dynamic> json) {
    return AdvisorMessageModel(
      messageID: json['messageID'] as String,
      conversationID: json['conversationID'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }

  /// Temporary message shown immediately while waiting for the AI reply.
  factory AdvisorMessageModel.pending(String content) {
    return AdvisorMessageModel(
      messageID: 'pending_${DateTime.now().microsecondsSinceEpoch}',
      conversationID: '',
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );
  }
}
