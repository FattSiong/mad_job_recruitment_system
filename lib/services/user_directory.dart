import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/table_constants.dart';
import '../models/chat_room_model.dart';

/// Looks up names, roles and photos of users (chat, community, ...).
/// Job seekers and employers keep their full name and photo in different
/// tables, so both are checked; results are cached for the app session.
class UserDirectory {
  UserDirectory._();

  static final Map<String, ChatParticipant> _cache = {};

  /// Names, roles and photos of [userIds] (cached ones are not fetched again).
  static Future<Map<String, ChatParticipant>> fetch(Iterable<String> userIds) async {
    final ids = userIds.where((id) => id.isNotEmpty).toSet();
    final missing = ids.where((id) => !_cache.containsKey(id)).toList();

    final temporary = <String, ChatParticipant>{}; // shown now, not cached
    if (missing.isNotEmpty) {
      final supabase = Supabase.instance.client;
      var lookupFailed = false;

      Future<List<Map<String, dynamic>>> safeSelect(
        String table,
        String columns,
        String idColumn,
      ) async {
        try {
          final rows = await supabase.from(table).select(columns).inFilter(idColumn, missing);
          return List<Map<String, dynamic>>.from(rows);
        } catch (e) {
          debugPrint('UserDirectory: $table lookup failed: $e');
          lookupFailed = true;
          return [];
        }
      }

      Future<List<Map<String, dynamic>>> seekerRows() async {
        try {
          return await publicSeekerRows(missing);
        } catch (e) {
          debugPrint('UserDirectory: job seeker lookup failed: $e');
          lookupFailed = true;
          return [];
        }
      }

      final results = await Future.wait([
        safeSelect(TableConstants.user, 'userID, username, role', 'userID'),
        seekerRows(),
        safeSelect(TableConstants.employer, 'employerID, fullName, profilePictureURL', 'employerID'),
      ]);

      final users = {for (final r in results[0]) r['userID'].toString(): r};
      final seekers = {for (final r in results[1]) r['seekerID'].toString(): r};
      final employers = {for (final r in results[2]) r['employerID'].toString(): r};

      for (final id in missing) {
        final profile = employers[id] ?? seekers[id];
        final user = users[id];

        String? clean(Object? value) {
          final text = value?.toString().trim();
          return (text == null || text.isEmpty) ? null : text;
        }

        final participant = ChatParticipant(
          userID: id,
          displayName: clean(profile?['fullName']) ?? clean(user?['username']) ?? 'Unknown user',
          role: clean(user?['role']) ?? (employers.containsKey(id) ? 'employer' : 'job_seeker'),
          photoUrl: clean(profile?['profilePictureURL']),
        );
        // A failed lookup (e.g. no connection) must not save "Unknown user"
        // for the rest of the session: try again next time instead.
        if (lookupFailed && profile == null && user == null) {
          temporary[id] = participant;
        } else {
          _cache[id] = participant;
        }
      }
    }

    return {
      for (final id in ids)
        if (_cache[id] != null) id: _cache[id]! else if (temporary[id] != null) id: temporary[id]!,
    };
  }

  /// Public profile fields of job seekers (name, photo, location, bio,
  /// career goal, links), never their email, phone or resume. Other job
  /// seekers can't read JobSeeker rows directly (migration
  /// 20261122000000_job_seeker_contact_privacy), so this goes through the
  /// database function public_seeker_profiles. Before that migration is run
  /// the function doesn't exist yet, and the same columns are read directly.
  static Future<List<Map<String, dynamic>>> publicSeekerRows(List<String> seekerIds) async {
    if (seekerIds.isEmpty) return [];
    final supabase = Supabase.instance.client;
    try {
      final rows = await supabase.rpc('public_seeker_profiles', params: {'p_ids': seekerIds});
      return List<Map<String, dynamic>>.from(rows as List);
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow; // PGRST202: no such function
      final rows = await supabase
          .from(TableConstants.jobSeeker)
          .select('seekerID, fullName, profilePictureURL, location, bio, careerGoal, linkedInURL, gitHubURL')
          .inFilter('seekerID', seekerIds);
      return List<Map<String, dynamic>>.from(rows);
    }
  }

  /// One user, or "Unknown user" if they can't be found.
  static Future<ChatParticipant> fetchOne(String userId) async {
    final result = await fetch([userId]);
    return result[userId] ??
        ChatParticipant(userID: userId, displayName: 'Unknown user', role: 'member');
  }

  /// Call after a user changes their own name or photo.
  static void forget(String userId) => _cache.remove(userId);
}
