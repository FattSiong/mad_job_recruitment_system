import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../controllers/guidance_report_controller.dart';

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
  static const Color _primary = AppColors.primary;
  static const Color _background = AppColors.background;
  static const Color _textPrimary = AppColors.textDark;
  static const Color _textMuted = AppColors.textMuted;

  Uint8List? _bytes;
  File? _file;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _bytes = null;
      _error = null;
    });
    try {
      final bytes = await widget.buildPdf();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.fileName}');
      await file.writeAsBytes(bytes, flush: true);
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

  Future<void> _share() async {
    final file = _file;
    if (file == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: widget.title,
      ),
    );
  }

  Future<void> _openExternally() async {
    final file = _file;
    if (file == null) return;
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type != ResultType.done && mounted) {
      SnackBarHelper.showStyled(
        context,
        message: result.type == ResultType.noAppToOpen
            ? 'No PDF app found on this device.'
            : 'Unable to open the PDF.',
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.errorRed,
      );
    }
  }

  Widget _actionButton(IconData icon, String tooltip, VoidCallback? onPressed) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: IconButton(
        icon: Icon(icon, color: onPressed == null ? const Color(0xFFB0BCCB) : _primary),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _bytes != null;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textPrimary),
            ),
            const Text('PDF preview', style: TextStyle(fontSize: 12, color: _textMuted)),
          ],
        ),
        actions: [
          _actionButton(Icons.ios_share_rounded, 'Share or save', ready ? _share : null),
          _actionButton(Icons.open_in_new_rounded, 'Open in another app', ready ? _openExternally : null),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: _error != null
            ? _buildError()
            : !ready
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: _primary),
                        SizedBox(height: 16),
                        Text('Preparing your PDF…', style: TextStyle(color: _textMuted)),
                      ],
                    ),
                  )
                : SfPdfViewer.memory(
                    _bytes!,
                    canShowScrollHead: true,
                    pageSpacing: 6,
                  ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 44, color: AppColors.errorRed),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, color: _textPrimary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
