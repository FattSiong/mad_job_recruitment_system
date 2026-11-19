import 'package:intl/intl.dart';

/// Date/time labels used by the chat screens.
class ChatFormatters {
  ChatFormatters._();

  /// Chat list: "2:05 PM" today, "Yesterday", "Mon", or "12/03/26".
  static String listTime(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final daysAgo = today.difference(day).inDays;

    if (daysAgo <= 0) return _time.format(local);
    if (daysAgo == 1) return 'Yesterday';
    if (daysAgo < 7) return DateFormat('EEE').format(local);
    return DateFormat('dd/MM/yy').format(local);
  }

  /// Same clock style as the rest of the app ("2:05 PM").
  static final DateFormat _time = DateFormat('h:mm a');

  /// Under each bubble: "2:05 PM".
  static String bubbleTime(DateTime time) => _time.format(time.toLocal());

  /// Separator between days: "Today", "Yesterday", "Monday, 3 Nov 2026".
  static String daySeparator(DateTime time) {
    final local = time.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final daysAgo = today.difference(day).inDays;

    if (daysAgo <= 0) return 'Today';
    if (daysAgo == 1) return 'Yesterday';
    return DateFormat('EEEE, d MMM yyyy').format(local);
  }

  /// True if [a] and [b] fall on the same local calendar day.
  static bool isSameDay(DateTime a, DateTime b) {
    final x = a.toLocal(), y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  /// "0:07" for voice notes.
  static String duration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
