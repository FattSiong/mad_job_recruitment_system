import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../models/job_applicant_model.dart';
import '../../../models/job_model.dart';
import '../../../core/constants/table_constants.dart';
import '../../../core/utils/session_helper.dart';

/// The job seeker's applications (My Jobs > Applied): loading, withdrawing
/// and answering job offers.
class AppliedJobsController {
  final _supabase = Supabase.instance.client;
  String get _currentSeekerID => SessionHelper.requireUserId();

  /// Bump this to make the Applied and Interviews tabs reload
  /// (after applying for a job, or when the My Jobs tab is opened).
  static final ValueNotifier<int> refreshSignal = ValueNotifier(0);

  /// Makes the Applied and Interviews tabs reload.
  static void notifyChanged() => refreshSignal.value++;

  /// The user's applications with their jobs, newest first.
  Future<List<Map<String, dynamic>>> fetchAppliedJobs() async {
    try {
      final response = await _supabase
          .from(TableConstants.jobApplicant)
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
          'raw': row,
          'job': job,
          'jobStatus': jobStatus,
          'isJobDeleted': isJobDeleted,
          'isJobInactive': isJobInactive,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching applied jobs: $e');
      throw DataLoadException(
        'Unable to load your applications. Please check your connection and try again.',
      );
    }
  }

  /// Only a pending application can be withdrawn (FN-JAM-06).
  static bool canWithdraw(String status) => status.trim().toLowerCase() == 'pending';

  /// Withdraws one of the user's pending applications. The record is kept
  /// as 'withdrawn' (the employer no longer sees it, its notifications are
  /// removed, and the job can't be applied for again).
  /// Throws [DataLoadException] with a message to show.
  Future<void> withdrawApplication(String applicantId) async {
    try {
      await _supabase.rpc(
        'withdraw_job_application',
        params: {'p_applicant_id': applicantId.trim()},
      );
      notifyChanged();
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('not_pending')) {
        notifyChanged(); // show its real status
        throw DataLoadException(
          'The employer has already started processing this application, so it can\'t be withdrawn.',
        );
      }
      if (msg.contains('application_not_found')) {
        notifyChanged();
        throw DataLoadException('This application no longer exists.');
      }
      debugPrint('Withdraw application PostgrestException: ${e.message}');
      throw DataLoadException('Unable to withdraw your application. Please try again.');
    } catch (e) {
      if (e is DataLoadException) rethrow;
      debugPrint('Withdraw application error: $e');
      throw DataLoadException(
        'Unable to withdraw your application. Please check your connection and try again.',
      );
    }
  }

  /// Accepts ([accept] true) or declines an active job offer (status
  /// 'offered') through the `respond_to_job_offer` database function.
  /// Returns the new status and reloads the My Jobs tabs.
  /// Throws [DataLoadException] with a message to show.
  Future<String> respondToJobOffer({
    required String applicantId,
    required bool accept,
    String? declineReason,
  }) async {
    try {
      final result = await _supabase.rpc(
        'respond_to_job_offer',
        params: {
          'p_applicant_id': applicantId.trim(),
          'p_accept': accept,
          'p_decline_reason':
              (declineReason != null && declineReason.trim().isNotEmpty)
                  ? declineReason.trim()
                  : null,
        },
      );
      notifyChanged();
      return (result ?? (accept ? 'accepted' : 'offer_declined')).toString();
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('quota_full')) {
        throw DataLoadException(
          'All vacancies for this position have already been filled.',
        );
      }
      if (msg.contains('offer_not_active')) {
        throw DataLoadException(
          'This job offer is no longer active.',
        );
      }
      debugPrint('Respond to job offer PostgrestException: ${e.message}');
      throw DataLoadException(
        'Unable to submit your response right now. Please try again.',
      );
    } catch (e) {
      if (e is DataLoadException) rethrow;
      debugPrint('Respond to job offer error: $e');
      throw DataLoadException(
        'Unable to submit your response right now. Please try again.',
      );
    }
  }
}
