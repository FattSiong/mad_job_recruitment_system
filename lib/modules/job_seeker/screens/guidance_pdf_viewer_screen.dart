import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/pdf_file_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../controllers/guidance_report_controller.dart';
import '../widgets/pdf_preview_frame.dart';
import '../../../shared_widgets/app_bar_action_button.dart';

/// Shows a generated Guidance Report PDF inside the app, with Share and Open options.
class GuidancePdfViewerScreen extends StatefulWidget {
  final String title;
  final String fileName; // e.g. guidance_report_2026-10-31.pdf

  /// Builds the PDF bytes (data loading + PDF generation).
  final Future<Uint8List> Function() buildPdf;

  const GuidancePdfViewerScreen({
    super.key,
    required this.title,
    required this.fileName,
    required this.buildPdf,
  });

  @override
  State<GuidancePdfViewerScreen> createState() => _GuidancePdfViewerScreenState();
}

class _GuidancePdfViewerScreenState extends State<GuidancePdfViewerScreen> {
  Uint8List? _bytes;
  File? _file;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  /// Builds the PDF and saves it to a temporary file for viewing and sharing.
  Future<void> _generate() async {
    setState(() {
      _bytes = null;
      _error = null;
    });
    try {
      final bytes = await widget.buildPdf();
      final file = await PdfFileHelper.saveTemp(bytes, widget.fileName);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _file = file;
      });
    } catch (e) {
      debugPrint('PDF generation failed: $e');
      if (!mounted) return;
      setState(() => _error = e is GuidanceReportException
          ? e.message
          : 'Unable to create the PDF. Please try again.');
    }
  }

  /// Opens the phone's share sheet with the PDF.
  Future<void> _share() async {
    final file = _file;
    if (file != null) await PdfFileHelper.share(file, subject: widget.title);
  }

  /// Opens the PDF in another app (says so if there is none).
  Future<void> _openExternally() async {
    final file = _file;
    if (file == null) return;
    final error = await PdfFileHelper.openExternally(file);
    if (error != null && mounted) SnackBarHelper.showError(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _bytes != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
            const Text('PDF preview', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          AppBarActionButton(icon: Icons.ios_share_rounded, tooltip: 'Share or save', onPressed: ready ? _share : null),
          AppBarActionButton(icon: Icons.open_in_new_rounded, tooltip: 'Open in another app', onPressed: ready ? _openExternally : null),
          const SizedBox(width: 8),
        ],
      ),
      body: PdfPreviewFrame(
        bytes: _bytes,
        error: _error,
        loadingText: 'Preparing your PDF…',
        onRetry: _generate,
      ),
    );
  }
}
