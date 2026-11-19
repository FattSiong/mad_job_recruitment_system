import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saving, sharing and opening the PDFs the app makes (resume, reports).
class PdfFileHelper {
  PdfFileHelper._();

  /// Saves [bytes] as [fileName] in the temporary folder.
  static Future<File> saveTemp(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Opens the phone's share sheet with [file].
  static Future<void> share(File file, {required String subject}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')], subject: subject),
    );
  }

  /// Opens [file] in another app. Returns a message to show when that
  /// didn't work, or null.
  static Future<String?> openExternally(File file) async {
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type == ResultType.done) return null;
    return result.type == ResultType.noAppToOpen ? 'No PDF app found on this device.' : 'Unable to open the PDF.';
  }
}
