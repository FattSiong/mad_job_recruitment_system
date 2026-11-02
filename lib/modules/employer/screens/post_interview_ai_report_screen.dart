import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/post_interview_pdf_builder.dart';
import '../../../models/post_interview_report_model.dart';
import '../../../services/employer_service.dart';
import '../../job_seeker/screens/guidance_pdf_viewer_screen.dart';

/// Displays the Employer Post-Interview AI Analysis Report & Scorecard,
/// with in-app PDF preview, download, and share options.
class PostInterviewAiReportScreen extends StatefulWidget {
  final PostInterviewReportModel? initialReport;
  final String? scheduleID;
  final String? applicantID;

  const PostInterviewAiReportScreen({
    super.key,
    this.initialReport,
    this.scheduleID,
    this.applicantID,
  });

  @override
  State<PostInterviewAiReportScreen> createState() =>
      _PostInterviewAiReportScreenState();
}

class _PostInterviewAiReportScreenState
    extends State<PostInterviewAiReportScreen> {
  static const Color _primary = Color(0xFF163B65);
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _textPrimary = Color(0xFF1B2433);
  static const Color _textMuted = Color(0xFF687588);
  static const Color _surfaceAlt = Color(0xFFF7F9FC);
  static const Color _border = Color(0xFFE1E8F0);
  static const Color _green = Color(0xFF2D8A5D);
  static const Color _amber = Color(0xFFC28A22);
  static const Color _red = Color(0xFFC24E4E);

  final EmployerService _employerService = EmployerService();
  late Future<PostInterviewReportModel?> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _loadReport();
  }

  Future<PostInterviewReportModel?> _loadReport() async {
    if (widget.initialReport != null) {
      return widget.initialReport;
    }
    if (widget.scheduleID != null && widget.scheduleID!.isNotEmpty) {
      return _employerService
          .getPostInterviewReportByScheduleId(widget.scheduleID!);
    }
    if (widget.applicantID != null && widget.applicantID!.isNotEmpty) {
      return _employerService
          .getPostInterviewReportByApplicantId(widget.applicantID!);
    }
    return null;
  }

  Color _scoreColor(int score) {
    if (score >= 75) return _green;
    if (score >= 50) return _amber;
    return _red;
  }

  Color _recommendationColor(String rec) {
    switch (rec.toLowerCase()) {
      case 'strong hire':
      case 'recommended':
        return _green;
      case 'consider':
        return _amber;
      case 'not recommended':
        return _red;
      default:
        return _primary;
    }
  }

  void _openPdfPreview(PostInterviewReportModel report) {
    final safeName = report.candidateName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final dateTag = DateFormat('yyyyMMdd_HHmm').format(report.updatedAt.toLocal());

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuidancePdfViewerScreen(
          title: 'Post-Interview AI Report',
          fileName:
              'post_interview_ai_report_${safeName.isEmpty ? 'candidate' : safeName}_$dateTag.pdf',
          buildPdf: () => PostInterviewPdfBuilder.build(report),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PostInterviewReportModel?>(
      future: _reportFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final report = snapshot.data;

        return Scaffold(
          backgroundColor: _background,
          body: SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: _primary))
                : report == null
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildHeroHeader(null),
                            const Expanded(
                              child: Center(
                                child: Text(
                                  'Unable to load this Post-Interview AI Report.',
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeroHeader(report),
                            const SizedBox(height: 18),
                            _buildInterviewAndCandidateCard(report),
                            const SizedBox(height: 18),
                            _buildScoreCard(report),
                            const SizedBox(height: 18),
                            _buildCommunicationCard(report),
                            const SizedBox(height: 18),
                            _buildSummaryAndInsightsCard(report),
                            if (report.qaBreakdown.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              _buildQaBreakdownCard(report),
                            ],
                            if (report.transcriptText.trim().isNotEmpty) ...[
                              const SizedBox(height: 18),
                              _buildTranscriptCard(report),
                            ],
                          ],
                        ),
                      ),
          ),
          bottomNavigationBar:
              report == null ? null : _buildBottomBar(report),
        );
      },
    );
  }

  Widget _buildHeroHeader(PostInterviewReportModel? report) {
    final date = report?.interviewDate ?? report?.createdAt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
              Material(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (report != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        report.shortReportCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Post-Interview AI Report',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          if (report != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                report.candidateName,
                report.jobTitle,
                if (date != null) DateFormat('d MMM yyyy').format(date),
              ].join(' · '),
              style: const TextStyle(color: Colors.white70, fontSize: 13.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _surfaceCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _textPrimary,
        ),
      ),
    );
  }

  Widget _buildInterviewAndCandidateCard(PostInterviewReportModel report) {
    final interviewDateStr = report.interviewDate != null
        ? DateFormat('d MMM yyyy').format(report.interviewDate!)
        : DateFormat('d MMM yyyy').format(report.createdAt);

    final contactLine = [
      if (report.candidateEmail.isNotEmpty) report.candidateEmail,
      if (report.candidatePhone.isNotEmpty) report.candidatePhone,
    ].join(' · ');

    return _surfaceCard(
      children: [
        // Company header row
        Row(
          children: [
            _buildAvatar(
              imageUrl: report.companyLogoUrl,
              fallbackText: report.companyName,
              size: 46,
              bgColor: const Color(0xFFDCEBFB),
              fgColor: _primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.companyName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Generated ${DateFormat('d MMM yyyy, h:mm a').format(report.updatedAt.toLocal())}',
                    style: const TextStyle(fontSize: 12, color: _textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(color: _border, height: 1),
        ),
        const Text(
          '1. Interview Information',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _primary,
          ),
        ),
        const SizedBox(height: 10),
        _infoTile(
          icon: Icons.work_outline_rounded,
          label: 'Job Title',
          value: report.jobTitle,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _infoTile(
                icon: Icons.event_rounded,
                label: 'Interview Date',
                value: interviewDateStr,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _infoTile(
                icon: Icons.timer_outlined,
                label: 'Duration',
                value: report.formattedDuration,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          '2. Candidate Profile',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _primary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surfaceAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              _buildAvatar(
                imageUrl: report.candidatePhotoUrl,
                fallbackText: report.candidateName,
                size: 56,
                bgColor: _primary,
                fgColor: Colors.white,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.candidateName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    if (contactLine.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        contactLine,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: _textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _smallBadge(
                          text: report.jobTitle,
                          bg: const Color(0xFFDCEBFB),
                          fg: _primary,
                        ),
                        if (report.resumeAiMatchScore != null)
                          _smallBadge(
                            text: 'Resume Match ${report.resumeAiMatchScore}%',
                            bg: const Color(0xFFF3EEFF),
                            fg: const Color(0xFF6B4FD3),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar({
    required String? imageUrl,
    required String fallbackText,
    required double size,
    required Color bgColor,
    required Color fgColor,
  }) {
    final cleanUrl = (imageUrl ?? '').trim();
    final initial =
        fallbackText.trim().isNotEmpty ? fallbackText.trim()[0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: cleanUrl.startsWith('http')
          ? Image.network(
              cleanUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Text(
                initial,
                style: TextStyle(
                  color: fgColor,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : Text(
              initial,
              style: TextStyle(
                color: fgColor,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  Widget _smallBadge({
    required String text,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _primary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: _textMuted),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(PostInterviewReportModel report) {
    final overall = report.overallScore;
    final scoreCol = _scoreColor(overall);
    final recCol = _recommendationColor(report.recommendation);

    return _surfaceCard(
      children: [
        _sectionTitle('3. AI Evaluation Scorecard'),
        Row(
          children: [
            SizedBox(
              width: 104,
              height: 104,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: overall / 100,
                    strokeWidth: 10,
                    backgroundColor: const Color(0xFFE8EEF6),
                    valueColor: AlwaysStoppedAnimation(scoreCol),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$overall',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: scoreCol,
                          ),
                        ),
                        const Text(
                          '/ 100',
                          style: TextStyle(color: _textMuted, fontSize: 12),
                        ),
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
                  const Text(
                    'Overall Interview Score',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: recCol.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      report.recommendation,
                      style: TextStyle(
                        color: recCol,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '60% role & technical fit + 40% delivery',
                    style: TextStyle(color: _textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _scoreBar(
          'Role & Technical Fit',
          report.contentScore,
          'Relevance to job requirements, examples & technical depth',
        ),
        _scoreBar(
          'Communication & Delivery',
          report.deliveryScore,
          'Speaking pace, fluency, answer structure & clarity',
        ),
      ],
    );
  }

  Widget _scoreBar(String label, int score, String hint) {
    final color = _scoreColor(score);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ),
              Text(
                '$score / 100',
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFE8EEF6),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 5),
          Text(hint, style: const TextStyle(color: _textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCommunicationCard(PostInterviewReportModel report) {
    final paceValue = report.estimatedWpm > 0
        ? (report.paceLabel.isNotEmpty
            ? '~${report.estimatedWpm} WPM · ${report.paceLabel}'
            : '~${report.estimatedWpm} WPM')
        : report.paceLabel;

    return _surfaceCard(
      children: [
        _sectionTitle('Speaking & Communication Delivery'),
        _metricTile(
          icon: Icons.speed_rounded,
          label: 'Speaking Pace',
          value: paceValue,
          hint: 'Comfortable range: ~110–165 WPM',
        ),
        const SizedBox(height: 10),
        _metricTile(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Fluency & Fillers',
          value: report.fillerAssessment,
          hint: 'Verbal smoothness & filler word control',
        ),
        const SizedBox(height: 10),
        _metricTile(
          icon: Icons.account_tree_outlined,
          label: 'Answer Structure',
          value: report.clarityAssessment,
          hint: 'Clarity, coherence & STAR organization',
        ),
        const SizedBox(height: 10),
        _metricTile(
          icon: Icons.record_voice_over_outlined,
          label: 'Confidence & Tone',
          value: report.confidenceAssessment,
          hint: 'Engagement & vocal assurance in call',
        ),
        if (report.deliveryNotes.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6FB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.notes_rounded,
                    size: 18,
                    color: _primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    report.deliveryNotes,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 13.5,
                      height: 1.48,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _metricTile({
    required IconData icon,
    required String label,
    required String value,
    required String hint,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFDCEBFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: _primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _primary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hint,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryAndInsightsCard(PostInterviewReportModel report) {
    return _surfaceCard(
      children: [
        _sectionTitle('AI Interview Summary & Insights'),
        if (report.summary.isNotEmpty) ...[
          Text(
            report.summary,
            style: const TextStyle(
              color: _textPrimary,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
        ],
        _bulletSection(
          'Key Strengths Demonstrated',
          report.strengths,
          Icons.check_circle_outline_rounded,
          _green,
        ),
        _bulletSection(
          'Concerns & Areas to Probe',
          report.concerns,
          Icons.warning_amber_rounded,
          _amber,
        ),
        _bulletSection(
          'Suggested Follow-Up Questions',
          report.followUpQuestions,
          Icons.help_outline_rounded,
          _primary,
        ),
      ],
    );
  }

  Widget _bulletSection(
    String title,
    List<String> items,
    IconData icon,
    Color color,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: _textMuted,
                        height: 1.42,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQaBreakdownCard(PostInterviewReportModel report) {
    return _surfaceCard(
      children: [
        _sectionTitle('Question-by-Question Breakdown'),
        ...report.qaBreakdown.map(_buildQaTile),
      ],
    );
  }

  Widget _buildQaTile(InterviewQaExchange qa) {
    final color = _scoreColor(qa.score);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${qa.score}',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          title: Text(
            'Question ${qa.questionIndex}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          subtitle: Text(
            qa.questionAsked,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _textMuted, fontSize: 13),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                qa.questionAsked,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                  height: 1.4,
                ),
              ),
            ),
            if (qa.candidateResponseSummary.isNotEmpty) ...[
              const SizedBox(height: 12),
              _detailBlock('Candidate Response', qa.candidateResponseSummary),
            ],
            if (qa.evaluationNote.isNotEmpty)
              _detailBlock('AI Assessment', qa.evaluationNote),
          ],
        ),
      ),
    );
  }

  Widget _detailBlock(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _textPrimary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              color: _textMuted,
              height: 1.45,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptCard(PostInterviewReportModel report) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFDCEBFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.subtitles_outlined,
              color: _primary,
              size: 20,
            ),
          ),
          title: const Text(
            'Conversation Transcript',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _textPrimary,
              fontSize: 16,
            ),
          ),
          subtitle: const Text(
            'Tap to view diarized Interviewer & Candidate dialogue',
            style: TextStyle(color: _textMuted, fontSize: 12.5),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: SelectableText(
                report.transcriptText,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(PostInterviewReportModel report) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: AppColors.borderActive),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => _openPdfPreview(report),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text(
                  'Preview & Export PDF',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
