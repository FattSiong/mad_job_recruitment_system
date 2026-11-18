import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/skill_gap_model.dart';
import '../controllers/skill_gap_controller.dart';
import 'add_skill_screen.dart';
import 'education_screen.dart';
import 'skill_gap_result_screen.dart';
import 'work_experience_screen.dart';
import '../widgets/load_error_view.dart';
import '../../../shared_widgets/confirm_dialog.dart';
import '../../../shared_widgets/surface_card.dart';
import '../../../shared_widgets/gradient_page_header.dart';
import '../widgets/career_tools/career_tool_widgets.dart';

/// Use Case 4.60: choose a target role and run the skill gap analysis.
class SkillGapAnalysisScreen extends StatefulWidget {
  const SkillGapAnalysisScreen({super.key});

  @override
  State<SkillGapAnalysisScreen> createState() => _SkillGapAnalysisScreenState();
}

class _SkillGapAnalysisScreenState extends State<SkillGapAnalysisScreen> {
  static const List<String> _suggestedRoles = [
    'Software Developer',
    'Data Analyst',
    'UI/UX Designer',
    'Digital Marketing Executive',
    'Accountant',
    'Business Analyst',
    'Network Engineer',
    'HR Executive',
  ];

  final SkillGapController _controller = SkillGapController();
  final TextEditingController _roleController = TextEditingController();

  SkillGapReadiness? _readiness;
  List<SkillGapAnalysisModel> _history = [];
  bool _isLoading = true;
  bool _isAnalysing = false;

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

  /// Loads the profile readiness counts and past analyses.
  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _controller.fetchReadiness(),
        _controller.fetchHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _readiness = results[0] as SkillGapReadiness?;
        _history = results[1] as List<SkillGapAnalysisModel>;
        _loadError = null;
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

  /// Try Again after loading failed.
  Future<void> _retryLoad() async {
    setState(() => _isLoading = true);
    await _load();
  }

  bool get _canAnalyse =>
      !_isAnalysing &&
      _roleController.text.trim().isNotEmpty &&
      (_readiness?.canAnalyse ?? false);

