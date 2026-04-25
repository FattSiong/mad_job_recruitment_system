class WorkExperienceModel {
  final String? experienceID;
  final String seekerID;
  final String companyName;
  final String jobTitle;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isCurrent;
  final String? description;

  WorkExperienceModel({
    this.experienceID,
    required this.seekerID,
    required this.companyName,
    required this.jobTitle,
    required this.startDate,
    this.endDate,
    this.isCurrent = false,
    this.description,
  });

  factory WorkExperienceModel.fromJson(Map<String, dynamic> json) {
    return WorkExperienceModel(
      experienceID: json['experienceID'] as String?,
      seekerID: json['seekerID'] as String,
      companyName: json['companyName'] as String,
      jobTitle: json['jobTitle'] as String,
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      isCurrent: json['isCurrent'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seekerID': seekerID,
      'companyName': companyName,
      'jobTitle': jobTitle,
      'startDate': startDate.toIso8601String().split('T')[0], // Save as YYYY-MM-DD
      'endDate': isCurrent ? null : endDate?.toIso8601String().split('T')[0],
      'isCurrent': isCurrent,
      'description': description,
    };
  }
}