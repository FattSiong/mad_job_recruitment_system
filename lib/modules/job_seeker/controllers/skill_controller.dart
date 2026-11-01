import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../models/skill_model.dart';

/// Thrown when a skill can't be added; [message] is safe to show to the user.
class SkillException implements Exception {
  final String message;
  SkillException(this.message);

  @override
  String toString() => message;
}

/// Skills on the logged-in job seeker's profile.
class SkillController {
  final _supabase = Supabase.instance.client;

  static const int maxNameLength = 50;

  /// The seeker's skills, oldest first.
  Future<List<SkillModel>> fetchMySkills() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from(TableConstants.skill)
          .select()
          .eq('seekerID', userId)
          .order('createdAt', ascending: true);

      return (response as List)
          .map((row) => SkillModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching skills: $e');
      throw DataLoadException('Unable to load your skills. Please check your connection and try again.');
    }
  }

  /// Adds a skill and returns the saved row.
  /// Throws [SkillException] for empty, too long or duplicate names.
  Future<SkillModel> addSkill(String name, {String? proficiency}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw SkillException('Please log in again.');

    final cleaned = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) throw SkillException('Please enter a skill name.');
    if (cleaned.length > maxNameLength) {
      throw SkillException('Skill names can be up to $maxNameLength characters.');
    }
    if (proficiency != null && !SkillModel.proficiencyLevels.contains(proficiency)) {
      throw SkillException('Please choose a valid proficiency level.');
    }

    try {
      final row = await _supabase
          .from(TableConstants.skill)
          .insert(SkillModel(seekerID: userId, skillName: cleaned, proficiency: proficiency).toJson())
          .select()
          .single();
      return SkillModel.fromJson(row);
    } on PostgrestException catch (e) {
      debugPrint('Error adding skill: ${e.code} ${e.message}');
      // 23505 = unique index skill_seeker_name_uq (same name, any letter case)
      if (e.code == '23505') throw SkillException('"$cleaned" is already in your skills.');
      throw SkillException('Failed to add skill. Please try again.');
    } catch (e) {
      debugPrint('Error adding skill: $e');
      throw SkillException('Failed to add skill. Please check your connection and try again.');
    }
  }

  /// Changes the proficiency of an existing skill.
  Future<bool> updateProficiency(String skillID, String? proficiency) async {
    try {
      await _supabase
          .from(TableConstants.skill)
          .update({'proficiency': proficiency})
          .eq('skillID', skillID);
      return true;
    } catch (e) {
      debugPrint('Error updating skill: $e');
      return false;
    }
  }

  Future<bool> deleteSkill(String skillID) async {
    try {
      await _supabase.from(TableConstants.skill).delete().eq('skillID', skillID);
      return true;
    } catch (e) {
      debugPrint('Error deleting skill: $e');
      return false;
    }
  }
}
