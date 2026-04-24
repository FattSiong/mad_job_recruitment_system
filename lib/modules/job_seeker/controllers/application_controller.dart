import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/pre_screening_question_model.dart'; // 👉 New Model
import '../../../models/job_applicant_model.dart';          // 👉 New Model
import '../../../models/application_answer_model.dart';     // 👉 New Model

class ApplicationController {
  final _supabase = Supabase.instance.client;
  final String _mockSeekerID = '773ed23f-95ca-4853-ae50-06bd5e411bad';

  // 👉 Now returns a list of strict Models instead of raw Maps
  Future<List<PreScreeningQuestionModel>> getQuestions(String jobId) async {
    try {
      final response = await _supabase.from('PreScreeningQuestion').select().eq('jobID', jobId);
      return (response as List<dynamic>)
          .map((json) => PreScreeningQuestionModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching questions: $e');
      return [];
    }
  }

  Future<String?> getSeekerResume() async {
    try {
      final response = await _supabase.from('JobSeeker').select('resumeURL').eq('seekerID', _mockSeekerID).maybeSingle();
      return response?['resumeURL'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _uploadFile(File file, String bucketName) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final filePath = '$_mockSeekerID/$fileName';

      await _supabase.storage.from(bucketName).upload(filePath, file);
      return _supabase.storage.from(bucketName).getPublicUrl(filePath);
    } catch (e) {
      print('File upload error: $e');
      return null;
    }
  }

  Future<bool> submitApplication({
    required String jobId,
    required Map<String, dynamic> answers,
    required String? existingResumeUrl,
    required File? newResumeFile,
  }) async {
    try {
      String finalResumeUrl = existingResumeUrl ?? '';
      if (newResumeFile != null) {
        final uploadedUrl = await _uploadFile(newResumeFile, 'resumes');
        if (uploadedUrl != null) {
          finalResumeUrl = uploadedUrl;
          await _supabase.from('JobSeeker').update({'resumeURL': finalResumeUrl}).eq('seekerID', _mockSeekerID);
        }
      }

      // 👉 1. Use Model for JobApplicant
      final newApplicant = JobApplicantModel(
        jobID: jobId,
        seekerID: _mockSeekerID,
        submittedResumeURL: finalResumeUrl,
        applicationStatus: 'pending',
      );

      final applicantResponse = await _supabase.from('JobApplicant')
          .insert(newApplicant.toJson())
          .select('applicantID')
          .single();

      final String applicantId = applicantResponse['applicantID'];

      // 👉 2. Use Model for ApplicationAnswers
      for (var entry in answers.entries) {
        final questionId = entry.key;
        final answerValue = entry.value;

        String? textAnswer;
        String? fileUrl;

        if (answerValue is String) {
          textAnswer = answerValue;
        } else if (answerValue is File) {
          fileUrl = await _uploadFile(answerValue, 'answer_files');
        }

        final newAnswer = ApplicationAnswerModel(
          applicantID: applicantId,
          questionID: questionId,
          answerText: textAnswer,
          answerFileURL: fileUrl,
        );

        await _supabase.from('ApplicationAnswer').insert(newAnswer.toJson());
      }

      return true;
    } catch (e) {
      print('Application submission error: $e');
      return false;
    }
  }
}