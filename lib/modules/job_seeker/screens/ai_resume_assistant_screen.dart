import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/file_preview_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/resume_review_model.dart';
import '../controllers/resume_review_controller.dart';
import '../widgets/load_error_view.dart';
import '../widgets/resume_review/resume_review_widgets.dart';
import 'build_resume_screen.dart';
import 'resume_review_result_screen.dart';
import '../../../shared_widgets/confirm_dialog.dart';
import '../../../shared_widgets/surface_card.dart';
import '../../../shared_widgets/gradient_page_header.dart';
import '../widgets/career_tools/career_tool_widgets.dart';
import '../../../core/utils/app_date_format.dart';

/// AI Resume Assistant: pick a resume (uploaded or built in the app), optionally
/// a target job, and get AI feedback on how to improve it.
class AiResumeAssistantScreen extends StatefulWidget {
  const AiResumeAssistantScreen({super.key});

  @override
  State<AiResumeAssistantScreen> createState() => _AiResumeAssistantScreenState();
}

class _AiResumeAssistantScreenState extends State<AiResumeAssistantScreen> {
  static const List<String> _suggestedRoles = [
    'Software Developer',
    'Data Analyst',
    'UI/UX Designer',
    'Digital Marketing Executive',
    'Accountant',
    'Business Analyst',
  ];

  final ResumeReviewController _controller = ResumeReviewController();
  final TextEditingController _roleController = TextEditingController();

  ResumeReviewSources? _sources;
  ResumeReviewSource? _selected;
  List<ResumeReviewModel> _history = [];
  bool _isLoading = true;
  bool _isReviewing = false;

  @override
  void initState() {
    super.initState();
    _roleController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _roleController.dispose();
    super.dispose();
  }

  String? _loadError;

