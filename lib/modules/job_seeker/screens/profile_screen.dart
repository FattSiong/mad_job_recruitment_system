import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_picker_helper.dart';
import '../../../core/utils/file_preview_helper.dart';
import '../../../core/utils/link_helper.dart';
import '../../../models/education_model.dart';
import '../../../models/job_seeker_model.dart';
import '../../../models/skill_model.dart';
import '../../../models/work_experience_model.dart';
import '../../../shared_widgets/login_screen.dart';
import '../../../shared_widgets/skill_chips.dart';
import '../controllers/my_profile_controller.dart';
import '../widgets/profile/profile_qr_dialog.dart';
import '../widgets/profile/profile_record_card.dart';
import '../widgets/profile/profile_sheet_helpers.dart';
import '../widgets/load_error_view.dart';
import 'add_skill_screen.dart';
import 'education_screen.dart';
import 'work_experience_screen.dart';
import 'ai_career_advisor_screen.dart';
import 'mock_interview_setup_screen.dart';
import 'skill_gap_analysis_screen.dart';
import 'guidance_reports_screen.dart';
import 'ai_resume_assistant_screen.dart';
import 'build_resume_screen.dart';
import '../../../shared_widgets/hero_icon_button.dart';
import '../../../shared_widgets/surface_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Profile state (profile, skills, edit mode, saving) lives here (MVC).
  final MyProfileController _myProfile = MyProfileController();

  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();

  // Read-only views of the controller state used by the UI below.
  JobSeekerModel? get _profile => _myProfile.profile;
  List<SkillModel> get _skills => _myProfile.skills;
  bool get _isLoading => _myProfile.isLoading;
  bool get _isUploading => _myProfile.isUploadingResume;
  bool get _isEditing => _myProfile.isEditing;
  bool get _isSavingProfile => _myProfile.isSaving;
  File? get _newProfileImage => _myProfile.newPhoto;
  bool get _removePhoto => _myProfile.photoRemoved;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _linkedinController = TextEditingController();
  final TextEditingController _githubController = TextEditingController();

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
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    _linkedinController.dispose();
    _githubController.dispose();
    _myProfile.removeListener(_onProfileChanged);
    _myProfile.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    await _myProfile.load();
    if (mounted) _populateControllers();
  }

  Future<void> _openSkillsScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddSkillScreen()),
    );
    if (mounted) await _myProfile.refreshSkills();
  }

  Widget _buildSkillsSection() {
    if (_skills.isEmpty) {
      return _buildEmptyInfoCard('No skills added yet.');
    }
    return SurfaceCard(child: SkillChips(skills: _skills));
  }

  void _populateControllers() {
    if (_profile != null) {
      _nameController.text = _profile!.fullName;
      _emailController.text = _profile!.email ?? '';
      _phoneController.text = _profile!.phoneNumber ?? '';
      _locationController.text = _profile!.location ?? '';
      _bioController.text = _profile!.bio ?? '';
      _linkedinController.text = _profile!.linkedInURL ?? '';
      _githubController.text = _profile!.gitHubURL ?? '';
    }
  }

  Future<void> _launchURL(String urlString) async {
    final opened = await LinkHelper.openExternal(urlString);
    if (!opened && mounted) {
      _showStyledSnackBar(
        message: LinkHelper.toWebUri(urlString) == null
            ? 'This link doesn\'t look right. Please check it in Edit Profile.'
            : 'Could not open this link.',
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.errorRed,
      );
    }
  }

  Future<void> _pickAndUploadResume() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: FileLimits.resumeExtensions,
    );

    final path = result?.files.single.path;
    if (path == null) return; // cancelled

    final error = await _myProfile.uploadResume(File(path));
    if (!mounted) return;
    if (error == null) {
      _populateControllers();
      _showStyledSnackBar(
        message: 'Resume uploaded successfully!',
        icon: Icons.check_circle_outline_rounded,
        accentColor: AppColors.successGreen,
      );
    } else {
      _showStyledSnackBar(
        message: error,
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.errorRed,
      );
    }
  }

  void _showStyledSnackBar({
    required String message,
    required IconData icon,
    required Color accentColor,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accentColor.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFirstName() {
    if (_profile == null) return 'there';
    final fullName = _profile!.fullName.trim();
    if (fullName.isEmpty) return 'there';
    return fullName.split(' ').first;
  }

  String _getProfileInitial() {
    if (_profile == null || _profile!.fullName.trim().isEmpty) return 'J';
    return _profile!.fullName.trim()[0].toUpperCase();
  }

  /// URL that failed to load; we then show the initial instead of an empty circle.
  String? _failedImageUrl;

  void _onProfileImageError(Object error, StackTrace? stackTrace) {
    final url = _profile?.profilePictureURL;
    debugPrint('Profile photo failed to load ($url): $error');
    if (!mounted || url == null || url == _failedImageUrl) return;
    setState(() => _failedImageUrl = url);
  }

  ImageProvider? _getProfileImageProvider() {
    if (_newProfileImage != null) {
      return FileImage(_newProfileImage!);
    }
    if (_removePhoto) return null;

    final imageUrl = _profile?.profilePictureURL;
    if (imageUrl != null && imageUrl.isNotEmpty && imageUrl != _failedImageUrl) {
      // Cached on disk (no re-download every launch) and decoded at avatar size.
      return ResizeImage(CachedNetworkImageProvider(imageUrl), width: 300);
    }

    return null;
  }

  bool get _hasPhoto => _myProfile.hasPhoto;

  /// Camera / library / remove options for the profile photo (edit mode).
  Future<void> _showPhotoOptions() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Profile Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(sheetContext, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Choose from library'),
                onTap: () => Navigator.pop(sheetContext, 'gallery'),
              ),
              if (_hasPhoto)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
                  title: const Text('Remove photo', style: TextStyle(color: AppColors.errorRed)),
                  onTap: () => Navigator.pop(sheetContext, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || choice == null) return;
    switch (choice) {
      case 'camera':
        await _pickProfileImage(ImageSource.camera);
      case 'gallery':
        await _pickProfileImage(ImageSource.gallery);
      case 'remove':
        _myProfile.removePhoto();
    }
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1600, // the cropper then makes the final 512px image
        maxHeight: 1600,
      );
    } catch (e) {
      debugPrint('Image picker error: $e');
      if (!mounted) return;
      _showStyledSnackBar(
        message: source == ImageSource.camera
            ? 'Unable to open the camera. Please allow camera access in Settings.'
            : 'Unable to open your photos. Please allow photo access in Settings.',
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.errorRed,
      );
      return;
    }
    final path = picked?.path;
    if (path == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      // A 512px JPEG is ~50-100 KB instead of a multi-MB full-size PNG.
      maxWidth: 512,
      maxHeight: 512,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Profile Photo',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: AppColors.primary,
          lockAspectRatio: true,
          hideBottomControls: false,
          cropStyle: CropStyle.circle,
          showCropGrid: false,
          dimmedLayerColor: Colors.black54,
        ),
        IOSUiSettings(
          title: 'Adjust Profile Photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          cropStyle: CropStyle.circle,
        ),
      ],
    );

    if (croppedFile == null || !mounted) return;

    final sizeError = await FilePickerHelper.checkSize(File(croppedFile.path), FileLimits.imageMB);
    if (sizeError != null) {
      if (!mounted) return;
      _showStyledSnackBar(
        message: sizeError,
        icon: Icons.info_outline_rounded,
        accentColor: AppColors.errorRed,
      );
      return;
    }

    _myProfile.setNewPhoto(File(croppedFile.path));
  }

  Widget _buildProfileAvatar({
    double radius = 34,
    bool showEditBadge = false,
  }) {
    final imageProvider = _getProfileImageProvider();

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: Colors.white.withValues(alpha: 0.18),
          backgroundImage: imageProvider,
          onBackgroundImageError: imageProvider == null ? null : _onProfileImageError,
          child: imageProvider == null
              ? Text(
                  _getProfileInitial(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: radius * 0.76,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        if (showEditBadge)
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _isSavingProfile ? null : _showPhotoOptions,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
            ),
          ),
      ],
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  ButtonStyle _secondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.textDark,
      backgroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onAddPressed}) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          if (onAddPressed != null && _isEditing)
            TextButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: const Text(
                'Manage',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'My Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (!_isEditing && _profile != null)
                HeroIconButton(
                  icon: Icons.qr_code_rounded,
                  tooltip: 'Show QR',
                  onTap: () => showProfileQrDialog(context, _profile!.seekerID),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileAvatar(
                radius: 34,
                showEditBadge: _isEditing,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${_getFirstName()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required Widget icon,
    int maxLines = 1,
    bool isReadOnly = false,
    bool isLink = false,
    String? Function(String?)? validator,
  }) {
    if (!_isEditing) {
      final isEmpty = controller.text.trim().isEmpty;

      String displayValue = controller.text;
      if (isEmpty) {
        displayValue = '-';
      } else if (isLink) {
        displayValue = controller.text.trim();
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: (!isEmpty && isLink) ? () => _launchURL(controller.text) : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Text(
                      displayValue,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: (!isEmpty && isLink) ? AppColors.primary : AppColors.textDark,
                        fontWeight: (!isEmpty && isLink) ? FontWeight.w600 : FontWeight.w500,
                        decoration: (!isEmpty && isLink)
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        readOnly: isReadOnly,
        validator: validator,
        style: TextStyle(
          color: isReadOnly ? Colors.grey.shade500 : AppColors.textDark,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: icon,
          ),
          filled: true,
          fillColor: isReadOnly ? Colors.grey.shade200 : AppColors.surfaceAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyInfoCard(String message) {
    return SurfaceCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeSection() {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BuildResumeScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.description_outlined),
              label: const Text('Build Resume'),
              style: _secondaryButtonStyle().copyWith(
                foregroundColor: WidgetStateProperty.all(AppColors.primary),
                side: WidgetStateProperty.all(
                  const BorderSide(color: AppColors.borderActive),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_profile!.resumeURL != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppColors.errorRed,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resume Uploaded',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your latest resume is ready to preview.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => FilePreviewHelper.previewNetworkFile(
                    context,
                    _profile!.resumeURL!,
                    title: 'My Resume',
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(Icons.description_outlined, color: AppColors.textMuted),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No resume uploaded yet. Add a ${FileLimits.resumeTypesLabel} file (max ${FileLimits.resumeMB} MB).',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickAndUploadResume,
              icon: _isUploading
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(
                _profile!.resumeURL != null ? 'Upload New Resume' : 'Upload Resume',
              ),
              style: _secondaryButtonStyle().copyWith(
                foregroundColor: WidgetStateProperty.all(AppColors.primary),
                side: WidgetStateProperty.all(
                  const BorderSide(color: AppColors.borderActive),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AiResumeAssistantScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('AI Resume Assistant'),
              style: _secondaryButtonStyle().copyWith(
                foregroundColor: WidgetStateProperty.all(AppColors.primary),
                side: WidgetStateProperty.all(
                  const BorderSide(color: AppColors.borderActive),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Asks before deleting a profile record.
  void _showResult(bool ok, String success, String failure) {
    _showStyledSnackBar(
      message: ok ? success : failure,
      icon: ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
      accentColor: ok ? AppColors.successGreen : AppColors.errorRed,
    );
  }

  Future<void> _openRecordsScreen(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _loadProfile();
  }

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
    return ProfileRecordCard(
      icon: Icons.school_outlined,
      iconColor: Colors.orange,
      title: edu.fieldOfStudy != null && edu.fieldOfStudy!.isNotEmpty
          ? '${edu.degree} - ${edu.fieldOfStudy}'
          : edu.degree,
      subtitle: edu.institutionName,
      dateRange: formatProfileDateRange(edu.startDate, edu.endDate, edu.isCurrent),
      description: edu.description,
    );
  }

  Future<void> _saveProfileDetails() async {
    if (_nameController.text.trim().isEmpty) {
      _showStyledSnackBar(
        message: 'Name cannot be empty.',
        icon: Icons.info_outline_rounded,
        accentColor: AppColors.errorRed,
      );
      return;
    }

    if (!_profileFormKey.currentState!.validate()) {
      return;
    }

    final error = await _myProfile.save(ProfileEdits(
      fullName: _nameController.text,
      phone: _phoneController.text,
      location: _locationController.text,
      bio: _bioController.text,
      linkedIn: _linkedinController.text,
      gitHub: _githubController.text,
    ));
    if (!mounted) return;

    if (error == null) _populateControllers();
    _showResult(error == null, 'Profile updated successfully!', error ?? '');
  }

  Future<void> _logout() async {
    await _myProfile.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildCareerToolButton({
    required String label,
    required IconData icon,
    required Widget destination,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => destination),
            );
          },
          icon: Icon(icon),
          label: Text(label),
          style: _secondaryButtonStyle().copyWith(
            foregroundColor: WidgetStateProperty.all(AppColors.primary),
            side: WidgetStateProperty.all(
              const BorderSide(color: AppColors.borderActive),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      )
          : _profile == null
          ? LoadErrorView(
              message: _myProfile.loadError ?? 'Failed to load profile.',
              onRetry: _loadProfile,
            )
          : SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroHeader(),
                const SizedBox(height: 24),

                SurfaceCard(
                  child: Form(
                    key: _profileFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_isEditing) ...[
                          Text(
                            _profile!.fullName,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (_isEditing)
                          _buildEditableField(
                            label: 'Full Name',
                            controller: _nameController,
                            icon: const Icon(
                              Icons.person_outline_rounded,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                        _buildEditableField(
                          label: 'Email',
                          controller: _emailController,
                          icon: const Icon(
                            Icons.email_outlined,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          isReadOnly: true,
                        ),
                        _buildEditableField(
                          label: 'Phone Number',
                          controller: _phoneController,
                          icon: const Icon(Icons.phone_outlined, color: AppColors.textMuted, size: 20),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return null;
                            final phoneRegex = RegExp(r'^[0-9+\-\s]{8,20}$');
                            return phoneRegex.hasMatch(text) ? null : 'Enter a valid phone number';
                          },
                        ),
                        _buildEditableField(
                          label: 'Location',
                          controller: _locationController,
                          icon: const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                        ),
                        _buildEditableField(
                          label: 'Bio / About Me',
                          controller: _bioController,
                          icon: const Icon(
                            Icons.menu_book_outlined,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          maxLines: 4,
                        ),
                        _buildEditableField(
                          label: 'LinkedIn URL',
                          controller: _linkedinController,
                          icon: const FaIcon(
                            FontAwesomeIcons.linkedin,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                          isLink: true,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return null;

                            final normalized = text.startsWith('http') ? text : 'https://$text';
                            final uri = Uri.tryParse(normalized);

                            if (uri == null || !uri.hasAuthority) {
                              return 'Enter a valid LinkedIn URL';
                            }

                            if (!uri.host.toLowerCase().contains('linkedin.com')) {
                              return 'Use a valid linkedin.com URL';
                            }

                            return null;
                          },
                        ),
                        _buildEditableField(
                          label: 'GitHub URL',
                          controller: _githubController,
                          icon: const FaIcon(
                            FontAwesomeIcons.github,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                          isLink: true,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return null;

                            final normalized = text.startsWith('http') ? text : 'https://$text';
                            final uri = Uri.tryParse(normalized);

                            if (uri == null || !uri.hasAuthority) {
                              return 'Enter a valid GitHub URL';
                            }

                            if (!uri.host.toLowerCase().contains('github.com')) {
                              return 'Use a valid github.com URL';
                            }

                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                _buildSectionHeader('Resume Document'),
                _buildResumeSection(),

                _buildSectionHeader('Career Tools'),
                _buildCareerToolButton(
                  label: 'AI Career Advisor',
                  icon: Icons.smart_toy_outlined,
                  destination: const AiCareerAdvisorScreen(),
                ),
                _buildCareerToolButton(
                  label: 'Mock Interview',
                  icon: Icons.record_voice_over_outlined,
                  destination: const MockInterviewSetupScreen(),
                ),
                _buildCareerToolButton(
                  label: 'Skill Gap Analysis',
                  icon: Icons.insights_outlined,
                  destination: const SkillGapAnalysisScreen(),
                ),
                _buildCareerToolButton(
                  label: 'Guidance Reports',
                  icon: Icons.assignment_outlined,
                  destination: const GuidanceReportsScreen(),
                ),

                _buildSectionHeader(
                  'Skills',
                  onAddPressed: _openSkillsScreen,
                ),
                _buildSkillsSection(),

                _buildSectionHeader(
                  'Work Experience',
                  onAddPressed: () => _openRecordsScreen(const WorkExperienceScreen()),
                ),
                if (_profile!.workExperience.isEmpty)
                  _buildEmptyInfoCard('No work experience added yet.')
                else
                  ..._profile!.workExperience.map(_experienceCard),

                _buildSectionHeader(
                  'Education',
                  onAddPressed: () => _openRecordsScreen(const EducationScreen()),
                ),
                if (_profile!.education.isEmpty)
                  _buildEmptyInfoCard('No education details added yet.')
                else
                  ..._profile!.education.map(_educationCard),

                if (!_isEditing) ...[
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text(
                        'Logout',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: _primaryButtonStyle(),
                    ),
                  ),
                ],

              ],
            ),
          ),
        ),
      ),
      floatingActionButton: (!_isEditing && _profile != null)
          ? FloatingActionButton.extended(
        onPressed: _myProfile.startEditing,
        icon: const Icon(Icons.edit_rounded, color: Colors.white),
        label: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
      )
          : null,
      bottomNavigationBar: _isEditing
          ? SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSavingProfile
                      ? null
                      : () {
                    _myProfile.cancelEditing();
                    _populateControllers();
                  },
                  style: _secondaryButtonStyle(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSavingProfile ? null : _saveProfileDetails,
                  style: _primaryButtonStyle(),
                  child: _isSavingProfile
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Details',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      )
          : null,
    );
  }

}
