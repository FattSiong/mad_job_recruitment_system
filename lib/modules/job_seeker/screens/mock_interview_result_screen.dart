import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/guidance_pdf_builder.dart';
import '../../../models/mock_interview_model.dart';
import '../controllers/guidance_report_controller.dart';
import '../controllers/mock_interview_controller.dart';
import 'guidance_pdf_viewer_screen.dart';
import 'mock_interview_setup_screen.dart';

/// Interview scorecard (end of Use Case 4.59). Also reusable from Guidance Reports.
class MockInterviewResultScreen extends StatefulWidget {
  final String sessionID;
  final MockInterviewRecordModel? initialRecord;

  const MockInterviewResultScreen({
    super.key,
    required this.sessionID,
    this.initialRecord,
  });

  @override
  State<MockInterviewResultScreen> createState() => _MockInterviewResultScreenState();
}

class _MockInterviewResultScreenState extends State<MockInterviewResultScreen> {
  static const Color _primary = Color(0xFF163B65);
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _textPrimary = Color(0xFF1B2433);
  static const Color _textMuted = Color(0xFF687588);
  static const Color _surfaceAlt = Color(0xFFF7F9FC);
  static const Color _border = Color(0xFFE1E8F0);
  static const Color _warning = Color(0xFFC77700);

