import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/mock_interview_model.dart';
import '../../models/skill_gap_model.dart';
import 'pdf_text.dart';
import 'app_date_format.dart';
import 'text_cut.dart';

/// Builds the Guidance Report PDFs (full history, one interview, one skill gap analysis).
class GuidancePdfBuilder {
  GuidancePdfBuilder._();

  // Palette (same as the app)
  static final PdfColor _navy = PdfColor.fromInt(0xFF163B65);
  static final PdfColor _navyLight = PdfColor.fromInt(0xFFDCEBFB);
  static final PdfColor _text = PdfColor.fromInt(0xFF1B2433);
  static final PdfColor _muted = PdfColor.fromInt(0xFF687588);
  static final PdfColor _surface = PdfColor.fromInt(0xFFF7F9FC);
  static final PdfColor _border = PdfColor.fromInt(0xFFE1E8F0);
  static final PdfColor _green = PdfColor.fromInt(0xFF2E7D32);
  static final PdfColor _amber = PdfColor.fromInt(0xFFC77700);
  static final PdfColor _red = PdfColor.fromInt(0xFFD32F2F);


  /// Shortens [s] to [max] characters, ending with "…".
  static String _cut(String s, int max) => TextCut.withEllipsis(s, max);

  /// Green / amber / red for a 0-100 score (grey when there is no score).
  static PdfColor _scoreColor(int? score) {
    if (score == null) return _muted;
    if (score >= 75) return _green;
    if (score >= 50) return _amber;
    return _red;
  }

  /// [s] with its first letter in capitals.
  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // =====================================================================
  // Public builders
  // =====================================================================

  /// The whole history: overview, summary tables and every report in detail.
  static Future<Uint8List> fullReport({
    required String applicantName,
    required List<MockInterviewSessionModel> interviews,
    required List<SkillGapAnalysisModel> skillGaps,
  }) async {
    final theme = await PdfText.theme();
    final doc = pw.Document(
      theme: theme,
      title: 'Career Guidance Report',
      author: 'Job Recruitment App',
    );

    doc.addPage(_multiPage(
      title: 'Career Guidance Report',
      subtitle: '${PdfText.clean(applicantName)} · Generated ${AppDateFormat.dayTime.format(DateTime.now())}',
      body: [
        ..._overview(interviews, skillGaps),
        if (interviews.isNotEmpty) ..._interviewTable(interviews),
        if (skillGaps.isNotEmpty) ..._skillGapTable(skillGaps),
      ],
    ));

    for (final r in interviews) {
      doc.addPage(_multiPage(
        title: 'Mock Interview Scorecard',
        subtitle: '${PdfText.clean(r.targetJobRole)} · ${AppDateFormat.day.format(r.completedAt ?? r.createdAt)}',
        body: _interviewDetail(r),
      ));
    }
    for (final a in skillGaps) {
      doc.addPage(_multiPage(
        title: 'Skill Gap Report',
        subtitle: '${PdfText.clean(a.targetJobRole)} · ${AppDateFormat.day.format(a.createdAt)}',
        body: _skillGapDetail(a),
      ));
    }
    return doc.save();
  }

  /// One mock interview scorecard as a PDF.
  static Future<Uint8List> interviewReport(
    MockInterviewSessionModel r, {
    String? applicantName,
  }) async {
    final doc = pw.Document(theme: await PdfText.theme(), title: 'Mock Interview Scorecard');
    doc.addPage(_multiPage(
      title: 'Mock Interview Scorecard',
      subtitle: [
        if (applicantName != null && applicantName.isNotEmpty) PdfText.clean(applicantName),
        PdfText.clean(r.targetJobRole),
        AppDateFormat.day.format(r.completedAt ?? r.createdAt),
      ].join(' · '),
      body: _interviewDetail(r),
    ));
    return doc.save();
  }

