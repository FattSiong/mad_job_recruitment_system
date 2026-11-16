import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/reported_job_model.dart';
import '../../../core/constants/table_constants.dart';
import '../../../core/utils/session_helper.dart';

/// Outcome of reporting a job.
enum JobReportResult { submitted, alreadyReported, failed }

/// Reporting a job post to the admins.
class ReportController {
  final _supabase = Supabase.instance.client;

  /// Longest "Additional details" text (the form shows a counter).
  static const int maxDetailsLength = 500;
  String get _currentSeekerID => SessionHelper.requireUserId();

  /// Sends a report on a job to the admins. A seeker can have only one open
  /// (pending) report per job, so the same job can't be reported repeatedly.
  Future<JobReportResult> submitJobReport({
    required String jobId,
    required String category,
    String? details,
  }) async {
    try {
      final seekerID = _currentSeekerID;

      if (await _hasOpenReport(jobId, seekerID)) {
        return JobReportResult.alreadyReported;
      }

      final newReport = ReportedJobModel(
        jobID: jobId,
        reporterID: seekerID,
        reportCategory: category,
        additionalDetails: _cleanDetails(details),
        status: 'pending', // the admin dashboard counts pending reports
      );
      await _supabase.from(TableConstants.reportedJob).insert(newReport.toJson());
      return JobReportResult.submitted;
    } on PostgrestException catch (e) {
      // 23505: the same report was just sent (double tap, or another phone)
      if (e.code == '23505') return JobReportResult.alreadyReported;
      debugPrint('Error submitting report: ${e.code} ${e.message}');
      return JobReportResult.failed;
    } catch (e) {
      debugPrint('Error submitting report: $e');
      return JobReportResult.failed;
    }
  }

  static String? _cleanDetails(String? details) {
    final text = details?.trim() ?? '';
    if (text.isEmpty) return null;
    return text.length > maxDetailsLength ? text.substring(0, maxDetailsLength) : text;
  }

  /// True if this seeker already has a report on this job that the admins
  /// haven't dealt with yet (status empty or "pending").
  Future<bool> _hasOpenReport(String jobId, String seekerID) async {
    try {
      final rows = await _supabase
          .from(TableConstants.reportedJob)
          .select('jobID')
          .eq('jobID', jobId)
          .eq('reporterID', seekerID)
          .or('status.is.null,status.ilike.%pending%')
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (e) {
      // e.g. no read access to reports: don't block the report.
      debugPrint('Report duplicate check skipped: $e');
      return false;
    }
  }
}
