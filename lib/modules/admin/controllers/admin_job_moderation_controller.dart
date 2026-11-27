import 'package:flutter/foundation.dart';

import '../../../core/constants/table_constants.dart';
import '../../../models/chat_room_model.dart';
import '../../../models/job_moderation_item_model.dart';
import '../../../services/user_directory.dart';
import 'moderation_list_controller.dart';
import 'moderation_query_utils.dart';

/// Admin > Jobs: reported and all job posts, and the admin's actions on
/// them (dismiss the reports, or remove the job). Lists, search, sort and
/// the actions' flow come from [ModerationListController].
///
/// The database functions are in migration 20261118000000.
class AdminJobModerationController extends ModerationListController<JobModerationItem> {
  static const String _jobColumns =
      'jobID, companyID, employerID, title, description, salaryRange, status, createdAt, jobType, '
      'minExperienceYears, locationName, expiresAt, workplaceType, workingPeriod, qualification, '
      'vacancies, latitude, longitude, Company(name)';
  static const String _reportColumns =
      'reportJobID, jobID, reporterID, reportCategory, additionalDetails, reportedAt';

  final Map<String, ({List<String> companies, List<String> employers})> _nameMatches = {};
  int _reportedJobs = 0;

  /// Jobs with open reports (for the header and the badge).
  int get reportedJobs => _reportedJobs;

  @override
  String get logName => 'Admin jobs';

  @override
  String get loadErrorMessage => 'Unable to load job posts. Please check your connection and try again.';

  @override
  String get notAdminMessage => 'Only admins can moderate job posts.';

  @override
  String get migrationNames => 'migration 20261118000000';

  @override
  String idOf(JobModerationItem item) => item.id;

  @override
  JobModerationItem withoutReports(JobModerationItem item) => item.withoutReports();

  @override
  String goneMessage(JobModerationItem item) => 'This job no longer exists.';

  @override
  List<JobModerationItem> searchAndSortReported(
    List<JobModerationItem> items,
    String search,
    ModerationSort sort,
  ) =>
      JobModerationItem.searchAndSortReported(items, search, sort);

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  /// How many jobs have open reports, the same way the dashboard counts
  /// them (failures only logged).
  @override
  Future<void> loadCounts() async {
    try {
      final rows = await supabase.from(TableConstants.reportedJob).select('jobID').eq('status', 'pending');
      _reportedJobs = List<Map<String, dynamic>>.from(rows).map((r) => r['jobID'].toString()).toSet().length;
      notifySafely();
    } catch (e) {
      debugPrint('Admin jobs count failed: $e');
    }
  }

  /// Jobs with open reports, in order of their newest report. Jobs that
  /// were already removed are kept, so their leftover reports can be closed.
  @override
  Future<ModerationPage<JobModerationItem>> loadReported() async {
    final reportRows = await newestOpenReports(TableConstants.reportedJob, _reportColumns);
    final capped = reportRows.length >= ModerationListController.maxReports;

    final ids = uniqueIdsInOrder(reportRows, 'jobID');
    if (ids.isEmpty) return ModerationPage<JobModerationItem>(const [], capped: capped);

    final jobRows = <Map<String, dynamic>>[];
    for (final chunk in chunkIds(ids)) {
      jobRows.addAll(List<Map<String, dynamic>>.from(
          await supabase.from(TableConstants.job).select(_jobColumns).inFilter('jobID', chunk)));
    }
    final byId = {for (final r in jobRows) r['jobID'].toString(): r};
    final items = await _build([for (final id in ids) if (byId[id] != null) byId[id]!], reportRows);
    return ModerationPage<JobModerationItem>(items, capped: capped);
  }

  /// One page of jobs that are not removed, by time (newest or oldest
  /// first), older / newer than [before].
  @override
  Future<ModerationPage<JobModerationItem>> loadPage({ModerationCursor? before}) async {
    final text = cleanModerationSearch(search);
    final query = supabase.from(TableConstants.job).select(_jobColumns).neq('status', 'deleted');

    String? searchOr;
    if (text.isNotEmpty) {
      // Title, description or place, or the company / employer name
      final names = await _namesMatching(text);
      searchOr = [
        'title.ilike.*$text*',
        'description.ilike.*$text*',
        'locationName.ilike.*$text*',
        if (names.companies.isNotEmpty) 'companyID.in.(${names.companies.join(',')})',
        if (names.employers.isNotEmpty) 'employerID.in.(${names.employers.join(',')})',
      ].join(',');
    }
    final rows = await readPage(query, before, idColumn: 'jobID', searchOr: searchOr);
    if (rows.isEmpty) return ModerationPage<JobModerationItem>(const []);

    final ids = rows.map((r) => r['jobID'].toString()).toList();
    final reportRows = await openReportsFor(TableConstants.reportedJob, _reportColumns, 'jobID', ids);
    return pageOf(await _build(rows, reportRows), rows, idColumn: 'jobID');
  }

  /// Turns job rows into items, with employer / reporter names and the
  /// reports on each job.
  Future<List<JobModerationItem>> _build(
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> reportRows,
  ) async {
    final people = await UserDirectory.fetch([
      ...rows.map((r) => r['employerID']?.toString() ?? ''),
      ...reportRows.map((r) => r['reporterID']?.toString() ?? ''),
    ]);
    ChatParticipant person(String id, String role) =>
        people[id] ?? ChatParticipant(userID: id, displayName: 'Unknown user', role: role);

    final reportsByJob = <String, List<ContentReport>>{};
    for (final r in reportRows) {
      reportsByJob.putIfAbsent(r['jobID'].toString(), () => []).add(ContentReport.fromJson(
            r,
            idColumn: 'reportJobID',
            reporter: person(r['reporterID']?.toString() ?? '', 'job_seeker'),
          ));
    }

    final items = <JobModerationItem>[];
    for (final r in rows) {
      try {
        items.add(JobModerationItem.fromJson(
          r,
          employer: person(r['employerID']?.toString() ?? '', 'employer'),
          reports: reportsByJob[r['jobID'].toString()] ?? const [],
        ));
      } catch (e) {
        debugPrint('Admin jobs: skipped a job that could not be read ($e)'); // e.g. missing title
      }
    }
    return items;
  }

  /// Company and employer IDs whose name contains [text] (at most 50
  /// each; remembered while the screen is open).
  Future<({List<String> companies, List<String> employers})> _namesMatching(String text) async {
    final key = text.toLowerCase();
    final known = _nameMatches[key];
    if (known != null) return known;

    final found = await Future.wait([
      idsWithName(TableConstants.company, 'companyID', 'name', text),
      idsWithName(TableConstants.employer, 'employerID', 'fullName', text),
    ]);
    final result = (companies: found[0], employers: found[1]);
    _nameMatches[key] = result;
    return result;
  }

  // ---------------------------------------------------------------------
  // Actions (database functions)
  // ---------------------------------------------------------------------

  @override
  Future<int> closeReports(JobModerationItem item, String? note) async {
    final closed = await supabase.rpc('admin_dismiss_job_reports', params: {
      'p_job_id': item.id,
      'p_note': note,
    });
    return (closed as num? ?? 0).toInt();
  }

  /// Hides the job from everyone and closes its reports. With [notify] the
  /// employer gets the report reasons (not the note) and everyone with an
  /// open application is told the job is gone.
  @override
  Future<void> removeItem(JobModerationItem item, String? note, bool notify) async {
    await supabase.rpc('admin_remove_job', params: {
      'p_job_id': item.id,
      'p_note': note,
      'p_notify': notify,
    });
  }
}
