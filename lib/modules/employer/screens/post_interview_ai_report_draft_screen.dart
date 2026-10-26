import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// PDF-style layout draft for FYP documentation only.
/// The report intentionally contains labelled placeholders, not live AI data.
class PostInterviewAiReportDraftScreen extends StatefulWidget {
  const PostInterviewAiReportDraftScreen({super.key});

  @override
  State<PostInterviewAiReportDraftScreen> createState() =>
      _PostInterviewAiReportDraftScreenState();
}

class _PostInterviewAiReportDraftScreenState
    extends State<PostInterviewAiReportDraftScreen> {
  bool _isOpeningPdf = false;

  Future<void> _openPdf() async {
    setState(() => _isOpeningPdf = true);

    try {
      final bytes = await _buildPdf();
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/post_interview_ai_report_draft.pdf');
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the PDF on this device.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to create the PDF draft.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningPdf = false);
    }
  }

  Future<Uint8List> _buildPdf() async {
    final document = PdfDocument();
    final page = document.pages.add();
    final graphics = page.graphics;
    const pageWidth = 500.0;
    const margin = 42.0;
    final contentWidth = pageWidth - (margin * 2);

    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 17,
        style: PdfFontStyle.bold);
    final sectionFont = PdfStandardFont(PdfFontFamily.helvetica, 12,
        style: PdfFontStyle.bold);
    final labelFont = PdfStandardFont(PdfFontFamily.helvetica, 9,
        style: PdfFontStyle.regular);
    final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);
    final navy = PdfColor(22, 59, 101);
    final muted = PdfColor(104, 117, 136);
    final boxFill = PdfColor(247, 249, 252);
    final boxBorder = PdfColor(185, 198, 213);
    double y = margin;

    void drawLabel(String label, double x, double top, double width, double height) {
      graphics.drawRectangle(
        bounds: Rect.fromLTWH(x, top, width, height),
        brush: PdfSolidBrush(boxFill),
        pen: PdfPen(boxBorder),
      );
      graphics.drawString(
        label,
        labelFont,
        brush: PdfSolidBrush(muted),
        bounds: Rect.fromLTWH(x + 8, top + (height / 2) - 7, width - 16, 16),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
    }

    void drawSection(String title) {
      graphics.drawString(title, sectionFont, brush: PdfSolidBrush(navy), bounds: Rect.fromLTWH(margin, y, contentWidth, 18));
      y += 26;
    }

    drawLabel('Company Logo', margin, y, 110, 64);
    graphics.drawString(
      'Post-Interview AI Analysis Report',
      titleFont,
      brush: PdfSolidBrush(navy),
      bounds: Rect.fromLTWH(margin + 130, y + 9, contentWidth - 130, 24),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    graphics.drawString(
      'Report ID - Generated Date',
      labelFont,
      brush: PdfSolidBrush(muted),
      bounds: Rect.fromLTWH(margin + 130, y + 38, contentWidth - 130, 16),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    y += 86;
    graphics.drawLine(PdfPen(navy, width: 1), Offset(margin, y), Offset(margin + contentWidth, y));
    y += 20;

    drawSection('1. Interview Information');
    drawLabel('Job Title', margin, y, contentWidth, 34);
    y += 44;
    drawLabel('Interview Date', margin, y, (contentWidth - 10) / 2, 34);
    drawLabel('Interview Duration', margin + ((contentWidth + 10) / 2), y, (contentWidth - 10) / 2, 34);
    y += 58;

    drawSection('2. Candidate Profile');
    drawLabel('Candidate Photo', margin, y, 84, 84);
    final candidateX = margin + 96;
    final candidateWidth = contentWidth - 96;
    drawLabel('Candidate Name', candidateX, y, candidateWidth, 24);
    drawLabel('Candidate Email / Contact', candidateX, y + 30, candidateWidth, 24);
    drawLabel('Applied Position', candidateX, y + 60, candidateWidth, 24);
    y += 108;

    drawSection('3. AI Interview Summary');
    drawLabel('Generated Interview Summary', margin, y, contentWidth, 136);
    y += 154;

    graphics.drawLine(PdfPen(PdfColor(217, 225, 234)), Offset(margin, y), Offset(margin + contentWidth, y));
    graphics.drawString(
      'Post-Interview AI Analysis Report Draft',
      smallFont,
      brush: PdfSolidBrush(muted),
      bounds: Rect.fromLTWH(margin, y + 12, contentWidth, 12),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6EAF0),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                'PDF report layout draft - placeholder labels only',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF687588)),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: _buildReportPage(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          Material(
            color: const Color(0xFFF1F5FA),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.arrow_back_rounded, color: Color(0xFF163B65)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'AI Interview Report Draft',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1B2433)),
            ),
          ),
          FilledButton.icon(
            onPressed: _isOpeningPdf ? null : _openPdf,
            icon: _isOpeningPdf
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(_isOpeningPdf ? 'Opening' : 'Open PDF'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF163B65),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportPage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _placeholder('Company Logo', height: 76)),
              const SizedBox(width: 18),
              const Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _ReportLabel('Post-Interview AI Analysis Report', isTitle: true),
                    SizedBox(height: 8),
                    _ReportLabel('Report ID - Generated Date'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF163B65), thickness: 1.5),
          const SizedBox(height: 20),
          _sectionTitle('1. Interview Information'),
          const SizedBox(height: 10),
          _placeholder('Job Title', height: 42),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _placeholder('Interview Date', height: 42)),
              const SizedBox(width: 10),
              Expanded(child: _placeholder('Interview Duration', height: 42)),
            ],
          ),
          const SizedBox(height: 22),
          _sectionTitle('2. Candidate Profile'),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 92, child: _placeholder('Candidate Photo', height: 92)),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  children: [
                    _PlaceholderBox(label: 'Candidate Name', height: 40),
                    SizedBox(height: 10),
                    _PlaceholderBox(label: 'Candidate Email / Contact', height: 40),
                    SizedBox(height: 10),
                    _PlaceholderBox(label: 'Applied Position', height: 40),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _sectionTitle('3. AI Interview Summary'),
          const SizedBox(height: 10),
          _placeholder('Generated Interview Summary', height: 150),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFD9E1EA)),
          const SizedBox(height: 12),
          const Text(
            'Post-Interview AI Analysis Report Draft',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Color(0xFF687588)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF163B65)));
  }

  Widget _placeholder(String label, {required double height}) {
    return _PlaceholderBox(label: label, height: height);
  }
}

class _PlaceholderBox extends StatelessWidget {
  final String label;
  final double height;

  const _PlaceholderBox({required this.label, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        border: Border.all(color: const Color(0xFFB9C6D5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF687588))),
    );
  }
}

class _ReportLabel extends StatelessWidget {
  final String text;
  final bool isTitle;

  const _ReportLabel(this.text, {this.isTitle = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: isTitle ? 19 : 11,
        fontWeight: isTitle ? FontWeight.w800 : FontWeight.w500,
        color: isTitle ? const Color(0xFF163B65) : const Color(0xFF687588),
      ),
    );
  }
}
