import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/guidance_pdf_builder.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/guidance_report_model.dart';
import '../../../models/mock_interview_model.dart';
import '../../../models/skill_gap_model.dart';
import '../controllers/guidance_report_controller.dart';
import '../controllers/skill_gap_controller.dart';
import 'guidance_pdf_viewer_screen.dart';
import 'mock_interview_result_screen.dart';
import 'mock_interview_setup_screen.dart';
import 'skill_gap_analysis_screen.dart';
import 'skill_gap_result_screen.dart';

enum _Filter { all, interviews, skillGaps }

/// Use Case 4.61: historical dashboard of AI evaluations.
class GuidanceReportsScreen extends StatefulWidget {
  const GuidanceReportsScreen({super.key});

  @override
  State<GuidanceReportsScreen> createState() => _GuidanceReportsScreenState();
}

class _GuidanceReportsScreenState extends State<GuidanceReportsScreen> {
  static const Color _primary = AppColors.primary;
  static const Color _background = AppColors.background;
  static const Color _textPrimary = AppColors.textDark;
  static const Color _textMuted = AppColors.textMuted;
  static const Color _surfaceAlt = AppColors.surfaceAlt;
  static const Color _border = AppColors.border;
  static const Color _warning = AppColors.warning;
  static const Color _interviewColor = AppColors.primary;
  static const Color _skillGapColor = Color(0xFF2E7D8C);

  final GuidanceReportController _controller = GuidanceReportController();
  final SkillGapController _skillGapController = SkillGapController();

