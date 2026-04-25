import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/job_model.dart';

class JobDiscoveryController {
  final _supabase = Supabase.instance.client;

  // Helper method to extract the highest number from a salary string
  double _extractMaxSalary(String text) {
    String cleanText = text.replaceAll(',', ''); // Remove commas
    Iterable<Match> matches = RegExp(r'\d+(\.\d+)?').allMatches(cleanText);

    if (matches.isEmpty) return 0;

    double maxSalary = 0;
    for (Match match in matches) {
      double? val = double.tryParse(match.group(0) ?? '');
      if (val != null && val > maxSalary) {
        maxSalary = val;
      }
    }
    return maxSalary;
  }

  Future<List<JobModel>> fetchActiveJobs() async {
    try {
      final response = await _supabase
          .from('Job')
          .select('*, Company(name)')
          .eq('status', 'active')
          .order('createdAt', ascending: false);

      return (response as List<dynamic>)
          .map((jobJson) => JobModel.fromJson(jobJson as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Unexpected Error fetching jobs: $e');
      return [];
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
      // 1. Supabase Database Filtering
      var queryBuilder = _supabase
          .from('Job')
          .select('*, Company(name)')
          .eq('status', 'active');

      if (query.isNotEmpty) {
        queryBuilder = queryBuilder.or('title.ilike.%$query%,description.ilike.%$query%');
      }

      // 👉 Supabase directly filters the locationName column here!
      if (location.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('locationName', '%$location%');
      }

      if (jobType != null && jobType != 'All') {
        queryBuilder = queryBuilder.eq('jobType', jobType);
      }

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

      // 2. Client-Side Filtering (NOW ONLY FOR SALARY)
      if (salary != null && salary != 'Any') {
        return jobs.where((job) {
          double targetSalary = _extractMaxSalary(salary); // The filter number
          double jobMaxSalary = _extractMaxSalary(job.salaryRange); // The job's number
          return jobMaxSalary >= targetSalary;
        }).toList();
      }

      return jobs;
    } catch (e) {
      print('Unexpected Error searching jobs: $e');
      return [];
    }
  }
}