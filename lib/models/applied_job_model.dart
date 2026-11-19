import '../core/utils/app_date_format.dart';
import 'job_applicant_model.dart';
import 'job_model.dart';

/// One of the job seeker's applications with its job, and how My Jobs >
/// Applied shows it (a deleted or inactive job is shown as such).
class AppliedJob {
  final JobApplicantModel application;

  /// Null when the job was deleted.
  final JobModel? job;
  final bool isJobDeleted;
  final bool isJobInactive;

  const AppliedJob({
    required this.application,
    required this.job,
    required this.isJobDeleted,
    required this.isJobInactive,
  });

  /// Builds it from a JobApplicant row with its `Job (*, Company(name))`.
  factory AppliedJob.fromJson(Map<String, dynamic> row) {
    final jobJson = row['Job'] as Map<String, dynamic>?;
    final job = jobJson != null ? JobModel.fromJson(jobJson) : null;
    final jobStatus = job?.status.trim().toLowerCase() ?? 'deleted';
    return AppliedJob(
      application: JobApplicantModel.fromJson(row),
      job: job,
      isJobDeleted: job == null || jobStatus == 'deleted',
      isJobInactive: jobStatus == 'inactive',
    );
  }

  /// The application status in lower case ("pending", "offered", ...).
  String get status => application.applicationStatus.trim().toLowerCase();

  bool get isOffered => status == 'offered';

  /// An offer was made (whatever the answer): the job stays visible even
  /// if the employer made it inactive afterwards.
  bool get _hasOfferStage => isOffered || status == 'accepted' || status == 'offer_declined';

  /// The job can't be opened any more (deleted, or inactive before an offer).
  bool get isUnavailable => isJobDeleted || (isJobInactive && !_hasOfferStage);

  /// Status used for the badge colour ("deleted" / "inactive" for gone jobs).
  String get badgeStatus => isJobDeleted ? 'deleted' : (isUnavailable ? 'inactive' : status);

  /// Badge text ("OFFER RECEIVED", "JOB INACTIVE", "PENDING", ...).
  String get badgeLabel {
    if (isJobDeleted) return 'JOB DELETED';
    if (isUnavailable) return 'JOB INACTIVE';
    return switch (status) {
      'offered' => 'OFFER RECEIVED',
      'accepted' => 'OFFER ACCEPTED',
      'offer_declined' => 'OFFER DECLINED',
      _ => application.applicationStatus.toUpperCase(),
    };
  }

  String get title => isJobDeleted ? 'Deleted Job Post' : (job?.title ?? 'Unknown Job');

  /// Company name, or why the job isn't available.
  String get subtitle {
    if (isJobDeleted) return 'This posting is no longer available';
    if (isUnavailable) return 'This job posting is inactive';
    return job?.companyName ?? 'Unknown Company';
  }

  String get companyName => job?.companyName ?? 'Company';

  /// "18 Nov 2026" (or "Unknown date").
  String get appliedDateText {
    final appliedAt = application.appliedAt;
    return appliedAt == null ? 'Unknown date' : AppDateFormat.day.format(appliedAt.toLocal());
  }

  /// True when there are offer details worth showing.
  bool get hasOfferDetails {
    bool has(String? s) => (s ?? '').trim().isNotEmpty;
    return isOffered || has(application.offerSalary) || has(application.offerMessage) || has(application.offerLetterURL);
  }
}
