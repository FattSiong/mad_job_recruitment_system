import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/job_applicant_model.dart';
import '../../../models/job_model.dart';

class AppliedJobsController {
  final _supabase = Supabase.instance.client;
  String get _currentSeekerID => Supabase.instance.client.auth.currentUser!.id;

  /// Fetches all jobs the user has applied for
  Future<List<Map<String, dynamic>>> fetchAppliedJobs() async {
    try {
      final response = await _supabase
          .from('JobApplicant')
          .select('*, Job (*, Company(name))')
          .eq('seekerID', _currentSeekerID)
          .order('appliedAt', ascending: false);

      return (response as List<dynamic>).map((json) {
        final row = json as Map<String, dynamic>;
        final jobJson = row['Job'] as Map<String, dynamic>?;
        final job = jobJson != null ? JobModel.fromJson(jobJson) : null;

        final jobStatus = job?.status.trim().toLowerCase() ?? 'deleted';
        final isJobDeleted = job == null || jobStatus == 'deleted';
        final isJobInactive = jobStatus == 'inactive';

        return {
          'application': JobApplicantModel.fromJson(row),
          'job': job,
          'jobStatus': jobStatus,
          'isJobDeleted': isJobDeleted,
          'isJobInactive': isJobInactive,
        };
      }).toList();
    } catch (e) {
      print('Error fetching applied jobs: $e');
      return [];
    }
  }
}