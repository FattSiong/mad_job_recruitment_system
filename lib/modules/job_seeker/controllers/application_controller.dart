import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../models/pre_screening_question_model.dart';
import 'applied_jobs_controller.dart';
import '../../../core/utils/session_helper.dart';

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

/// Which resume goes with the application.
enum ResumeChoice { existing, newFile }

/// Applying for a job: the form state (answers, resume choice) for the
/// application screen, plus loading questions and submitting.
class ApplicationController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  String get _currentSeekerID => SessionHelper.requireUserId();

  static const String _resumeBucket = 'resumes';
  static const String _answerBucket = 'answer_files';

  // ---------------------------------------------------------------------
  // Form state
  // ---------------------------------------------------------------------

  List<PreScreeningQuestionModel> _questions = [];
  String? _existingResumeUrl;
  final Map<String, dynamic> _answers = {}; // questionID -> String or File
  ResumeChoice _resumeChoice = ResumeChoice.existing;
  File? _newResumeFile;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;
  bool _disposed = false;

  List<PreScreeningQuestionModel> get questions => List.unmodifiable(_questions);
  String? get existingResumeUrl => _existingResumeUrl;
  ResumeChoice get resumeChoice => _resumeChoice;
  File? get newResumeFile => _newResumeFile;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get loadError => _loadError;

  /// The answer to a question: a String, a File, or null.
  dynamic answerFor(String questionID) => _answers[questionID];

  /// Loads the job's questions and the seeker's saved resume.
  Future<void> load(String jobId) async {
    _isLoading = true;
    _loadError = null;
    _notify();
    try {
      final results = await Future.wait([getQuestions(jobId), getSeekerResume()]);
      _questions = results[0] as List<PreScreeningQuestionModel>;
      _existingResumeUrl = results[1] as String?;
      if (_existingResumeUrl == null) _resumeChoice = ResumeChoice.newFile;
    } on DataLoadException catch (e) {
      _loadError = e.message;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Typing doesn't rebuild the screen, so no notify here.
  void setTextAnswer(String questionID, String text) => _answers[questionID] = text;

  void setFileAnswer(String questionID, File file) {
    _answers[questionID] = file;
    _notify();
  }

  void chooseResume(ResumeChoice choice) {
    if (_resumeChoice == choice) return;
    _resumeChoice = choice;
    _notify();
  }

  void setNewResumeFile(File file) {
    _newResumeFile = file;
    _resumeChoice = ResumeChoice.newFile;
    _notify();
  }

  /// True when every question has an answer.
  bool get questionsAnswered => _questions.every((q) {
        final answer = _answers[q.questionID];
        if (answer == null) return false;
        if (answer is String && answer.trim().isEmpty) return false;
        return true;
      });

  /// Checks the resume step. Returns a message to show, or null if OK.
  String? validateResume() {
    if (_resumeChoice == ResumeChoice.newFile && _newResumeFile == null) {
      return 'Please select a resume file to upload.';
    }
    if (_resumeChoice == ResumeChoice.existing && _existingResumeUrl == null) {
      return 'No existing resume found. Please upload a new one.';
    }
    return null;
  }

  /// Submits the form. Throws [ApplicationException] with a message to show.
  Future<void> submit(String jobId) async {
    final problem = validateResume();
    if (problem != null) throw ApplicationException('resume_required', problem);
    if (_isSubmitting) return;

    _isSubmitting = true;
    _notify();
    try {
      await submitApplication(
        jobId: jobId,
        answers: Map.of(_answers),
        existingResumeUrl: _resumeChoice == ResumeChoice.existing ? _existingResumeUrl : null,
        newResumeFile: _resumeChoice == ResumeChoice.newFile ? _newResumeFile : null,
      );
    } finally {
      _isSubmitting = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------

  /// Throws [DataLoadException] if the questions can't be loaded (applying
  /// without them would skip required answers).
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
      throw DataLoadException(
        'Unable to load the application form. Please check your connection and try again.',
      );
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
      throw DataLoadException(
        'Unable to load the application form. Please check your connection and try again.',
      );
    }
  }

  /// True if the current user already applied for this job (fix #1).
  /// Returns false if it can't be checked: the server still blocks a
  /// duplicate application when it is submitted.
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
      AppliedJobsController.notifyChanged(); // refresh My Jobs > Applied
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
