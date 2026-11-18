import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../models/content_report_model.dart';

/// Search field of an admin moderation list (with a clear button).
class ModerationSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool hasText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const ModerationSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.hasText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, color: AdminColors.textSecondary),
        suffixIcon: hasText
            ? IconButton(tooltip: 'Clear', icon: const Icon(Icons.close_rounded, size: 18), onPressed: onClear)
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}

/// "Sort" button with a menu of [options].
class ModerationSortButton extends StatelessWidget {
  final ModerationSort selected;
  final List<ModerationSort> options;
  final ValueChanged<ModerationSort> onSelected;

  /// Label shown for an option (e.g. "Waiting longest" for oldest reports).
  final String Function(ModerationSort sort) labelFor;

  const ModerationSortButton({
    super.key,
    required this.selected,
    required this.options,
    required this.onSelected,
    required this.labelFor,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ModerationSort>(
      tooltip: 'Sort',
      initialValue: selected,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        for (final s in options)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Icon(
                  s == selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  size: 18,
                  color: AdminColors.heroEnd,
                ),
                const SizedBox(width: 10),
                Text(labelFor(s)),
              ],
            ),
          ),
      ],
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, color: AdminColors.heroStart, size: 20),
            SizedBox(width: 6),
            Text('Sort', style: TextStyle(fontWeight: FontWeight.w700, color: AdminColors.heroStart)),
          ],
        ),
      ),
    );
  }
}

/// Empty / error / no-results card.
class ModerationStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const ModerationStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AdminColors.heroEnd),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminColors.textPrimary)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AdminColors.textSecondary, height: 1.4)),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}

/// Red line shown above a list that could not be refreshed.
class ModerationRefreshFailedBanner extends StatelessWidget {
  const ModerationRefreshFailedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AdminColors.alertRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: AdminColors.alertRed),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Couldn\'t refresh. Showing the list from before; pull down to try again.',
              style: TextStyle(fontSize: 12.5, color: AdminColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Spinner while the next page loads, or a "Load more" / "Try again" button.
class ModerationLoadMore extends StatelessWidget {
  final bool loading;
  final bool failed;
  final VoidCallback onPressed;

  const ModerationLoadMore({super.key, required this.loading, required this.failed, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: loading
            ? const CircularProgressIndicator(color: AdminColors.heroEnd)
            : TextButton.icon(
                onPressed: onPressed,
                icon: Icon(failed ? Icons.refresh_rounded : Icons.expand_more_rounded),
                label: Text(failed ? 'Couldn\'t load more. Try again' : 'Load more'),
              ),
      ),
    );
  }
}
