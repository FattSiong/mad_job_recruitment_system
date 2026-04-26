class EducationModel {
  final String? educationID;
  final String? seekerID; // Nullable based on your SQL schema
  final String institutionName;
  final String degree;
  final String? fieldOfStudy;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isCurrent;
  final String? description;

  EducationModel({
    this.educationID,
    this.seekerID,
    required this.institutionName,
    required this.degree,
    this.fieldOfStudy,
    required this.startDate,
    this.endDate,
    this.isCurrent = false,
    this.description,
  });

  factory EducationModel.fromJson(Map<String, dynamic> json) {
    return EducationModel(
      educationID: json['educationID'] as String?,
      seekerID: json['seekerID'] as String?,
      institutionName: json['institutionName'] as String,
      degree: json['degree'] as String,
      fieldOfStudy: json['fieldOfStudy'] as String?,
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      isCurrent: json['isCurrent'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (seekerID != null) 'seekerID': seekerID,
      'institutionName': institutionName,
      'degree': degree,
      'fieldOfStudy': fieldOfStudy,
      'startDate': startDate.toIso8601String().split('T')[0],
      'endDate': isCurrent ? null : endDate?.toIso8601String().split('T')[0],
      'isCurrent': isCurrent,
      'description': description,
    };
  }
}