class JobApplicantModel {
  final String? applicantID;
  final String jobID;
  final String seekerID;
  final String submittedResumeURL;
  final String applicationStatus;
  final double? aiRankingScore;
  final String? aiFeedback;
  final DateTime? appliedAt;

  JobApplicantModel({
    this.applicantID,
    required this.jobID,
    required this.seekerID,
    required this.submittedResumeURL,
    required this.applicationStatus,
    this.aiRankingScore,
    this.aiFeedback,
    this.appliedAt,
  });

  factory JobApplicantModel.fromJson(Map<String, dynamic> json) {
    return JobApplicantModel(
      applicantID: json['applicantID'] as String?,
      jobID: json['jobID'] as String,
      seekerID: json['seekerID'] as String,
      submittedResumeURL: json['submittedResumeURL'] as String,
      applicationStatus: json['applicationStatus'] as String,
      // Using 'num?' before converting to double safely handles if Supabase returns a whole number like '5' instead of '5.0'
      aiRankingScore: (json['aiRankingScore'] as num?)?.toDouble(),
      aiFeedback: json['aiFeedback'] as String?,
      appliedAt: json['appliedAt'] != null ? DateTime.parse(json['appliedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (applicantID != null) 'applicantID': applicantID,
      'jobID': jobID,
      'seekerID': seekerID,
      'submittedResumeURL': submittedResumeURL,
      'applicationStatus': applicationStatus,
      if (aiRankingScore != null) 'aiRankingScore': aiRankingScore,
      if (aiFeedback != null) 'aiFeedback': aiFeedback,
      if (appliedAt != null) 'appliedAt': appliedAt!.toIso8601String(),
    };
  }
}