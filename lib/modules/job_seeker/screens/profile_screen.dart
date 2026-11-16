import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_picker_helper.dart';
import '../../../core/utils/link_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/education_model.dart';
import '../../../models/profile_check.dart';
import '../../../models/work_experience_model.dart';
import '../../../shared_widgets/confirm_dialog.dart';
import '../../../shared_widgets/login_screen.dart';
import '../../../shared_widgets/skill_chips.dart';
import '../../../shared_widgets/surface_card.dart';
import '../controllers/my_profile_controller.dart';
import '../widgets/load_error_view.dart';
import '../widgets/profile/career_tools_grid.dart';
import '../widgets/profile/profile_avatar.dart';
import '../widgets/profile/profile_completeness_card.dart';
import '../widgets/profile/profile_details_card.dart';
import '../widgets/profile/profile_hero_header.dart';
import '../widgets/profile/profile_photo_picker.dart';
import '../widgets/profile/profile_qr_dialog.dart';
import '../widgets/profile/profile_record_card.dart';
import '../widgets/profile/profile_resume_card.dart';
import '../widgets/profile/profile_sections.dart';
import '../widgets/profile/profile_sheet_helpers.dart';
import 'add_skill_screen.dart';
import 'education_screen.dart';
import 'public_profile_screen.dart';
import 'work_experience_screen.dart';

