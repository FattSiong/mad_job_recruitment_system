import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// The rounded green gradient card at the top of the job seeker screens.
class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const HeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: child,
    );
  }
}

/// Small see-through label on a [HeroCard] ("Job Application",
/// a job's location...).
class HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Cut a long label with "…". Only where the pill's width is limited
  /// (e.g. in a Wrap), not next to a Spacer in a Row.
  final bool shrinkLabel;

  const HeroPill({super.key, required this.icon, required this.label, this.shrinkLabel = false});

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          if (shrinkLabel) Flexible(child: text) else text,
        ],
      ),
    );
  }
}
