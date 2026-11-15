import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/file_picker_helper.dart';
import '../../../core/utils/storage_url_helper.dart';
import '../../../models/education_model.dart';
import '../../../models/job_seeker_model.dart';
import '../../../models/work_experience_model.dart';
import '../../../core/utils/session_helper.dart';
import '../../../services/auth_service.dart';

/// Job seeker profile data.
///
/// Convention used by all job seeker controllers:
/// - loads throw [DataLoadException] (or [SessionExpiredException]) with a
///   message the screen can show, so "failed" never looks like "empty";
/// - writes return true/false (or null for uploads) and the screen shows
///   the success or failure message.
class ProfileController {
  final _supabase = Supabase.instance.client;
  static const String _profilePicturesBucket = 'profile_pictures';
  static const String _resumesBucket = 'resumes';

  /// The logged-in seeker's profile with work experience and education.
  Future<JobSeekerModel> fetchProfile() async {
    try {
      final userId = SessionHelper.requireUserId();
      final response = await _supabase
          .from(TableConstants.jobSeeker)
          .select('*, WorkExperience(*), Education(*)')
          .eq('seekerID', userId)
          .single();

      return JobSeekerModel.fromJson(response);
    } on DataLoadException {
      rethrow; // session expired
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      throw DataLoadException(
        'Unable to load your profile. Please check your connection and try again.',
      );
    }
  }

  /// Full name of the logged-in job seeker (for the dashboard greeting).
  /// Optional decoration, so it returns null instead of throwing.
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

  /// Profile shown after scanning a QR code.
  /// Email, phone and resume are only included for employers, admins and the owner;
  /// [contactVisible] tells the screen whether they were hidden.
  /// Returns null if there is no such profile; throws [DataLoadException]
  /// if it couldn't be loaded.
  Future<({JobSeekerModel profile, bool contactVisible})?> fetchPublicProfile(
    String targetSeekerId,
  ) async {
    try {
      final viewerId = _supabase.auth.currentUser?.id;

      final response = await _supabase
          .from(TableConstants.jobSeeker)
          .select('*, WorkExperience(*), Education(*)')
          .eq('seekerID', targetSeekerId)
          .maybeSingle();
      if (response == null) return null;
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
        careerGoal: full.careerGoal,
        linkedInURL: full.linkedInURL,
        gitHubURL: full.gitHubURL,
        education: full.education,
        workExperience: full.workExperience,
        // email, phoneNumber and resumeURL intentionally left out
      );
      return (profile: limited, contactVisible: false);
    } catch (e) {
      debugPrint('Error fetching public profile: $e');
      throw DataLoadException(
        'Unable to load this profile. Please check your connection and try again.',
      );
    }
  }

  /// Uploads a resume file and saves its link on the profile.
  /// Returns the link, or null if it failed.
  ///
  /// The previous resume file is deleted afterwards, but only if none of the
  /// user's applications still uses it (employers open those links).
  Future<String?> uploadResume(File file) async {
    try {
      final userId = SessionHelper.requireUserId();
      final oldResumeUrl = await _currentResumeUrl(userId);
      final original = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'resume.pdf';
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${FilePickerHelper.storageSafeName(original)}';
      final filePath = '$userId/$fileName';

      // 1. Upload to Supabase Storage (Ensure you have a bucket named 'resumes')
      await _supabase.storage.from(_resumesBucket).upload(filePath, file);

      // 2. Get the public URL
      final newResumeUrl = _supabase.storage.from(_resumesBucket).getPublicUrl(filePath);

      // 3. Update the JobSeeker table with the new URL
      await _supabase
          .from(TableConstants.jobSeeker)
          .update({'resumeURL': newResumeUrl})
          .eq('seekerID', userId);

      // 4. Tidy up the replaced file (never blocks the upload)
      if (oldResumeUrl != null && oldResumeUrl != newResumeUrl) {
        await _deleteResumeIfUnused(userId, oldResumeUrl);
      }

      return newResumeUrl;
    } catch (e) {
      debugPrint('Error uploading resume: $e');
      return null;
    }
  }

  /// The resume link saved on the profile now, or null (none / can't tell).
  Future<String?> _currentResumeUrl(String userId) async {
    try {
      final row = await _supabase
          .from(TableConstants.jobSeeker)
          .select('resumeURL')
          .eq('seekerID', userId)
          .maybeSingle();
      final url = (row?['resumeURL'] as String?)?.trim();
      return url == null || url.isEmpty ? null : url;
    } catch (e) {
      debugPrint('Could not read the current resume link: $e');
      return null; // then nothing is deleted
    }
  }

  /// Deletes an old resume file from storage unless an application still links
  /// to it. Best effort: if anything fails, the file is simply kept.
  Future<void> _deleteResumeIfUnused(String userId, String oldUrl) async {
    final path = StorageUrlHelper.ownedPath(oldUrl, bucket: _resumesBucket, userId: userId);
    if (path == null) return; // not a file in the user's own resume folder
    try {
      final used = await _supabase
          .from(TableConstants.jobApplicant)
          .select('applicantID')
          .eq('seekerID', userId)
          .eq('submittedResumeURL', oldUrl)
          .limit(1);
      if ((used as List).isNotEmpty) return; // sent with an application: keep it
      await _supabase.storage.from(_resumesBucket).remove([path]);
    } catch (e) {
      debugPrint('Could not delete the old resume file: $e');
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

  /// Saves the fields of the profile form. The resume link and email are not
  /// in the form, so they are left out: a profile loaded before a new resume
  /// was set (e.g. from Build Resume) must not put the old link back.
  Future<bool> updateProfileBasics(JobSeekerModel updatedModel) async {
    try {
      final data = updatedModel.toJson()
        ..remove('seekerID')
        ..remove('resumeURL')
        ..remove('email');
      await _supabase
          .from(TableConstants.jobSeeker)
          .update(data)
          .eq('seekerID', updatedModel.seekerID);
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  /// The seeker's work experience, most recent first.
  Future<List<WorkExperienceModel>> fetchWorkExperiences() async {
    final userId = SessionHelper.requireUserId(); // throws if signed out
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
    final userId = SessionHelper.requireUserId(); // throws if signed out
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

  /// Logs out. Marked as manual so the dashboard doesn't show
  /// "session expired" for a logout the user asked for.
  Future<void> signOut() async {
    SessionHelper.markManualSignOut();
    await AuthService().signOut();
  }
}
