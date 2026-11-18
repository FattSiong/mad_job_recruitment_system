import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Empty / error message: an icon in a soft square, a title, a short
/// message and an optional [action] (e.g. Try Again).
class StateMessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  /// Icon colour (its square is a light shade of it).
  final Color color;
  final Widget? action;

  /// White rounded card behind it; false shows it on the page background.
  final bool boxed;

  const StateMessageCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.color = AppColors.primary,
    this.action,
    this.boxed = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: boxed
          ? BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28))
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 34, color: color),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textMuted),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
