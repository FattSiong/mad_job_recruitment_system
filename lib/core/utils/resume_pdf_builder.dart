import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/education_model.dart';
import '../../models/resume_model.dart';
import '../../models/work_experience_model.dart';

/// One clean, ATS-friendly A4 resume (single column, real text, no tables).
class ResumePdfBuilder {
  ResumePdfBuilder._();

  static final PdfColor _navy = PdfColor.fromInt(0xFF163B65);
  static final PdfColor _text = PdfColor.fromInt(0xFF1B2433);
  static final PdfColor _muted = PdfColor.fromInt(0xFF5B6678);
  static final PdfColor _rule = PdfColor.fromInt(0xFFD6DEE8);

  static final DateFormat _month = DateFormat('MMM yyyy');

  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> _loadTheme() async {
    if (_theme != null) return _theme!;
    final regular = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Poppins-Bold.ttf');
    _theme = pw.ThemeData.withFont(base: pw.Font.ttf(regular), bold: pw.Font.ttf(bold));
    return _theme!;
  }

  /// Removes characters the font can't draw (emoji, symbols).
  static String _clean(String? s) {
    if (s == null) return '';
    return s
        .replaceAll('→', '->')
        .replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true), '')
        .trim();
  }

  static String _period(DateTime start, DateTime? end, bool isCurrent) {
    final from = _month.format(start);
    final to = isCurrent ? 'Present' : (end != null ? _month.format(end) : '');
    return to.isEmpty ? from : '$from - $to';
  }

  // =====================================================================

  static Future<Uint8List> build(ResumeModel r) async {
    final theme = await _loadTheme();
    final doc = pw.Document(
      theme: theme,
      title: '${_clean(r.fullName)} - Resume',
      author: _clean(r.fullName),
    );

    final summary = r.sections.where((s) => s.type == ResumeSectionType.summary && !s.isEmpty);
    final extras = r.sections.where((s) => s.type != ResumeSectionType.summary && !s.isEmpty);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 40, 42, 36),
        footer: (context) => context.pagesCount > 1
            ? pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: _muted),
                ),
              )
            : pw.SizedBox(),
        build: (context) => [
          _header(r),
          for (final s in summary) ..._textSection(s.type.label, s.text),
          if (r.education.isNotEmpty) ..._educationSection(r.education),
          if (r.experience.isNotEmpty) ..._experienceSection(r.experience),
          if (r.skills.isNotEmpty) ..._skillsSection(r.skills),
          for (final s in extras)
            ...(s.type.isTextOnly ? _textSection(s.type.label, s.text) : _itemSection(s)),
        ],
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------------
  // Parts
  // ---------------------------------------------------------------------

  static pw.Widget _header(ResumeModel r) {
    final contact = [r.phone, r.email, r.address]
        .map(_clean)
        .where((s) => s.isNotEmpty)
        .join('   |   ');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          _clean(r.fullName).toUpperCase(),
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: _navy,
            letterSpacing: 1.2,
          ),
        ),
        if (contact.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(contact, style: pw.TextStyle(fontSize: 9.5, color: _muted)),
        ],
        pw.SizedBox(height: 10),
        pw.Container(height: 2, color: _navy),
      ],
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Container(height: 0.8, color: _rule),
        ],
      ),
    );
  }

  /// Title + right-aligned date, then subtitle, then description.
  /// Returned as separate widgets so a long entry can continue on the next page.
  static List<pw.Widget> _entry({
    required String title,
    String? subtitle,
    String? period,
    String? description,
  }) {
    final desc = _clean(description);
    return [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(
              _clean(title),
              style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _text),
            ),
          ),
          if (period != null && period.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 8),
              child: pw.Text(_clean(period), style: pw.TextStyle(fontSize: 9, color: _muted)),
            ),
        ],
      ),
      if (subtitle != null && subtitle.trim().isNotEmpty)
        pw.Text(_clean(subtitle), style: pw.TextStyle(fontSize: 9.5, color: _muted)),
      if (desc.isNotEmpty) ...[
        pw.SizedBox(height: 3),
        ..._description(desc),
      ],
      pw.SizedBox(height: 8),
    ];
  }

  /// Lines starting with "-", "*" or "•" become bullet points.
  static List<pw.Widget> _description(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
    return lines.map((line) {
      final isBullet = RegExp(r'^[-*•]\s*').hasMatch(line);
      final content = line.replaceFirst(RegExp(r'^[-*•]\s*'), '');
      if (!isBullet) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(content, style: pw.TextStyle(fontSize: 9.5, color: _text, lineSpacing: 1.5)),
        );
      }
      return pw.Padding(
        padding: const pw.EdgeInsets.only(left: 6, bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('-  ', style: pw.TextStyle(fontSize: 9.5, color: _navy)),
            pw.Expanded(
              child: pw.Text(content, style: pw.TextStyle(fontSize: 9.5, color: _text, lineSpacing: 1.5)),
            ),
          ],
        ),
      );
    }).toList();
  }

  static List<pw.Widget> _textSection(String title, String text) => [
        _sectionTitle(title),
        ..._description(_clean(text)),
      ];

  static List<pw.Widget> _educationSection(List<EducationModel> list) => [
        _sectionTitle('Education'),
        for (final e in list)
          ..._entry(
              title: (e.fieldOfStudy != null && e.fieldOfStudy!.trim().isNotEmpty)
                  ? '${e.degree} in ${e.fieldOfStudy}'
                  : e.degree,
              subtitle: e.institutionName,
              period: _period(e.startDate, e.endDate, e.isCurrent),
              description: e.description,
            ),
      ];

  static List<pw.Widget> _experienceSection(List<WorkExperienceModel> list) => [
        _sectionTitle('Work Experience'),
        for (final e in list)
          ..._entry(
            title: e.jobTitle,
            subtitle: e.companyName,
            period: _period(e.startDate, e.endDate, e.isCurrent),
            description: e.description,
          ),
      ];

  static List<pw.Widget> _skillsSection(List<ResumeSkill> skills) => [
        _sectionTitle('Skills'),
        pw.Text(
          skills
              .map((s) => s.level == null ? _clean(s.name) : '${_clean(s.name)} (${s.level})')
              .join('   |   '),
          style: pw.TextStyle(fontSize: 9.5, color: _text, lineSpacing: 2),
        ),
      ];

  static List<pw.Widget> _itemSection(ResumeSection s) {
    if (s.type == ResumeSectionType.languages) {
      return [
        _sectionTitle(s.type.label),
        pw.Text(
          s.items
              .map((i) => (i.subtitle == null || i.subtitle!.isEmpty)
                  ? _clean(i.title)
                  : '${_clean(i.title)} (${_clean(i.subtitle)})')
              .join('   |   '),
          style: pw.TextStyle(fontSize: 9.5, color: _text, lineSpacing: 2),
        ),
      ];
    }
    return [
      _sectionTitle(s.type.label),
      for (final i in s.items)
        ..._entry(
          title: i.title,
          subtitle: i.subtitle,
          period: i.period,
          description: i.description,
        ),
    ];
  }
}
