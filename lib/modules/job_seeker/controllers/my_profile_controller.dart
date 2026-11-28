import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/file_picker_helper.dart';
import '../../../core/utils/link_helper.dart';
import '../../../models/job_seeker_model.dart';
import '../../../models/profile_check.dart';
import '../../../models/skill_model.dart';
import '../../../services/user_directory.dart';
import 'profile_controller.dart';
import 'skill_controller.dart';
import '../../../core/utils/safe_notifier.dart';

/// What the user typed in the profile form.
class ProfileEdits {
  final String fullName;
  final String phone;
  final String location;
  final String bio;
  final String careerGoal;
  final String linkedIn;
  final String gitHub;

  const ProfileEdits({
    required this.fullName,
    required this.phone,
    required this.location,
    required this.bio,
    required this.careerGoal,
    required this.linkedIn,
    required this.gitHub,
  });
}

/// State of the job seeker's own Profile tab: the profile, skills, edit mode,
/// the new / removed photo, and saving or uploading.
///
/// Data access goes through [ProfileController] and [SkillController].
/// Picking files and photos stays in the screen (it opens system UI).
class MyProfileController extends ChangeNotifier with SafeNotifier {
  final ProfileController _profiles;
  final SkillController _skillsApi;

  MyProfileController({ProfileController? profiles, SkillController? skills})
      : _profiles = profiles ?? ProfileController(),
        _skillsApi = skills ?? SkillController();

  JobSeekerModel? _profile;
  List<SkillModel> _skills = [];
  bool _isLoading = true;
  String? _loadError;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingResume = false;
  File? _newPhoto;
  bool _removePhoto = false; // "Remove photo" chosen; applied on Save

  JobSeekerModel? get profile => _profile;
  List<SkillModel> get skills => List.unmodifiable(_skills);
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  bool get isEditing => _isEditing;
  bool get isSaving => _isSaving;
  bool get isUploadingResume => _isUploadingResume;
  File? get newPhoto => _newPhoto;
  bool get photoRemoved => _removePhoto;

  // ---------------------------------------------------------------------
  // Profile checklist ("Profile 70% complete")
  // ---------------------------------------------------------------------

  /// Each [ProfileCheck] and whether it is filled in (saved data only).
  Map<ProfileCheck, bool> get checklist {
    final p = _profile;
    bool filled(String? value) => value != null && value.trim().isNotEmpty;
    return {
      ProfileCheck.photo: filled(p?.profilePictureURL),
      ProfileCheck.phone: filled(p?.phoneNumber),
      ProfileCheck.location: filled(p?.location),
      ProfileCheck.bio: filled(p?.bio),
      ProfileCheck.careerGoal: filled(p?.careerGoal),
      ProfileCheck.resume: filled(p?.resumeURL),
      ProfileCheck.experience: p?.workExperience.isNotEmpty ?? false,
      ProfileCheck.education: p?.education.isNotEmpty ?? false,
      ProfileCheck.skills: _skills.isNotEmpty,
    };
  }

  List<ProfileCheck> get missingItems =>
      checklist.entries.where((e) => !e.value).map((e) => e.key).toList();

  /// 0-100.
  int get completionPercent {
    final items = checklist;
    final done = items.values.where((v) => v).length;
    return (done * 100 / items.length).round();
  }

  /// True if [edits] (what is in the form) or the photo differ from the
  /// saved profile, i.e. Cancel / Back would lose something.
  bool hasUnsavedChanges(ProfileEdits edits) {
    final p = _profile;
    if (p == null || !_isEditing) return false;
    String n(String? value) => (value ?? '').trim();
    return _newPhoto != null ||
        _removePhoto ||
        n(edits.fullName) != n(p.fullName) ||
        n(edits.phone) != n(p.phoneNumber) ||
        n(edits.location) != n(p.location) ||
        n(edits.bio) != n(p.bio) ||
        n(edits.careerGoal) != n(p.careerGoal) ||
        n(edits.linkedIn) != n(p.linkedInURL) ||
        n(edits.gitHub) != n(p.gitHubURL);
  }

  bool get hasPhoto =>
      _newPhoto != null ||
      (!_removePhoto && (_profile?.profilePictureURL?.isNotEmpty ?? false));

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  /// Loads the profile and skills. Shows the spinner only on the first load.
  Future<void> load() async {
    _isLoading = _profile == null;
    _loadError = null;
    notifySafely();
    try {
      final results = await Future.wait([
        _profiles.fetchProfile(),
        _fetchSkillsSafely(),
      ]);
      _profile = results[0] as JobSeekerModel;
      _skills = results[1] as List<SkillModel>;
      // (a photo picked in edit mode but not saved yet is kept)
    } on DataLoadException catch (e) {
      _loadError = e.message;
    } finally {
      _isLoading = false;
      notifySafely();
    }
  }

