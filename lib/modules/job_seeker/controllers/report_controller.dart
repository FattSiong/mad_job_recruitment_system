import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/reported_job_model.dart';
import '../../../core/constants/table_constants.dart';

class ReportController {
  final _supabase = Supabase.instance.client;
  String get _currentSeekerID => Supabase.instance.client.auth.currentUser!.id;

  Future<bool> submitJobReport({
    required String jobId,
    required String category,
    String? details,
  }) async {
    try {
      // 1. Package the data into the Model
      final newReport = ReportedJobModel(
        jobID: jobId,
        seekerID: _currentSeekerID,
        reportCategory: category,
        additionalDetails: (details != null && details.trim().isNotEmpty) ? details.trim() : null,
      );

      // 2. Insert using toJson()
      await _supabase.from(TableConstants.reportedJob).insert(newReport.toJson());

      return true;
    } catch (e) {
      debugPrint('Error submitting report: $e');
      return false;
    }
  }
}