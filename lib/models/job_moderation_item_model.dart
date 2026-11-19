import 'chat_room_model.dart';
import 'content_report_model.dart';
import 'job_model.dart';

export 'content_report_model.dart';

/// A job post in Admin > Jobs, with its open reports.
class JobModerationItem with ReportSummary {
  final JobModel job;

  /// The employer who posted it (name from UserDirectory).
  final ChatParticipant employer;

  /// Open ("pending") reports, newest first.
  @override
  final List<ContentReport> reports;

  const JobModerationItem({required this.job, required this.employer, this.reports = const []});

  String get id => job.jobID ?? '';
  String get title => job.title.trim().isEmpty ? 'Untitled job' : job.title.trim();
  String get companyName => (job.companyName?.trim().isNotEmpty ?? false) ? job.companyName!.trim() : 'Unknown company';
  String get status => job.status.trim().toLowerCase();

  /// Already removed (by an admin or the employer); only leftover reports
  /// may need closing.
  bool get isRemoved => status == 'deleted';

  /// Shown as "EXPIRED" when an active job's end date has passed.
  String get statusLabel {
    if (isRemoved) return 'REMOVED';
    if (status == 'active' && job.isExpired) return 'EXPIRED';
    return status.isEmpty ? 'UNKNOWN' : status.toUpperCase();
  }

  /// Where and how: "Kuala Lumpur · Hybrid · Full-time".
  String get workSummary => [
        if (job.locationName?.trim().isNotEmpty ?? false) job.locationName!.trim(),
        job.workplaceType,
        job.jobType,
      ].where((s) => s.trim().isNotEmpty).join(' · ');

  /// True if [query] (lower case) is in the title, description, company,
  /// employer, location, or a report's reason, details or reporter.
  bool matches(String query) {
    bool has(String? text) => text != null && text.toLowerCase().contains(query);
    return has(job.title) ||
        has(job.description) ||
        has(job.companyName) ||
        has(employer.displayName) ||
        has(job.locationName) ||
        reportsMatch(query);
  }

  /// The Reported list: items matching [search], in the [sort] order.
  static List<JobModerationItem> searchAndSortReported(
    Iterable<JobModerationItem> items,
    String search,
    ModerationSort sort,
  ) {
    final q = search.trim().toLowerCase();
    final list = q.isEmpty ? items.toList() : items.where((i) => i.matches(q)).toList();
    return sortByReports(list, sort);
  }

  /// Same job without its reports (after they were dismissed).
  JobModerationItem withoutReports() => JobModerationItem(job: job, employer: employer);

  /// A "Job" row with "Company(name)".
  factory JobModerationItem.fromJson(
    Map<String, dynamic> json, {
    required ChatParticipant employer,
    List<ContentReport> reports = const [],
  }) =>
      JobModerationItem(job: JobModel.fromJson(json), employer: employer, reports: reports);
}
