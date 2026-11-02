import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// White rounded card that groups content on the job seeker screens.
/// Pass [child], or [children] to stack them in a left-aligned column.
class SurfaceCard extends StatelessWidget {
  final Widget? child;
  final List<Widget>? children;
  final EdgeInsetsGeometry padding;

  const SurfaceCard({
    super.key,
    this.child,
    this.children,
    this.padding = const EdgeInsets.all(22),
  }) : assert((child == null) != (children == null), 'Pass either child or children');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child ??
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: children!),
    );
  }
}

/// Bold section heading, with an optional grey line underneath.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionTitle(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
          ],
        ],
      ),
    );
  }
}
