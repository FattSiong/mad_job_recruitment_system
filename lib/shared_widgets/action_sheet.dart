import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// One choice in [showActionSheet].
class SheetAction<T> {
  final T value;
  final String label;
  final IconData? icon;
  final String? subtitle;

  /// Shown in red (delete, remove...).
  final bool destructive;

  const SheetAction(this.value, this.label, {this.icon, this.subtitle, this.destructive = false});
}

/// Bottom sheet with a list of choices (and an optional [title]).
/// Returns the chosen value, or null when the sheet is closed.
Future<T?> showActionSheet<T>(
  BuildContext context, {
  String? title,
  required List<SheetAction<T>> actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
              ),
            for (final a in actions)
              ListTile(
                leading: a.icon == null
                    ? null
                    : Icon(a.icon, color: a.destructive ? AppColors.errorRed : AppColors.primary),
                title: Text(a.label, style: a.destructive ? const TextStyle(color: AppColors.errorRed) : null),
                subtitle: a.subtitle == null ? null : Text(a.subtitle!),
                onTap: () => Navigator.pop(sheetContext, a.value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
