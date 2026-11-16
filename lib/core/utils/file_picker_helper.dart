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

  /// True if [path] has a resume extension the app accepts (PDF or DOCX).
  static bool isAllowedResume(String path) =>
      resumeExtensions.contains(path.split('.').last.toLowerCase());
}

/// Picking files from the phone and making their names safe for upload.
class FilePickerHelper {
  FilePickerHelper._();

  /// A file name Supabase Storage accepts, keeping it readable:
  /// "Resume #2 (Final).PDF" -> "Resume _2 (Final).pdf", "简历.pdf" -> "file.pdf".
  /// Storage only allows letters, digits and a few symbols in a file path, so
  /// names with accents, Chinese characters, # or % made the upload fail.
  static String storageSafeName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0
        ? fileName.substring(dot + 1).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')
        : '';
    var safe = base
        .replaceAll(RegExp(r'[^A-Za-z0-9 ._()\-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    if (safe.length > 80) safe = safe.substring(0, 80).trim();
    if (RegExp(r'^[_. ]*$').hasMatch(safe)) safe = 'file';
    return ext.isEmpty ? safe : '$safe.$ext';
  }

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
  /// [allowedExtensions] (e.g. ['pdf', 'png']) limits the file types.
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
