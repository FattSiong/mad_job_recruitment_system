import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum CareerToolMockupType {
  aiCareerAdvisor,
  mockInterview,
  skillGapAnalysis,
  guidanceReports,
}

class CareerToolsMockupScreen extends StatelessWidget {
  final CareerToolMockupType type;

  const CareerToolsMockupScreen({
    super.key,
    required this.type,
  });

  static const Color _primary = AppColors.primary;
  static const Color _background = AppColors.background;
  static const Color _textPrimary = AppColors.textDark;
  static const Color _textMuted = AppColors.textMuted;
  static const Color _surfaceAlt = AppColors.surfaceAlt;
  static const Color _border = AppColors.border;

  String get _title {
    switch (type) {
      case CareerToolMockupType.aiCareerAdvisor:
        return 'AI Career Advisor';
      case CareerToolMockupType.mockInterview:
        return 'Mock Interview';
      case CareerToolMockupType.skillGapAnalysis:
        return 'Skill Gap Analysis';
      case CareerToolMockupType.guidanceReports:
        return 'Guidance Reports';
    }
  }

  String get _subtitle {
    switch (type) {
      case CareerToolMockupType.aiCareerAdvisor:
        return 'Ask career questions and receive AI guidance.';
      case CareerToolMockupType.mockInterview:
        return 'Practice interview questions before applying.';
      case CareerToolMockupType.skillGapAnalysis:
        return 'Compare your skills with job requirements.';
      case CareerToolMockupType.guidanceReports:
        return 'Review saved career guidance and progress reports.';
    }
  }

