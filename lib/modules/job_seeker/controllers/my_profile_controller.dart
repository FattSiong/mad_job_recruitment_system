import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/file_picker_helper.dart';
import '../../../models/job_seeker_model.dart';
import '../../../models/skill_model.dart';
import '../../../services/user_directory.dart';
import 'profile_controller.dart';
import 'skill_controller.dart';

/// What the user typed in the profile form.
class ProfileEdits {
  final String fullName;
  final String phone;
  final String location;
  final String bio;
  final String linkedIn;
  final String gitHub;

  const ProfileEdits({
    required this.fullName,
    required this.phone,
    required this.location,
    required this.bio,
    required this.linkedIn,
    required this.gitHub,
  });
}

/// State of the job seeker's own Profile tab: the profile, skills, edit mode,
/// the new / removed photo, and saving or uploading.
///
/// Data access goes through [ProfileController] and [SkillController].
/// Picking files and photos stays in the screen (it opens system UI).
class MyProfileController extends ChangeNotifier {
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
  bool _disposed = false;

  JobSeekerModel? get profile => _profile;
  List<SkillModel> get skills => List.unmodifiable(_skills);
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  bool get isEditing => _isEditing;
  bool get isSaving => _isSaving;
  bool get isUploadingResume => _isUploadingResume;
  File? get newPhoto => _newPhoto;
  bool get photoRemoved => _removePhoto;

  bool get hasPhoto =>
      _newPhoto != null ||
      (!_removePhoto && (_profile?.profilePictureURL?.isNotEmpty ?? false));

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  Future<void> load() async {
    _isLoading = _profile == null;
    _loadError = null;
    _notify();
    try {
      final results = await Future.wait([
        _profiles.fetchProfile(),
        _fetchSkillsSafely(),
      ]);
      _profile = results[0] as JobSeekerModel;
      _skills = results[1] as List<SkillModel>;
      _newPhoto = null;
    } on DataLoadException catch (e) {
      _loadError = e.message;
    } finally {
      _isLoading = false;
      _notify();
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
    _notify();
  }

  // ---------------------------------------------------------------------
  // Editing
  // ---------------------------------------------------------------------

  void startEditing() {
    if (_profile == null) return;
    _isEditing = true;
    _notify();
  }

  void cancelEditing() {
    _isEditing = false;
    _newPhoto = null;
    _removePhoto = false;
    _notify();
  }

  void setNewPhoto(File file) {
    _newPhoto = file;
    _removePhoto = false;
    _notify();
  }

  void removePhoto() {
    _newPhoto = null;
    _removePhoto = true;
    _notify();
  }

  /// Saves the form (and the new or removed photo).
  /// Returns an error message, or null when saved.
  Future<String?> save(ProfileEdits edits) async {
    final current = _profile;
    if (current == null || _isSaving) return null;
    if (edits.fullName.trim().isEmpty) return 'Name cannot be empty.';

    _isSaving = true;
    _notify();
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
        linkedInURL: orNull(edits.linkedIn),
        gitHubURL: orNull(edits.gitHub),
        education: current.education,
        workExperience: current.workExperience,
      );

      if (!await _profiles.updateProfileBasics(updated)) {
        return 'Failed to update profile.';
      }

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
      _notify();
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
    _notify();
    try {
      final url = await _profiles.uploadResume(file);
      if (url == null) return 'Failed to upload resume.';
      await load();
      return null;
    } finally {
      _isUploadingResume = false;
      _notify();
    }
  }

  Future<void> signOut() => _profiles.signOut();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