  /// Skills failing to load shouldn't stop the rest of the profile from showing.
  Future<List<SkillModel>> _fetchSkillsSafely() async {
    try {
      return await _skillsApi.fetchMySkills();
    } catch (_) {
      return _skills;
    }
  }

  /// After the Skills screen closes.
  Future<void> refreshSkills() async {
    _skills = await _fetchSkillsSafely();
    notifySafely();
  }

  // ---------------------------------------------------------------------
  // Editing
  // ---------------------------------------------------------------------

  /// Switches the Profile tab to edit mode.
  void startEditing() {
    if (_profile == null) return;
    _isEditing = true;
    notifySafely();
  }

  /// Leaves edit mode and forgets an unsaved photo change.
  void cancelEditing() {
    _isEditing = false;
    _newPhoto = null;
    _removePhoto = false;
    notifySafely();
  }

  /// A new photo to upload on Save.
  void setNewPhoto(File file) {
    _newPhoto = file;
    _removePhoto = false;
    notifySafely();
  }

  /// Removes the photo on Save.
  void removePhoto() {
    _newPhoto = null;
    _removePhoto = true;
    notifySafely();
  }

  /// Saves the form (and the new or removed photo).
  /// Returns an error message, or null when saved.
  Future<String?> save(ProfileEdits edits) async {
    final current = _profile;
    if (current == null || _isSaving) return null;
    if (edits.fullName.trim().isEmpty) return 'Name cannot be empty.';

    _isSaving = true;
    notifySafely();
    try {
      final oldPictureUrl = current.profilePictureURL;
      String? pictureUrl = _removePhoto ? null : oldPictureUrl;
      if (_newPhoto != null) {
        final uploaded = await _profiles.uploadProfilePicture(_newPhoto!);
        if (uploaded == null) return 'Failed to upload profile photo.';
        pictureUrl = uploaded;
      }

      String? orNull(String value) => value.trim().isEmpty ? null : value.trim();
      final updated = JobSeekerModel(
        seekerID: current.seekerID,
        fullName: edits.fullName.trim(),
        email: current.email,
        resumeURL: current.resumeURL,
        profilePictureURL: pictureUrl,
        phoneNumber: orNull(edits.phone),
        location: orNull(edits.location),
        bio: orNull(edits.bio),
        careerGoal: orNull(edits.careerGoal),
        linkedInURL: LinkHelper.toSavedLink(edits.linkedIn),
        gitHubURL: LinkHelper.toSavedLink(edits.gitHub),
        education: current.education,
        workExperience: current.workExperience,
      );

      var saved = await _profiles.updateProfileBasics(updated);
      if (!saved && pictureUrl != null && pictureUrl != oldPictureUrl) {
        // The save may have gone through with only its reply lost (the new
        // photo link tells). If not, that photo is deleted (Save uploads it again).
        saved = await _profiles.profilePictureSavedAnyway(pictureUrl);
      }
      if (!saved) return 'Failed to update profile.';

      _profile = updated;
      _isEditing = false;
      UserDirectory.forget(updated.seekerID); // chat / community show the new name and photo
      _newPhoto = null;
      _removePhoto = false;

      // The old photo is no longer used (replaced or removed): clean it up.
      if (oldPictureUrl != null && oldPictureUrl.isNotEmpty && oldPictureUrl != pictureUrl) {
        _profiles.deleteProfilePictureFile(oldPictureUrl);
      }
      return null;
    } finally {
      _isSaving = false;
      notifySafely();
    }
  }

  // ---------------------------------------------------------------------
  // Resume
  // ---------------------------------------------------------------------

  /// Uploads a resume chosen by the user. Returns an error message, or null
  /// when uploaded (the profile is then reloaded).
  Future<String?> uploadResume(File file) async {
    if (!FileLimits.isAllowedResume(file.path)) {
      return 'Please choose a ${FileLimits.resumeTypesLabel} file.';
    }
    final sizeError = await FilePickerHelper.checkSize(file, FileLimits.resumeMB);
    if (sizeError != null) return sizeError;

    _isUploadingResume = true;
    notifySafely();
    try {
      final url = await _profiles.uploadResume(file);
      if (url == null) return 'Failed to upload resume.';
      await load();
      return null;
    } finally {
      _isUploadingResume = false;
      notifySafely();
    }
  }

  /// Logs out (see [ProfileController.signOut]).
  Future<void> signOut() => _profiles.signOut();
}
