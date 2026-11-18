/// A seeker's report on a job post ("ReportedJob"), reviewed by the admins.
class ReportedJobModel {
  final String? reportID;
  final String jobID;
  final String reporterID; // the job seeker who reported the job
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
    required this.reporterID,
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
      reportID: json['reportJobID'] as String?, // the table's key column
      jobID: json['jobID'] as String,
      reporterID: json['reporterID'] as String,
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
      if (reportID != null) 'reportJobID': reportID,
      'jobID': jobID,
      'reporterID': reporterID,
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