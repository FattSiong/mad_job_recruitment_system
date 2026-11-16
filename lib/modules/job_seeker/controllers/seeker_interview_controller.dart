import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../services/interview_service.dart';

/// Data for the job seeker's My Jobs > Interviews tab (the tab itself does
/// no database work).
class SeekerInterviewController {
  final _supabase = Supabase.instance.client;
  final InterviewService _interviewService = InterviewService();

  /// Interview schedules for the logged-in job seeker, soonest first,
  /// with the job title and company name.
  Future<List<Map<String, dynamic>>> fetchMyInterviews() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from(TableConstants.interviewSchedule)
          .select('''
            *,
            JobApplicant!inner(
              seekerID,
              Job (
                title,
                Company (name)
              )
            )
          ''')
          .eq('JobApplicant.seekerID', userId)
          .order('date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching interviews: $e');
      throw DataLoadException(
        'Unable to load your interviews. Please check your connection and try again.',
      );
    }
  }

  /// The interview room linked to a schedule, or null if it isn't set up yet.
  Future<Map<String, dynamic>?> getRoomForSchedule(String scheduleID) {
    return _interviewService.getRoomByScheduleId(scheduleID);
  }

  /// Accept or decline (with reason and preferred time) an interview invitation.
  Future<bool> respondToInterview({
    required String scheduleID,
    required bool accept,
    String? rejectionReason,
    String? preferredTime,
  }) {
    return _interviewService.respondToInterviewSchedule(
      scheduleID: scheduleID,
      accept: accept,
      rejectionReason: rejectionReason,
      preferredTime: preferredTime,
    );
  }
}
