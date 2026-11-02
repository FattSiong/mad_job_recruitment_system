import 'package:intl/intl.dart';

/// Date/time labels used by the chat screens.
class ChatFormatters {
  ChatFormatters._();

  /// Chat list: "14:05" today, "Yesterday", "Mon", or "12/03/26".
  static String listTime(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final daysAgo = today.difference(day).inDays;

    if (daysAgo <= 0) return DateFormat('HH:mm').format(local);
    if (daysAgo == 1) return 'Yesterday';
    if (daysAgo < 7) return DateFormat('EEE').format(local);
    return DateFormat('dd/MM/yy').format(local);
  }

  /// Under each bubble: "14:05".
  static String bubbleTime(DateTime time) => DateFormat('HH:mm').format(time.toLocal());

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