  /// One skill gap analysis as a PDF.
  static Future<Uint8List> skillGapReport(
    SkillGapAnalysisModel a, {
    String? applicantName,
  }) async {
    final doc = pw.Document(theme: await PdfText.theme(), title: 'Skill Gap Report');
    doc.addPage(_multiPage(
      title: 'Skill Gap Report',
      subtitle: [
        if (applicantName != null && applicantName.isNotEmpty) PdfText.clean(applicantName),
        PdfText.clean(a.targetJobRole),
        AppDateFormat.day.format(a.createdAt),
      ].join(' · '),
      body: _skillGapDetail(a),
    ));
    return doc.save();
  }

  // =====================================================================
  // Page frame
  // =====================================================================

  static pw.MultiPage _multiPage({
    required String title,
    required String subtitle,
    required List<pw.Widget> body,
  }) {
    // The banner is the first body widget (not a page header) so every report section
    // in the full PDF starts with its own banner.
    final banner = pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: _navy,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('AI CAREER ADVISORY',
              style: pw.TextStyle(color: _navyLight, fontSize: 8, letterSpacing: 1.5)),
          pw.SizedBox(height: 4),
          pw.Text(title,
              style: pw.TextStyle(
                  color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(subtitle, style: pw.TextStyle(color: _navyLight, fontSize: 10)),
        ],
      ),
    );

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 28),
      footer: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _border)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                '$title · AI-generated guidance for practice. Scores are estimates.',
                maxLines: 1,
                style: pw.TextStyle(color: _muted, fontSize: 7),
              ),
            ),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(color: _muted, fontSize: 7)),
          ],
        ),
      ),
      build: (context) => [banner, ...body],
    );
  }

  // =====================================================================
  // Building blocks
  // =====================================================================

  static pw.Widget _section(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 8),
        child: pw.Text(text,
            style: pw.TextStyle(color: _navy, fontSize: 13, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _subTitle(String text, {PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
        child: pw.Text(text,
            style: pw.TextStyle(
                color: color ?? _text, fontSize: 10, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _para(String text, {PdfColor? color, double size = 9.5}) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(PdfText.clean(text),
            style: pw.TextStyle(color: color ?? _text, fontSize: size, lineSpacing: 2)),
      );

  static List<pw.Widget> _bullets(List<String> items, {PdfColor? color}) => items
      .where((s) => s.trim().isNotEmpty)
      .map((s) => pw.Bullet(
            text: PdfText.clean(s),
            style: pw.TextStyle(color: _text, fontSize: 9.5, lineSpacing: 2),
            bulletColor: color ?? _navy,
            bulletSize: 3.5,
            margin: const pw.EdgeInsets.only(bottom: 3, left: 4),
          ))
      .toList();

  /// A row of score boxes.
  static pw.Widget _statRow(List<(String label, String value, PdfColor color)> stats) {
    return pw.Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: pw.BoxDecoration(
                color: _surface,
                border: pw.Border.all(color: _border),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(stats[i].$2,
                      style: pw.TextStyle(
                          color: stats[i].$3, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text(stats[i].$1, style: pw.TextStyle(color: _muted, fontSize: 8)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    Map<int, pw.TableColumnWidth>? widths,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows.map((r) => r.map(PdfText.clean).toList()).toList(),
      columnWidths: widths,
      border: pw.TableBorder.all(color: _border, width: 0.6),
      headerDecoration: pw.BoxDecoration(color: _navy),
      headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
      cellStyle: pw.TextStyle(color: _text, fontSize: 8.5),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      oddRowDecoration: pw.BoxDecoration(color: _surface),
    );
  }

  static pw.Widget _callout(String title, String text) => pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 4, bottom: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _navyLight,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(color: _navy, fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(PdfText.clean(text), style: pw.TextStyle(color: _text, fontSize: 9, lineSpacing: 2)),
          ],
        ),
      );

  // =====================================================================
  // Full report: overview + summary tables
  // =====================================================================

  static List<pw.Widget> _overview(
    List<MockInterviewSessionModel> interviews,
    List<SkillGapAnalysisModel> skillGaps,
  ) {
    final scores = interviews.map((r) => r.overallScore).whereType<int>().toList();
    final avg = scores.isEmpty ? null : (scores.reduce((a, b) => a + b) / scores.length).round();
    final best = scores.isEmpty ? null : scores.reduce((a, b) => a > b ? a : b);
    final latestGap = skillGaps.isEmpty ? null : skillGaps.first;

    // Trend: oldest vs newest interview score
    String trend = 'Not enough interviews to show a trend yet.';
    if (scores.length >= 2) {
      final diff = scores.first - scores.last; // lists are newest first
      trend = diff == 0
          ? 'Your interview score is unchanged since your first recorded practice.'
          : 'Your interview score has ${diff > 0 ? 'improved' : 'dropped'} by ${diff.abs()} points '
              'since your first recorded practice.';
    }

    return [
      _section('Overview'),
      _statRow([
        ('Mock interviews', '${interviews.length}', _navy),
        ('Skill analyses', '${skillGaps.length}', _navy),
        ('Average interview score', avg == null ? '-' : '$avg', _scoreColor(avg)),
        ('Best interview score', best == null ? '-' : '$best', _scoreColor(best)),
        ('Latest skill match', latestGap == null ? '-' : '${latestGap.matchScore}%',
            _scoreColor(latestGap?.matchScore)),
      ]),
      pw.SizedBox(height: 8),
      _para(trend, color: _muted, size: 9),
    ];
  }

  static List<pw.Widget> _interviewTable(List<MockInterviewSessionModel> interviews) => [
        _section('Mock Interview History'),
        _table(
          headers: ['Date', 'Target role', 'Overall', 'Content', 'Delivery', 'Readiness'],
          widths: {
            0: const pw.FixedColumnWidth(62),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FixedColumnWidth(44),
            3: const pw.FixedColumnWidth(44),
            4: const pw.FixedColumnWidth(46),
            5: const pw.FlexColumnWidth(2),
          },
          rows: interviews
              .map((r) => [
                    AppDateFormat.day.format(r.completedAt ?? r.createdAt),
                    r.targetJobRole,
                    '${r.overallScore ?? '-'}',
                    '${r.contentScore ?? '-'}',
                    '${r.deliveryScore ?? '-'}',
                    r.readiness,
                  ])
              .toList(),
        ),
      ];

  static List<pw.Widget> _skillGapTable(List<SkillGapAnalysisModel> skillGaps) => [
        _section('Skill Gap History'),
        _table(
          headers: ['Date', 'Target role', 'Match', 'Missing', 'Top gaps'],
          widths: {
            0: const pw.FixedColumnWidth(62),
            1: const pw.FlexColumnWidth(2.2),
            2: const pw.FixedColumnWidth(40),
            3: const pw.FixedColumnWidth(42),
            4: const pw.FlexColumnWidth(3),
          },
          rows: skillGaps
              .map((a) => [
                    AppDateFormat.day.format(a.createdAt),
                    a.targetJobRole,
                    '${a.matchScore}%',
                    '${a.missing.length}',
                    a.missing.take(3).map((s) => s.skill).join(', '),
                  ])
              .toList(),
        ),
      ];

  // =====================================================================
  // Interview detail
  // =====================================================================

  static List<pw.Widget> _interviewDetail(MockInterviewSessionModel r) {
    final speech = r.speech;
    String n(String k) => '${(speech[k] as num?) ?? 0}';

    return [
      _statRow([
        ('Overall score', '${r.overallScore ?? '-'}', _scoreColor(r.overallScore)),
        ('Answer content', '${r.contentScore ?? '-'}', _scoreColor(r.contentScore)),
        ('Delivery', '${r.deliveryScore ?? '-'}', _scoreColor(r.deliveryScore)),
        ('Readiness', r.readiness.isEmpty ? '-' : r.readiness, _navy),
      ]),
      pw.SizedBox(height: 4),
      _para('Overall score = 60% answer content + 40% delivery.', color: _muted, size: 8),

      _section('Speaking Delivery'),
      _table(
        headers: ['Avg pace (wpm)', 'Fillers / 100 words', 'Total fillers', 'Hesitations', 'Long pauses'],
        rows: [
          [n('averageWordsPerMinute'), n('fillerRate'), n('totalFillerWords'), n('totalHesitations'), n('totalLongPauses')],
        ],
      ),
      _para('Comfortable pace is about 110-165 words per minute. Hesitations are pauses of 1 second or more '
          'and repeated words; long pauses are 2.5 seconds or more.', color: _muted, size: 8),

      ..._bodyLanguage(r),

      if (r.summary.isNotEmpty) ...[_section('AI Feedback'), _para(r.summary)],
      if (r.strengths.isNotEmpty) ...[_subTitle('Strengths', color: _green), ..._bullets(r.strengths, color: _green)],
      if (r.improvements.isNotEmpty) ...[
        _subTitle('Areas to improve', color: _amber),
        ..._bullets(r.improvements, color: _amber),
      ],
      if (r.tips.isNotEmpty) ...[_subTitle('Tips for next time'), ..._bullets(r.tips)],

      if (r.answers.isNotEmpty) ...[
        _section('Question-by-Question'),
        for (final a in r.answers) ..._answerBlock(a),
      ],
    ];
  }

  /// Camera cues (feedback only, not part of the scores).
  static List<pw.Widget> _bodyLanguage(MockInterviewSessionModel r) {
    final withCamera = r.answersWithCamera;
    if (withCamera == 0) return const [];
    final body = r.bodyLanguage;
    final lookAways = (body['totalLookAways'] as num?)?.round() ??
        r.answers.fold<int>(0, (sum, a) => sum + (a.lookAwayCount ?? 0));
    final feedback = body['feedback'] as String? ?? '';
    String percent(int? v) => v == null ? '-' : '$v%';

    return [
      _section('Body Language'),
      _table(
        headers: ['Eye contact', 'Smiling', 'Look-aways (1s+)', 'Answers on camera'],
        rows: [
          [percent(r.eyeContactPercent), percent(r.smilePercent), '$lookAways', '$withCamera of ${r.answers.length}'],
        ],
      ),
      if (feedback.isNotEmpty) _para(feedback),
      _para('Estimated on the phone (Google ML Kit) from head direction and expression while answering with '
          'the camera on. Video is not recorded or uploaded. Not part of the scores.', color: _muted, size: 8),
    ];
  }

  static List<pw.Widget> _answerBlock(MockInterviewAnswerModel a) {
    return [
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 6, bottom: 4),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(color: _surface, border: pw.Border.all(color: _border),
            borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(a.questionIndex == 0 ? 'Introduction' : 'Question ${a.questionIndex}',
                      style: pw.TextStyle(color: _navy, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text(PdfText.clean(a.questionText), style: pw.TextStyle(color: _text, fontSize: 9.5)),
                ],
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Text('Content ${a.contentScore ?? '-'}  ·  Delivery ${a.deliveryScore ?? '-'}',
                style: pw.TextStyle(color: _muted, fontSize: 8)),
          ],
        ),
      ),
      _para('${a.wordsPerMinute?.round() ?? 0} wpm${a.paceLabel.isEmpty ? '' : ' (${a.paceLabel})'}  ·  '
          '${a.fillerWordCount ?? 0} filler words  ·  ${a.hesitationCount ?? 0} hesitations'
          '${a.eyeContactPercent == null ? '' : '  ·  ${a.eyeContactPercent}% eye contact'}',
          color: _muted, size: 8),
      if (a.transcriptText.isNotEmpty) ...[
        _subTitle('Your answer'),
        _para(_cut(a.transcriptText, 1200), color: _muted, size: 9),
      ],
      if (a.relevance.isNotEmpty) _para('Relevance: ${a.relevance}'),
      if (a.strengths.isNotEmpty) ...[_subTitle('What went well', color: _green), ..._bullets(a.strengths, color: _green)],
      if (a.improvements.isNotEmpty) ...[
        _subTitle('What to improve', color: _amber),
        ..._bullets(a.improvements, color: _amber),
      ],
      if (a.deliveryFeedback.isNotEmpty) _para('Delivery: ${a.deliveryFeedback}'),
      if (a.bodyLanguageFeedback.isNotEmpty) _para('Body language: ${a.bodyLanguageFeedback}'),
      if (a.improvedAnswer.isNotEmpty) _callout('Stronger sample answer', _cut(a.improvedAnswer, 1200)),
    ];
  }

  // =====================================================================
  // Skill gap detail
  // =====================================================================

  static List<pw.Widget> _skillGapDetail(SkillGapAnalysisModel a) {
    final m = a.marketInsights;
    final basedOn = [
      if (a.resumeAnalysed) 'resume',
      'profile',
      a.jobSampleSize > 0 ? '${a.jobSampleSize} job postings' : 'AI market knowledge',
    ].join(', ');

    final skills = [...a.missing, ...a.partial, ...a.matching];

    return [
      _statRow([
        ('Skill match', '${a.matchScore}%', _scoreColor(a.matchScore)),
        ('Matching', '${a.matching.length}', _green),
        ('Partial', '${a.partial.length}', _amber),
        ('Missing', '${a.missing.length}', _red),
      ]),
      pw.SizedBox(height: 4),
      _para('Based on: $basedOn. Match = importance-weighted share of required skills '
          '(partial skills count half).', color: _muted, size: 8),

      if (a.summary.isNotEmpty) ...[_section('Summary'), _para(a.summary)],

      _section('Market Demand'),
      _para([
        if (m.demandLevel.isNotEmpty) 'Demand: ${m.demandLevel}',
        if (m.typicalSalary.isNotEmpty) 'Typical salary: ${m.typicalSalary}',
      ].join('   ·   ')),
      if (m.summary.isNotEmpty) _para(m.summary, color: _muted),
      if (m.commonRequirements.isNotEmpty) ...[
        _subTitle('Employers commonly ask for'),
        ..._bullets(m.commonRequirements),
      ],

      if (skills.isNotEmpty) ...[
        _section('Skills Breakdown'),
        _table(
          headers: ['Skill', 'Importance', 'Status', 'Notes'],
          widths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FixedColumnWidth(58),
            2: const pw.FixedColumnWidth(52),
            3: const pw.FlexColumnWidth(4),
          },
          rows: skills
              .map((s) => [
                    s.skill,
                    _cap(s.importance),
                    _cap(s.status),
                    s.status == 'matched' ? s.evidence : s.gap,
                  ])
              .toList(),
        ),
      ],

      if (a.actionPaths.isNotEmpty) ...[
        _section('Recommended Action Paths'),
        for (var i = 0; i < a.actionPaths.length; i++) ..._actionPath(i + 1, a.actionPaths[i]),
      ],

      if (a.resumeTips.isNotEmpty) ...[_section('Resume Tips'), ..._bullets(a.resumeTips)],

      if (a.userSkills.isNotEmpty) ...[
        _section('Your Detected Skills'),
        _para(a.userSkills.map((s) => s.skill).join(', '), color: _muted),
      ],
    ];
  }

  static List<pw.Widget> _actionPath(int number, ActionPath p) {
    return [
      pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 6, bottom: 4),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(color: _surface, border: pw.Border.all(color: _border),
            borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('$number. ${PdfText.clean(p.title)}',
                style: pw.TextStyle(color: _navy, fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(
              [
                '${_cap(p.priority)} priority',
                if (p.type.isNotEmpty) _cap(p.type),
                if (p.timeframe.isNotEmpty) p.timeframe,
              ].join('  ·  '),
              style: pw.TextStyle(color: _muted, fontSize: 8),
            ),
          ],
        ),
      ),
      if (p.skillsAddressed.isNotEmpty) _para('Builds: ${p.skillsAddressed.join(', ')}', size: 9),
      for (var i = 0; i < p.steps.length; i++)
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 6, bottom: 3),
          child: pw.Text('${i + 1}. ${PdfText.clean(p.steps[i])}',
              style: pw.TextStyle(color: _text, fontSize: 9, lineSpacing: 2)),
        ),
      if (p.suggestedResources.isNotEmpty)
        _para('Suggested resources: ${p.suggestedResources.join('; ')}', color: _muted, size: 8.5),
    ];
  }
}
