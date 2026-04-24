import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/reported_job_model.dart'; // 👉 Import the model

class ReportController {
  final _supabase = Supabase.instance.client;
  final String _mockSeekerID = '773ed23f-95ca-4853-ae50-06bd5e411bad';

  Future<bool> submitJobReport({
    required String jobId,
    required String category,
    String? details,
  }) async {
    try {
      // 1. Package the data into the Model
      final newReport = ReportedJobModel(
        jobID: jobId,
        seekerID: _mockSeekerID,
        reportCategory: category,
        additionalDetails: (details != null && details.trim().isNotEmpty) ? details.trim() : null,
      );

      // 2. Insert using toJson()
      await _supabase.from('ReportedJob').insert(newReport.toJson());

      return true;
    } catch (e) {
      print('Error submitting report: $e');
      return false;
    }
  }
}