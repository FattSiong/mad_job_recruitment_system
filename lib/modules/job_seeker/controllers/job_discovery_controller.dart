import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/job_model.dart';

class JobDiscoveryController {
  final _supabase = Supabase.instance.client;

  Future<List<JobModel>> fetchActiveJobs() async {
    try {
      final response = await _supabase
          .from('Job')
          .select('*, Company(name)')
          .eq('status', 'active')
          .order('createdAt', ascending: false);

      final List<JobModel> jobs = (response as List<dynamic>)
          .map((jobJson) => JobModel.fromJson(jobJson as Map<String, dynamic>))
          .toList();

      return jobs;
    } catch (e) {
      print('Unexpected Error fetching jobs: $e');
      return [];
    }
  }

  Future<List<JobModel>> searchJobs(String query) async {
    try {
      final response = await _supabase
          .from('Job')
      // 👉 Updated to perform the JOIN
          .select('*, Company(name)')
          .eq('status', 'active')
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order('createdAt', ascending: false);

      return (response as List<dynamic>)
          .map((jobJson) => JobModel.fromJson(jobJson as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Unexpected Error searching jobs: $e');
      return [];
    }
  }
}