  IconData get _icon {
    switch (type) {
      case CareerToolMockupType.aiCareerAdvisor:
        return Icons.smart_toy_outlined;
      case CareerToolMockupType.mockInterview:
        return Icons.record_voice_over_outlined;
      case CareerToolMockupType.skillGapAnalysis:
        return Icons.insights_outlined;
      case CareerToolMockupType.guidanceReports:
        return Icons.assignment_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildMainMockup(context),
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
          Icon(_icon, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainMockup(BuildContext context) {
    switch (type) {
      case CareerToolMockupType.aiCareerAdvisor:
        return _buildAdvisorMockup();
      case CareerToolMockupType.mockInterview:
        return _buildInterviewMockup();
      case CareerToolMockupType.skillGapAnalysis:
        return _buildSkillGapMockup();
      case CareerToolMockupType.guidanceReports:
        return _buildReportsMockup(context);
    }
  }

  Widget _buildAdvisorMockup() {
    return _surfaceCard(
      children: [
        _sectionTitle('Career Chat'),
        _messageBubble('User', 'What career path suits my Flutter skills?', true),
        _messageBubble(
          'AI Advisor',
          'Based on your profile, mobile app developer and junior Flutter developer roles are a strong match.',
          false,
        ),
        const SizedBox(height: 16),
        _mockInput('Ask your career question...', Icons.send_rounded),
      ],
    );
  }

  Widget _buildInterviewMockup() {
    return _surfaceCard(
      children: [
        _sectionTitle('Interview Practice'),
        _infoTile(Icons.work_outline, 'Target Role', 'Junior Software Developer'),
        _infoTile(Icons.help_outline, 'Question 1', 'Tell me about yourself.'),
        _infoTile(Icons.mic_none_rounded, 'Your Answer', 'Tap record to practise your response.'),
        const SizedBox(height: 16),
        _primaryMockButton('Start Mock Interview', Icons.play_arrow_rounded),
      ],
    );
  }

  Widget _buildSkillGapMockup() {
    return _surfaceCard(
      children: [
        _sectionTitle('Skill Gap Result'),
        _progressTile('Flutter', 0.85),
        _progressTile('Firebase / Supabase', 0.70),
        _progressTile('UI/UX Design', 0.55),
        _progressTile('API Integration', 0.62),
        const SizedBox(height: 16),
        _infoTile(
          Icons.tips_and_updates_outlined,
          'Suggestion',
          'Improve API integration and UI/UX design to match more job requirements.',
        ),
      ],
    );
  }

  Widget _buildReportsMockup(BuildContext context) {
    return _surfaceCard(
      children: [
        _sectionTitle('Guidance Report Summary'),
        _infoTile(
          Icons.calendar_month_outlined,
          'Latest Report',
          'Post-interview AI analysis report',
        ),
        _infoTile(
          Icons.trending_up_rounded,
          'Overall Result',
          'Candidate performance score: 82%',
        ),
        _infoTile(
          Icons.school_outlined,
          'Recommended Action',
          'Improve answer structure and technical explanation.',
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GuidanceReportDetailScreen(),
                ),
              );
            },
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('View Full Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: _textPrimary,
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: _textMuted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(String sender, String message, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? _primary : _surfaceAlt,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          '$sender: $message',
          style: TextStyle(
            color: isUser ? Colors.white : _textPrimary,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _progressTile(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: value,
            minHeight: 9,
            backgroundColor: _surfaceAlt,
            color: _primary,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }

  Widget _mockInput(String hint, IconData icon) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: Icon(icon, color: _primary),
        filled: true,
        fillColor: _surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _primaryMockButton(String label, IconData icon) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class GuidanceReportDetailScreen extends StatefulWidget {
  const GuidanceReportDetailScreen({super.key});

  @override
  State<GuidanceReportDetailScreen> createState() =>
      _GuidanceReportDetailScreenState();
}

class _GuidanceReportDetailScreenState
    extends State<GuidanceReportDetailScreen> {
  bool _isExporting = false;

  static const Color _primary = AppColors.primary;
  static const Color _background = AppColors.background;
  static const Color _textPrimary = AppColors.textDark;
  static const Color _textMuted = AppColors.textMuted;
  static const Color _surfaceAlt = AppColors.surfaceAlt;
  static const Color _border = AppColors.border;

  // Change these mock report values here so the screen preview and exported PDF stay the same.
  static const String _reportTitle = 'Post-Interview AI Analysis Report';
  static const String _reportId = 'RPT-2026-001';
  static const String _generatedDate = '01 Aug 2026';
  static const String _jobTitle = 'Job Title:';
  static const String _interviewDate = 'Interview Date:';
  static const String _interviewDuration = 'Duration:';
  static const String _candidateName = 'Candidate Name:';
  static const String _candidateContact = 'Email / Contact:';
  static const String _appliedPosition = 'Applied Position:';
  static const String _interviewSummary = '';
  static const String _communicationScore = '%';
  static const String _technicalScore = '%';
  static const String _problemSolvingScore = '%';
  static const String _confidenceScore = '%';
  static const String _aiSuggestions = '';

  Future<void> _exportReportPdf() async {
    setState(() => _isExporting = true);

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 120,
                    height: 70,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blueGrey200),
                    ),
                    child: pw.Text(
                      'Company Logo',
                      style: const pw.TextStyle(
                        color: PdfColors.blueGrey500,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 30),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          _reportTitle,
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('#163B65'),
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'Report ID: $_reportId - Generated: $_generatedDate',
                          style: const pw.TextStyle(
                            color: PdfColors.blueGrey500,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Divider(color: PdfColor.fromHex('#163B65')),
              _pdfSectionTitle('1. Interview Information'),
              _pdfBox(_jobTitle),
              pw.Row(
                children: [
                  pw.Expanded(child: _pdfBox(_interviewDate)),
                  pw.SizedBox(width: 12),
                  pw.Expanded(child: _pdfBox(_interviewDuration)),
                ],
              ),
              _pdfSectionTitle('2. Candidate Profile'),
              pw.Row(
                children: [
                  pw.Container(
                    width: 90,
                    height: 90,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blueGrey200),
                    ),
                    child: pw.Text(
                      'Candidate\nPhoto',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        color: PdfColors.blueGrey500,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        _pdfBox(_candidateName),
                        _pdfBox(_candidateContact),
                        _pdfBox(_appliedPosition),
                      ],
                    ),
                  ),
                ],
              ),
              _pdfSectionTitle('3. AI Interview Summary'),
              _pdfLargeBox(
                _interviewSummary,
              ),
              _pdfSectionTitle('4. Performance Details'),
              _pdfBox('Communication Score: $_communicationScore'),
              _pdfBox('Technical Knowledge Score: $_technicalScore'),
              _pdfBox('Problem Solving Score: $_problemSolvingScore'),
              _pdfBox('Confidence Score: $_confidenceScore'),
              _pdfSectionTitle('5. AI Suggestions'),
              _pdfLargeBox(
                _aiSuggestions,
              ),
            ],
          );
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/post_interview_ai_report_$timestamp.pdf');
    await file.writeAsBytes(await pdf.save());

    if (!mounted) return;

    setState(() => _isExporting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report exported as PDF.')),
    );

    await OpenFilex.open(file.path);
  }

  static pw.Widget _pdfSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 18, bottom: 10),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: PdfColor.fromHex('#163B65'),
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _pdfBox(String text) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey200),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          color: PdfColors.blueGrey700,
          fontSize: 10,
        ),
      ),
    );
  }

  static pw.Widget _pdfLargeBox(String text) {
    return pw.Container(
      width: double.infinity,
      height: 95,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey200),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          color: PdfColors.blueGrey700,
          fontSize: 10,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildReportPreview(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isExporting ? null : _exportReportPdf,
          icon: _isExporting
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(_isExporting ? 'Exporting...' : 'Export Report as PDF'),
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
    );
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guidance Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Post-interview AI analysis report.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _outlineBox(
                width: 100,
                height: 72,
                child: const Center(child: Text('Company\nLogo', textAlign: TextAlign.center)),
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _reportTitle,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: _primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Report ID: $_reportId\nGenerated: $_generatedDate',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Divider(color: _primary),
          _reportSectionTitle('1. Interview Information'),
          _outlineBoxText(_jobTitle),
          Row(
            children: [
              Expanded(child: _outlineBoxText(_interviewDate)),
              const SizedBox(width: 12),
              Expanded(child: _outlineBoxText(_interviewDuration)),
            ],
          ),
          _reportSectionTitle('2. Candidate Profile'),
          Row(
            children: [
              _outlineBox(
                width: 92,
                height: 108,
                child: const Center(child: Text('Candidate\nPhoto', textAlign: TextAlign.center)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _outlineBoxText(_candidateName),
                    _outlineBoxText(_candidateContact),
                    _outlineBoxText(_appliedPosition),
                  ],
                ),
              ),
            ],
          ),
          _reportSectionTitle('3. AI Interview Summary'),
          _outlineBoxText(
            _interviewSummary,
            height: 120,
          ),
          _reportSectionTitle('4. Performance Details'),
          _detailRow('Communication', _communicationScore),
          _detailRow('Technical Knowledge', _technicalScore),
          _detailRow('Problem Solving', _problemSolvingScore),
          _detailRow('Confidence', _confidenceScore),
          _reportSectionTitle('5. AI Suggestions'),
          _outlineBoxText(
            _aiSuggestions,
            height: 110,
          ),
        ],
      ),
    );
  }

  Widget _reportSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: _primary,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _outlineBox({
    required double width,
    required double height,
    required Widget child,
  }) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _surfaceAlt,
        border: Border.all(color: const Color(0xFFC7D4E5)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: _textMuted, fontSize: 12),
        child: child,
      ),
    );
  }

  Widget _outlineBoxText(String text, {double? height}) {
    return Container(
      width: double.infinity,
      height: height,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      alignment: height == null ? Alignment.center : Alignment.topLeft,
      decoration: BoxDecoration(
        color: _surfaceAlt,
        border: Border.all(color: const Color(0xFFC7D4E5)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: _textMuted, height: 1.35),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