  List<GuidanceReportItem> _reports = [];
  bool _isLoading = true;
  String? _error;
  _Filter _filter = _Filter.all;
  String? _openingID;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = _reports.isEmpty;
      _error = null;
    });
    try {
      final reports = await _controller.fetchReports();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } on GuidanceReportException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  List<GuidanceReportItem> get _interviews => _reports.where((r) => r.isMockInterview).toList();
  List<GuidanceReportItem> get _skillGaps => _reports.where((r) => r.isSkillGap).toList();

  List<GuidanceReportItem> get _filtered {
    switch (_filter) {
      case _Filter.all:
        return _reports;
      case _Filter.interviews:
        return _interviews;
      case _Filter.skillGaps:
        return _skillGaps;
    }
  }

  Color _scoreColor(int? score) {
    if (score == null) return _textMuted;
    if (score >= 75) return AppColors.successGreen;
    if (score >= 50) return _warning;
    return AppColors.errorRed;
  }

  Future<void> _openReport(GuidanceReportItem item) async {
    if (_openingID != null) return;

    if (item.isMockInterview) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MockInterviewResultScreen(sessionID: item.reportID)),
      );
    } else {
      setState(() => _openingID = item.reportID);
      final analysis = await _skillGapController.fetchAnalysis(item.reportID);
      if (!mounted) return;
      setState(() => _openingID = null);
      if (analysis == null) {
        SnackBarHelper.showStyled(
          context,
          message: 'Unable to load this report. It may have been deleted.',
          icon: Icons.error_outline_rounded,
          accentColor: AppColors.errorRed,
        );
        _load();
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SkillGapResultScreen(analysis: analysis)),
      );
    }
    if (mounted) _load(); // reports may have changed (e.g. "Practise Again")
  }

  /// Opens the PDF version of the reports currently shown by the filter.
  void _viewPdf() {
    final filter = _filter;
    final title = switch (filter) {
      _Filter.all => 'Career Guidance Report',
      _Filter.interviews => 'Mock Interview Reports',
      _Filter.skillGaps => 'Skill Gap Reports',
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuidancePdfViewerScreen(
          title: title,
          fileName: 'guidance_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
          buildPdf: () async {
            final results = await Future.wait<Object>([
              _controller.fetchApplicantName(),
              filter == _Filter.skillGaps
                  ? Future.value(<MockInterviewRecordModel>[])
                  : _controller.fetchInterviewDetails(),
              filter == _Filter.interviews
                  ? Future.value(<SkillGapAnalysisModel>[])
                  : _controller.fetchSkillGapDetails(),
            ]);
            return GuidancePdfBuilder.fullReport(
              applicantName: results[0] as String,
              interviews: results[1] as List<MockInterviewRecordModel>,
              skillGaps: results[2] as List<SkillGapAnalysisModel>,
            );
          },
        ),
      ),
    );
  }

  void _startActivity(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) {
      if (mounted) _load();
    });
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: RefreshIndicator(
          color: _primary,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              ..._buildBody(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    if (_isLoading) {
      return const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator(color: _primary)),
      ];
    }
    if (_error != null) return [_buildErrorState()];
    if (_reports.isEmpty) return [_buildEmptyState()];

    return [
      _buildSummaryCard(),
      const SizedBox(height: 20),
      _buildProgressCard(),
      const SizedBox(height: 20),
      _buildFilterBar(),
      const SizedBox(height: 12),
      if (_filtered.isNotEmpty) ...[
        _startButton(
          Icons.picture_as_pdf_outlined,
          switch (_filter) {
            _Filter.all => 'View All Reports as PDF',
            _Filter.interviews => 'View Interview Reports as PDF',
            _Filter.skillGaps => 'View Skill Gap Reports as PDF',
          },
          _viewPdf,
        ),
        const SizedBox(height: 4),
      ],
      ..._buildTimeline(),
    ];
  }

  Widget _buildHeader() {
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
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.assignment_outlined, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Guidance Reports',
                  style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  'Track your mock interviews and skill gap results over time.',
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _sectionTitle(String text, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: _textMuted, height: 1.4)),
          ],
        ],
      ),
    );
  }

  // ---- Use case A1: no reports yet --------------------------------------

  Widget _buildEmptyState() {
    return _surfaceCard(
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.assignment_outlined, size: 34, color: _primary),
          ),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'No guidance reports yet',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textPrimary),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Complete a mock interview or a skill gap analysis and your results will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _textMuted, height: 1.45),
        ),
        const SizedBox(height: 20),
        _startButton(
          Icons.record_voice_over_outlined,
          'Start a Mock Interview',
          () => _startActivity(const MockInterviewSetupScreen()),
          filled: true,
        ),
        const SizedBox(height: 10),
        _startButton(
          Icons.insights_outlined,
          'Run a Skill Gap Analysis',
          () => _startActivity(const SkillGapAnalysisScreen()),
        ),
      ],
    );
  }

  Widget _startButton(IconData icon, String label, VoidCallback onPressed, {bool filled = false}) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
    const padding = EdgeInsets.symmetric(vertical: 15);
    return SizedBox(
      width: double.infinity,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: padding,
                shape: shape,
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: AppColors.borderActive),
                padding: padding,
                shape: shape,
              ),
            ),
    );
  }

  // ---- Use case A2: database error ----------------------------------------

  Widget _buildErrorState() {
    return _surfaceCard(
      children: [
        const Center(
          child: Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.errorRed),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            _error ?? 'Unable to load reports.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600, color: _textPrimary),
          ),
        ),
        const SizedBox(height: 16),
        _startButton(Icons.refresh_rounded, 'Try Again', _load, filled: true),
      ],
    );
  }

  // ---- Summary ------------------------------------------------------------

  Widget _buildSummaryCard() {
    final interviewScores = _interviews.map((r) => r.score).whereType<int>().toList();
    final avgInterview = interviewScores.isEmpty
        ? null
        : (interviewScores.reduce((a, b) => a + b) / interviewScores.length).round();
    final bestInterview =
        interviewScores.isEmpty ? null : interviewScores.reduce((a, b) => a > b ? a : b);
    final latestSkillGap = _skillGaps.isEmpty ? null : _skillGaps.first;

    return _surfaceCard(
      children: [
        _sectionTitle('Overview'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _statTile(Icons.record_voice_over_outlined, '${_interviews.length}',
                'Mock interviews', _interviewColor),
            _statTile(Icons.insights_outlined, '${_skillGaps.length}', 'Skill analyses',
                _skillGapColor),
            _statTile(Icons.speed_rounded, avgInterview == null ? '–' : '$avgInterview',
                bestInterview == null ? 'Avg interview score' : 'Avg score · best $bestInterview',
                _scoreColor(avgInterview)),
            _statTile(
              Icons.track_changes_rounded,
              latestSkillGap?.score == null ? '–' : '${latestSkillGap!.score}%',
              latestSkillGap == null ? 'Latest skill match' : 'Latest match · ${latestSkillGap.targetJobRole}',
              _scoreColor(latestSkillGap?.score),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statTile(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  // ---- Progress chart ---------------------------------------------------------

  Widget _buildProgressCard() {
    return _surfaceCard(
      children: [
        _sectionTitle('Progress', subtitle: 'Your most recent results, oldest to newest.'),
        _progressRow('Mock interview scores', _interviews, _interviewColor),
        const SizedBox(height: 18),
        _progressRow('Skill match %', _skillGaps, _skillGapColor),
      ],
    );
  }

  Widget _progressRow(String title, List<GuidanceReportItem> items, Color color) {
    final recent = items.take(8).toList().reversed.toList(); // oldest -> newest
    String? trend;
    if (recent.length >= 2 && recent.first.score != null && recent.last.score != null) {
      final diff = recent.last.score! - recent.first.score!;
      trend = diff == 0 ? 'No change' : '${diff > 0 ? '+' : ''}$diff since ${DateFormat('d MMM').format(recent.first.createdAt)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
            ),
            if (trend != null)
              Text(trend,
                  style: TextStyle(
                    color: trend.startsWith('+')
                        ? AppColors.successGreen
                        : trend.startsWith('-')
                            ? AppColors.errorRed
                            : _textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  )),
          ],
        ),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          const Text('No results yet.', style: TextStyle(color: _textMuted))
        else
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: recent.map((r) {
                final score = (r.score ?? 0).clamp(0, 100);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('$score',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700, color: _textPrimary)),
                        const SizedBox(height: 4),
                        Container(
                          height: 70 * score / 100 + 4,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: r == recent.last ? 1 : 0.45),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(DateFormat('d/M').format(r.createdAt),
                            style: const TextStyle(fontSize: 10, color: _textMuted)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // ---- Filter + timeline ---------------------------------------------------------

  Widget _buildFilterBar() {
    Widget chip(_Filter f, String label, int count) {
      final selected = _filter == f;
      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: f == _Filter.skillGaps ? 0 : 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _primary : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? _primary : _border),
              ),
              child: Text(
                '$label ($count)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : _textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(_Filter.all, 'All', _reports.length),
        chip(_Filter.interviews, 'Interviews', _interviews.length),
        chip(_Filter.skillGaps, 'Skill Gaps', _skillGaps.length),
      ],
    );
  }

  /// Reports grouped by month, newest first.
  List<Widget> _buildTimeline() {
    final items = _filtered;
    if (items.isEmpty) {
      return [
        _surfaceCard(children: [
          const Text('No reports of this type yet.', style: TextStyle(color: _textMuted)),
          const SizedBox(height: 14),
          _startButton(
            _filter == _Filter.interviews ? Icons.record_voice_over_outlined : Icons.insights_outlined,
            _filter == _Filter.interviews ? 'Start a Mock Interview' : 'Run a Skill Gap Analysis',
            () => _startActivity(_filter == _Filter.interviews
                ? const MockInterviewSetupScreen()
                : const SkillGapAnalysisScreen()),
          ),
        ]),
      ];
    }

    final widgets = <Widget>[];
    String? currentMonth;
    for (final item in items) {
      final month = DateFormat('MMMM yyyy').format(item.createdAt);
      if (month != currentMonth) {
        currentMonth = month;
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
          child: Text(month,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: _textMuted, letterSpacing: 0.3)),
        ));
      }
      widgets.add(_reportTile(item));
    }
    return widgets;
  }

  Widget _reportTile(GuidanceReportItem item) {
    final typeColor = item.isMockInterview ? _interviewColor : _skillGapColor;
    final scoreColor = _scoreColor(item.score);
    final opening = _openingID == item.reportID;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openReport(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    item.isMockInterview ? Icons.record_voice_over_outlined : Icons.insights_outlined,
                    color: typeColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.typeLabel,
                          style: TextStyle(
                              color: typeColor, fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(height: 3),
                      Text(item.targetJobRole,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: _textPrimary, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text(DateFormat('d MMM yyyy, h:mm a').format(item.createdAt),
                          style: const TextStyle(color: _textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (opening)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                  )
                else
                  Column(
                    children: [
                      Text(
                        item.score == null
                            ? '–'
                            : item.isSkillGap
                                ? '${item.score}%'
                                : '${item.score}',
                        style: TextStyle(
                            color: scoreColor, fontWeight: FontWeight.w800, fontSize: 20),
                      ),
                      Text(item.isSkillGap ? 'match' : 'score',
                          style: const TextStyle(color: _textMuted, fontSize: 11)),
                    ],
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: _textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
