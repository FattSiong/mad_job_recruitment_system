import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/pdf_file_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../controllers/guidance_report_controller.dart';
import '../widgets/pdf_preview_frame.dart';
import '../../../shared_widgets/plain_app_bar.dart';

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
      appBar: PlainAppBar(
        title: widget.title,
        subtitle: 'PDF preview',
        actions: [
          IconButton(
            tooltip: 'Share or save',
            onPressed: ready ? _share : null,
            icon: Icon(Icons.ios_share_rounded, color: ready ? AppColors.primary : AppColors.iconDisabled),
          ),
          IconButton(
            tooltip: 'Open in another app',
            onPressed: ready ? _openExternally : null,
            icon: Icon(Icons.open_in_new_rounded, color: ready ? AppColors.primary : AppColors.iconDisabled),
          ),
          const SizedBox(width: 4),
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
