import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../controllers/resume_builder_controller.dart';

/// PDF preview of the built resume: share, download, open, and optionally
/// use it as the profile resume for job applications.
class ResumePreviewScreen extends StatefulWidget {
  final ResumeBuilderController controller;

  const ResumePreviewScreen({super.key, required this.controller});

  @override
  State<ResumePreviewScreen> createState() => _ResumePreviewScreenState();
}

class _ResumePreviewScreenState extends State<ResumePreviewScreen> {
  Uint8List? _bytes;
  File? _file;
  String? _error;
  bool _isSettingResume = false;
  bool _setAsResume = false;

  ResumeBuilderController get _controller => widget.controller;

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
      final bytes = await _controller.buildPdf();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${_controller.pdfFileName}');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _file = file;
      });
      _askToUseAsResume();
    } catch (e) {
      debugPrint('Resume PDF failed: $e');
      if (mounted) setState(() => _error = 'Unable to create your resume PDF. Please try again.');
    }
  }

  void _toast(String message, {bool success = true}) {
    if (!mounted) return;
    SnackBarHelper.showStyled(
      context,
      message: message,
      icon: success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
      accentColor: success ? AppColors.successGreen : AppColors.errorRed,
    );
  }

  /// Asked once when the PDF is ready.
  Future<void> _askToUseAsResume() async {
    await Future.delayed(const Duration(milliseconds: 600)); // let the preview appear first
    if (!mounted || _setAsResume) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.description_outlined, color: AppColors.primary, size: 32),
        title: const Text('Use as your resume?'),
        content: const Text(
          'Set this PDF as the resume on your profile. It will be used when you apply for jobs '
          'and replaces your current resume file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Use as resume'),
          ),
        ],
      ),
    );
    if (yes == true) await _useAsResume();
  }

  Future<void> _useAsResume() async {
    final bytes = _bytes;
    if (bytes == null || _isSettingResume) return;
    setState(() => _isSettingResume = true);
    final ok = await _controller.setAsProfileResume(bytes);
    if (!mounted) return;
    setState(() {
      _isSettingResume = false;
      if (ok) _setAsResume = true;
    });
    _toast(
      ok ? 'Saved as your profile resume.' : 'Could not save the resume. Please try again.',
      success: ok,
    );
  }

  Future<void> _share() async {
    final file = _file;
    if (file == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'My Resume',
      ),
    );
  }

  Future<void> _download() async {
    final bytes = _bytes;
    if (bytes == null) return;
    try {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save resume',
        fileName: _controller.pdfFileName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: bytes,
      );
      if (path != null) _toast('Resume saved.');
    } catch (e) {
      debugPrint('Save resume failed: $e');
      _toast('Could not save the file. Try "Share" and choose Save to device.', success: false);
    }
  }

  Future<void> _openExternally() async {
    final file = _file;
    if (file == null) return;
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type != ResultType.done) {
      _toast(
        result.type == ResultType.noAppToOpen ? 'No PDF app found on this device.' : 'Unable to open the PDF.',
        success: false,
      );
    }
  }

  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ready = _bytes != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          tooltip: 'Back to editing',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resume Preview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
            Text('Go back to make changes', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Download',
            onPressed: ready ? _download : null,
            icon: const Icon(Icons.download_rounded, color: AppColors.primary),
          ),
          IconButton(
            tooltip: 'Share',
            onPressed: ready ? _share : null,
            icon: const Icon(Icons.ios_share_rounded, color: AppColors.primary),
          ),
          IconButton(
            tooltip: 'Open in another app',
            onPressed: ready ? _openExternally : null,
            icon: const Icon(Icons.open_in_new_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: _error != null
            ? _buildError()
            : !ready
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text('Creating your resume…', style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : SfPdfViewer.memory(_bytes!, canShowScrollHead: true, pageSpacing: 6),
      ),
      bottomNavigationBar: ready
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: ElevatedButton.icon(
                  onPressed: (_setAsResume || _isSettingResume) ? null : _useAsResume,
                  icon: _isSettingResume
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(_setAsResume ? Icons.check_circle_rounded : Icons.badge_outlined),
                  label: Text(
                    _setAsResume
                        ? 'This is your profile resume'
                        : (_isSettingResume ? 'Saving…' : 'Use as my profile resume'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _setAsResume ? AppColors.teal : AppColors.border,
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            )
          : null,
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
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
