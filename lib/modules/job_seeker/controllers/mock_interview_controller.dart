import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../models/mock_interview_model.dart';
import '../../../core/utils/session_helper.dart';

/// Error with a message that is safe to show to the user.
class MockInterviewException implements Exception {
  final String code;
  final String message;

  MockInterviewException(this.code, this.message);

  @override
  String toString() => message;
}

class StartInterviewResult {
  final String sessionID;
  final List<InterviewQuestion> questions;

  StartInterviewResult(this.sessionID, this.questions);
}

class EvaluateAnswerResult {
  final MockInterviewAnswerModel answer;

  /// Only returned after the introduction: the generated interview questions.
  final List<InterviewQuestion>? questions;

  EvaluateAnswerResult(this.answer, this.questions);
}

class MockInterviewController {
  final _supabase = Supabase.instance.client;
  String get _currentSeekerID => SessionHelper.requireUserId();

  static const String _functionName = 'mock-interview';
  static const String _unavailable =
      'The AI interviewer is currently unavailable. Please try again later.';

  /// Calls the Edge Function and turns every failure into a [MockInterviewException].
  Future<Map<String, dynamic>> _invoke(
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final response = await _supabase.functions
          .invoke(_functionName, body: body)
          .timeout(timeout);
      return response.data as Map<String, dynamic>;
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['message'] is String) {
        throw MockInterviewException(
          (details['error'] ?? 'error').toString(),
          details['message'] as String,
        );
      }
      debugPrint('mock-interview FunctionException: ${e.status} ${e.details}');
      throw MockInterviewException('ai_unavailable', _unavailable);
    } on TimeoutException {
      throw MockInterviewException(
        'timeout',
        'This is taking longer than expected. Please check your connection and try again.',
      );
    } catch (e) {
      debugPrint('mock-interview error: $e');
      throw MockInterviewException('ai_unavailable', _unavailable);
    }
  }

  /// Creates the session. [consent] must be true (AI processing consent).
  Future<StartInterviewResult> startInterview({
    required String targetJobRole,
    String? experienceLevel,
    required int questionCount,
    required bool consent,
  }) async {
    final data = await _invoke({
      'action': 'start',
      'targetJobRole': targetJobRole.trim(),
      'experienceLevel': experienceLevel,
      'questionCount': questionCount,
      'consent': consent,
    });
    return StartInterviewResult(
      data['sessionId'] as String,
      InterviewQuestion.listFromJson(data['questions']),
    );
  }

  /// Sends one recorded answer (mono AAC .m4a) for transcription + evaluation.
  Future<EvaluateAnswerResult> evaluateAnswer({
    required String sessionID,
    required int questionIndex,
    required File audioFile,
    List<double> amplitudeDb = const [],
    int amplitudeIntervalMs = 100,
  }) async {
    final bytes = await audioFile.readAsBytes();
    final data = await _invoke(
      {
        'action': 'evaluate-answer',
        'sessionId': sessionID,
        'questionIndex': questionIndex,
        'audioBase64': base64Encode(bytes),
        'mimeType': 'audio/mp4',
        // Microphone levels, used to find "erm/aaa" sounds the transcript misses
        if (amplitudeDb.isNotEmpty)
          'amplitude': {
            'intervalMs': amplitudeIntervalMs,
            'db': amplitudeDb.map((v) => (v * 10).round() / 10).toList(),
          },
      },
      // The introduction also generates the questions, so allow extra time
      timeout: const Duration(seconds: 90),
    );

    return EvaluateAnswerResult(
      MockInterviewAnswerModel.fromJson(data['answer'] as Map<String, dynamic>),
      data['questions'] == null
          ? null
          : InterviewQuestion.listFromJson(data['questions']),
    );
  }

  /// Ends the interview and generates the overall scorecard.
  Future<MockInterviewRecordModel> finishInterview(String sessionID) async {
    final data = await _invoke(
      {'action': 'finish', 'sessionId': sessionID},
      timeout: const Duration(seconds: 60),
    );
    final record = data['record'] as Map<String, dynamic>;
    // Load again with the answers attached
    return await fetchInterview(record['sessionID'] as String) ??
        MockInterviewRecordModel.fromJson(record);
  }

  /// Use case A2 (early exit): removes the unfinished session and its answers.
  Future<void> discardInterview(String sessionID) async {
    try {
      await _supabase
          .from(TableConstants.mockInterviewRecord)
          .delete()
          .eq('sessionID', sessionID)
          .eq('seekerID', _currentSeekerID)
          .eq('status', 'in_progress');
    } catch (e) {
      debugPrint('Error discarding mock interview: $e');
    }
  }

  /// One interview with all its answers (used by the result screen / guidance reports).
  Future<MockInterviewRecordModel?> fetchInterview(String sessionID) async {
    try {
      final response = await _supabase
          .from(TableConstants.mockInterviewRecord)
          .select('*, MockInterviewAnswer(*)')
          .eq('sessionID', sessionID)
          .eq('seekerID', _currentSeekerID)
          .maybeSingle();
      return response == null ? null : MockInterviewRecordModel.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching mock interview: $e');
      return null;
    }
  }

  /// Completed interviews, newest first.
  Future<List<MockInterviewRecordModel>> fetchCompletedInterviews() async {
    try {
      final response = await _supabase
          .from(TableConstants.mockInterviewRecord)
          .select()
          .eq('seekerID', _currentSeekerID)
          .eq('status', 'completed')
          .order('completedAt', ascending: false);
      return (response as List<dynamic>)
          .map((e) => MockInterviewRecordModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching mock interviews: $e');
      return [];
    }
  }
}
