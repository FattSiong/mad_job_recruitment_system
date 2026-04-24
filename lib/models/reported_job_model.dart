class ReportedJobModel {
  final String? reportID;
  final String jobID;
  final String seekerID;
  final String reportCategory;
  final String? additionalDetails;
  final String? status;
  final DateTime? reportedAt;
  final DateTime? resolvedAt;
  final String? adminID;
  final String? adminNotes;

  ReportedJobModel({
    this.reportID,
    required this.jobID,
    required this.seekerID,
    required this.reportCategory,
    this.additionalDetails,
    this.status,
    this.reportedAt,
    this.resolvedAt,
    this.adminID,
    this.adminNotes,
  });

  factory ReportedJobModel.fromJson(Map<String, dynamic> json) {
    return ReportedJobModel(
      reportID: json['reportID'] as String?,
      jobID: json['jobID'] as String,
      seekerID: json['seekerID'] as String,
      reportCategory: json['reportCategory'] as String,
      additionalDetails: json['additionalDetails'] as String?,
      status: json['status'] as String?,
      reportedAt: json['reportedAt'] != null ? DateTime.parse(json['reportedAt'] as String) : null,
      resolvedAt: json['resolvedAt'] != null ? DateTime.parse(json['resolvedAt'] as String) : null,
      adminID: json['adminID'] as String?,
      adminNotes: json['adminNotes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (reportID != null) 'reportID': reportID,
      'jobID': jobID,
      'seekerID': seekerID,
      'reportCategory': reportCategory,
      if (additionalDetails != null) 'additionalDetails': additionalDetails,
      if (status != null) 'status': status,
      if (reportedAt != null) 'reportedAt': reportedAt!.toIso8601String(),
      if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
      if (adminID != null) 'adminID': adminID,
      if (adminNotes != null) 'adminNotes': adminNotes,
    };
  }
}