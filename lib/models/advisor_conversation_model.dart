/// One AI Career Advisor conversation ("AdvisorConversation").
class AdvisorConversationModel {
  final String conversationID;
  final String seekerID;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  AdvisorConversationModel({
    required this.conversationID,
    required this.seekerID,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdvisorConversationModel.fromJson(Map<String, dynamic> json) {
    return AdvisorConversationModel(
      conversationID: json['conversationID'] as String,
      seekerID: json['seekerID'] as String,
      title: json['title'] as String? ?? 'New conversation',
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }
}
