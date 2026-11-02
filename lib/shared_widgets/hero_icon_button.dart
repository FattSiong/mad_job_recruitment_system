import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Round-cornered icon button on the dark gradient headers (back, share,
/// save...). [isActive] shows the icon highlighted, e.g. a saved job.
class HeroIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;

  const HeroIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: isActive ? AppColors.highlight : Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
