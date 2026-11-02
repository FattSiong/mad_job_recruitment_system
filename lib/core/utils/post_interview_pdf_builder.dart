import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/post_interview_report_model.dart';
import 'storage_url_helper.dart';

/// Builds a multi-page A4 Post-Interview AI Analysis Report PDF for employers,
/// combining the official employer report layout with the AI scorecard & Q&A breakdown.
class PostInterviewPdfBuilder {
  PostInterviewPdfBuilder._();

  static const PdfColor _navy = PdfColor.fromInt(0xFF163B65);
  static const PdfColor _navySoft = PdfColor.fromInt(0xFFDCEBFB);
  static const PdfColor _text = PdfColor.fromInt(0xFF1B2433);
  static const PdfColor _muted = PdfColor.fromInt(0xFF687588);
  static const PdfColor _surface = PdfColor.fromInt(0xFFF7F9FC);
  static const PdfColor _border = PdfColor.fromInt(0xFFD9E2EC);
  static const PdfColor _green = PdfColor.fromInt(0xFF2D8A5D);
  static const PdfColor _amber = PdfColor.fromInt(0xFFC28A22);
  static const PdfColor _red = PdfColor.fromInt(0xFFC24E4E);

  static final DateFormat _dateFmt = DateFormat('d MMM yyyy');
  static final DateFormat _dateTimeFmt = DateFormat('d MMM yyyy, h:mm a');

  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> _loadTheme() async {
    if (_theme != null) return _theme!;
    final regular = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Poppins-Bold.ttf');
    _theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    );
    return _theme!;
  }

  static String _clean(String? s) {
    if (s == null) return '';
    return s
        .replaceAll('→', '->')
        .replaceAll('✓', '-')
        .replaceAll('✔', '-')
        .replaceAll('·', '-')
        .replaceAll(
          RegExp(r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true),
          '',
        )
        .trim();
  }

  static PdfColor _scoreColor(int score) {
    if (score >= 75) return _green;
    if (score >= 50) return _amber;
    return _red;
  }

  static PdfColor _recommendationColor(String rec) {
    switch (rec.toLowerCase()) {
      case 'strong hire':
      case 'recommended':
        return _green;
      case 'consider':
        return _amber;
      case 'not recommended':
        return _red;
      default:
        return _navy;
    }
  }

  static Future<pw.MemoryImage?> _tryLoadNetworkImage(String? rawUrl) async {
    final trimmed = (rawUrl ?? '').trim();
    if (trimmed.isEmpty || !trimmed.startsWith('http')) return null;
    try {
      final resolved = await StorageUrlHelper.resolve(trimmed);
      final resp = await http
          .get(Uri.parse(resolved))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final contentType = (resp.headers['content-type'] ?? '').toLowerCase();
        // pdf package natively decodes PNG and JPEG bytes
        if (contentType.contains('png') ||
            contentType.contains('jpeg') ||
            contentType.contains('jpg') ||
            resolved.toLowerCase().contains('.png') ||
            resolved.toLowerCase().contains('.jpg') ||
            resolved.toLowerCase().contains('.jpeg')) {
          return pw.MemoryImage(resp.bodyBytes);
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<Uint8List> build(PostInterviewReportModel report) async {
    final theme = await _loadTheme();
    final results = await Future.wait<pw.MemoryImage?>([
      _tryLoadNetworkImage(report.companyLogoUrl),
      _tryLoadNetworkImage(report.candidatePhotoUrl),
    ]);
    final companyLogo = results[0];
    final candidatePhoto = results[1];

    final doc = pw.Document(
      theme: theme,
      title: 'Post-Interview AI Analysis Report',
      author: _clean(report.companyName),
    );

    final interviewDateText = report.interviewDate != null
        ? _dateFmt.format(report.interviewDate!)
        : _dateFmt.format(report.createdAt);

    final contactParts = [
      if (report.candidateEmail.isNotEmpty) _clean(report.candidateEmail),
      if (report.candidatePhone.isNotEmpty) _clean(report.candidatePhone),
    ];
    final contactText =
        contactParts.isEmpty ? 'Not provided' : contactParts.join('  |  ');

    doc.addPage(
      pw.MultiPage(
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
                  'Post-Interview AI Analysis Report  -  ${_clean(report.companyName)}  -  AI decision-support summary',
                  maxLines: 1,
                  style: pw.TextStyle(color: _muted, fontSize: 7.5),
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(color: _muted, fontSize: 7.5),
              ),
            ],
          ),
        ),
        build: (context) => [
          // Official Top Header (Company Logo + Report Title & ID)
          _buildReportHeader(report, companyLogo),
          pw.SizedBox(height: 12),
          pw.Divider(color: _navy, thickness: 1.4),
          pw.SizedBox(height: 8),

          // 1. Interview Information
          _sectionTitle('1. Interview Information'),
          _infoField('Job Title', _clean(report.jobTitle)),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(
                child: _infoField('Interview Date', interviewDateText),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _infoField('Interview Duration', report.formattedDuration),
              ),
              if (report.resumeAiMatchScore != null) ...[
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _infoField(
                    'Resume AI Match',
                    '${report.resumeAiMatchScore}%',
                  ),
                ),
              ],
            ],
          ),

          // 2. Candidate Profile
          _sectionTitle('2. Candidate Profile'),
          _buildCandidateProfileBox(report, candidatePhoto, contactText),

          // 3. AI Interview Scorecard & Summary
          _sectionTitle('3. AI Interview Scorecard & Summary'),
          _statRow([
            (
              'Overall Score',
              '${report.overallScore} / 100',
              _scoreColor(report.overallScore),
            ),
            (
              'Role & Tech Fit (60%)',
              '${report.contentScore} / 100',
              _scoreColor(report.contentScore),
            ),
            (
              'Delivery (40%)',
              '${report.deliveryScore} / 100',
              _scoreColor(report.deliveryScore),
            ),
            (
              'Recommendation',
              _clean(report.recommendation),
              _recommendationColor(report.recommendation),
            ),
          ]),
          if (report.summary.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _surface,
                border: pw.Border.all(color: _border),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                _clean(report.summary),
                style: pw.TextStyle(color: _text, fontSize: 9.5, lineSpacing: 2.2),
              ),
            ),
          ],

          // 4. Communication & Speaking Delivery
          _sectionTitle('4. Communication & Speaking Delivery'),
          _statRow([
            (
              'Speaking Pace',
              report.estimatedWpm > 0
                  ? '~${report.estimatedWpm} WPM (${_clean(report.paceLabel)})'
                  : _clean(report.paceLabel),
              _navy,
            ),
            ('Fluency & Fillers', _clean(report.fillerAssessment), _navy),
          ]),
          pw.SizedBox(height: 6),
          _statRow([
            ('Answer Structure', _clean(report.clarityAssessment), _navy),
            ('Confidence & Tone', _clean(report.confidenceAssessment), _navy),
          ]),
          if (report.deliveryNotes.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              _clean(report.deliveryNotes),
              style: pw.TextStyle(color: _muted, fontSize: 9, lineSpacing: 2),
            ),
          ],

          // 5. Structured Employer Insights
          _sectionTitle('5. Key Insights & Recommendations'),
          if (report.strengths.isNotEmpty) ...[
            _subTitle('Strengths Demonstrated', color: _green),
            ..._bullets(report.strengths, color: _green),
          ],
          if (report.concerns.isNotEmpty) ...[
            _subTitle('Concerns / Areas to Probe', color: _amber),
            ..._bullets(report.concerns, color: _amber),
          ],
          if (report.followUpQuestions.isNotEmpty) ...[
            _subTitle('Suggested Follow-Up Questions', color: _navy),
            ..._bullets(report.followUpQuestions, color: _navy),
          ],

          // 6. Question-by-Question Discussion Breakdown
          if (report.qaBreakdown.isNotEmpty) ...[
            _sectionTitle('6. Question-by-Question Breakdown'),
            ...report.qaBreakdown.map(_buildQaBox),
          ],
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildReportHeader(
    PostInterviewReportModel report,
    pw.MemoryImage? companyLogo,
  ) {
    final companyInitial = report.companyName.trim().isNotEmpty
        ? _clean(report.companyName)[0].toUpperCase()
        : 'C';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 56,
          height: 56,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: _navySoft,
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: _border),
          ),
          child: companyLogo != null
              ? pw.ClipRRect(
                  horizontalRadius: 9,
                  verticalRadius: 9,
                  child: pw.Image(companyLogo, fit: pw.BoxFit.cover),
                )
              : pw.Text(
                  companyInitial,
                  style: pw.TextStyle(
                    color: _navy,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _clean(report.companyName),
                style: pw.TextStyle(
                  color: _navy,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Employer Recruitment Analytics',
                style: pw.TextStyle(color: _muted, fontSize: 8.5),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Post-Interview AI Analysis Report',
              style: pw.TextStyle(
                color: _navy,
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${report.shortReportCode}  -  Generated ${_dateTimeFmt.format(report.updatedAt.toLocal())}',
              style: pw.TextStyle(color: _muted, fontSize: 8.5),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildCandidateProfileBox(
    PostInterviewReportModel report,
    pw.MemoryImage? candidatePhoto,
    String contactText,
  ) {
    final initial = report.candidateName.trim().isNotEmpty
        ? _clean(report.candidateName)[0].toUpperCase()
        : 'A';

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _surface,
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 64,
            height: 64,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _navy,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: candidatePhoto != null
                ? pw.ClipRRect(
                    horizontalRadius: 10,
                    verticalRadius: 10,
                    child: pw.Image(candidatePhoto, fit: pw.BoxFit.cover),
                  )
                : pw.Text(
                    initial,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _clean(report.candidateName),
                  style: pw.TextStyle(
                    color: _text,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Contact: $contactText',
                  style: pw.TextStyle(color: _muted, fontSize: 9),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Applied Position: ${_clean(report.jobTitle)}',
                  style: pw.TextStyle(
                    color: _navy,
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 8),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            color: _navy,
            fontSize: 12.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );

  static pw.Widget _subTitle(String text, {PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            color: color ?? _text,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );

  static pw.Widget _infoField(String label, String value) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _surface,
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(color: _muted, fontSize: 7.5)),
          pw.SizedBox(height: 2),
          pw.Text(
            value.isEmpty ? '-' : value,
            style: pw.TextStyle(
              color: _text,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _statRow(
    List<(String label, String value, PdfColor color)> stats,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 9,
                horizontal: 9,
              ),
              decoration: pw.BoxDecoration(
                color: _surface,
                border: pw.Border.all(color: _border),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    stats[i].$1,
                    style: pw.TextStyle(color: _muted, fontSize: 7.5),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    stats[i].$2,
                    style: pw.TextStyle(
                      color: stats[i].$3,
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static List<pw.Widget> _bullets(List<String> items, {PdfColor? color}) =>
      items
          .where((s) => s.trim().isNotEmpty)
          .map(
            (s) => pw.Bullet(
              text: _clean(s),
              style: pw.TextStyle(color: _text, fontSize: 9.2, lineSpacing: 2),
              bulletColor: color ?? _navy,
              bulletSize: 3.5,
              margin: const pw.EdgeInsets.only(bottom: 3, left: 4),
            ),
          )
          .toList();

  static pw.Widget _buildQaBox(InterviewQaExchange qa) {
    final scoreColor = _scoreColor(qa.score);
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _surface,
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Q${qa.questionIndex}: ${_clean(qa.questionAsked)}',
                  style: pw.TextStyle(
                    color: _navy,
                    fontSize: 9.8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                '${qa.score}/100',
                style: pw.TextStyle(
                  color: scoreColor,
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          if (qa.candidateResponseSummary.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Candidate Response: ${_clean(qa.candidateResponseSummary)}',
              style: pw.TextStyle(color: _text, fontSize: 9, lineSpacing: 1.8),
            ),
          ],
          if (qa.evaluationNote.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              'AI Assessment: ${_clean(qa.evaluationNote)}',
              style: pw.TextStyle(color: _muted, fontSize: 8.8, lineSpacing: 1.8),
            ),
          ],
        ],
      ),
    );
  }
}
