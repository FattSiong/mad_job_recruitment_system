import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/job_seeker_model.dart';

class ProfileController {
  final _supabase = Supabase.instance.client;
  String get _currentSeekerID => Supabase.instance.client.auth.currentUser!.id;

  /// Fetches the user's profile and returns a JobSeekerModel
  Future<JobSeekerModel?> getProfile() async {
    try {
      final response = await _supabase
          .from('JobSeeker')
          .select()
          .eq('seekerID', _currentSeekerID)
          .maybeSingle();

      if (response != null) {
        return JobSeekerModel.fromJson(response); // 👉 Convert JSON to Model
      }
      return null;
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }

  /// Uploads a new resume to storage and updates the database
  Future<String?> uploadResume(File file) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final filePath = '$_currentSeekerID/$fileName';

      await _supabase.storage.from('resumes').upload(filePath, file);
      final newResumeUrl = _supabase.storage.from('resumes').getPublicUrl(filePath);

      await _supabase
          .from('JobSeeker')
          .update({'resumeURL': newResumeUrl})
          .eq('seekerID', _currentSeekerID);

      return newResumeUrl;
    } catch (e) {
      print('Error uploading resume: $e');
      return null;
    }
  }
}