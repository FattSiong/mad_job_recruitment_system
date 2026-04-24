import 'dart:io';
import 'package:file_picker/file_picker.dart';

class FilePickerHelper {
  /// Opens the device file picker.
  /// If [allowedExtensions] are provided (e.g., ['pdf', 'png']), it restricts the file types.
  /// Returns a [File] if the user picks one, or [null] if they cancel.
  static Future<File?> pickFile({List<String>? allowedExtensions}) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        // If extensions are provided, enforce them. Otherwise, allow any file.
        type: (allowedExtensions != null && allowedExtensions.isNotEmpty)
            ? FileType.custom
            : FileType.any,
        allowedExtensions: allowedExtensions,
      );

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
      return null; // User canceled the picker
    } catch (e) {
      print('Error picking file: $e');
      return null;
    }
  }
}