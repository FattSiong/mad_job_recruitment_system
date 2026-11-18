import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Soft card with an icon and a short message, shown where a list has no
/// entries yet ("No skills added yet...").
class EmptyHint extends StatelessWidget {
  final String text;
  final IconData icon;

  /// Card colour: [AppColors.surfaceAlt] inside a white card, [AppColors.surface] on the page background.
  final Color color;
  final EdgeInsetsGeometry margin;

  const EmptyHint({
    super.key,
    required this.text,
    this.icon = Icons.inbox_outlined,
    this.color = AppColors.surfaceAlt,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
