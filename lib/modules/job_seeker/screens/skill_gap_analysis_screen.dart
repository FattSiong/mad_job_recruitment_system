import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/skill_gap_model.dart';
import '../controllers/skill_gap_controller.dart';
import 'skill_gap_result_screen.dart';

/// Use Case 4.60: choose a target role and run the skill gap analysis.
class SkillGapAnalysisScreen extends StatefulWidget {
  const SkillGapAnalysisScreen({super.key});

  @override
  State<SkillGapAnalysisScreen> createState() => _SkillGapAnalysisScreenState();
}

class _SkillGapAnalysisScreenState extends State<SkillGapAnalysisScreen> {
  static const Color _primary = Color(0xFF163B65);
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _textPrimary = Color(0xFF1B2433);
  static const Color _textMuted = Color(0xFF687588);
  static const Color _surfaceAlt = Color(0xFFF7F9FC);
  static const Color _border = Color(0xFFE1E8F0);
  static const Color _warning = Color(0xFFC77700);

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

  Future<void> _load() async {
    final results = await Future.wait([
      _controller.fetchReadiness(),
      _controller.fetchHistory(),
    ]);
    if (!mounted) return;
    setState(() {
      _readiness = results[0] as SkillGapReadiness?;
      _history = results[1] as List<SkillGapAnalysisModel>;
      _isLoading = false;
    });
  }

  bool get _canAnalyse =>
      !_isAnalysing &&
      _roleController.text.trim().isNotEmpty &&
      (_readiness?.canAnalyse ?? false);

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
        SnackBarHelper.showStyled(
          context,
          message: e.message,
          icon: Icons.error_outline_rounded,
          accentColor: AppColors.errorRed,
          duration: const Duration(seconds: 3),
        );
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

  void _setRole(String role) {
    _roleController.text = role;
    _roleController.selection = TextSelection.collapsed(offset: role.length);
  }

  Future<void> _confirmDelete(SkillGapAnalysisModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete analysis?'),
        content: Text('The "${item.targetJobRole}" analysis will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await _controller.deleteAnalysis(item.analysisID);
    if (!mounted) return;
    if (ok) {
      setState(() => _history.removeWhere((h) => h.analysisID == item.analysisID));
    } else {
      SnackBarHelper.showStyled(
        context,
        message: 'Unable to delete the analysis.',
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.errorRed,
      );
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _primary))
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
      bottomNavigationBar: _isLoading ? null : _buildBottomButton(),
    );
  }

  Widget _buildHeader() {
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
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.insights_outlined, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skill Gap Analysis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Compare your profile and resume with what employers want.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _surfaceCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: _textMuted, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildRoleCard() {
    return _surfaceCard(
      children: [
        _sectionTitle('Target Job Role', 'Which job do you want to be ready for?'),
        TextField(
          controller: _roleController,
          enabled: !_isAnalysing,
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _analyse(),
          decoration: InputDecoration(
            hintText: 'e.g. Junior Data Analyst',
            counterText: '',
            prefixIcon: const Icon(Icons.work_outline, color: _primary),
            filled: true,
            fillColor: _surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: _primary, width: 1.2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestedRoles.map((role) {
            final selected = _roleController.text.trim() == role;
            return ChoiceChip(
              label: Text(role),
              selected: selected,
              onSelected: _isAnalysing ? null : (_) => _setRole(role),
              selectedColor: const Color(0xFFDCEBFB),
              backgroundColor: _surfaceAlt,
              side: BorderSide(color: selected ? _primary : _border),
              labelStyle: TextStyle(
                color: selected ? _primary : _textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              showCheckmark: false,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildReadinessCard() {
    final r = _readiness;
    if (r == null) {
      return _surfaceCard(children: const [
        Text('Unable to load your profile. Please try again later.',
            style: TextStyle(color: _textMuted)),
      ]);
    }

    final resumeSubtitle = !r.hasResume
        ? 'No resume uploaded – you can upload one in your Profile.'
        : r.resumeReadable
            ? r.resumeFileName
            : '${r.resumeFileName} – only PDF or DOCX can be analysed.';

    return _surfaceCard(
      children: [
        _sectionTitle('What We\'ll Analyse',
            'Your details are compared with live job postings and AI market knowledge.'),
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
              ? '${r.skillCount} skill${r.skillCount == 1 ? '' : 's'} in your profile'
              : 'None listed – skills will be detected from your resume and experience.',
          r.skillCount > 0,
        ),
        _readinessTile(
          Icons.school_outlined,
          'Education',
          r.educationCount > 0 ? '${r.educationCount} record(s)' : 'Not added yet',
          r.educationCount > 0,
        ),
        _readinessTile(
          Icons.work_history_outlined,
          'Work Experience',
          r.experienceCount > 0 ? '${r.experienceCount} record(s)' : 'Not added yet',
          r.experienceCount > 0,
        ),
        if (!r.canAnalyse)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.errorRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.errorRed),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Please complete your profile (education, work experience or a PDF/DOCX resume) '
                    'before running an analysis.',
                    style: TextStyle(color: AppColors.errorRed, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _readinessTile(IconData icon, String title, String subtitle, bool ok) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textMuted, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            ok ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
            color: ok ? AppColors.successGreen : _warning,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    return _surfaceCard(
      children: [
        _sectionTitle('Past Analyses', 'Tap to view a previous report.'),
        ..._history.map((h) {
          final color = h.matchScore >= 75
              ? AppColors.successGreen
              : h.matchScore >= 50
                  ? _warning
                  : AppColors.errorRed;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: _surfaceAlt,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SkillGapResultScreen(analysis: h)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('${h.matchScore}%',
                            style: TextStyle(
                                color: color, fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h.targetJobRole,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: _textPrimary)),
                            const SizedBox(height: 4),
                            Text(
                              '${DateFormat('d MMM yyyy').format(h.createdAt)} · '
                              '${h.missing.length} skill gap${h.missing.length == 1 ? '' : 's'}',
                              style: const TextStyle(color: _textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
                        onPressed: () => _confirmDelete(h),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBottomButton() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isAnalysing)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Analysing your profile against market demand… this can take up to a minute.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _textMuted, fontSize: 13),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _canAnalyse ? _analyse : null,
                icon: _isAnalysing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.analytics_outlined),
                label: Text(_isAnalysing ? 'Analysing…' : 'Analyse Skill Gap'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD7E3F3),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
