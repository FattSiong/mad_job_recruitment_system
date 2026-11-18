import 'package:intl/intl.dart';

/// Date formats shared by the screens and PDFs.
class AppDateFormat {
  AppDateFormat._();

  /// 18 Nov 2026
  static final DateFormat day = DateFormat('d MMM yyyy');

  /// 18 Nov 2026, 3:05 PM
  static final DateFormat dayTime = DateFormat('d MMM yyyy, h:mm a');

  /// Nov 2026
  static final DateFormat month = DateFormat('MMM yyyy');

  /// 20261118_1505, for file names
  static final DateFormat fileStamp = DateFormat('yyyyMMdd_HHmm');
}
