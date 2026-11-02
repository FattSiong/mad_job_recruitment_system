import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/guidance_pdf_builder.dart';
import '../../../models/skill_gap_model.dart';
import '../controllers/guidance_report_controller.dart';
import 'guidance_pdf_viewer_screen.dart';
import '../../../shared_widgets/surface_card.dart';

/// Skill Gap Report (end of Use Case 4.60). Also reusable from Guidance Reports.
class SkillGapResultScreen extends StatelessWidget {
  final SkillGapAnalysisModel analysis;

  const SkillGapResultScreen({super.key, required this.analysis});

  Color _priorityColor(String p) {
    switch (p) {
      case 'high':
        return AppColors.errorRed;
      case 'low':
        return AppColors.textMuted;
      default:
        return AppColors.warning;
    }
  }

  IconData _pathIcon(String type) {
    switch (type) {
      case 'course':
        return Icons.menu_book_outlined;
      case 'certification':
        return Icons.workspace_premium_outlined;
      case 'project':
        return Icons.build_outlined;
      case 'experience':
        return Icons.work_history_outlined;
      case 'networking':
        return Icons.groups_outlined;
      case 'resume':
        return Icons.description_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildScoreCard(),
              const SizedBox(height: 20),
              _buildMarketCard(),
              const SizedBox(height: 20),
              _buildSkillsCard(),
              if (a.actionPaths.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildActionPathsCard(),
              ],
              if (a.resumeTips.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildResumeTipsCard(),
              ],
              if (a.userSkills.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildDetectedSkillsCard(),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GuidancePdfViewerScreen(
                        title: 'Skill Gap Report',
                        fileName:
                            'skill_gap_report_${DateFormat('yyyyMMdd_HHmm').format(analysis.createdAt)}.pdf',
                        buildPdf: () async => GuidancePdfBuilder.skillGapReport(
                          analysis,
                          applicantName: await GuidanceReportController().fetchApplicantName(),
                        ),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('View as PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.borderActive),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('Done'),
            ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Skill Gap Report',
                  style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  '${analysis.targetJobRole} · ${DateFormat('d MMM yyyy').format(analysis.createdAt)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    final a = analysis;
    final color = AppColors.forScore(a.matchScore);
    final basedOn = [
      if (a.resumeAnalysed) 'your resume',
      'profile',
      a.jobSampleSize > 0
          ? '${a.jobSampleSize} job posting${a.jobSampleSize == 1 ? '' : 's'}'
          : 'AI market knowledge',
    ].join(', ');

    return SurfaceCard(
      children: [
        Row(
          children: [
            SizedBox(
              width: 104,
              height: 104,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: a.matchScore / 100,
                    strokeWidth: 10,
                    backgroundColor: AppColors.progressTrack,
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${a.matchScore}%',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
                        const Text('match', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _countRow(Icons.check_circle_rounded, AppColors.successGreen,
                      '${a.matching.length} matching'),
                  _countRow(Icons.adjust_rounded, AppColors.warning, '${a.partial.length} partial'),
                  _countRow(Icons.cancel_rounded, AppColors.errorRed, '${a.missing.length} missing'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Based on $basedOn.', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        if (a.summary.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(a.summary, style: const TextStyle(color: AppColors.textDark, height: 1.5)),
        ],
      ],
    );
  }

  Widget _countRow(IconData icon, Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
        ],
      ),
    );
  }

  Widget _buildMarketCard() {
    final m = analysis.marketInsights;
    final demandColor = m.demandLevel == 'High'
        ? AppColors.successGreen
        : m.demandLevel == 'Low'
            ? AppColors.errorRed
            : AppColors.warning;

    return SurfaceCard(
      children: [
        SectionTitle('Market Demand'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (m.demandLevel.isNotEmpty)
              _pill(Icons.trending_up_rounded, '${m.demandLevel} demand', demandColor),
            if (m.typicalSalary.isNotEmpty)
              _pill(Icons.payments_outlined, m.typicalSalary, AppColors.primary),
          ],
        ),
        if (m.summary.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(m.summary, style: const TextStyle(color: AppColors.textMuted, height: 1.45)),
        ],
        if (m.commonRequirements.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Employers commonly ask for',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 8),
          ...m.commonRequirements.map((r) => _bullet(r, Icons.chevron_right_rounded, AppColors.primary)),
        ],
      ],
    );
  }

  Widget _pill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textMuted, height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildSkillsCard() {
    final a = analysis;
    return SurfaceCard(
      children: [
        SectionTitle('Skills Breakdown',
          subtitle: 'Required skills for this role compared with yours.',
        ),
        if (a.missing.isNotEmpty) ...[
          _groupTitle('Missing skills', AppColors.errorRed),
          ...a.missing.map((s) => _skillTile(s, AppColors.errorRed, Icons.cancel_rounded, s.gap)),
        ],
        if (a.partial.isNotEmpty) ...[
          _groupTitle('Partially matching', AppColors.warning),
          ...a.partial.map((s) => _skillTile(s, AppColors.warning, Icons.adjust_rounded, s.gap)),
        ],
        if (a.matching.isNotEmpty) ...[
          _groupTitle('Matching skills', AppColors.successGreen),
          ...a.matching.map(
              (s) => _skillTile(s, AppColors.successGreen, Icons.check_circle_rounded, s.evidence)),
        ],
      ],
    );
  }

  Widget _groupTitle(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _skillTile(RequiredSkillItem s, Color color, IconData icon, String detail) {
    final pColor = _priorityColor(s.importance);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(s.skill,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: pColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${_cap(s.importance)} priority',
                          style: TextStyle(color: pColor, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                if (s.category.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_cap(s.category), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(detail, style: const TextStyle(color: AppColors.textMuted, height: 1.35, fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPathsCard() {
    final paths = analysis.actionPaths;
    return SurfaceCard(
      children: [
        SectionTitle('Recommended Action Paths', subtitle: 'Start with the highest priority.'),
        for (var i = 0; i < paths.length; i++) _actionPathTile(i + 1, paths[i]),
      ],
    );
  }

  Widget _actionPathTile(int number, ActionPath p) {
    final pColor = _priorityColor(p.priority);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_pathIcon(p.type), color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$number. ${p.title}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: AppColors.textDark, height: 1.3)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _smallTag('${_cap(p.priority)} priority', pColor),
                        if (p.type.isNotEmpty) _smallTag(_cap(p.type), AppColors.primary),
                        if (p.timeframe.isNotEmpty) _smallTag(p.timeframe, AppColors.textMuted),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (p.skillsAddressed.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Builds: ${p.skillsAddressed.join(', ')}',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
          if (p.steps.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (var i = 0; i < p.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 1),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p.steps[i],
                          style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
                    ),
                  ],
                ),
              ),
          ],
          if (p.suggestedResources.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: p.suggestedResources
                  .map((r) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bookmark_border_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(r,
                                  style: const TextStyle(
                                      color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _smallTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildResumeTipsCard() {
    return SurfaceCard(
      children: [
        SectionTitle('Resume Tips', subtitle: 'Show the skills you already have more clearly.'),
        ...analysis.resumeTips.map((t) => _bullet(t, Icons.tips_and_updates_outlined, AppColors.primary)),
        if (analysis.resumeNote.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(analysis.resumeNote, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _buildDetectedSkillsCard() {
    return SurfaceCard(
      children: [
        SectionTitle('Your Detected Skills',
          subtitle: 'Found in your profile, resume, education and experience.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: analysis.userSkills
              .map((s) => Tooltip(
                    message: 'From ${s.source}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(s.skill,
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
