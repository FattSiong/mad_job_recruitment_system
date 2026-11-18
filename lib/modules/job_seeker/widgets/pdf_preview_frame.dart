import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/theme/app_colors.dart';

/// The white rounded area of a PDF preview screen: the PDF once [bytes]
/// are ready, a spinner with [loadingText] before, or [error] with
/// Try Again.
class PdfPreviewFrame extends StatelessWidget {
  final Uint8List? bytes;
  final String? error;
  final String loadingText;
  final VoidCallback onRetry;

  const PdfPreviewFrame({
    super.key,
    required this.bytes,
    required this.error,
    required this.loadingText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (error != null) {
      child = _buildError();
    } else if (bytes == null) {
      child = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(loadingText, style: const TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    } else {
      child = SfPdfViewer.memory(bytes!, canShowScrollHead: true, pageSpacing: 6);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
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
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
