import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// The light app bar of the inner screens: back button in the primary
/// colour, a bold title (with an optional small [subtitle]) and no shadow
/// when the page scrolls under it.
class PlainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;

  /// Replaces [title] / [subtitle] (e.g. the chat room's avatar and name).
  final Widget? titleWidget;
  final IconData backIcon;
  final String backTooltip;

  /// Defaults to [Navigator.maybePop] (so a PopScope can still ask first).
  final VoidCallback? onBack;
  final List<Widget>? actions;

  const PlainAppBar({
    super.key,
    this.title = '',
    this.subtitle,
    this.titleWidget,
    this.backIcon = Icons.arrow_back_rounded,
    this.backTooltip = 'Back',
    this.onBack,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final compact = titleWidget != null || subtitle != null;
    return AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: compact ? 0 : null,
      leading: IconButton(
        tooltip: backTooltip,
        icon: Icon(backIcon, color: AppColors.primary),
        onPressed: onBack ?? () => Navigator.maybePop(context),
      ),
      title: titleWidget ?? (subtitle == null ? _title(null) : _titleWithSubtitle()),
      actions: actions,
    );
  }

  Widget _title(double? fontSize) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: AppColors.textDark),
    );
  }

  Widget _titleWithSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(18),
        Text(
          subtitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
