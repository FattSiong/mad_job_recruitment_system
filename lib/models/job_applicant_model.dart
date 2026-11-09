class JobApplicantModel {
  final String? applicantID;
  final String jobID;
  final String seekerID;
  final String submittedResumeURL;
  final String applicationStatus;
  final double? aiRankingScore;
  final String? aiFeedback;
  final DateTime? appliedAt;
  final String? offerSalary;
  final DateTime? offerStartDate;
  final String? offerMessage;
  final String? offerLetterURL;
  final DateTime? offeredAt;
  final DateTime? offerRespondedAt;
  final String? offerDeclineReason;

  JobApplicantModel({
    this.applicantID,
    required this.jobID,
    required this.seekerID,
    required this.submittedResumeURL,
    required this.applicationStatus,
    this.aiRankingScore,
    this.aiFeedback,
    this.appliedAt,
    this.offerSalary,
    this.offerStartDate,
    this.offerMessage,
    this.offerLetterURL,
    this.offeredAt,
    this.offerRespondedAt,
    this.offerDeclineReason,
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
      appliedAt: json['appliedAt'] != null
          ? DateTime.tryParse(json['appliedAt'].toString())
          : null,
      offerSalary: json['offerSalary']?.toString(),
      offerStartDate: json['offerStartDate'] != null
          ? DateTime.tryParse(json['offerStartDate'].toString())
          : null,
      offerMessage: json['offerMessage']?.toString(),
      offerLetterURL: json['offerLetterURL']?.toString(),
      offeredAt: json['offeredAt'] != null
          ? DateTime.tryParse(json['offeredAt'].toString())
          : null,
      offerRespondedAt: json['offerRespondedAt'] != null
          ? DateTime.tryParse(json['offerRespondedAt'].toString())
          : null,
      offerDeclineReason: json['offerDeclineReason']?.toString(),
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
      if (offerSalary != null) 'offerSalary': offerSalary,
      if (offerStartDate != null)
        'offerStartDate': offerStartDate!.toIso8601String().split('T').first,
      if (offerMessage != null) 'offerMessage': offerMessage,
      if (offerLetterURL != null) 'offerLetterURL': offerLetterURL,
      if (offeredAt != null) 'offeredAt': offeredAt!.toIso8601String(),
      if (offerRespondedAt != null)
        'offerRespondedAt': offerRespondedAt!.toIso8601String(),
      if (offerDeclineReason != null) 'offerDeclineReason': offerDeclineReason,
    };
  }
}
