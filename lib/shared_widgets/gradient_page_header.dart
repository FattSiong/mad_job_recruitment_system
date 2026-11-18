import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// The green header at the top of a sub-page: back button, an optional
/// icon, the title and a short line under it, and an optional widget on
/// the right (e.g. a "saving" spinner). Used by My Skills, Education,
/// Work Experience, Build Resume and the career tool screens.
class GradientPageHeader extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;

  /// Shown on the right, after the title (e.g. a small spinner).
  final Widget? trailing;

  /// Lines of [subtitle] before it is cut with "…" (null = no limit).
  final int? subtitleMaxLines;

  const GradientPageHeader({
    super.key,
    this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.subtitleMaxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 8),
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 34),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: subtitleMaxLines,
                  overflow: subtitleMaxLines == null ? null : TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
