import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../models/job_model.dart';
import '../../../models/bookmarked_job_model.dart';
import '../../../core/constants/table_constants.dart';

class BookmarkedController {
  final _supabase = Supabase.instance.client;
  String get _currentSeekerID => Supabase.instance.client.auth.currentUser!.id;
  /// Flipped whenever a bookmark is added/removed (the Bookmarked tab reloads its list).
  static final ValueNotifier<bool> bookmarkNotifier = ValueNotifier(false);

  /// IDs of the current user's bookmarked jobs, loaded ONCE and shared by every
  /// JobCard and JobDetails screen (previously each card ran its own query, and
  /// every toggle made every card query again).
  static final ValueNotifier<Set<String>> bookmarkedIds = ValueNotifier(<String>{});
  static String? _loadedForUser;
  static Future<void>? _loading;

  /// Loads the bookmarked job IDs if they aren't loaded yet for the current user.
  /// Many cards can call this at the same time; only one query is sent.
  Future<void> ensureBookmarksLoaded({bool force = false}) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      bookmarkedIds.value = <String>{};
      _loadedForUser = null;
      return Future.value();
    }
    if (!force && _loadedForUser == userId) return Future.value();
    if (!force && _loading != null) return _loading!;

    _loading = _loadIds(userId).whenComplete(() => _loading = null);
    return _loading!;
  }

  Future<void> _loadIds(String userId) async {
    try {
      final rows = await _supabase
          .from(TableConstants.bookmarkedJob)
          .select('jobID')
          .eq('seekerID', userId);
      bookmarkedIds.value = (rows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['jobID'] as String)
          .toSet();
      _loadedForUser = userId; // switching account loads the new user's set
    } catch (e) {
      debugPrint('Error loading bookmarks: $e'); // will retry on next call
    }
  }

  void _setBookmarked(String jobId, bool bookmarked) {
    final updated = Set<String>.from(bookmarkedIds.value);
    bookmarked ? updated.add(jobId) : updated.remove(jobId);
    bookmarkedIds.value = updated;
  }

  /// Uses the shared cache: no database query per job.
  Future<bool> isJobBookmarked(String jobId) async {
    await ensureBookmarksLoaded();
    return bookmarkedIds.value.contains(jobId);
  }

  Future<bool> toggleBookmark(String jobId, bool currentlyBookmarked) async {
    try {
      if (currentlyBookmarked) {
        await _supabase
            .from(TableConstants.bookmarkedJob)
            .delete()
            .eq('seekerID', _currentSeekerID)
            .eq('jobID', jobId);

        _setBookmarked(jobId, false);
        bookmarkNotifier.value = !bookmarkNotifier.value;
        return false;
      } else {
        // 👉 Package the data into the Model
        final newBookmark = BookmarkedJobModel(
          seekerID: _currentSeekerID,
          jobID: jobId,
        );

        // 👉 Insert using toJson()
        await _supabase.from(TableConstants.bookmarkedJob).insert(newBookmark.toJson());
        _setBookmarked(jobId, true);
        bookmarkNotifier.value = !bookmarkNotifier.value;
        return true;
      }
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
      return currentlyBookmarked;
    }
  }

  Future<List<JobModel>> fetchBookmarkedJobs() async {
    try {
      final response = await _supabase
          .from(TableConstants.bookmarkedJob)
          .select('Job(*, Company(name))')
          .eq('seekerID', _currentSeekerID)
          .order('savedAt', ascending: false);

      final List<JobModel> bookmarkedJobs = (response as List<dynamic>)
          .where((item) => item['Job'] != null)
          .map((item) => JobModel.fromJson(item['Job'] as Map<String, dynamic>))
          .toList();

      return bookmarkedJobs;
    } catch (e) {
      debugPrint('Error fetching bookmarked jobs: $e');
      throw DataLoadException(
        'Unable to load your bookmarked jobs. Please check your connection and try again.',
      );
    }
  }
}