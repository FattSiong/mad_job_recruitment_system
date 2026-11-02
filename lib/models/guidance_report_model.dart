/// One row of the GuidanceReport view (mock interviews + skill gap analyses).
class GuidanceReportItem {
  static const String typeMockInterview = 'mock_interview';
  static const String typeSkillGap = 'skill_gap';

  final String reportID; // sessionID or analysisID
  final String seekerID;
  final String type;     // mock_interview | skill_gap
  final String targetJobRole;
  final int? score;      // overall interview score or skill match %
  final DateTime createdAt;

  GuidanceReportItem({
    required this.reportID,
    required this.seekerID,
    required this.type,
    required this.targetJobRole,
    this.score,
    required this.createdAt,
  });

  bool get isMockInterview => type == typeMockInterview;
  bool get isSkillGap => type == typeSkillGap;

  String get typeLabel => isMockInterview ? 'Mock Interview' : 'Skill Gap Analysis';

  factory GuidanceReportItem.fromJson(Map<String, dynamic> json) {
    return GuidanceReportItem(
      reportID: json['reportID'] as String,
      seekerID: json['seekerID'] as String,
      type: json['type'] as String? ?? '',
      targetJobRole: json['targetJobRole'] as String? ?? '',
      score: (json['score'] as num?)?.round(),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }
}
