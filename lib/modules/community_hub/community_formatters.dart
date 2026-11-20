import '../../core/utils/app_date_format.dart';

/// Time labels used by the Community Hub.
class CommunityFormatters {
  CommunityFormatters._();

  /// "Just now", "5m", "3h", "2d", "1w", or "12 Mar 2026" for older posts.
  static String relative(DateTime time) {
    final diff = DateTime.now().difference(time.toLocal());
    if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7}w';
    return AppDateFormat.day.format(time.toLocal());
  }

  /// "1.2k" for big counts.
  static String count(int n) {
    if (n < 1000) return '$n';
    final k = n / 1000;
    // One decimal below 10k ("1.2k"); whole numbers from 10k ("15k").
    // Rounded first, so 9,999 shows "10k" rather than "10.0k".
    final oneDecimal = (k * 10).round() / 10;
    return oneDecimal < 10 ? '${oneDecimal.toStringAsFixed(1)}k' : '${k.round()}k';
  }
}
