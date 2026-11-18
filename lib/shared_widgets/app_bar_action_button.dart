import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// White rounded icon button in a screen's app bar (Share, History, Call...).
/// Grey when [onPressed] is null. [AppBarActionButton.custom] wraps any
/// widget (e.g. a menu button) in the same box.
class AppBarActionButton extends StatelessWidget {
  final IconData? icon;
  final String? tooltip;
  final VoidCallback? onPressed;

  /// Icon colour when enabled.
  final Color color;

  /// Shown instead of the icon (e.g. a spinner while it works).
  final Widget? busyChild;
  final Widget? child;

  const AppBarActionButton({
    super.key,
    required IconData this.icon,
    required String this.tooltip,
    required this.onPressed,
    this.color = AppColors.primary,
    this.busyChild,
  }) : child = null;

  const AppBarActionButton.custom({super.key, required Widget this.child})
      : icon = null,
        tooltip = null,
        onPressed = null,
        color = AppColors.primary,
        busyChild = null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: child ??
          IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: busyChild ?? Icon(icon, color: onPressed == null ? AppColors.iconDisabled : color),
          ),
    );
  }
}
