import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/file_preview_helper.dart';
import '../../../core/utils/link_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/job_seeker_model.dart';
import '../../../models/work_experience_model.dart';
import '../../../models/education_model.dart';
import '../../../models/skill_model.dart';
import '../../../shared_widgets/skill_chips.dart';
import '../controllers/profile_controller.dart';
import '../controllers/skill_controller.dart';
import '../widgets/load_error_view.dart';

class PublicProfileScreen extends StatefulWidget {
  final String seekerId;

  const PublicProfileScreen({super.key, required this.seekerId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  // Theme Colors matching profile_screen.dart
  static const Color _primary = AppColors.primary;
  static const Color _textPrimary = AppColors.textDark;
  static const Color _textMuted = AppColors.textMuted;
  static const Color _surfaceAlt = AppColors.surfaceAlt;

  final ProfileController _controller = ProfileController();
  final SkillController _skillController = SkillController();
  JobSeekerModel? _profile;
  List<SkillModel> _skills = [];
  bool _contactVisible = false;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPublicProfile();
  }

  Future<void> _loadPublicProfile() async {
    if (!_isLoading) {
      // Try Again (the first load starts with _isLoading already true).
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final responses = await Future.wait([
        _controller.fetchPublicProfile(widget.seekerId),
        _skillController.fetchSkillsForSeeker(widget.seekerId),
      ]);
      final result = responses[0] as ({JobSeekerModel profile, bool contactVisible})?;
      if (!mounted) return;
      setState(() {
        _profile = result?.profile;
        _skills = responses[1] as List<SkillModel>;
        _contactVisible = result?.contactVisible ?? false;
        _isLoading = false;
      });
    } on DataLoadException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _launchURL(String urlString) async {
    final opened = await LinkHelper.openExternal(urlString);
    if (!opened && mounted) {
      SnackBarHelper.showStyled(
        context,
        message: LinkHelper.toWebUri(urlString) == null
            ? 'This link isn\'t a valid web address.'
            : 'Could not open this link.',
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.errorRed,
      );
    }
  }

  String _formatDateRange(DateTime start, DateTime? end, bool isCurrent) {
    final DateFormat formatter = DateFormat('MMM yyyy');
    String startStr = formatter.format(start);
    String endStr = isCurrent ? 'Present' : (end != null ? formatter.format(end) : 'N/A');
    return '$startStr - $endStr';
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
    final imageUrl = _profile?.profilePictureURL;
    if (imageUrl != null && imageUrl.isNotEmpty && imageUrl != _failedImageUrl) {
      return ResizeImage(CachedNetworkImageProvider(imageUrl), width: 300);
    }
    return null;
  }

  Widget _buildSurfaceCard({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(22)}) {
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 14),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: _textPrimary,
        ),
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
              _buildHeroActionButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onTap: () => Navigator.pop(context),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_search_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Candidate Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                backgroundImage: _getProfileImageProvider(),
                onBackgroundImageError:
                    _getProfileImageProvider() == null ? null : _onProfileImageError,
                child: _getProfileImageProvider() == null
                    ? Text(
                        _getProfileInitial(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profile!.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    if (_profile!.location != null && _profile!.location!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _profile!.location!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({required String label, required String? value, required Widget icon, bool isLink = false}) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink(); // Hide empty fields entirely

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
                  onTap: isLink ? () => _launchURL(value) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: isLink ? _primary : _textPrimary,
                      fontWeight: isLink ? FontWeight.w600 : FontWeight.w500,
                      decoration: isLink ? TextDecoration.underline : TextDecoration.none,
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _loadError != null
          ? LoadErrorView(message: _loadError!, onRetry: _loadPublicProfile)
          : _profile == null
          ? const Center(child: Text('Profile not found.', style: TextStyle(color: _textPrimary)))
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroHeader(),
              const SizedBox(height: 24),

              // 👉 Basic Information Card
              _buildSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_contactVisible)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline_rounded, color: _textMuted, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Contact details and resume are only visible to employers.',
                                style: TextStyle(color: _textMuted, fontSize: 13, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildField(
                      label: 'Email',
                      value: _profile!.email,
                      icon: const Icon(Icons.email_outlined, color: _textMuted, size: 20),
                    ),
                    _buildField(
                      label: 'Phone Number',
                      value: _profile!.phoneNumber,
                      icon: const Icon(Icons.phone_outlined, color: _textMuted, size: 20),
                    ),
                    _buildField(
                      label: 'Bio / About Me',
                      value: _profile!.bio,
                      icon: const Icon(Icons.menu_book_outlined, color: _textMuted, size: 20),
                    ),
                    _buildField(
                      label: 'LinkedIn URL',
                      value: _profile!.linkedInURL,
                      icon: const FaIcon(FontAwesomeIcons.linkedin, color: _textMuted, size: 18),
                      isLink: true,
                    ),
                    _buildField(
                      label: 'GitHub URL',
                      value: _profile!.gitHubURL,
                      icon: const FaIcon(FontAwesomeIcons.github, color: _textMuted, size: 18),
                      isLink: true,
                    ),
                  ],
                ),
              ),

              // 👉 Resume Section
              if (_profile!.resumeURL != null) ...[
                _buildSectionHeader('Resume Document'),
                _buildSurfaceCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
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
                              'Resume Document',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Candidate attached a file.',
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
                          title: '${_profile!.fullName} - Resume',
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('View'),
                        style: TextButton.styleFrom(
                          foregroundColor: _primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Skills Section
              if (_skills.isNotEmpty) ...[
                _buildSectionHeader('Skills'),
                _buildSurfaceCard(child: SkillChips(skills: _skills)),
              ],

              // 👉 Work Experience Section
              if (_profile!.workExperience.isNotEmpty) ...[
                _buildSectionHeader('Experience'),
                ..._profile!.workExperience.map(_buildExperienceCard),
              ],

              // 👉 Education Section
              if (_profile!.education.isNotEmpty) ...[
                _buildSectionHeader('Education'),
                ..._profile!.education.map(_buildEducationCard),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
