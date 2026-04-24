import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/job_applicant_model.dart'; // 👉 New Model
import '../../../models/job_model.dart';           // 👉 New Model

class AppliedJobsController {
  final _supabase = Supabase.instance.client;
  final String _mockSeekerID = '773ed23f-95ca-4853-ae50-06bd5e411bad';

  /// Fetches all jobs the user has applied for
  Future<List<Map<String, dynamic>>> fetchAppliedJobs() async {
    try {
      final response = await _supabase
          .from('JobApplicant')
          .select('*, Job (*, Company(name))') // Added wildcard '*' to get all Applicant fields
          .eq('seekerID', _mockSeekerID)
          .order('appliedAt', ascending: false);

      // 👉 Converts the raw JSON into secure Dart Models
      return (response as List<dynamic>).map((json) {
        return {
          'application': JobApplicantModel.fromJson(json as Map<String, dynamic>),
          'job': JobModel.fromJson(json['Job'] as Map<String, dynamic>),
        };
      }).toList();

    } catch (e) {
      print('Error fetching applied jobs: $e');
      return [];
    }
  }
}