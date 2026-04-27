import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_preview_helper.dart';
import '../../../models/education_model.dart';
import '../../../models/job_seeker_model.dart';
import '../../../models/work_experience_model.dart';
import '../../../services/auth_service.dart';
import '../../../shared_widgets/login_screen.dart';
import '../controllers/profile_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _primary = Color(0xFF163B65);
  static const Color _textPrimary = Color(0xFF1B2433);
  static const Color _textMuted = Color(0xFF687588);
  static const Color _surfaceAlt = Color(0xFFF7F9FC);
  static const Color _border = Color(0xFFE1E8F0);

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

  String _formatDateRange(DateTime start, DateTime? end, bool isCurrent) {
    final formatter = DateFormat('MMM yyyy');
    final startStr = formatter.format(start);
    final endStr = isCurrent ? 'Present' : (end != null ? formatter.format(end) : 'N/A');
    return '$startStr - $endStr';
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
          colors: [Color(0xFF163B65), Color(0xFF335D8A)],
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
                  onTap: _showQRCodeDialog,
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
        ],
      ),
    );
  }

  Widget _buildExperienceCard(WorkExperienceModel exp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: _buildSurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.work_outline_rounded, color: _primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exp.jobTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exp.companyName,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateRange(exp.startDate, exp.endDate, exp.isCurrent),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                    ),
                  ),
                  if (exp.description != null && exp.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      exp.description!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: _textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_isEditing && exp.experienceID != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
                onPressed: () => _controller.deleteWorkExperience(
                  context: context,
                  experienceId: exp.experienceID!,
                  onSuccess: _loadProfile,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationCard(EducationModel edu) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: _buildSurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.school_outlined, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    edu.fieldOfStudy != null && edu.fieldOfStudy!.isNotEmpty
                        ? '${edu.degree} - ${edu.fieldOfStudy}'
                        : edu.degree,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    edu.institutionName,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateRange(edu.startDate, edu.endDate, edu.isCurrent),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                    ),
                  ),
                  if (edu.description != null && edu.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      edu.description!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: _textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_isEditing && edu.educationID != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
                onPressed: () => _controller.deleteEducation(
                  context: context,
                  educationId: edu.educationID!,
                  onSuccess: _loadProfile,
                ),
              ),
          ],
        ),
      ),
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

    final didUpdate = await _controller.updateProfileBasics(
      context: context,
      updatedModel: updatedModel,
    );

    if (!mounted) return;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
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
          color: AppColors.primaryBlue,
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
                          icon: const FaIcon(FontAwesomeIcons.linkedin, color: _textMuted, size: 18),
                          isLink: true,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return null;
                            final uri = Uri.tryParse(text.startsWith('http') ? text : 'https://$text');
                            return uri != null && uri.hasAuthority ? null : 'Enter a valid URL';
                          },
                        ),
                        _buildEditableField(
                          label: 'GitHub URL',
                          controller: _githubController,
                          icon: const FaIcon(FontAwesomeIcons.github, color: _textMuted, size: 18),
                          isLink: true,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return null;
                            final uri = Uri.tryParse(text.startsWith('http') ? text : 'https://$text');
                            return uri != null && uri.hasAuthority ? null : 'Enter a valid URL';
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                _buildSectionHeader('Resume Document'),
                _buildResumeSection(),

                _buildSectionHeader(
                  'Work Experience',
                  onAddPressed: () => _showAddExperienceSheet(context),
                ),
                if (_profile!.workExperience.isEmpty)
                  _buildEmptyInfoCard('No work experience added yet.')
                else
                  ..._profile!.workExperience.map(_buildExperienceCard),

                _buildSectionHeader(
                  'Education',
                  onAddPressed: () => _showAddEducationSheet(context),
                ),
                if (_profile!.education.isEmpty)
                  _buildEmptyInfoCard('No education details added yet.')
                else
                  ..._profile!.education.map(_buildEducationCard),

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

  void _showQRCodeDialog() {
    if (_profile == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'My Profile QR',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Let recruiters scan this to view your resume and experience.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              height: 220,
              child: QrImageView(
                data: 'profile:${_profile!.seekerID}',
                version: QrVersions.auto,
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _primary),
            child: const Text(
              'Close',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime? initialDate) async {
    return await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primaryBlue),
          ),
          child: child!,
        );
      },
    );
  }

  InputDecoration _sheetInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
    );
  }

  void _showAddExperienceSheet(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final companyController = TextEditingController();
    final descController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    bool isCurrentRole = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Add Work Experience',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: titleController,
                      decoration: _sheetInputDecoration('Job Title*', Icons.work),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: companyController,
                      decoration: _sheetInputDecoration('Company Name*', Icons.business),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await _pickDate(context, startDate);
                              if (date != null) setModalState(() => startDate = date);
                            },
                            child: InputDecorator(
                              decoration: _sheetInputDecoration(
                                'Start Date*',
                                Icons.calendar_today,
                              ),
                              child: Text(
                                startDate == null
                                    ? 'Select'
                                    : DateFormat('yMd').format(startDate!),
                                style: TextStyle(
                                  color: startDate == null
                                      ? Colors.grey.shade600
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: isCurrentRole
                                ? null
                                : () async {
                              final date = await _pickDate(context, endDate);
                              if (date != null) setModalState(() => endDate = date);
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'End Date',
                                prefixIcon: Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                                filled: true,
                                fillColor: isCurrentRole
                                    ? Colors.grey.shade200
                                    : Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: Text(
                                isCurrentRole
                                    ? 'Present'
                                    : (endDate == null
                                    ? 'Select'
                                    : DateFormat('yMd').format(endDate!)),
                                style: TextStyle(
                                  color: (endDate == null && !isCurrentRole)
                                      ? Colors.grey.shade600
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (startDate == null)
                      const Padding(
                        padding: EdgeInsets.only(left: 12.0, top: 6),
                        child: Text(
                          'Start date required',
                          style: TextStyle(
                            color: AppColors.errorRed,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: isCurrentRole,
                          activeColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (v) {
                            setModalState(() {
                              isCurrentRole = v ?? false;
                              if (isCurrentRole) endDate = null;
                            });
                          },
                        ),
                        const Text(
                          'I currently work here',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descController,
                      decoration: _sheetInputDecoration(
                        'Description',
                        Icons.description,
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate() && startDate != null) {
                          if (!isCurrentRole && endDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please select an end date or mark as current role.',
                                ),
                              ),
                            );
                            return;
                          }
                          if (!isCurrentRole &&
                              endDate != null &&
                              endDate!.isBefore(startDate!)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'End date cannot be before start date.',
                                ),
                              ),
                            );
                            return;
                          }

                          final newExp = WorkExperienceModel(
                            seekerID: '',
                            companyName: companyController.text.trim(),
                            jobTitle: titleController.text.trim(),
                            startDate: startDate!,
                            endDate: endDate,
                            isCurrent: isCurrentRole,
                            description: descController.text.trim(),
                          );

                          Navigator.pop(context);
                          _controller.addWorkExperience(
                            context: context,
                            experience: newExp,
                            onSucess: _loadProfile,
                          );
                        } else if (startDate == null) {
                          setModalState(() {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Add Experience',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddEducationSheet(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final institutionController = TextEditingController();
    final fieldOfStudyController = TextEditingController();
    final descController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    bool isCurrent = false;

    final List<String> degreeOptions = [
      'High School / SPM',
      'Certificate',
      'Diploma',
      "Bachelor's Degree",
      "Master's Degree",
      'Doctorate / PhD',
      'Other',
    ];
    String? selectedDegree;

    bool isDiplomaOrAbove(String? degree) {
      return degree == 'Diploma' ||
          degree == "Bachelor's Degree" ||
          degree == "Master's Degree" ||
          degree == 'Doctorate / PhD';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Add Education',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: institutionController,
                      decoration: _sheetInputDecoration(
                        'Institution Name*',
                        Icons.school,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: _sheetInputDecoration(
                        'Degree/Qualification*',
                        Icons.history_edu,
                      ),
                      initialValue: selectedDegree,
                      items: degreeOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setModalState(() {
                          selectedDegree = newValue;
                          if (!isDiplomaOrAbove(newValue)) {
                            fieldOfStudyController.clear();
                          }
                        });
                      },
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    if (isDiplomaOrAbove(selectedDegree)) ...[
                      TextFormField(
                        controller: fieldOfStudyController,
                        decoration: _sheetInputDecoration(
                          'Field of Study*',
                          Icons.menu_book,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await _pickDate(context, startDate);
                              if (date != null) setModalState(() => startDate = date);
                            },
                            child: InputDecorator(
                              decoration: _sheetInputDecoration(
                                'Start Date*',
                                Icons.calendar_today,
                              ),
                              child: Text(
                                startDate == null
                                    ? 'Select'
                                    : DateFormat('yMd').format(startDate!),
                                style: TextStyle(
                                  color: startDate == null
                                      ? Colors.grey.shade600
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: isCurrent
                                ? null
                                : () async {
                              final date = await _pickDate(context, endDate);
                              if (date != null) setModalState(() => endDate = date);
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'End Date',
                                prefixIcon: Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                                filled: true,
                                fillColor: isCurrent
                                    ? Colors.grey.shade200
                                    : Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: Text(
                                isCurrent
                                    ? 'Current'
                                    : (endDate == null
                                    ? 'Select'
                                    : DateFormat('yMd').format(endDate!)),
                                style: TextStyle(
                                  color: (endDate == null && !isCurrent)
                                      ? Colors.grey.shade600
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (startDate == null)
                      const Padding(
                        padding: EdgeInsets.only(left: 12.0, top: 6),
                        child: Text(
                          'Start date required',
                          style: TextStyle(
                            color: AppColors.errorRed,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: isCurrent,
                          activeColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (v) {
                            setModalState(() {
                              isCurrent = v ?? false;
                              if (isCurrent) endDate = null;
                            });
                          },
                        ),
                        const Text(
                          'I am currently studying here',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descController,
                      decoration: _sheetInputDecoration(
                        'Description / Achievements',
                        Icons.description,
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate() && startDate != null) {
                          if (!isCurrent && endDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please select an end date or mark as current study.',
                                ),
                              ),
                            );
                            return;
                          }
                          if (!isCurrent &&
                              endDate != null &&
                              endDate!.isBefore(startDate!)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'End date cannot be before start date.',
                                ),
                              ),
                            );
                            return;
                          }

                          final newEdu = EducationModel(
                            institutionName: institutionController.text.trim(),
                            degree: selectedDegree!,
                            fieldOfStudy: isDiplomaOrAbove(selectedDegree)
                                ? fieldOfStudyController.text.trim()
                                : null,
                            description: descController.text.trim(),
                            startDate: startDate!,
                            endDate: endDate,
                            isCurrent: isCurrent,
                          );

                          Navigator.pop(context);
                          _controller.addEducation(
                            context: context,
                            education: newEdu,
                            onSucess: _loadProfile,
                          );
                        } else if (startDate == null) {
                          setModalState(() {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Add Education',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
