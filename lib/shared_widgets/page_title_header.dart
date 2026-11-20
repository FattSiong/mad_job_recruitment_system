import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Title and short description at the top of a tab (Community Hub,
/// Messages), with an optional button on the right.
class PageTitleHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const PageTitleHeader({super.key, required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
