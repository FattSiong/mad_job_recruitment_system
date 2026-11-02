import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../shared_widgets/document_viewer_screen.dart';

class FilePreviewHelper {
  /// Opens a stored file inside the app (PDFs and images are shown directly;
  /// other types get an "Open in another app" button).
  /// Files in private buckets (resumes, answer files) are opened through a signed URL.
  static Future<void> previewNetworkFile(BuildContext context, String url, {String? title}) async {
    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid document URL.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DocumentViewerScreen(url: url, title: title)),
    );
  }

  /// Opens a local file: PDFs and images inside the app, anything else in
  /// the phone's default viewer.
  static Future<void> previewLocalFile(BuildContext context, File file, {String? title}) async {
    if (DocumentViewerScreen.kindOf(file.path) != DocumentKind.other) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DocumentViewerScreen(file: file, title: title)),
      );
      return;
    }

    try {
      final result = await OpenFilex.open(file.path);

      if (result.type != ResultType.done && context.mounted) {
        String errorMessage = 'Could not open file: ${result.message}';

        if (result.type == ResultType.noAppToOpen) {
          errorMessage = 'You do not have an app installed on your phone to view this type of file.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange.shade800, // Warning color
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening local file.')),
        );
      }
    }
  }
}
