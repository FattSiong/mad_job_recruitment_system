class JobModel {
  final String? jobID; // Nullable because Supabase generates this when inserting
  final String companyID;
  final String employerID;
  final String title;
  final String description;
  final double? latitude;
  final double? longitude;
  final String salaryRange;
  final String status; // e.g., 'active', 'draft', 'archived'
  final DateTime? createdAt;
  final int minExperienceYears;
  final String jobType;

  JobModel({
    this.jobID,
    required this.companyID,
    required this.employerID,
    required this.title,
    required this.description,
    this.latitude,
    this.longitude,
    required this.salaryRange,
    this.status = 'active',
    this.createdAt,
    this.minExperienceYears = 0,
    this.jobType = 'Full-ime',
  });

  // 1. Convert from Supabase JSON to Dart Object (When reading data)
  factory JobModel.fromJson(Map<String, dynamic> json) {
    return JobModel(
      jobID: json['jobID'] as String?,
      companyID: json['companyID'] as String,
      employerID: json['employerID'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      salaryRange: json['salaryRange'] as String,
      status: json['status'] as String,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      minExperienceYears: json['minExperienceYears'] as int? ?? 0,
      jobType: json['jobType'] as String? ?? 'Full-time',
    );
  }

  // 2. Convert from Dart Object to Supabase JSON (When inserting data)
  Map<String, dynamic> toJson() {
    return {
      'companyID': companyID,
      'employerID': employerID,
      'title': title,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'salaryRange': salaryRange,
      'status': status,
      'minExperienceYears': minExperienceYears,
      'jobType': jobType,
    }; // Notice we don't send jobID or createdAt; Supabase handles those automatically!
  }
}