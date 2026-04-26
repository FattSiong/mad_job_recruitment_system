import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/education_model.dart';
import '../../../models/job_seeker_model.dart';
import '../../../models/work_experience_model.dart';

class ProfileController {
  final _supabase = Supabase.instance.client;
  static const String _profilePicturesBucket = 'profile_pictures';
  bool isLoading = false;

  Future<JobSeekerModel?> fetchProfile() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('JobSeeker')
          .select('*, WorkExperience(*), Education(*)')
          .eq('seekerID', userId)
          .single();

      return JobSeekerModel.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  Future<JobSeekerModel?> fetchPublicProfile(String targetSeekerId) async {
    try {
      final response = await _supabase
          .from('JobSeeker')
          .select('*, WorkExperience(*), Education(*)')
          .eq('seekerID', targetSeekerId)
          .single();

      return JobSeekerModel.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching public profile: $e');
      return null;
    }
  }

  // 👉 ADDED BACK: The missing uploadResume method
  Future<String?> uploadResume(File file) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final filePath = '$userId/$fileName';

      // 1. Upload to Supabase Storage (Ensure you have a bucket named 'resumes')
      await _supabase.storage.from('resumes').upload(filePath, file);

      // 2. Get the public URL
      final newResumeUrl = _supabase.storage.from('resumes').getPublicUrl(filePath);

      // 3. Update the JobSeeker table with the new URL
      await _supabase
          .from('JobSeeker')
          .update({'resumeURL': newResumeUrl})
          .eq('seekerID', userId);

      return newResumeUrl;
    } catch (e) {
      debugPrint('Error uploading resume: $e');
      return null;
    }
  }

  Future<String?> uploadProfilePicture(File file) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final fileExt = file.path.split('.').last.toLowerCase();
      final fileName =
          'profile_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$userId/$fileName';

      await _supabase.storage.from(_profilePicturesBucket).upload(filePath, file);

      return _supabase.storage
          .from(_profilePicturesBucket)
          .getPublicUrl(filePath);
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      return null;
    }
  }

  Future<bool> updateProfileBasics({
    required BuildContext context,
    required JobSeekerModel updatedModel,
  }) async {
    try {
      await _supabase
          .from('JobSeeker')
          .update(updatedModel.toJson())
          .eq('seekerID', updatedModel.seekerID);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile.')),
        );
      }
      return false;
    }
  }

  Future<void> deleteWorkExperience({
    required BuildContext context,
    required String experienceId,
    required VoidCallback onSuccess,
  }) async {
    try {
      await _supabase.from('WorkExperience').delete().eq('experienceID', experienceId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Work experience removed'), backgroundColor: Colors.orange),
        );
      }
      onSuccess();
    } catch (e) {
      debugPrint('Error deleting experience: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove work experience.')),
        );
      }
    }
  }

  Future<void> addWorkExperience({
    required BuildContext context,
    required WorkExperienceModel experience,
    required VoidCallback onSucess,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = experience.toJson();
      data['seekerID'] = userId;

      await _supabase.from('WorkExperience').insert(data);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Work experience added!')),
        );
      }
      onSucess();
    } catch (e) {
      debugPrint('Error adding experience: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add work experience.')),
        );
      }
    }
  }

  Future<void> addEducation({
    required BuildContext context,
    required EducationModel education,
    required VoidCallback onSucess,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = education.toJson();
      data['seekerID'] = userId;

      await _supabase.from('Education').insert(data);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Education added!')),
        );
      }
      onSucess();
    } catch (e) {
      debugPrint('Error adding education: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add education.')),
        );
      }
    }
  }

  Future<void> deleteEducation({
    required BuildContext context,
    required String educationId,
    required VoidCallback onSuccess,
  }) async {
    try {
      await _supabase.from('Education').delete().eq('educationID', educationId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Education removed'), backgroundColor: Colors.orange),
        );
      }
      onSuccess();
    } catch (e) {
      debugPrint('Error deleting education: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove education.')),
        );
      }
    }
  }
}
