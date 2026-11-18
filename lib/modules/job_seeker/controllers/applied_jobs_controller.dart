import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/storage_url_helper.dart';
import '../../../services/notification_service.dart';
import '../../../models/applied_job_model.dart';
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
  Future<List<AppliedJob>> fetchAppliedJobs() async {
    try {
      final response = await _supabase
          .from(TableConstants.jobApplicant)
          .select('*, Job (*, Company(name))')
          .eq('seekerID', _currentSeekerID)
          .order('appliedAt', ascending: false);
      return List<Map<String, dynamic>>.from(response).map(AppliedJob.fromJson).toList();
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
      unawaited(NotificationService.refreshUnreadCount()); // its notifications are gone
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

  /// The offer letter PDF at [url] as a local file (downloaded once, then
  /// reused). Throws when it can't be downloaded.
  Future<File> downloadOfferLetter(String url) async {
    var fileName = url.split('/').last.split('?').first;
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      fileName = 'offer_letter_${DateTime.now().millisecondsSinceEpoch}.pdf';
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    if (await _isSavedPdf(file)) return file;

    final signedUrl = await StorageUrlHelper.resolve(url);
    final response = await http.get(Uri.parse(signedUrl)).timeout(const Duration(seconds: 30));
    // Never save an error page as the PDF: it would be reopened every time
    if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  /// True when [file] exists and starts like a PDF.
  static Future<bool> _isSavedPdf(File file) async {
    try {
      if (!await file.exists()) return false;
      final head = await file.openRead(0, 4).first;
      return String.fromCharCodes(head) == '%PDF';
    } catch (_) {
      return false;
    }
  }
}
