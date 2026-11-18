import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/file_preview_helper.dart';
import '../../../core/utils/link_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/job_seeker_model.dart';
import '../../../models/skill_model.dart';
import '../../../shared_widgets/skill_chips.dart';
import '../controllers/profile_controller.dart';
import '../controllers/skill_controller.dart';
import '../widgets/load_error_view.dart';
import '../widgets/profile/profile_details_card.dart';
import '../widgets/profile/profile_record_card.dart';
import '../../../shared_widgets/hero_icon_button.dart';
import '../../../shared_widgets/surface_card.dart';
import '../../../shared_widgets/hero_card.dart';

/// A job seeker's profile as others see it (read-only), e.g. after
/// scanning their QR code. Contact details and resume are shown only to
/// employers, admins and the owner.
class PublicProfileScreen extends StatefulWidget {
  final String seekerId;

  const PublicProfileScreen({super.key, required this.seekerId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
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

  /// Loads the profile and skills (also used by Try Again).
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

  /// Opens a link from the profile, or says why it can't.
  Future<void> _launchURL(String urlString) async {
    final opened = await LinkHelper.openExternal(urlString);
    if (!opened && mounted) {
      SnackBarHelper.showError(
        context,
        LinkHelper.toWebUri(urlString) == null
            ? 'This link isn\'t a valid web address.'
            : 'Could not open this link.',
      );
    }
  }

  /// First letter of the name for the avatar ('J' when there is no name).
  String _getProfileInitial() {
    if (_profile == null || _profile!.fullName.trim().isEmpty) return 'J';
    return _profile!.fullName.trim()[0].toUpperCase();
  }

  /// URL that failed to load; the initial is shown instead of an empty circle.
  String? _failedImageUrl;

  /// The photo failed to load: show the initial instead.
  void _onProfileImageError(Object error, StackTrace? stackTrace) {
    final url = _profile?.profilePictureURL;
    debugPrint('Profile photo failed to load ($url): $error');
    if (!mounted || url == null || url == _failedImageUrl) return;
    setState(() => _failedImageUrl = url);
  }

  /// The profile photo, or null to show the initial.
  ImageProvider? _getProfileImageProvider() {
    final imageUrl = _profile?.profilePictureURL;
    if (imageUrl != null && imageUrl.isNotEmpty && imageUrl != _failedImageUrl) {
      return ResizeImage(CachedNetworkImageProvider(imageUrl), width: 300);
    }
    return null;
  }

  /// Big section title (Skills, Work Experience, ...).
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 14),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),
    );
  }

  /// Gradient header with the photo, name and location.
  Widget _buildHeroHeader() {
    return HeroCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HeroIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onTap: () => Navigator.pop(context),
              ),
              const Spacer(),
              const HeroPill(icon: Icons.person_search_rounded, label: 'Candidate Profile'),
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

  /// One labelled detail row; hidden when [value] is empty.
  Widget _buildField({required String label, required String? value, required Widget icon, bool isLink = false}) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink(); // empty fields are not shown
    return ProfileInfoRow(label: label, value: value, icon: icon, onTap: isLink ? () => _launchURL(value) : null);
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
          ? const Center(child: Text('Profile not found.', style: TextStyle(color: AppColors.textDark)))
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroHeader(),
              const SizedBox(height: 24),

              // Basic information
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_contactVisible)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Contact details and resume are only visible to employers.',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildField(
                      label: 'Email',
                      value: _profile!.email,
                      icon: const Icon(Icons.email_outlined, color: AppColors.textMuted, size: 20),
                    ),
                    _buildField(
                      label: 'Phone Number',
                      value: _profile!.phoneNumber,
                      icon: const Icon(Icons.phone_outlined, color: AppColors.textMuted, size: 20),
                    ),
                    _buildField(
                      label: 'Bio / About Me',
                      value: _profile!.bio,
                      icon: const Icon(Icons.menu_book_outlined, color: AppColors.textMuted, size: 20),
                    ),
                    _buildField(
                      label: 'Career Goal',
                      value: _profile!.careerGoal,
                      icon: const Icon(Icons.flag_outlined, color: AppColors.textMuted, size: 20),
                    ),
                    _buildField(
                      label: 'LinkedIn URL',
                      value: _profile!.linkedInURL,
                      icon: const FaIcon(FontAwesomeIcons.linkedin, color: AppColors.textMuted, size: 18),
                      isLink: true,
                    ),
                    _buildField(
                      label: 'GitHub URL',
                      value: _profile!.gitHubURL,
                      icon: const FaIcon(FontAwesomeIcons.github, color: AppColors.textMuted, size: 18),
                      isLink: true,
                    ),
                  ],
                ),
              ),

              // Resume
              if (_profile!.resumeURL != null) ...[
                _buildSectionHeader('Resume Document'),
                SurfaceCard(
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
                                color: AppColors.textDark,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Candidate attached a file.',
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
                          title: '${_profile!.fullName} - Resume',
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('View'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Skills
              if (_skills.isNotEmpty) ...[
                _buildSectionHeader('Skills'),
                SurfaceCard(child: SkillChips(skills: _skills)),
              ],

              // Work experience
              if (_profile!.workExperience.isNotEmpty) ...[
                _buildSectionHeader('Experience'),
                ..._profile!.workExperience.map(ProfileRecordCard.experience),
              ],

              // Education
              if (_profile!.education.isNotEmpty) ...[
                _buildSectionHeader('Education'),
                ..._profile!.education.map(ProfileRecordCard.education),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
