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

      final results = await Future.wait([
        safeSelect(TableConstants.user, 'userID, username, role', 'userID'),
        safeSelect(TableConstants.jobSeeker, 'seekerID, fullName, profilePictureURL', 'seekerID'),
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

  static Future<ChatParticipant> fetchOne(String userId) async {
    final result = await fetch([userId]);
    return result[userId] ??
        ChatParticipant(userID: userId, displayName: 'Unknown user', role: 'member');
  }

  /// Call after a user changes their own name or photo.
  static void forget(String userId) => _cache.remove(userId);
}
