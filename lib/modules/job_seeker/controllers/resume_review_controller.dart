import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/session_helper.dart';
import '../../../models/resume_review_model.dart';

/// Error with a message that is safe to show to the user.
class ResumeReviewException implements Exception {
  final String code;
  final String message;

  ResumeReviewException(this.code, this.message);

  @override
  String toString() => message;
}

/// AI Resume Assistant: reviews the uploaded resume or the resume built in
/// the app (Edge Function `resume-review`) and keeps the past reviews.
class ResumeReviewController {
  final _supabase = Supabase.instance.client;
  String get _currentSeekerID => SessionHelper.requireUserId();

  static const String _unavailable =
      'The AI service is currently unavailable. Please try again later.';

  /// Reviews the chosen resume and returns the saved review.
  Future<ResumeReviewModel> review(
    ResumeReviewSource source, {
    String? targetJobRole,
  }) async {
    final role = targetJobRole?.trim() ?? '';
    try {
      final response = await _supabase.functions.invoke(
        'resume-review',
        body: {
          'source': source.name,
          if (role.isNotEmpty) 'targetJobRole': role,
        },
      ).timeout(const Duration(seconds: 90));
      final data = response.data as Map<String, dynamic>;
      return ResumeReviewModel.fromJson(data['review'] as Map<String, dynamic>);
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['message'] is String) {
        throw ResumeReviewException(
          (details['error'] ?? 'error').toString(),
          details['message'] as String,
        );
      }
      debugPrint('resume-review FunctionException: ${e.status} ${e.details}');
      throw ResumeReviewException('ai_unavailable', _unavailable);
    } on TimeoutException {
      throw ResumeReviewException(
        'timeout',
        'The review is taking longer than expected. Please check your connection and try again.',
      );
    } catch (e) {
      debugPrint('resume-review error: $e');
      throw ResumeReviewException('ai_unavailable', _unavailable);
    }
  }

  /// Which resumes the user has: the uploaded file and/or the in-app resume.
  /// Throws [DataLoadException] if they can't be loaded.
  Future<ResumeReviewSources?> fetchSources() async {
    try {
      final userId = _currentSeekerID;
      final results = await Future.wait([
        _supabase
            .from(TableConstants.jobSeeker)
            .select('resumeURL')
            .eq('seekerID', userId)
            .maybeSingle(),
        _supabase
            .from(TableConstants.resume)
            .select('content, updatedAt')
            .eq('seekerID', userId)
            .maybeSingle(),
      ]);
      final seeker = results[0];
      final built = results[1];
      if (seeker == null) return null;

      return ResumeReviewSources(
        uploadedURL: seeker['resumeURL'] as String?,
        hasBuiltResume: _hasContent(built?['content']),
        builtResumeUpdatedAt: DateTime.tryParse(built?['updatedAt']?.toString() ?? '')?.toLocal(),
      );
    } on DataLoadException {
      rethrow; // session expired
    } catch (e) {
      debugPrint('Error fetching resume sources: $e');
      throw DataLoadException(
        'Unable to load your resumes. Please check your connection and try again.',
      );
    }
  }

  /// Same rule as the Edge Function: education, experience or skills filled in.
  static bool _hasContent(dynamic content) {
    if (content is! Map) return false;
    bool filled(String key) => content[key] is List && (content[key] as List).isNotEmpty;
    return filled('education') || filled('experience') || filled('skills');
  }

  /// Past reviews, newest first. Throws [DataLoadException].
  Future<List<ResumeReviewModel>> fetchHistory() async {
    try {
      final response = await _supabase
          .from(TableConstants.resumeReviewRecord)
          .select()
          .eq('seekerID', _currentSeekerID)
          .order('createdAt', ascending: false);
      return (response as List<dynamic>)
          .map((e) => ResumeReviewModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DataLoadException {
      rethrow; // session expired
    } catch (e) {
      debugPrint('Error fetching resume reviews: $e');
      throw DataLoadException(
        'Unable to load your past reviews. Please check your connection and try again.',
      );
    }
  }

  /// Deletes one of the user's past reviews. Returns false if it failed.
  Future<bool> deleteReview(String reviewID) async {
    try {
      await _supabase
          .from(TableConstants.resumeReviewRecord)
          .delete()
          .eq('reviewID', reviewID)
          .eq('seekerID', _currentSeekerID);
      return true;
    } catch (e) {
      debugPrint('Error deleting resume review: $e');
      return false;
    }
  }
}
