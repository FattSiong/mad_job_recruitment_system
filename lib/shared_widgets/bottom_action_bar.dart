import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// White bar with a soft shadow at the bottom of a screen, holding its
/// main buttons (Submit, Save, Next...). Keeps clear of the phone's
/// navigation bar.
class BottomActionBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const BottomActionBar({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 8)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}
