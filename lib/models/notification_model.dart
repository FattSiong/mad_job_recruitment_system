class NotificationModel {
  final String notificationID;
  final String userID;
  final String type;
  final String title;
  final String body;
  final String? jobID;
  final String? applicantID;
  final String? scheduleID;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.notificationID,
    required this.userID,
    required this.type,
    required this.title,
    required this.body,
    this.jobID,
    this.applicantID,
    this.scheduleID,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawJobId = json['jobID']?.toString().trim();
    final rawApplicantId = json['applicantID']?.toString().trim();
    final rawScheduleId = json['scheduleID']?.toString().trim();
    final rawCreatedAt = json['createdAt']?.toString() ?? '';

    return NotificationModel(
      notificationID: (json['notificationID'] ?? '').toString(),
      userID: (json['userID'] ?? '').toString(),
      type: (json['type'] ?? 'recruitment_update').toString(),
      title: (json['title'] ?? 'Recruitment Update').toString(),
      body: (json['body'] ?? '').toString(),
      jobID: (rawJobId != null && rawJobId.isNotEmpty) ? rawJobId : null,
      applicantID:
          (rawApplicantId != null && rawApplicantId.isNotEmpty)
              ? rawApplicantId
              : null,
      scheduleID:
          (rawScheduleId != null && rawScheduleId.isNotEmpty)
              ? rawScheduleId
              : null,
      isRead: json['isRead'] == true,
      createdAt:
          DateTime.tryParse(rawCreatedAt)?.toLocal() ?? DateTime.now(),
    );
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      notificationID: notificationID,
      userID: userID,
      type: type,
      title: title,
      body: body,
      jobID: jobID,
      applicantID: applicantID,
      scheduleID: scheduleID,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  /// An admin removed the user's community post or comment.
  bool get isCommunityNotice => type == 'community_post_removed' || type == 'community_comment_removed';

  /// An admin removed something the user posted (community post / comment,
  /// or an employer's job post): the message says it all, nothing to open.
  bool get isModerationNotice => isCommunityNotice || type == 'job_removed';

  /// True when the notification targets an Employer (e.g. new application, interview response, offer response).
  bool get isEmployerEvent {
    switch (type) {
      case 'new_application':
      case 'interview_accepted':
      case 'interview_declined':
      case 'offer_accepted':
      case 'offer_declined':
        return true;
      default:
        return false;
    }
  }

  /// True when the notification is related to an interview schedule / video room for a Job Seeker.
  bool get isInterviewTabEvent {
    switch (type) {
      case 'interview_scheduled':
      case 'interview_live':
        return true;
      default:
        return false;
    }
  }
}
