import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../models/education_model.dart';
import '../../../models/job_seeker_model.dart';
import '../../../models/work_experience_model.dart';
import '../../../core/utils/session_helper.dart';

class ProfileController {
  final _supabase = Supabase.instance.client;
  static const String _profilePicturesBucket = 'profile_pictures';

  Future<JobSeekerModel?> fetchProfile() async {
    try {
      final userId = SessionHelper.requireUserId();
      final response = await _supabase
          .from(TableConstants.jobSeeker)
          .select('*, WorkExperience(*), Education(*)')
          .eq('seekerID', userId)
          .single();

      return JobSeekerModel.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  /// Full name of the logged-in job seeker (for the dashboard greeting).
  Future<String?> fetchFullName() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;
      final row = await _supabase
          .from(TableConstants.jobSeeker)
          .select('fullName')
          .eq('seekerID', userId)
          .maybeSingle();
      return row?['fullName'] as String?;
    } catch (e) {
      debugPrint('Error fetching name: $e');
      return null;
    }
  }

  /// Profile shown after scanning a QR code (fix #8).
  /// Email, phone and resume are only included for employers, admins and the owner;
  /// [contactVisible] tells the screen whether they were hidden.
  Future<({JobSeekerModel profile, bool contactVisible})?> fetchPublicProfile(
    String targetSeekerId,
  ) async {
    try {
      final viewerId = _supabase.auth.currentUser?.id;

      final response = await _supabase
          .from(TableConstants.jobSeeker)
          .select('*, WorkExperience(*), Education(*)')
          .eq('seekerID', targetSeekerId)
          .single();
      final full = JobSeekerModel.fromJson(response);

      String? viewerRole;
      if (viewerId != null) {
        final roleRow = await _supabase
            .from(TableConstants.user)
            .select('role')
            .eq('userID', viewerId)
            .maybeSingle();
        viewerRole = roleRow?['role'] as String?;
      }

      final contactVisible = viewerId == targetSeekerId ||
          viewerRole == 'employer' ||
          viewerRole == 'admin';
      if (contactVisible) return (profile: full, contactVisible: true);

      final limited = JobSeekerModel(
        seekerID: full.seekerID,
        fullName: full.fullName,
        profilePictureURL: full.profilePictureURL,
        location: full.location,
        bio: full.bio,
        linkedInURL: full.linkedInURL,
        gitHubURL: full.gitHubURL,
        education: full.education,
        workExperience: full.workExperience,
        // email, phoneNumber and resumeURL intentionally left out
      );
      return (profile: limited, contactVisible: false);
    } catch (e) {
      debugPrint('Error fetching public profile: $e');
      return null;
    }
  }

  // 👉 ADDED BACK: The missing uploadResume method
  Future<String?> uploadResume(File file) async {
    try {
      final userId = SessionHelper.requireUserId();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final filePath = '$userId/$fileName';

      // 1. Upload to Supabase Storage (Ensure you have a bucket named 'resumes')
      await _supabase.storage.from('resumes').upload(filePath, file);

      // 2. Get the public URL
      final newResumeUrl = _supabase.storage.from('resumes').getPublicUrl(filePath);

      // 3. Update the JobSeeker table with the new URL
      await _supabase
          .from(TableConstants.jobSeeker)
          .update({'resumeURL': newResumeUrl})
          .eq('seekerID', userId);

      return newResumeUrl;
    } catch (e) {
      debugPrint('Error uploading resume: $e');
      return null;
    }
  }

  /// Deletes an old profile photo from storage (best effort: a leftover file
  /// is harmless, so errors are only logged).
  Future<void> deleteProfilePictureFile(String publicUrl) async {
    try {
      const marker = '/$_profilePicturesBucket/';
      final index = publicUrl.indexOf(marker);
      if (index == -1) return;
      final path = Uri.decodeComponent(publicUrl.substring(index + marker.length).split('?').first);
      await _supabase.storage.from(_profilePicturesBucket).remove([path]);
    } catch (e) {
      debugPrint('Could not delete old profile photo: $e');
    }
  }

