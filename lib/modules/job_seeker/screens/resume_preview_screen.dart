import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/pdf_file_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../controllers/resume_builder_controller.dart';
import '../widgets/pdf_preview_frame.dart';
import '../../../core/theme/app_button_styles.dart';
import '../../../shared_widgets/button_spinner.dart';
import '../../../shared_widgets/plain_app_bar.dart';

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

  /// Builds the resume PDF and saves it to a temporary file for viewing.
  Future<void> _generate() async {
    setState(() {
      _bytes = null;
      _error = null;
    });
    try {
      final bytes = await _controller.buildPdf();
      final file = await PdfFileHelper.saveTemp(bytes, _controller.pdfFileName);
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

  /// Green or red snackbar (if the screen is still open).
  void _toast(String message, {bool success = true}) {
    if (!mounted) return;
    if (success) {
      SnackBarHelper.showSuccess(context, message);
    } else {
      SnackBarHelper.showError(context, message);
    }
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
            style: AppButtonStyles.filled(),
            child: const Text('Use as resume'),
          ),
        ],
      ),
    );
    if (yes == true) await _useAsResume();
  }

  /// Uploads this PDF and makes it the profile resume.
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

  /// Opens the phone's share sheet with the PDF.
  Future<void> _share() async {
    final file = _file;
    if (file != null) await PdfFileHelper.share(file, subject: 'My Resume');
  }

  /// Lets the user save the PDF where they choose.
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

  /// Opens the PDF in another app (says so if there is none).
  Future<void> _openExternally() async {
    final file = _file;
    if (file == null) return;
    final error = await PdfFileHelper.openExternally(file);
    if (error != null) _toast(error, success: false);
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ready = _bytes != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PlainAppBar(
        title: 'Resume Preview',
        subtitle: 'Go back to make changes',
        backTooltip: 'Back to editing',
        actions: [
          IconButton(
            tooltip: 'Download',
            onPressed: ready ? _download : null,
            icon: Icon(Icons.download_rounded, color: ready ? AppColors.primary : AppColors.iconDisabled),
          ),
          IconButton(
            tooltip: 'Share',
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
        loadingText: 'Creating your resume…',
        onRetry: _generate,
      ),
      bottomNavigationBar: ready
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: ElevatedButton.icon(
                  onPressed: (_setAsResume || _isSettingResume) ? null : _useAsResume,
                  icon: _isSettingResume
                      ? const ButtonSpinner()
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
}
