import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/salary_utils.dart';
import '../../../models/job_model.dart';
import '../../../core/constants/table_constants.dart';

/// Search options for the Home job list. Kept together so "load more"
/// continues with exactly the same search the first page used.
class JobSearchFilters {
  final String query;
  final String location;
  final String? jobType;
  final String? datePosted;
  final String? salary;

  const JobSearchFilters({
    this.query = '',
    this.location = '',
    this.jobType,
    this.datePosted,
    this.salary,
  });
}

/// One page of results.
class JobsPage {
  final List<JobModel> jobs;

  /// Row offset to pass for the next page.
  final int nextOffset;

  /// False when the database has no more matching rows.
  final bool hasMore;

  const JobsPage({required this.jobs, required this.nextOffset, required this.hasMore});
}

class JobDiscoveryController {
  final _supabase = Supabase.instance.client;

  static const String _loadError =
      'Unable to load jobs. Please check your connection and try again.';

  /// Rows fetched per round when a salary filter is active (salary is free text,
  /// so it's checked in Dart and some rows of each round may be filtered out).
  static const int _salaryBatchSize = 30;
  static const int _maxRoundsPerPage = 5;

  /// Expiry condition: no expiry date, or expiry date still in the future.
  /// Expired jobs are marked inactive on the server by the
  /// `deactivate-expired-jobs` schedule (pg_cron), not by the seeker app.
  String _notExpiredCondition() =>
      'or(expiresAt.is.null,expiresAt.gt.${DateTime.now().toUtc().toIso8601String()})';

  /// Keeps characters that are safe inside a PostgREST filter string.
  static String sanitizeKeyword(String input) => input
      .replaceAll(RegExp(r'[^A-Za-z0-9\s+#&/-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// IDs of companies whose name contains [keyword], so the keyword search can
  /// match company names in the same database query.
  Future<List<String>> _companyIdsMatching(String keyword) async {
    final rows = await _supabase
        .from(TableConstants.company)
        .select('companyID')
        .ilike('name', '%$keyword%')
        .limit(50);
    return (rows as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['companyID'] as String)
        .toList();
  }

  /// One "or" filter that holds the expiry condition and, if given, the keyword
  /// search, joined with AND. A single nested filter avoids sending two
  /// separate "or" parameters.
  String _combinedFilter(String keyword, List<String> companyIds) {
    final expiry = _notExpiredCondition();
    if (keyword.isEmpty) return 'and($expiry)';

    final keywordParts = [
      'title.ilike.%$keyword%',
      'description.ilike.%$keyword%',
      if (companyIds.isNotEmpty) 'companyID.in.(${companyIds.join(',')})',
    ];
    return 'and($expiry,or(${keywordParts.join(',')}))';
  }

  DateTime? _dateFrom(String? datePosted) {
    final now = DateTime.now();
    switch (datePosted) {
      case 'Last 24 hours':
        return now.subtract(const Duration(hours: 24));
      case 'Last 3 days':
        return now.subtract(const Duration(days: 3));
      case 'Last 7 days':
        return now.subtract(const Duration(days: 7));
      case 'Last 14 days':
        return now.subtract(const Duration(days: 14));
      default:
        return null;
    }
  }

  /// Loads one page of active, non-expired jobs, newest first.
  ///
  /// Everything except the salary filter is done by the database, and only
  /// [pageSize] rows are downloaded at a time (the old version downloaded every job).
  /// When a salary filter is set, rows are fetched in batches and checked with
  /// [SalaryUtils] until the page is full or there are no more rows.
  Future<JobsPage> fetchJobsPage({
    JobSearchFilters filters = const JobSearchFilters(),
    int offset = 0,
    int pageSize = 10,
  }) async {
    try {
      final keyword = sanitizeKeyword(filters.query);
      final companyIds = keyword.isEmpty ? <String>[] : await _companyIdsMatching(keyword);
      final combinedFilter = _combinedFilter(keyword, companyIds);
      final location = filters.location.trim();
      final fromDate = _dateFrom(filters.datePosted);
      final salaryActive = SalaryUtils.minimumFromFilter(filters.salary) != null;
      final batchSize = salaryActive ? _salaryBatchSize : pageSize;

      final collected = <JobModel>[];
      var cursor = offset;
      var hasMore = true;
      var rounds = 0;

      while (collected.length < pageSize && hasMore && rounds < _maxRoundsPerPage) {
        var query = _supabase
            .from(TableConstants.job)
            .select('*, Company(name)')
            .eq('status', 'active')
            .or(combinedFilter);

        if (location.isNotEmpty) {
          query = query.ilike('locationName', '%${sanitizeKeyword(location)}%');
        }
        if (filters.jobType != null && filters.jobType != 'All') {
          query = query.eq('jobType', filters.jobType!);
        }
        if (fromDate != null) {
          query = query.gte('createdAt', fromDate.toUtc().toIso8601String());
        }

        final rows = await query
            .order('createdAt', ascending: false)
            .order('jobID', ascending: true) // stable order between pages
            .range(cursor, cursor + batchSize - 1);

        final list = rows as List<dynamic>;
        cursor += list.length;
        hasMore = list.length == batchSize;
        rounds++;

        collected.addAll(
          list
              .map((j) => JobModel.fromJson(j as Map<String, dynamic>))
              .where((job) => SalaryUtils.meetsMinimum(job.salaryRange, filters.salary)),
        );
      }

      return JobsPage(jobs: collected, nextOffset: cursor, hasMore: hasMore);
    } catch (e) {
      debugPrint('Error fetching jobs page: $e');
      throw DataLoadException(_loadError);
    }
  }
}