  /// Loads the resumes the user has and their past reviews.
  Future<void> _load() async {
    final List<Object?> results;
    try {
      results = await Future.wait([
        _controller.fetchSources(),
        _controller.fetchHistory(),
      ]);
    } on DataLoadException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
      return;
    }
    if (!mounted) return;
    final sources = results[0] as ResumeReviewSources?;
    setState(() {
      _sources = sources;
      _history = results[1] as List<ResumeReviewModel>;
      _loadError = null;
      _isLoading = false;
      // Keep the user's choice if it is still available, otherwise pick one.
      if (_selected == null || !(sources?.isAvailable(_selected!) ?? false)) {
        _selected = sources == null
            ? null
            : sources.isAvailable(ResumeReviewSource.uploaded)
                ? ResumeReviewSource.uploaded
                : sources.isAvailable(ResumeReviewSource.builder)
                    ? ResumeReviewSource.builder
                    : null;
      }
    });
  }

  bool get _canReview => !_isReviewing && _selected != null;

  /// Reviews the chosen resume and opens the report.
  Future<void> _review() async {
    final source = _selected;
    if (!_canReview || source == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _isReviewing = true);

    try {
      final review = await _controller.review(source, targetJobRole: _roleController.text);
      if (!mounted) return;
      setState(() {
        _isReviewing = false;
        _history.insert(0, review);
      });
      _openReview(review);
    } on ResumeReviewException catch (e) {
      if (!mounted) return;
      setState(() => _isReviewing = false);
      SnackBarHelper.showError(context, e.message, duration: const Duration(seconds: 4));
      // The resume may have changed (e.g. removed) - refresh the choices.
      if (e.code == 'no_resume' || e.code == 'resume_unreadable') _load();
    }
  }

  /// Opens a review report.
  void _openReview(ResumeReviewModel review) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResumeReviewResultScreen(review: review)),
    );
  }

  /// Opens Build Resume, then reloads (a resume may have been built).
  Future<void> _openBuilder() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const BuildResumeScreen()));
    if (mounted) _load();
  }

  /// Fills the target job with [role]; tapping the same one again clears it.
  void _setRole(String role) {
    final same = _roleController.text.trim() == role;
    _roleController.text = same ? '' : role;
    _roleController.selection = TextSelection.collapsed(offset: _roleController.text.length);
  }

  /// Deletes a past review after asking.
  Future<void> _confirmDelete(ResumeReviewModel item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete review?',
      message: 'The review from ${AppDateFormat.day.format(item.createdAt)} will be permanently deleted.',
    );
    if (!confirmed) return;

    final ok = await _controller.deleteReview(item.reviewID);
    if (!mounted) return;
    if (ok) {
      setState(() => _history.removeWhere((h) => h.reviewID == item.reviewID));
    } else {
      SnackBarHelper.showError(context, 'Unable to delete the review.');
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _loadError != null
            ? LoadErrorView(
                message: _loadError!,
                onRetry: () {
                  setState(() => _isLoading = true);
                  _load();
                },
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildResumePickerCard(),
                      const SizedBox(height: 20),
                      _buildRoleCard(),
                      const SizedBox(height: 20),
                      _buildChecklistCard(),
                      if (_history.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildHistoryCard(),
                      ],
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: _isLoading || _loadError != null ? null : _buildBottomButton(),
    );
  }

  /// Gradient header with the title and back button.
  Widget _buildHeader() => const GradientPageHeader(
        title: 'AI Resume Assistant',
        subtitle: 'Get a score and clear tips to improve your resume.',
      );

  // ---- Resume choice --------------------------------------------------

  /// Choice between the uploaded resume and the one built in the app.
  Widget _buildResumePickerCard() {
    final s = _sources;
    if (s == null) {
      return const SurfaceCard(children: [
        Text('Unable to load your resumes. Pull down to try again.',
            style: TextStyle(color: AppColors.textMuted)),
      ]);
    }

    final uploadedSubtitle = !s.hasUploaded
        ? 'No resume uploaded yet – upload one in your Profile.'
        : s.uploadedReadable
            ? s.uploadedFileName
            : '${s.uploadedFileName} – only PDF or Word (.docx) can be reviewed.';

    final builtSubtitle = s.hasBuiltResume
        ? s.builtResumeUpdatedAt != null
            ? 'Last saved ${AppDateFormat.day.format(s.builtResumeUpdatedAt!)}'
            : 'Saved in the app'
        : 'Not built yet – tap to create one in a few steps.';

    return SurfaceCard(
      children: [
        SectionTitle('Resume to Review',
          subtitle: 'Choose which resume the assistant should check.',
        ),
        _sourceTile(
          source: ResumeReviewSource.uploaded,
          icon: Icons.upload_file_rounded,
          title: 'Uploaded Resume',
          subtitle: uploadedSubtitle,
          available: s.isAvailable(ResumeReviewSource.uploaded),
          action: s.hasUploaded
              ? IconButton(
                  tooltip: 'Preview',
                  onPressed: () => FilePreviewHelper.previewNetworkFile(
                    context,
                    s.uploadedURL!,
                    title: 'My Resume',
                  ),
                  icon: const Icon(Icons.visibility_outlined, color: AppColors.primary),
                )
              : null,
        ),
        _sourceTile(
          source: ResumeReviewSource.builder,
          icon: Icons.description_outlined,
          title: 'Resume Built in App',
          subtitle: builtSubtitle,
          available: s.isAvailable(ResumeReviewSource.builder),
          onUnavailableTap: _openBuilder,
          action: s.hasBuiltResume
              ? IconButton(
                  tooltip: 'Edit',
                  onPressed: _isReviewing ? null : _openBuilder,
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                )
              : null,
        ),
        if (!s.isAvailable(ResumeReviewSource.uploaded) && !s.isAvailable(ResumeReviewSource.builder))
          const CareerToolNotice(
            'Upload a PDF/Word resume in your Profile or build one in the app to get feedback.',
          ),
      ],
    );
  }

  /// One resume option (greyed out when it isn't available).
  Widget _sourceTile({
    required ResumeReviewSource source,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool available,
    Widget? action,
    VoidCallback? onUnavailableTap,
  }) {
    final selected = _selected == source && available;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _isReviewing
              ? null
              : available
                  ? () => setState(() => _selected = source)
                  : onUnavailableTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.4 : 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: available ? 0.10 : 0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: available ? AppColors.primary : AppColors.textMuted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: available ? AppColors.textDark : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.35),
                      ),
                    ],
                  ),
                ),
                if (action != null) action,
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : available
                            ? Icons.radio_button_off_rounded
                            : Icons.chevron_right_rounded,
                    color: selected ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Target job -----------------------------------------------------

  /// Optional target job box with suggested roles.
  Widget _buildRoleCard() => TargetRoleField(
        title: 'Target Job (Optional)',
        subtitle: 'Add the job you are applying for to get keywords and tips for that job.',
        controller: _roleController,
        enabled: !_isReviewing,
        suggestions: _suggestedRoles,
        onSuggestionTap: _setRole,
        onSubmitted: (_) => _review(),
        showClear: true,
      );

  // ---- What is checked ------------------------------------------------

  /// What the review looks at (content, impact, keywords, ...).
  Widget _buildChecklistCard() {
    return SurfaceCard(
      children: [
        SectionTitle('What the Assistant Checks',
          subtitle: 'You get a score out of 100 and tips for each area.',
        ),
        _checklistItem(Icons.fact_check_outlined, 'Content & completeness',
            'Contact details, summary, education, experience and skills.'),
        _checklistItem(Icons.trending_up_rounded, 'Impact & achievements',
            'Results and numbers instead of only listing duties.'),
        _checklistItem(Icons.manage_search_outlined, 'Keywords & ATS',
            'Job keywords and headings that screening software can read.'),
        _checklistItem(Icons.format_align_left_rounded, 'Structure & formatting',
            'Order, dates, bullet points and length.'),
        _checklistItem(Icons.spellcheck_rounded, 'Writing & clarity',
            'Grammar, wording, and before/after rewrites you can copy.'),
      ],
    );
  }

  /// One row of the checklist card.
  Widget _checklistItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
            child: Icon(icon, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- History --------------------------------------------------------

  /// Past reviews with their scores; tapping one opens it.
  Widget _buildHistoryCard() {
    return SurfaceCard(
      children: [
        SectionTitle('Past Reviews', subtitle: 'Tap to view a previous report.'),
        for (final h in _history)
          CareerToolHistoryTile(
            score: '${h.overallScore}',
            scoreColor: resumeScoreColor(h.overallScore),
            title: h.roleLabel,
            subtitle: '${AppDateFormat.day.format(h.createdAt)} · ${h.source.label}',
            onTap: () => _openReview(h),
            onDelete: _isReviewing ? null : () => _confirmDelete(h),
          ),
      ],
    );
  }

  /// "Review My Resume" button (with a progress note while reviewing).
  Widget _buildBottomButton() => CareerToolRunBar(
        busy: _isReviewing,
        enabled: _canReview,
        onPressed: _review,
        icon: Icons.auto_awesome_rounded,
        label: 'Review My Resume',
        busyLabel: 'Reviewing…',
        busyHint: 'Reading your resume and preparing feedback… this can take up to a minute.',
      );
}
