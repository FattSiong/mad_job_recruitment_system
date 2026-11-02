import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../models/guidance_report_model.dart';
import '../../../models/mock_interview_model.dart';
import '../../../models/skill_gap_model.dart';
import '../../../core/utils/session_helper.dart';

/// Thrown when reports can't be loaded (use case A2: database error).
class GuidanceReportException implements Exception {
  final String message;
  GuidanceReportException(this.message);

  @override
  String toString() => message;
}

class GuidanceReportController {
  final _supabase = Supabase.instance.client;
  String get _currentSeekerID => SessionHelper.requireUserId();

  /// All completed AI advisory activities, newest first.
  /// Returns an empty list when there are none (use case A1),
  /// throws [GuidanceReportException] on a server error (use case A2).
  Future<List<GuidanceReportItem>> fetchReports() async {
    try {
      final response = await _supabase
          .from(TableConstants.guidanceReport)
          .select()
          .eq('seekerID', _currentSeekerID)
          .order('createdAt', ascending: false);

      return (response as List<dynamic>)
          .map((e) => GuidanceReportItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching guidance reports: $e');
      throw GuidanceReportException('Unable to load your reports. Please try again.');
    }
  }

  // ---------------------------------------------------------------------
  // Data for the PDF export
  // ---------------------------------------------------------------------

  /// Name printed on the PDF.
  Future<String> fetchApplicantName() async {
    try {
      final row = await _supabase
          .from(TableConstants.jobSeeker)
          .select('fullName')
          .eq('seekerID', _currentSeekerID)
          .maybeSingle();
      return (row?['fullName'] as String?) ?? '';
    } catch (e) {
      debugPrint('Error fetching applicant name: $e');
      return '';
    }
  }

  /// Completed mock interviews with all answers, newest first.
  Future<List<MockInterviewRecordModel>> fetchInterviewDetails({int limit = 20}) async {
    try {
      final response = await _supabase
          .from(TableConstants.mockInterviewRecord)
          .select('*, MockInterviewAnswer(*)')
          .eq('seekerID', _currentSeekerID)
          .eq('status', 'completed')
          .order('completedAt', ascending: false)
          .limit(limit);
      return (response as List<dynamic>)
          .map((e) => MockInterviewRecordModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching interview details: $e');
      throw GuidanceReportException('Unable to load your interview reports. Please try again.');
    }
  }

  /// Skill gap analyses, newest first.
  Future<List<SkillGapAnalysisModel>> fetchSkillGapDetails({int limit = 20}) async {
    try {
      final response = await _supabase
          .from(TableConstants.skillGapAnalysisRecord)
          .select()
          .eq('seekerID', _currentSeekerID)
          .order('createdAt', ascending: false)
          .limit(limit);
      return (response as List<dynamic>)
          .map((e) => SkillGapAnalysisModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching skill gap details: $e');
      throw GuidanceReportException('Unable to load your skill gap reports. Please try again.');
    }
  }
}
