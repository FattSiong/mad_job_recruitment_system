import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/salary_utils.dart';
import '../../../models/job_model.dart';

class JobDiscoveryController {
  final _supabase = Supabase.instance.client;

  static const String _loadError =
      'Unable to load jobs. Please check your connection and try again.';

  /// PostgREST filter: no expiry date, or expiry date still in the future.
  /// Expired jobs are marked inactive on the server by the
  /// `deactivate-expired-jobs` schedule (pg_cron), not by the seeker app.
  String get _notExpiredFilter =>
      'expiresAt.is.null,expiresAt.gt.${DateTime.now().toUtc().toIso8601String()}';

  Future<List<JobModel>> fetchActiveJobs() async {
    try {
      final response = await _supabase
          .from('Job')
          .select('*, Company(name)')
          .eq('status', 'active')
          .or(_notExpiredFilter)
          .order('createdAt', ascending: false);

      return (response as List<dynamic>)
          .map((jobJson) => JobModel.fromJson(jobJson as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching jobs: $e');
      throw DataLoadException(_loadError);
    }
  }

  Future<List<JobModel>> searchJobs({
    String query = '',
    String location = '',
    String? jobType,
    String? datePosted,
    String? salary,
  }) async {
    try {
      // ==========================================
      // 1. Supabase Database Filtering
      // ==========================================
      var queryBuilder = _supabase
          .from('Job')
          .select('*, Company(name)')
          .eq('status', 'active')
          .or(_notExpiredFilter);

      // 👉 Location Filter
      if (location.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('locationName', '%$location%');
      }

      // 👉 Job Type Filter
      if (jobType != null && jobType != 'All') {
        queryBuilder = queryBuilder.eq('jobType', jobType);
      }

      // 👉 Date Posted Filter
      if (datePosted != null && datePosted != 'All time') {
        DateTime filterDate = DateTime.now();
        if (datePosted == 'Last 24 hours') {
          filterDate = filterDate.subtract(const Duration(hours: 24));
        } else if (datePosted == 'Last 3 days') {
          filterDate = filterDate.subtract(const Duration(days: 3));
        } else if (datePosted == 'Last 7 days') {
          filterDate = filterDate.subtract(const Duration(days: 7));
        } else if (datePosted == 'Last 14 days') {
          filterDate = filterDate.subtract(const Duration(days: 14));
        }
        queryBuilder = queryBuilder.gte('createdAt', filterDate.toIso8601String());
      }

      final response = await queryBuilder.order('createdAt', ascending: false);
      List<JobModel> jobs = (response as List).map((j) => JobModel.fromJson(j)).toList();

      // ==========================================
      // 2. Client-Side Filtering
      // ==========================================

      // 👉 Keyword Search (Title, Description, & Company Name)
      if (query.isNotEmpty) {
        final String q = query.toLowerCase();
        jobs = jobs.where((job) {
          // 👉 Added ( ?? '') to safely handle null values before calling toLowerCase()
          final titleMatch = (job.title).toLowerCase().contains(q);
          final descMatch = (job.description).toLowerCase().contains(q);
          final companyMatch = (job.companyName ?? '').toLowerCase().contains(q);

          return titleMatch || descMatch || companyMatch;
        }).toList();
      }

      // 👉 Salary Filter (same rule as the Job Map, see SalaryUtils)
      jobs = jobs
          .where((job) => SalaryUtils.meetsMinimum(job.salaryRange, salary))
          .toList();

      return jobs;
    } catch (e) {
      debugPrint('Error searching jobs: $e');
      throw DataLoadException(_loadError);
    }
  }
}