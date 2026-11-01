import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../models/skill_gap_model.dart';
import '../../../core/utils/session_helper.dart';

/// Error with a message that is safe to show to the user.
class SkillGapException implements Exception {
  final String code;
  final String message;

  /// Filled for `insufficient_market_data` (use case A2).
  final List<String> suggestedRoles;

  SkillGapException(this.code, this.message, {this.suggestedRoles = const []});

  @override
  String toString() => message;
}

class SkillGapController {
  final _supabase = Supabase.instance.client;
  String get _currentSeekerID => SessionHelper.requireUserId();

  static const String _unavailable =
      'The AI service is currently unavailable. Please try again later.';

  /// Runs the analysis in the `skill-gap-analysis` Edge Function and returns the saved record.
  Future<SkillGapAnalysisModel> analyse(String targetJobRole) async {
    final role = targetJobRole.trim();
    if (role.isEmpty) {
      throw SkillGapException('bad_request', 'Please enter a target job title.');
    }

    try {
      final response = await _supabase.functions
          .invoke('skill-gap-analysis', body: {'targetJobRole': role})
          .timeout(const Duration(seconds: 90));
      final data = response.data as Map<String, dynamic>;
      return SkillGapAnalysisModel.fromJson(data['analysis'] as Map<String, dynamic>);
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['message'] is String) {
        final suggestions = details['suggestedRoles'];
        throw SkillGapException(
          (details['error'] ?? 'error').toString(),
          details['message'] as String,
          suggestedRoles:
              suggestions is List ? suggestions.map((s) => s.toString()).toList() : const [],
        );
      }
      debugPrint('skill-gap FunctionException: ${e.status} ${e.details}');
      throw SkillGapException('ai_unavailable', _unavailable);
    } on TimeoutException {
      throw SkillGapException(
        'timeout',
        'The analysis is taking longer than expected. Please check your connection and try again.',
      );
    } catch (e) {
      debugPrint('skill-gap error: $e');
      throw SkillGapException('ai_unavailable', _unavailable);
    }
  }

  /// Counts of the profile data the analysis will use.
  Future<SkillGapReadiness?> fetchReadiness() async {
    try {
      final row = await _supabase
          .from(TableConstants.jobSeeker)
          .select('resumeURL, Skill(count), Education(count), WorkExperience(count)')
          .eq('seekerID', _currentSeekerID)
          .maybeSingle();
      if (row == null) return null;

      int count(String table) {
        final v = row[table];
        if (v is List && v.isNotEmpty && v.first is Map) {
          return ((v.first as Map)['count'] as num?)?.toInt() ?? 0;
        }
        return 0;
      }

      return SkillGapReadiness(
        skillCount: count('Skill'),
        educationCount: count('Education'),
        experienceCount: count('WorkExperience'),
        resumeURL: row['resumeURL'] as String?,
      );
    } catch (e) {
      debugPrint('Error fetching skill gap readiness: $e');
      return null;
    }
  }

  /// Past analyses, newest first.
  Future<List<SkillGapAnalysisModel>> fetchHistory() async {
    try {
      final response = await _supabase
          .from(TableConstants.skillGapAnalysisRecord)
          .select()
          .eq('seekerID', _currentSeekerID)
          .order('createdAt', ascending: false);
      return (response as List<dynamic>)
          .map((e) => SkillGapAnalysisModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching skill gap history: $e');
      return [];
    }
  }

  Future<SkillGapAnalysisModel?> fetchAnalysis(String analysisID) async {
    try {
      final row = await _supabase
          .from(TableConstants.skillGapAnalysisRecord)
          .select()
          .eq('analysisID', analysisID)
          .eq('seekerID', _currentSeekerID)
          .maybeSingle();
      return row == null ? null : SkillGapAnalysisModel.fromJson(row);
    } catch (e) {
      debugPrint('Error fetching skill gap analysis: $e');
      return null;
    }
  }

  Future<bool> deleteAnalysis(String analysisID) async {
    try {
      await _supabase
          .from(TableConstants.skillGapAnalysisRecord)
          .delete()
          .eq('analysisID', analysisID)
          .eq('seekerID', _currentSeekerID);
      return true;
    } catch (e) {
      debugPrint('Error deleting skill gap analysis: $e');
      return false;
    }
  }
}
