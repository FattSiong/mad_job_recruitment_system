import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/job_model.dart';
import '../../../models/bookmarked_job_model.dart';

class BookmarkedController {
  final _supabase = Supabase.instance.client;
  String get _currentSeekerID => Supabase.instance.client.auth.currentUser!.id;
  static final ValueNotifier<bool> bookmarkNotifier = ValueNotifier(false);

  Future<bool> isJobBookmarked(String jobId) async {
    try {
      final response = await _supabase
          .from('BookmarkedJob')
          .select()
          .eq('seekerID', _currentSeekerID)
          .eq('jobID', jobId);

      return response.isNotEmpty;
    } catch (e) {
      print('Error checking bookmark status: $e');
      return false;
    }
  }

  Future<bool> toggleBookmark(String jobId, bool currentlyBookmarked) async {
    try {
      if (currentlyBookmarked) {
        await _supabase
            .from('BookmarkedJob')
            .delete()
            .eq('seekerID', _currentSeekerID)
            .eq('jobID', jobId);

        bookmarkNotifier.value = !bookmarkNotifier.value;
        return false;
      } else {
        // 👉 Package the data into the Model
        final newBookmark = BookmarkedJobModel(
          seekerID: _currentSeekerID,
          jobID: jobId,
        );

        // 👉 Insert using toJson()
        await _supabase.from('BookmarkedJob').insert(newBookmark.toJson());
        bookmarkNotifier.value = !bookmarkNotifier.value;
        return true;
      }
    } catch (e) {
      print('Error toggling bookmark: $e');
      return currentlyBookmarked;
    }
  }

  Future<List<JobModel>> fetchBookmarkedJobs() async {
    try {
      final response = await _supabase
          .from('BookmarkedJob')
          .select('Job(*, Company(name))')
          .eq('seekerID', _currentSeekerID)
          .order('savedAt', ascending: false);

      final List<JobModel> bookmarkedJobs = (response as List<dynamic>)
          .where((item) => item['Job'] != null)
          .map((item) => JobModel.fromJson(item['Job'] as Map<String, dynamic>))
          .toList();

      return bookmarkedJobs;
    } catch (e) {
      print('Error fetching bookmarked jobs: $e');
      return [];
    }
  }
}