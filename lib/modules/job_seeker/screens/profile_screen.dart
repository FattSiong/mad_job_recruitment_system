import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/utils/file_picker_helper.dart';
import '../../../core/utils/file_preview_helper.dart';
import '../../../models/education_model.dart';
import '../../../models/job_seeker_model.dart';
import '../../../models/work_experience_model.dart';
import '../../../services/auth_service.dart';
import '../../../shared_widgets/login_screen.dart';
import '../controllers/profile_controller.dart';
import '../widgets/profile/add_education_sheet.dart';
import '../widgets/profile/add_experience_sheet.dart';
import '../widgets/profile/profile_qr_dialog.dart';
import '../widgets/profile/profile_record_card.dart';
import '../widgets/profile/profile_sheet_helpers.dart';
import 'ai_career_advisor_screen.dart';
import 'mock_interview_setup_screen.dart';
import 'skill_gap_analysis_screen.dart';
import 'guidance_reports_screen.dart';
import 'ai_resume_assistant_screen.dart';
import 'build_resume_screen.dart';
import 'career_tools_mockup_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _primary = AppColors.primary;
  static const Color _textPrimary = AppColors.textDark;
  static const Color _textMuted = AppColors.textMuted;
  static const Color _surfaceAlt = AppColors.surfaceAlt;
  static const Color _border = AppColors.border;

  final ProfileController _controller = ProfileController();

  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();

  JobSeekerModel? _profile;
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isEditing = false;
  bool _isSavingProfile = false;
  File? _newProfileImage;

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
    _loadProfile();
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
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final profile = await _controller.fetchProfile();

    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
        _newProfileImage = null;
      });
      _populateControllers();
    }
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
    final Uri url = Uri.parse(
      urlString.startsWith('http') ? urlString : 'https://$urlString',
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        _showStyledSnackBar(
          message: 'Could not launch URL',
          icon: Icons.error_outline_rounded,
          accentColor: AppColors.errorRed,
        );
      }
    }
  }

  Future<void> _pickAndUploadResume() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isUploading = true);

      final file = File(result.files.single.path!);
      final sizeError = await FilePickerHelper.checkSize(file, FileLimits.resumeMB);
      if (sizeError != null) {
        if (mounted) {
          setState(() => _isUploading = false);
          _showStyledSnackBar(
            message: sizeError,
            icon: Icons.info_outline_rounded,
            accentColor: AppColors.errorRed,
          );
        }
        return;
      }
      final String? newUrl = await _controller.uploadResume(file);

      if (mounted) {
        if (newUrl != null) {
          _showStyledSnackBar(
            message: 'Resume uploaded successfully!',
            icon: Icons.check_circle_outline_rounded,
            accentColor: AppColors.successGreen,
          );
          _loadProfile();
        } else {
          _showStyledSnackBar(
            message: 'Failed to upload resume.',
            icon: Icons.error_outline_rounded,
            accentColor: AppColors.errorRed,
          );
        }
        setState(() => _isUploading = false);
      }
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
                    color: _textPrimary,
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

  ImageProvider? _getProfileImageProvider() {
    if (_newProfileImage != null) {
      return FileImage(_newProfileImage!);
    }

    final imageUrl = _profile?.profilePictureURL;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return NetworkImage(imageUrl);
    }

    return null;
  }

  Future<void> _pickProfileImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.png,
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Profile Photo',
          toolbarColor: _primary,
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: _primary,
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

    setState(() {
      _newProfileImage = File(croppedFile.path);
    });
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
              onTap: _isSavingProfile ? null : _pickProfileImage,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: _primary,
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
      backgroundColor: _primary,
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
      foregroundColor: _textPrimary,
      backgroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      side: const BorderSide(color: _border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildSurfaceCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(22),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
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
                color: _textPrimary,
              ),
            ),
          ),
          if (onAddPressed != null && _isEditing)
            TextButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text(
                'Add',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                foregroundColor: _primary,
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
                _buildHeroActionButton(
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

  Widget _buildHeroActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
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
                color: _surfaceAlt,
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
                      color: _textMuted,
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
                        color: (!isEmpty && isLink) ? _primary : _textPrimary,
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
          color: isReadOnly ? Colors.grey.shade500 : _textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: icon,
          ),
          filled: true,
          fillColor: isReadOnly ? Colors.grey.shade200 : _surfaceAlt,
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
            borderSide: const BorderSide(color: _primary, width: 1.6),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyInfoCard(String message) {
    return _buildSurfaceCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              color: _textMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _textMuted,
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
    return _buildSurfaceCard(
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
                foregroundColor: WidgetStateProperty.all(_primary),
                side: WidgetStateProperty.all(
                  const BorderSide(color: Color(0xFFB8D1EE)),
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
                          color: _textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your latest resume is ready to preview.',
                        style: TextStyle(
                          color: _textMuted,
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
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View'),
                  style: TextButton.styleFrom(
                    foregroundColor: _primary,
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
                color: _surfaceAlt,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(Icons.description_outlined, color: _textMuted),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No resume uploaded yet. Add one to strengthen your profile.',
                      style: TextStyle(
                        color: _textMuted,
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
                foregroundColor: WidgetStateProperty.all(_primary),
                side: WidgetStateProperty.all(
                  const BorderSide(color: Color(0xFFB8D1EE)),
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
                foregroundColor: WidgetStateProperty.all(_primary),
                side: WidgetStateProperty.all(
                  const BorderSide(color: Color(0xFFB8D1EE)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Asks before deleting a profile record.
  Future<bool> _confirmDelete(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ---------------------------------------------------------------------
  // Work experience / education (UI in widgets/profile, data in ProfileController)
  // ---------------------------------------------------------------------

  void _showResult(bool ok, String success, String failure) {
    _showStyledSnackBar(
      message: ok ? success : failure,
      icon: ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
      accentColor: ok ? AppColors.successGreen : AppColors.errorRed,
    );
  }

  Future<void> _addExperience() async {
    final experience = await showAddExperienceSheet(context);
    if (experience == null || !mounted) return;
    final ok = await _controller.addWorkExperience(experience);
    if (!mounted) return;
    _showResult(ok, 'Work experience added!', 'Failed to add work experience.');
    if (ok) _loadProfile();
  }

  Future<void> _addEducation() async {
    final education = await showAddEducationSheet(context);
    if (education == null || !mounted) return;
    final ok = await _controller.addEducation(education);
    if (!mounted) return;
    _showResult(ok, 'Education added!', 'Failed to add education.');
    if (ok) _loadProfile();
  }

  Future<void> _deleteExperience(WorkExperienceModel exp) async {
    final confirmed = await _confirmDelete(
      'Remove work experience?',
      '"${exp.jobTitle}" at ${exp.companyName} will be removed from your profile.',
    );
    if (!confirmed || !mounted) return;
    final ok = await _controller.deleteWorkExperience(exp.experienceID!);
    if (!mounted) return;
    _showResult(ok, 'Work experience removed.', 'Failed to remove work experience.');
    if (ok) _loadProfile();
  }

  Future<void> _deleteEducation(EducationModel edu) async {
    final confirmed = await _confirmDelete(
      'Remove education?',
      '"${edu.degree}" at ${edu.institutionName} will be removed from your profile.',
    );
    if (!confirmed || !mounted) return;
    final ok = await _controller.deleteEducation(edu.educationID!);
    if (!mounted) return;
    _showResult(ok, 'Education removed.', 'Failed to remove education.');
    if (ok) _loadProfile();
  }

  Widget _experienceCard(WorkExperienceModel exp) {
    return ProfileRecordCard(
      icon: Icons.work_outline_rounded,
      iconColor: _primary,
      title: exp.jobTitle,
      subtitle: exp.companyName,
      dateRange: formatProfileDateRange(exp.startDate, exp.endDate, exp.isCurrent),
      description: exp.description,
      onDelete: (_isEditing && exp.experienceID != null) ? () => _deleteExperience(exp) : null,
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
      onDelete: (_isEditing && edu.educationID != null) ? () => _deleteEducation(edu) : null,
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

    setState(() => _isSavingProfile = true);

    String? profilePictureUrl = _profile!.profilePictureURL;
    if (_newProfileImage != null) {
      final uploadedUrl = await _controller.uploadProfilePicture(_newProfileImage!);
      if (uploadedUrl == null) {
        if (mounted) {
          _showStyledSnackBar(
            message: 'Failed to upload profile photo.',
            icon: Icons.error_outline_rounded,
            accentColor: AppColors.errorRed,
          );
          setState(() => _isSavingProfile = false);
        }
        return;
      }
      profilePictureUrl = uploadedUrl;
    }

    final updatedModel = JobSeekerModel(
      seekerID: _profile!.seekerID,
      fullName: _nameController.text.trim(),
      email: _profile!.email,
      resumeURL: _profile!.resumeURL,
      profilePictureURL: profilePictureUrl,
      phoneNumber: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      bio: _bioController.text.trim().isEmpty
          ? null
          : _bioController.text.trim(),
      linkedInURL: _linkedinController.text.trim().isEmpty
          ? null
          : _linkedinController.text.trim(),
      gitHubURL: _githubController.text.trim().isEmpty
          ? null
          : _githubController.text.trim(),
      education: _profile!.education,
      workExperience: _profile!.workExperience,
    );

    if (!mounted) return;

    final didUpdate = await _controller.updateProfileBasics(updatedModel);

    if (!mounted) return;
    _showResult(didUpdate, 'Profile updated successfully!', 'Failed to update profile.');

    setState(() {
      _isSavingProfile = false;
      if (didUpdate) {
        _profile = updatedModel;
        _isEditing = false;
        _newProfileImage = null;
        _populateControllers();
      }
    });
  }

  Future<void> _logout() async {
    await AuthService().signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildCareerToolButton({
    required String label,
    required IconData icon,
    required CareerToolMockupType type,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    switch (type) {
                      CareerToolMockupType.aiCareerAdvisor => const AiCareerAdvisorScreen(),
                      CareerToolMockupType.mockInterview => const MockInterviewSetupScreen(),
                      CareerToolMockupType.skillGapAnalysis => const SkillGapAnalysisScreen(),
                      CareerToolMockupType.guidanceReports => const GuidanceReportsScreen(),
                    },
              ),
            );
          },
          icon: Icon(icon),
          label: Text(label),
          style: _secondaryButtonStyle().copyWith(
            foregroundColor: WidgetStateProperty.all(_primary),
            side: WidgetStateProperty.all(
              const BorderSide(color: Color(0xFFB8D1EE)),
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
          ? const Center(
        child: Text(
          'Failed to load profile.',
          style: TextStyle(color: _textPrimary),
        ),
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

                _buildSurfaceCard(
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
                              color: _textPrimary,
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
                              color: _textMuted,
                              size: 20,
                            ),
                          ),
                        _buildEditableField(
                          label: 'Email',
                          controller: _emailController,
                          icon: const Icon(
                            Icons.email_outlined,
                            color: _textMuted,
                            size: 20,
                          ),
                          isReadOnly: true,
                        ),
                        _buildEditableField(
                          label: 'Phone Number',
                          controller: _phoneController,
                          icon: const Icon(Icons.phone_outlined, color: _textMuted, size: 20),
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
                            color: _textMuted,
                            size: 20,
                          ),
                        ),
                        _buildEditableField(
                          label: 'Bio / About Me',
                          controller: _bioController,
                          icon: const Icon(
                            Icons.menu_book_outlined,
                            color: _textMuted,
                            size: 20,
                          ),
                          maxLines: 4,
                        ),
                        _buildEditableField(
                          label: 'LinkedIn URL',
                          controller: _linkedinController,
                          icon: const FaIcon(
                            FontAwesomeIcons.linkedin,
                            color: _textMuted,
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
                            color: _textMuted,
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
                  type: CareerToolMockupType.aiCareerAdvisor,
                ),
                _buildCareerToolButton(
                  label: 'Mock Interview',
                  icon: Icons.record_voice_over_outlined,
                  type: CareerToolMockupType.mockInterview,
                ),
                _buildCareerToolButton(
                  label: 'Skill Gap Analysis',
                  icon: Icons.insights_outlined,
                  type: CareerToolMockupType.skillGapAnalysis,
                ),
                _buildCareerToolButton(
                  label: 'Guidance Reports',
                  icon: Icons.assignment_outlined,
                  type: CareerToolMockupType.guidanceReports,
                ),

                _buildSectionHeader(
                  'Work Experience',
                  onAddPressed: _addExperience,
                ),
                if (_profile!.workExperience.isEmpty)
                  _buildEmptyInfoCard('No work experience added yet.')
                else
                  ..._profile!.workExperience.map(_experienceCard),

                _buildSectionHeader(
                  'Education',
                  onAddPressed: _addEducation,
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
        onPressed: () => setState(() => _isEditing = true),
        icon: const Icon(Icons.edit_rounded, color: Colors.white),
        label: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _primary,
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
                    setState(() => _isEditing = false);
                    _newProfileImage = null;
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