  final MockInterviewController _controller = MockInterviewController();
  late Future<MockInterviewRecordModel?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.initialRecord != null && widget.initialRecord!.answers.isNotEmpty
        ? Future.value(widget.initialRecord)
        : _controller.fetchInterview(widget.sessionID);
  }

  Color _scoreColor(int score) {
    if (score >= 75) return AppColors.successGreen;
    if (score >= 50) return _warning;
    return AppColors.errorRed;
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: FutureBuilder<MockInterviewRecordModel?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _primary));
            }
            final record = snapshot.data;
            if (record == null) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildHeader(null),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Unable to load this interview report.',
                          style: TextStyle(color: _textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(record),
                  const SizedBox(height: 20),
                  _buildScoreCard(record),
                  const SizedBox(height: 20),
                  _buildSpeechCard(record),
                  const SizedBox(height: 20),
                  _buildSummaryCard(record),
                  const SizedBox(height: 20),
                  _buildQuestionsCard(record),
                  const SizedBox(height: 20),
                  _buildPdfButton(record),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildHeader(MockInterviewRecordModel? record) {
    final date = record?.completedAt ?? record?.createdAt;
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Interview Scorecard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (record != null) record.targetJobRole,
                    if (date != null) DateFormat('d MMM yyyy').format(date),
                  ].join(' · '),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
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

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _textPrimary,
        ),
      ),
    );
  }

  Widget _buildScoreCard(MockInterviewRecordModel record) {
    final overall = record.overallScore ?? 0;
    final color = _scoreColor(overall);

    return _surfaceCard(
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
                    value: overall / 100,
                    strokeWidth: 10,
                    backgroundColor: const Color(0xFFE8EEF6),
                    valueColor: AlwaysStoppedAnimation(color),
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
                            color: color,
                          ),
                        ),
                        const Text('/ 100', style: TextStyle(color: _textMuted, fontSize: 12)),
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
                    'Overall Score',
                    style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (record.readiness.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        record.readiness,
                        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    '60% answer content + 40% delivery',
                    style: TextStyle(color: _textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _scoreBar('Answer Content', record.contentScore ?? 0,
            'Relevance, structure and examples'),
        _scoreBar('Delivery', record.deliveryScore ?? 0,
            'Pace, filler words and hesitations'),
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
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
              ),
              Text('$score', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
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
          const SizedBox(height: 6),
          Text(hint, style: const TextStyle(color: _textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSpeechCard(MockInterviewRecordModel record) {
    final speech = record.speech;
    num n(String key) => (speech[key] as num?) ?? 0;

    return _surfaceCard(
      children: [
        _sectionTitle('Speaking Delivery'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _metricTile(Icons.speed_rounded, '${n('averageWordsPerMinute').round()}',
                'Avg words / min', 'Aim for 110–165'),
            _metricTile(Icons.chat_bubble_outline_rounded, '${n('fillerRate')}',
                'Fillers / 100 words', '${n('totalFillerWords').round()} in total'),
            _metricTile(Icons.pause_circle_outline_rounded, '${n('totalHesitations').round()}',
                'Hesitations', 'Pauses ≥1s & repeats'),
            _metricTile(Icons.hourglass_bottom_rounded, '${n('totalLongPauses').round()}',
                'Long pauses', 'Pauses ≥2.5s'),
          ],
        ),
      ],
    );
  }

  Widget _metricTile(IconData icon, String value, String label, String hint) {
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
          Row(
            children: [
              Icon(icon, size: 18, color: _primary),
              const SizedBox(width: 6),
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, color: _textPrimary, fontSize: 13)),
          Text(hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(MockInterviewRecordModel record) {
    return _surfaceCard(
      children: [
        _sectionTitle('AI Feedback'),
        if (record.summary.isNotEmpty) ...[
          Text(record.summary, style: const TextStyle(color: _textPrimary, height: 1.5)),
          const SizedBox(height: 18),
        ],
        _bulletSection('Strengths', record.strengths, Icons.check_circle_outline_rounded,
            AppColors.successGreen),
        _bulletSection('Areas to Improve', record.improvements, Icons.trending_up_rounded, _warning),
        _bulletSection('Tips for Next Time', record.tips, Icons.tips_and_updates_outlined, _primary),
      ],
    );
  }

  Widget _bulletSection(String title, List<String> items, IconData icon, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
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
                    child: Text(item, style: const TextStyle(color: _textMuted, height: 1.4)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsCard(MockInterviewRecordModel record) {
    return _surfaceCard(
      children: [
        _sectionTitle('Question-by-Question'),
        ...record.answers.map(_buildAnswerTile),
      ],
    );
  }

  Widget _buildAnswerTile(MockInterviewAnswerModel a) {
    final avgScore = (((a.contentScore ?? 0) + (a.deliveryScore ?? 0)) / 2).round();
    final color = _scoreColor(avgScore);

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          leading: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('$avgScore',
                style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ),
          title: Text(
            a.questionIndex == 0 ? 'Introduction' : 'Question ${a.questionIndex}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary),
          ),
          subtitle: Text(
            a.questionText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _textMuted, fontSize: 13),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(a.questionText,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: _textPrimary, height: 1.4)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Content ${a.contentScore ?? 0}'),
                _chip('Delivery ${a.deliveryScore ?? 0}'),
                _chip('${a.wordsPerMinute?.round() ?? 0} wpm${a.paceLabel.isEmpty ? '' : ' (${a.paceLabel})'}'),
                _chip('${a.fillerWordCount ?? 0} fillers'),
                _chip('${a.hesitationCount ?? 0} hesitations'),
              ],
            ),
            const SizedBox(height: 14),
            _detailBlock('Your answer', a.transcriptText),
            if (a.relevance.isNotEmpty) _detailBlock('Relevance', a.relevance),
            _bulletSection('What went well', a.strengths, Icons.check_circle_outline_rounded,
                AppColors.successGreen),
            _bulletSection('What to improve', a.improvements, Icons.trending_up_rounded, _warning),
            if (a.deliveryFeedback.isNotEmpty) _detailBlock('Delivery', a.deliveryFeedback),
            if (a.improvedAnswer.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCEBFB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome_outlined, size: 18, color: _primary),
                        SizedBox(width: 8),
                        Text('Stronger sample answer',
                            style: TextStyle(fontWeight: FontWeight.bold, color: _primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(a.improvedAnswer,
                        style: const TextStyle(color: _textPrimary, height: 1.45)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Text(label,
          style: const TextStyle(color: _primary, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _detailBlock(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(color: _textMuted, height: 1.45)),
        ],
      ),
    );
  }

  Widget _buildPdfButton(MockInterviewRecordModel record) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuidancePdfViewerScreen(
              title: 'Interview Scorecard',
              fileName:
                  'interview_scorecard_${DateFormat('yyyyMMdd_HHmm').format(record.completedAt ?? record.createdAt)}.pdf',
              buildPdf: () async => GuidancePdfBuilder.interviewReport(
                record,
                applicantName: await GuidanceReportController().fetchApplicantName(),
              ),
            ),
          ),
        ),
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: const Text('View as PDF'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFB8D1EE)),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: Color(0xFFB8D1EE)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('Done'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MockInterviewSetupScreen()),
                ),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Practise Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
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