  /// Runs the analysis for the typed role and opens the report.
  Future<void> _analyse() async {
    if (!_canAnalyse) return;
    FocusScope.of(context).unfocus();
    setState(() => _isAnalysing = true);

    try {
      final analysis = await _controller.analyse(_roleController.text.trim());
      if (!mounted) return;
      setState(() {
        _isAnalysing = false;
        _history.insert(0, analysis);
      });
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SkillGapResultScreen(analysis: analysis),
        ),
      );
    } on SkillGapException catch (e) {
      if (!mounted) return;
      setState(() => _isAnalysing = false);
      if (e.code == 'insufficient_market_data') {
        _showSuggestedRoles(e);
      } else {
        SnackBarHelper.showError(context, e.message, duration: const Duration(seconds: 3));
      }
    }
  }

  /// Use case A2: not enough market data -> suggest broader roles.
  void _showSuggestedRoles(SkillGapException e) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Not enough market data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.message, style: const TextStyle(height: 1.4)),
            if (e.suggestedRoles.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Try one of these:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: e.suggestedRoles
                    .map((r) => ActionChip(
                          label: Text(r),
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _setRole(r);
                          },
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Fills the role box with a suggested role.
  void _setRole(String role) {
    _roleController.text = role;
    _roleController.selection = TextSelection.collapsed(offset: role.length);
  }

  /// Deletes a past analysis after asking.
  Future<void> _confirmDelete(SkillGapAnalysisModel item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete analysis?',
      message: 'The "${item.targetJobRole}" analysis will be permanently deleted.',
    );
    if (!confirmed) return;

    final ok = await _controller.deleteAnalysis(item.analysisID);
    if (!mounted) return;
    if (ok) {
      setState(() => _history.removeWhere((h) => h.analysisID == item.analysisID));
    } else {
      SnackBarHelper.showError(context, 'Unable to delete the analysis.');
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
            ? LoadErrorView(message: _loadError!, onRetry: _retryLoad)
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildRoleCard(),
                    const SizedBox(height: 20),
                    _buildReadinessCard(),
                    if (_history.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildHistoryCard(),
                    ],
                  ],
                ),
              ),
      ),
      bottomNavigationBar: _isLoading || _loadError != null ? null : _buildBottomButton(),
    );
  }

  /// Gradient header with the title and back button.
  Widget _buildHeader() => const GradientPageHeader(
        icon: Icons.insights_outlined,
        title: 'Skill Gap Analysis',
        subtitle: 'Compare your profile and resume with what employers want.',
      );

  /// Target job role box with suggested roles.
  Widget _buildRoleCard() => TargetRoleField(
        title: 'Target Job Role',
        subtitle: 'Which job do you want to be ready for?',
        controller: _roleController,
        enabled: !_isAnalysing,
        suggestions: _suggestedRoles,
        onSuggestionTap: _setRole,
        onSubmitted: (_) => _analyse(),
      );

  /// What the analysis can use: resume, skills, education, experience.
  Widget _buildReadinessCard() {
    final r = _readiness;
    if (r == null) {
      return const SurfaceCard(children: [
        Text('Unable to load your profile. Please try again later.',
            style: TextStyle(color: AppColors.textMuted)),
      ]);
    }

    final resumeSubtitle = !r.hasResume
        ? 'No resume uploaded – you can upload one in your Profile.'
        : r.resumeReadable
            ? r.resumeFileName
            : '${r.resumeFileName} – only PDF or DOCX can be analysed.';

    return SurfaceCard(
      children: [
        SectionTitle('What We\'ll Analyse',
          subtitle: 'Your details are compared with live job postings and AI market knowledge.',
        ),
        _readinessTile(
          Icons.description_outlined,
          'Resume',
          resumeSubtitle,
          r.hasResume && r.resumeReadable,
        ),
        _readinessTile(
          Icons.psychology_outlined,
          'Skills',
          r.skillCount > 0
              ? '${r.skillCount} skill${r.skillCount == 1 ? '' : 's'} in your profile – tap to manage'
              : 'None listed – tap to add, or they will be detected from your resume.',
          r.skillCount > 0,
          onTap: () => _openProfileScreen(const AddSkillScreen()),
        ),
        _readinessTile(
          Icons.school_outlined,
          'Education',
          r.educationCount > 0 ? '${r.educationCount} record(s) – tap to manage' : 'Not added yet – tap to add',
          r.educationCount > 0,
          onTap: () => _openProfileScreen(const EducationScreen()),
        ),
        _readinessTile(
          Icons.work_history_outlined,
          'Work Experience',
          r.experienceCount > 0 ? '${r.experienceCount} record(s) – tap to manage' : 'Not added yet – tap to add',
          r.experienceCount > 0,
          onTap: () => _openProfileScreen(const WorkExperienceScreen()),
        ),
        if (!r.canAnalyse)
          const CareerToolNotice(
            'Please complete your profile (education, work experience or a PDF/DOCX resume) '
            'before running an analysis.',
          ),
      ],
    );
  }

  /// Opens a profile screen (skills, education, experience) and refreshes the
  /// readiness counts when the user comes back.
  Future<void> _openProfileScreen(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  /// One readiness row (tick or warning); tappable to fix it.
  Widget _readinessTile(
    IconData icon,
    String title,
    String subtitle,
    bool ok, {
    VoidCallback? onTap,
  }) {
    final tile = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            ok ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
            color: ok ? AppColors.successGreen : AppColors.warning,
            size: 22,
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ],
      ),
    );

    if (onTap == null) return tile;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: tile);
  }

  /// Past analyses with their match %; tapping one opens it.
  Widget _buildHistoryCard() {
    return SurfaceCard(
      children: [
        SectionTitle('Past Analyses', subtitle: 'Tap to view a previous report.'),
        for (final h in _history)
          CareerToolHistoryTile(
            score: '${h.matchScore}%',
            scoreColor: AppColors.forScore(h.matchScore),
            scoreFontSize: 13,
            title: h.targetJobRole,
            subtitle: '${DateFormat('d MMM yyyy').format(h.createdAt)} · '
                '${h.missing.length} skill gap${h.missing.length == 1 ? '' : 's'}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SkillGapResultScreen(analysis: h)),
            ),
            onDelete: () => _confirmDelete(h),
          ),
      ],
    );
  }

  /// "Analyse Skill Gap" button (with a progress note while running).
  Widget _buildBottomButton() => CareerToolRunBar(
        busy: _isAnalysing,
        enabled: _canAnalyse,
        onPressed: _analyse,
        icon: Icons.analytics_outlined,
        label: 'Analyse Skill Gap',
        busyLabel: 'Analysing…',
        busyHint: 'Analysing your profile against market demand… this can take up to a minute.',
      );
}
