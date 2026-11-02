import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Upload size limits (MB).
class FileLimits {
  FileLimits._();

  static const int resumeMB = 5;
  static const int imageMB = 5;
  static const int answerFileMB = 10;

  /// Resume files: PDF (previewed in the app) and DOCX (read by Skill Gap
  /// Analysis). Older .doc, .rtf and .txt files are not supported.
  static const List<String> resumeExtensions = ['pdf', 'docx'];
  static const String resumeTypesLabel = 'PDF or Word (.docx)';

  static bool isAllowedResume(String path) =>
      resumeExtensions.contains(path.split('.').last.toLowerCase());
}

class FilePickerHelper {
  FilePickerHelper._();

  /// Returns an error message if [file] is larger than [maxMB], otherwise null.
  static Future<String?> checkSize(File file, int maxMB) async {
    final bytes = await file.length();
    if (bytes > maxMB * 1024 * 1024) {
      final sizeMB = (bytes / (1024 * 1024)).toStringAsFixed(1);
      return 'This file is $sizeMB MB. Please choose a file under $maxMB MB.';
    }
    return null;
  }

  /// Opens the device file picker.
  /// If [allowedExtensions] are provided (e.g., ['pdf', 'png']), it restricts the file types.
  /// If [maxSizeMB] is set and the file is bigger, [onTooLarge] is called with a
  /// message and null is returned.
  /// Returns a [File] if the user picks one, or null if they cancel.
  static Future<File?> pickFile({
    List<String>? allowedExtensions,
    int? maxSizeMB,
    void Function(String message)? onTooLarge,
  }) async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: (allowedExtensions != null && allowedExtensions.isNotEmpty)
            ? FileType.custom
            : FileType.any,
        allowedExtensions: allowedExtensions,
      );

      final path = result?.files.single.path;
      if (path == null) return null; // user cancelled

      final file = File(path);
      if (maxSizeMB != null) {
        final error = await checkSize(file, maxSizeMB);
        if (error != null) {
          onTooLarge?.call(error);
          return null;
        }
      }
      return file;
    } catch (e) {
      debugPrint('Error picking file: $e');
      return null;
    }
  }
}