/// The job seeker's own Profile tab: details, resume, career tools,
/// work experience, education and skills.
///
/// State lives in [MyProfileController]; the parts of the page are widgets
/// in widgets/profile. This screen wires them together and handles the
/// actions (save, cancel, upload, logout, opening other screens).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final MyProfileController _myProfile = MyProfileController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ProfileFormFields _fields = ProfileFormFields();

  @override
  void initState() {
    super.initState();
    _myProfile.addListener(_onProfileChanged);
    _loadProfile();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _fields.dispose();
    _myProfile.removeListener(_onProfileChanged);
    _myProfile.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  Future<void> _loadProfile() async {
    await _myProfile.load();
    _fillForm();
  }

  /// Puts the saved profile into the form. Skipped while editing, so a reload
  /// (after a resume upload, or back from Experience / Education) never
  /// throws away what the user is typing.
  void _fillForm() {
    final profile = _myProfile.profile;
    if (mounted && profile != null && !_myProfile.isEditing) _fields.fill(profile);
  }

  String get _firstName {
    final name = _myProfile.profile?.fullName.trim() ?? '';
    return name.isEmpty ? 'there' : name.split(RegExp(r'\s+')).first;
  }

  // ---------------------------------------------------------------------
  // Opening other screens
  // ---------------------------------------------------------------------

  /// Work experience / education screens; the profile reloads afterwards.
  Future<void> _openRecords(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _loadProfile();
  }

  /// Build Resume can set a new profile resume, so reload when it closes.
  void _onResumeToolClosed() {
    if (mounted) _loadProfile();
  }

  Future<void> _openSkills() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSkillScreen()));
    if (mounted) await _myProfile.refreshSkills();
  }

  /// The read-only profile employers and QR scanners see.
  void _openPublicProfile() {
    final profile = _myProfile.profile;
    if (profile == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PublicProfileScreen(seekerId: profile.seekerID)),
    );
  }

  Future<void> _openLink(String url) async {
    final opened = await LinkHelper.openExternal(url);
    if (!opened && mounted) {
      SnackBarHelper.showError(
        context,
        LinkHelper.toWebUri(url) == null
            ? 'This link doesn\'t look right. Please check it in Edit Profile.'
            : 'Could not open this link.',
      );
    }
  }

  /// A missing item in the profile checklist was tapped.
  void _fixItem(ProfileCheck item) {
    switch (item) {
      case ProfileCheck.photo:
        _myProfile.startEditing();
        _changePhoto();
      case ProfileCheck.phone:
      case ProfileCheck.location:
      case ProfileCheck.bio:
      case ProfileCheck.careerGoal:
        _myProfile.startEditing();
      case ProfileCheck.resume:
        _pickAndUploadResume();
      case ProfileCheck.experience:
        _openRecords(const WorkExperienceScreen());
      case ProfileCheck.education:
        _openRecords(const EducationScreen());
      case ProfileCheck.skills:
        _openSkills();
    }
  }

  // ---------------------------------------------------------------------
  // Editing
  // ---------------------------------------------------------------------

  Future<void> _changePhoto() async {
    final result = await pickProfilePhoto(context, hasPhoto: _myProfile.hasPhoto);
    if (!mounted || result == null) return;
    switch (result) {
      case ProfilePhotoPicked(:final file):
        _myProfile.setNewPhoto(file);
      case ProfilePhotoRemoved():
        _myProfile.removePhoto();
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final error = await _myProfile.save(_fields.toEdits());
    if (!mounted) return;
    if (error == null) {
      _fillForm();
      SnackBarHelper.showSuccess(context, 'Profile updated successfully!');
    } else {
      SnackBarHelper.showError(context, error);
    }
  }

  /// Leaves edit mode (Cancel or Back). Asks first if changes would be lost.
  Future<void> _cancelEditing() async {
    if (_myProfile.isSaving) return;
    if (_myProfile.hasUnsavedChanges(_fields.toEdits())) {
      final discard = await showConfirmDialog(
        context,
        title: 'Discard changes?',
        message: 'Your profile changes haven\'t been saved.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
      );
      if (!discard || !mounted) return;
    }
    _myProfile.cancelEditing();
    _fillForm();
  }

  // ---------------------------------------------------------------------
  // Resume and logout
  // ---------------------------------------------------------------------

  Future<void> _pickAndUploadResume() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: FileLimits.resumeExtensions,
    );
    final path = result?.files.single.path;
    if (path == null) return; // cancelled

    final error = await _myProfile.uploadResume(File(path));
    if (!mounted) return;
    if (error == null) {
      _fillForm();
      SnackBarHelper.showSuccess(context, 'Resume uploaded successfully!');
    } else {
      SnackBarHelper.showError(context, error);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: 'You\'ll need to log in again to see your jobs and messages.',
      confirmLabel: 'Log out',
    );
    if (!confirmed || !mounted) return;

    await _myProfile.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  Widget _experienceCard(WorkExperienceModel exp) {
    return ProfileRecordCard(
      icon: Icons.work_outline_rounded,
      iconColor: AppColors.primary,
      title: exp.jobTitle,
      subtitle: exp.companyName,
      dateRange: formatProfileDateRange(exp.startDate, exp.endDate, exp.isCurrent),
      description: exp.description,
    );
  }

  Widget _educationCard(EducationModel edu) {
    final field = edu.fieldOfStudy;
    return ProfileRecordCard(
      icon: Icons.school_outlined,
      iconColor: AppColors.warning,
      title: field != null && field.isNotEmpty ? '${edu.degree} - $field' : edu.degree,
      subtitle: edu.institutionName,
      dateRange: formatProfileDateRange(edu.startDate, edu.endDate, edu.isCurrent),
      description: edu.description,
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = _myProfile.isEditing;
    final saving = _myProfile.isSaving;

    return PopScope(
      // Back while editing leaves edit mode (asking first) instead of the app.
      canPop: !editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelEditing();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _buildBody(editing, saving),
        floatingActionButton: (!editing && _myProfile.profile != null)
            ? FloatingActionButton.extended(
                onPressed: _myProfile.startEditing,
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                label: const Text(
                  'Edit Profile',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                backgroundColor: AppColors.primary,
                elevation: 0,
              )
            : null,
        bottomNavigationBar: editing ? _buildEditBar(saving) : null,
      ),
    );
  }

  Widget _buildBody(bool editing, bool saving) {
    if (_myProfile.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final profile = _myProfile.profile;
    if (profile == null) {
      return LoadErrorView(
        message: _myProfile.loadError ?? 'Failed to load profile.',
        onRetry: _loadProfile,
      );
    }
    final skills = _myProfile.skills;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadProfile,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileHeroHeader(
                firstName: _firstName,
                avatar: ProfileAvatar(
                  name: profile.fullName,
                  imageUrl: profile.profilePictureURL,
                  newPhoto: _myProfile.newPhoto,
                  photoRemoved: _myProfile.photoRemoved,
                  onEdit: editing && !saving ? _changePhoto : null,
                ),
                onViewPublic: editing ? null : _openPublicProfile,
                onShowQr: editing ? null : () => showProfileQrDialog(context, profile.seekerID),
              ),
              if (!editing) ...[
                const SizedBox(height: 16),
                ProfileCompletenessCard(
                  percent: _myProfile.completionPercent,
                  missing: _myProfile.missingItems,
                  onFix: _fixItem,
                ),
              ],
              const SizedBox(height: 16),
              ProfileDetailsCard(
                formKey: _formKey,
                fields: _fields,
                isEditing: editing,
                onOpenLink: _openLink,
              ),

              const ProfileSectionHeader('Resume Document'),
              ProfileResumeCard(
                resumeURL: profile.resumeURL,
                isUploading: _myProfile.isUploadingResume,
                onUpload: _pickAndUploadResume,
                onReturn: _onResumeToolClosed,
              ),

              const ProfileSectionHeader('Career Tools'),
              const CareerToolsGrid(),

              ProfileSectionHeader(
                'Work Experience',
                onManage: editing ? () => _openRecords(const WorkExperienceScreen()) : null,
              ),
              ExpandableRecordList(
                records: profile.workExperience.map(_experienceCard).toList(),
                emptyMessage: 'No work experience added yet.',
              ),

              ProfileSectionHeader(
                'Education',
                onManage: editing ? () => _openRecords(const EducationScreen()) : null,
              ),
              ExpandableRecordList(
                records: profile.education.map(_educationCard).toList(),
                emptyMessage: 'No education details added yet.',
              ),

              ProfileSectionHeader('Skills', onManage: editing ? _openSkills : null),
              if (skills.isEmpty)
                const ProfileEmptyCard('No skills added yet.')
              else
                SurfaceCard(child: SkillChips(skills: skills)),

              if (!editing) ...[
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ProfileButtonStyles.primary(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Cancel / Save Details bar shown while editing.
  Widget _buildEditBar(bool saving) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, -4))],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: saving ? null : _cancelEditing,
                style: ProfileButtonStyles.secondary(),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: saving ? null : _save,
                style: ProfileButtonStyles.primary(),
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Details', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