  Future<String?> uploadProfilePicture(File file) async {
    try {
      final userId = SessionHelper.requireUserId();
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

  // ---------------------------------------------------------------------
  // Writes. These only talk to the database and return true/false.
  // The screen decides what message to show (MVC: no UI code in controllers).
  // ---------------------------------------------------------------------

  Future<bool> updateProfileBasics(JobSeekerModel updatedModel) async {
    try {
      await _supabase
          .from(TableConstants.jobSeeker)
          .update(updatedModel.toJson())
          .eq('seekerID', updatedModel.seekerID);
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  /// The seeker's work experience, most recent first.
  Future<List<WorkExperienceModel>> fetchWorkExperiences() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final response = await _supabase
          .from(TableConstants.workExperience)
          .select()
          .eq('seekerID', userId)
          .order('isCurrent', ascending: false)
          .order('startDate', ascending: false);
      return (response as List)
          .map((row) => WorkExperienceModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching experience: $e');
      throw DataLoadException(
        'Unable to load your work experience. Please check your connection and try again.',
      );
    }
  }

  /// The seeker's education, most recent first.
  Future<List<EducationModel>> fetchEducation() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final response = await _supabase
          .from(TableConstants.education)
          .select()
          .eq('seekerID', userId)
          .order('isCurrent', ascending: false)
          .order('startDate', ascending: false);
      return (response as List)
          .map((row) => EducationModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching education: $e');
      throw DataLoadException(
        'Unable to load your education. Please check your connection and try again.',
      );
    }
  }

  Future<bool> updateWorkExperience(WorkExperienceModel experience) async {
    if (experience.experienceID == null) return false;
    try {
      final data = experience.toJson()..remove('seekerID');
      await _supabase
          .from(TableConstants.workExperience)
          .update(data)
          .eq('experienceID', experience.experienceID!)
          .eq('seekerID', SessionHelper.requireUserId()); // only your own records
      return true;
    } catch (e) {
      debugPrint('Error updating experience: $e');
      return false;
    }
  }

  Future<bool> updateEducation(EducationModel education) async {
    if (education.educationID == null) return false;
    try {
      final data = education.toJson()..remove('seekerID');
      await _supabase
          .from(TableConstants.education)
          .update(data)
          .eq('educationID', education.educationID!)
          .eq('seekerID', SessionHelper.requireUserId()); // only your own records
      return true;
    } catch (e) {
      debugPrint('Error updating education: $e');
      return false;
    }
  }

  Future<bool> addWorkExperience(WorkExperienceModel experience) async {
    try {
      final data = experience.toJson();
      data['seekerID'] = SessionHelper.requireUserId();
      await _supabase.from(TableConstants.workExperience).insert(data);
      return true;
    } catch (e) {
      debugPrint('Error adding experience: $e');
      return false;
    }
  }

  Future<bool> deleteWorkExperience(String experienceId) async {
    try {
      await _supabase
          .from(TableConstants.workExperience)
          .delete()
          .eq('experienceID', experienceId)
          .eq('seekerID', SessionHelper.requireUserId()); // only your own records
      return true;
    } catch (e) {
      debugPrint('Error deleting experience: $e');
      return false;
    }
  }

  Future<bool> addEducation(EducationModel education) async {
    try {
      final data = education.toJson();
      data['seekerID'] = SessionHelper.requireUserId();
      await _supabase.from(TableConstants.education).insert(data);
      return true;
    } catch (e) {
      debugPrint('Error adding education: $e');
      return false;
    }
  }

  Future<bool> deleteEducation(String educationId) async {
    try {
      await _supabase
          .from(TableConstants.education)
          .delete()
          .eq('educationID', educationId)
          .eq('seekerID', SessionHelper.requireUserId()); // only your own records
      return true;
    } catch (e) {
      debugPrint('Error deleting education: $e');
      return false;
    }
  }
}
