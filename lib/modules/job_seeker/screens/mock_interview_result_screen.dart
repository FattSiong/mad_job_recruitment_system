import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/guidance_pdf_builder.dart';
import '../../../models/mock_interview_model.dart';
import '../controllers/guidance_report_controller.dart';
import '../../../core/utils/data_load_exception.dart';
import '../widgets/load_error_view.dart';
import '../controllers/mock_interview_controller.dart';
import 'guidance_pdf_viewer_screen.dart';
import 'mock_interview_setup_screen.dart';
import '../../../shared_widgets/surface_card.dart';

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
  final MockInterviewController _controller = MockInterviewController();
  late Future<MockInterviewRecordModel?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.initialRecord != null && widget.initialRecord!.answers.isNotEmpty
        ? Future.value(widget.initialRecord)
        : _controller.fetchInterview(widget.sessionID);
  }

  /// Loads the interview again (Try Again).
  void _retry() => setState(() => _future = _controller.fetchInterview(widget.sessionID));

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<MockInterviewRecordModel?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildHeader(null),
                    Expanded(
                      child: LoadErrorView(
                        message: snapshot.error is DataLoadException
                            ? (snapshot.error as DataLoadException).message
                            : 'Unable to load this interview report.',
                        onRetry: _retry,
                      ),
                    ),
                  ],
                ),
              );
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
                          'This interview report no longer exists.',
                          style: TextStyle(color: AppColors.textMuted),
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
                  _buildBodyLanguageCard(record),
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

  /// Gradient header with the role and date.
  Widget _buildHeader(MockInterviewRecordModel? record) {
    final date = record?.completedAt ?? record?.createdAt;
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

  /// Overall score ring and the score for each part.
  Widget _buildScoreCard(MockInterviewRecordModel record) {
    final overall = record.overallScore ?? 0;
    final color = AppColors.forScore(overall);

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
                    value: overall / 100,
                    strokeWidth: 10,
                    backgroundColor: AppColors.progressTrack,
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
                        const Text('/ 100', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 16),
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
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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

  /// One labelled score bar.
  Widget _scoreBar(String label, int score, String hint) {
    final color = AppColors.forScore(score);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
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
              backgroundColor: AppColors.progressTrack,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(hint, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  /// Speaking pace, filler words and pauses.
  Widget _buildSpeechCard(MockInterviewRecordModel record) {
    final speech = record.speech;
    num n(String key) => (speech[key] as num?) ?? 0;

    return SurfaceCard(
      children: [
        SectionTitle('Speaking Delivery'),
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

  /// Eye contact and smiling from the camera. Feedback only (not in the score).
  Widget _buildBodyLanguageCard(MockInterviewRecordModel record) {
    final withCamera = record.answersWithCamera;
    if (withCamera == 0) {
      return const SurfaceCard(
        children: [
          SectionTitle('Body Language'),
          Row(
            children: [
              Icon(Icons.videocam_off_outlined, color: AppColors.textMuted),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The camera was off. Turn it on next time to get feedback on eye contact and smiling.',
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final body = record.bodyLanguage;
    final lookAways = (body['totalLookAways'] as num?)?.round() ??
        record.answers.fold<int>(0, (sum, a) => sum + (a.lookAwayCount ?? 0));
    final feedback = body['feedback'] as String? ?? '';
    String percent(int? v) => v == null ? '–' : '$v%';

    return SurfaceCard(
      children: [
        const SectionTitle('Body Language'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _metricTile(Icons.visibility_outlined, percent(record.eyeContactPercent),
                'Eye contact', 'Facing the camera'),
            _metricTile(Icons.sentiment_satisfied_alt_outlined, percent(record.smilePercent),
                'Smiling', 'Of the time in view'),
            _metricTile(Icons.swap_horiz_rounded, '$lookAways',
                'Look-aways', 'Away for 1s or more'),
            _metricTile(Icons.videocam_outlined, '$withCamera / ${record.answers.length}',
                'Answers on camera', 'Camera turned on'),
          ],
        ),
        if (feedback.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(feedback, style: const TextStyle(color: AppColors.textDark, height: 1.5)),
        ],
        const SizedBox(height: 12),
        const Text(
          'Estimated on your phone from your head direction and expression. '
          'Video is never recorded or uploaded, and this does not change your score.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }

  /// One number in the speaking delivery grid.
  Widget _metricTile(IconData icon, String value, String label, String hint) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 13)),
          Text(hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  /// The AI's summary, strengths and things to improve.
  Widget _buildSummaryCard(MockInterviewRecordModel record) {
    return SurfaceCard(
      children: [
        SectionTitle('AI Feedback'),
        if (record.summary.isNotEmpty) ...[
          Text(record.summary, style: const TextStyle(color: AppColors.textDark, height: 1.5)),
          const SizedBox(height: 18),
        ],
        _bulletSection('Strengths', record.strengths, Icons.check_circle_outline_rounded,
            AppColors.successGreen),
        _bulletSection('Areas to Improve', record.improvements, Icons.trending_up_rounded, AppColors.warning),
        _bulletSection('Tips for Next Time', record.tips, Icons.tips_and_updates_outlined, AppColors.primary),
      ],
    );
  }

  /// A titled bullet list (hidden when empty).
  Widget _bulletSection(String title, List<String> items, IconData icon, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
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
                    child: Text(item, style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Every question with the user's answer and its feedback.
  Widget _buildQuestionsCard(MockInterviewRecordModel record) {
    return SurfaceCard(
      children: [
        SectionTitle('Question-by-Question'),
        ...record.answers.map(_buildAnswerTile),
      ],
    );
  }

  /// One question: score, transcript and feedback (tap to expand).
  Widget _buildAnswerTile(MockInterviewAnswerModel a) {
    final avgScore = (((a.contentScore ?? 0) + (a.deliveryScore ?? 0)) / 2).round();
    final color = AppColors.forScore(avgScore);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
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
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          subtitle: Text(
            a.questionText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(a.questionText,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, height: 1.4)),
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
                if (a.eyeContactPercent != null) _chip('${a.eyeContactPercent}% eye contact'),
                if (a.smilePercent != null) _chip('${a.smilePercent}% smiling'),
              ],
            ),
            const SizedBox(height: 14),
            _detailBlock('Your answer', a.transcriptText),
            if (a.relevance.isNotEmpty) _detailBlock('Relevance', a.relevance),
            _bulletSection('What went well', a.strengths, Icons.check_circle_outline_rounded,
                AppColors.successGreen),
            _bulletSection('What to improve', a.improvements, Icons.trending_up_rounded, AppColors.warning),
            if (a.deliveryFeedback.isNotEmpty) _detailBlock('Delivery', a.deliveryFeedback),
            if (a.bodyLanguageFeedback.isNotEmpty) _detailBlock('Body language', a.bodyLanguageFeedback),
            if (a.improvedAnswer.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome_outlined, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Stronger sample answer',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(a.improvedAnswer,
                        style: const TextStyle(color: AppColors.textDark, height: 1.45)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Small outlined label.
  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label,
          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  /// A bold title with a paragraph under it.
  Widget _detailBlock(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(color: AppColors.textMuted, height: 1.45)),
        ],
      ),
    );
  }

  /// Opens the scorecard as a PDF.
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
          foregroundColor: AppColors.primary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.borderActive),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  /// Practise Again and Done buttons.
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
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.borderActive),
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
                  backgroundColor: AppColors.primary,
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
