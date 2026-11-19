import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Font and text helpers shared by the app's PDF builders.
class PdfText {
  PdfText._();

  static pw.ThemeData? _theme;

  /// The Poppins fonts, loaded once and reused for every PDF.
  static Future<pw.ThemeData> theme() async {
    if (_theme != null) return _theme!;
    final regular = await rootBundle.load('assets/fonts/Poppins-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Poppins-Bold.ttf');
    return _theme = pw.ThemeData.withFont(base: pw.Font.ttf(regular), bold: pw.Font.ttf(bold));
  }

  /// [s] without characters the font can't draw (emoji, arrows, check marks).
  static String clean(String? s) {
    if (s == null) return '';
    return s
        .replaceAll('→', '->')
        .replaceAll('✓', '-')
        .replaceAll('✔', '-')
        .replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true), '')
        .trim();
  }
}
