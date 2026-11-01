import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../models/pre_screening_question_model.dart';

/// Error with a message that is safe to show to the user.
class ApplicationException implements Exception {
  /// already_applied | job_unavailable | upload_failed | resume_required |
  /// missing_answers | failed
  final String code;
  final String message;

  ApplicationException(this.code, this.message);

  @override
  String toString() => message;
}

class ApplicationController {
  final _supabase = Supabase.instance.client;
  String get _currentSeekerID => _supabase.auth.currentUser!.id;

  static const String _resumeBucket = 'resumes';
  static const String _answerBucket = 'answer_files';

  Future<List<PreScreeningQuestionModel>> getQuestions(String jobId) async {
    try {
      final response = await _supabase
          .from(TableConstants.preScreeningQuestion)
          .select()
          .eq('jobID', jobId);
      return (response as List<dynamic>)
          .map((json) => PreScreeningQuestionModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching questions: $e');
      return [];
    }
  }

  Future<String?> getSeekerResume() async {
    try {
      final response = await _supabase
          .from(TableConstants.jobSeeker)
          .select('resumeURL')
          .eq('seekerID', _currentSeekerID)
          .maybeSingle();
      return response?['resumeURL'] as String?;
    } catch (e) {
      debugPrint('Error fetching resume: $e');
      return null;
    }
  }

  /// True if the current user already applied for this job (fix #1).
  Future<bool> hasApplied(String jobId) async {
    try {
      final row = await _supabase
          .from(TableConstants.jobApplicant)
          .select('applicantID')
          .eq('jobID', jobId)
          .eq('seekerID', _currentSeekerID)
          .limit(1)
          .maybeSingle();
      return row != null;
    } catch (e) {
      debugPrint('Error checking existing application: $e');
      return false;
    }
  }

  /// Uploads a file to "<userId>/<timestamp>_<name>" and returns (path, url).
  Future<({String path, String url})> _uploadFile(File file, String bucket) async {
    final originalName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'file';
    final path = '$_currentSeekerID/${DateTime.now().millisecondsSinceEpoch}_$originalName';

    await _supabase.storage.from(bucket).upload(path, file);
    // Stored in the same format as before. The bucket is private, so the app opens it
    // through StorageUrlHelper.resolve() (signed URL).
    final url = _supabase.storage.from(bucket).getPublicUrl(path);
    return (path: path, url: url);
  }

  Future<void> _removeUploaded(Map<String, List<String>> uploaded) async {
    for (final entry in uploaded.entries) {
      if (entry.value.isEmpty) continue;
      try {
        await _supabase.storage.from(entry.key).remove(entry.value);
      } catch (e) {
        debugPrint('Cleanup of uploaded files failed: $e');
      }
    }
  }

  /// Submits the application in one database transaction (fix #2).
  ///
  /// 1. Uploads the new resume and every answer file first. If any upload fails,
  ///    the files already uploaded are removed and nothing is saved.
  /// 2. Calls the `submit_job_application` database function, which inserts the
  ///    application and all answers together, or nothing at all.
  ///
  /// Throws [ApplicationException] with a user-friendly message.
  Future<void> submitApplication({
    required String jobId,
    required Map<String, dynamic> answers,
    required String? existingResumeUrl,
    required File? newResumeFile,
  }) async {
    final uploaded = <String, List<String>>{_resumeBucket: [], _answerBucket: []};

    // ---- 1. Uploads -------------------------------------------------------
    String resumeUrl = existingResumeUrl ?? '';
    final answerRows = <Map<String, dynamic>>[];

    try {
      if (newResumeFile != null) {
        final result = await _uploadFile(newResumeFile, _resumeBucket);
        uploaded[_resumeBucket]!.add(result.path);
        resumeUrl = result.url;
      }

      for (final entry in answers.entries) {
        final value = entry.value;
        if (value is File) {
          final result = await _uploadFile(value, _answerBucket);
          uploaded[_answerBucket]!.add(result.path);
          answerRows.add({'questionID': entry.key, 'answerFileURL': result.url});
        } else if (value is String) {
          answerRows.add({'questionID': entry.key, 'answerText': value.trim()});
        }
      }
    } catch (e) {
      debugPrint('Application upload failed: $e');
      await _removeUploaded(uploaded);
      throw ApplicationException(
        'upload_failed',
        'We couldn\'t upload your files. Please check your connection and try again.',
      );
    }

    // ---- 2. Save everything in one transaction -----------------------------
    try {
      await _supabase.rpc('submit_job_application', params: {
        'p_job_id': jobId,
        'p_resume_url': resumeUrl,
        'p_answers': answerRows,
      });
    } on PostgrestException catch (e) {
      await _removeUploaded(uploaded);
      throw _mapDatabaseError(e.message);
    } catch (e) {
      debugPrint('Application submission error: $e');
      await _removeUploaded(uploaded);
      throw ApplicationException('failed', 'Failed to submit application. Please try again.');
    }
  }

  ApplicationException _mapDatabaseError(String message) {
    if (message.contains('already_applied') || message.contains('jobapplicant_job_seeker_uq')) {
      return ApplicationException('already_applied', 'You have already applied for this job.');
    }
    if (message.contains('job_unavailable')) {
      return ApplicationException(
        'job_unavailable',
        'This job is no longer accepting applications.',
      );
    }
    if (message.contains('resume_required')) {
      return ApplicationException('resume_required', 'Please attach a resume.');
    }
    if (message.contains('missing_answers') || message.contains('invalid_question')) {
      return ApplicationException(
        'missing_answers',
        'Please answer all pre-screening questions.',
      );
    }
    debugPrint('submit_job_application error: $message');
    return ApplicationException('failed', 'Failed to submit application. Please try again.');
  }
}
