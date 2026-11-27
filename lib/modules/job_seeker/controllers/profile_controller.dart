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
import '../../../services/user_directory.dart';

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

  /// Full name and photo of the logged-in job seeker (for the Home greeting).
  /// Optional decoration, so it returns null instead of throwing.
  Future<({String? fullName, String? photoUrl})?> fetchGreeting() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;
      final row = await _supabase
          .from(TableConstants.jobSeeker)
          .select('fullName, profilePictureURL')
          .eq('seekerID', userId)
          .maybeSingle();
      if (row == null) return null;
      return (
        fullName: row['fullName'] as String?,
        photoUrl: row['profilePictureURL'] as String?,
      );
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

      String? viewerRole;
      if (viewerId != null) {
        final roleRow = await _supabase
            .from(TableConstants.user)
            .select('role')
            .eq('userID', viewerId)
            .maybeSingle();
        viewerRole = (roleRow?['role'] as String?)?.toLowerCase();
      }

      final contactVisible = viewerId == targetSeekerId ||
          viewerRole == 'employer' ||
          viewerRole == 'admin';
      if (contactVisible) {
        final response = await _supabase
            .from(TableConstants.jobSeeker)
            .select('*, WorkExperience(*), Education(*)')
            .eq('seekerID', targetSeekerId)
            .maybeSingle();
        if (response == null) return null;
        return (profile: JobSeekerModel.fromJson(response), contactVisible: true);
      }

      // Other job seekers: public fields only. Email, phone and resume
      // aren't sent to their phone at all (the database keeps them back).
      final results = await Future.wait<List<Map<String, dynamic>>>([
        UserDirectory.publicSeekerRows([targetSeekerId]),
        _supabase.from(TableConstants.education).select().eq('seekerID', targetSeekerId),
        _supabase.from(TableConstants.workExperience).select().eq('seekerID', targetSeekerId),
      ]);
      if (results[0].isEmpty) return null;
      final profile = JobSeekerModel.fromJson({
        ...results[0].first,
        'Education': results[1],
        'WorkExperience': results[2],
      });
      return (profile: profile, contactVisible: false);
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

      // 1. Upload the file to the user's folder in the 'resumes' bucket
      await _supabase.storage.from(_resumesBucket).upload(filePath, file);

      // 2. Make the stored link. The bucket is private, so this link only
      //    names the file: the app opens it through a signed URL
      //    (StorageUrlHelper), and only people allowed to see it can.
      final newResumeUrl = _supabase.storage.from(_resumesBucket).getPublicUrl(filePath);

      // 3. Save the link on the profile. If that fails, the new file isn't
      //    used and is deleted. When it can't be told whether it saved
      //    (still offline), the file is kept: a spare file is harmless, a
      //    profile linking to a deleted resume is not.
      final saved = await _saveResumeUrl(userId, newResumeUrl);
      if (saved != true) {
        if (saved == false) {
          await StorageUrlHelper.removeOwnFile(newResumeUrl, bucket: _resumesBucket, userId: userId);
        }
        return null;
      }

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

  /// Saves [url] as the profile's resume: true when saved, false when not,
  /// null when it can't be told (the reply was lost and checking failed).
  Future<bool?> _saveResumeUrl(String userId, String url) async {
    try {
      await _supabase
          .from(TableConstants.jobSeeker)
          .update({'resumeURL': url})
          .eq('seekerID', userId);
      return true;
    } catch (e) {
      debugPrint('Error saving the resume link: $e');
      // The update may have gone through with only its reply lost
      return _savedValueIs('resumeURL', url);
    }
  }

  /// Whether the profile's [column] is [value] now: true / false, or null
  /// when it can't be checked (e.g. still offline).
  Future<bool?> _savedValueIs(String column, String value) async {
    try {
      final row = await _supabase
          .from(TableConstants.jobSeeker)
          .select(column)
          .eq('seekerID', SessionHelper.requireUserId())
          .maybeSingle();
      return row?[column] == value;
    } catch (e) {
      debugPrint('Could not check the saved $column: $e');
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

  /// After a failed profile save with the new photo [publicUrl]: true when
  /// the save went through anyway (only its reply was lost). Otherwise the
  /// photo isn't used and its file is deleted, unless that can't be told
  /// (then it's kept: a spare file is harmless, a missing photo is not).
  Future<bool> profilePictureSavedAnyway(String publicUrl) async {
    final saved = await _savedValueIs('profilePictureURL', publicUrl);
    if (saved == false) await deleteProfilePictureFile(publicUrl);
    return saved == true;
  }

  /// Uploads a profile photo and returns its public link, or null if it failed.
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

  /// Saves changes to one of the user's work experience entries.
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

  /// Saves changes to one of the user's education entries.
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

  /// Adds a work experience entry to the user's profile.
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

  /// Deletes one of the user's work experience entries.
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

  /// Adds an education entry to the user's profile.
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

  /// Deletes one of the user's education entries.
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
