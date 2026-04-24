import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/job_seeker_model.dart'; // 👉 Import the new model

class ProfileController {
  final _supabase = Supabase.instance.client;
  final String _mockSeekerID = '773ed23f-95ca-4853-ae50-06bd5e411bad';

  /// Fetches the user's profile and returns a JobSeekerModel
  Future<JobSeekerModel?> getProfile() async {
    try {
      final response = await _supabase
          .from('JobSeeker')
          .select()
          .eq('seekerID', _mockSeekerID)
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
      final filePath = '$_mockSeekerID/$fileName';

      await _supabase.storage.from('resumes').upload(filePath, file);
      final newResumeUrl = _supabase.storage.from('resumes').getPublicUrl(filePath);

      await _supabase
          .from('JobSeeker')
          .update({'resumeURL': newResumeUrl})
          .eq('seekerID', _mockSeekerID);

      return newResumeUrl;
    } catch (e) {
      print('Error uploading resume: $e');
      return null;
    }
  }
}