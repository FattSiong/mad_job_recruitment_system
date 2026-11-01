import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';

import 'storage_url_helper.dart';

class FilePreviewHelper {
  /// Opens a network URL using the device's browser or default app.
  /// Files in private buckets (resumes, answer files) are opened through a signed URL.
  static Future<void> previewNetworkFile(BuildContext context, String url) async {
    try {
      final Uri uri = Uri.parse(await StorageUrlHelper.resolve(url));
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the document.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid document URL.')),
        );
      }
    }
  }

  /// Opens a local file using the device's default viewer
  static Future<void> previewLocalFile(BuildContext context, File file) async {
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