import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared_widgets/surface_card.dart';

// Pieces shared by the AI career tools (Resume Assistant, Skill Gap
// Analysis, Mock Interview): the target-role card, the bottom button and
// a row of the "past results" list.

/// Card with a job-role text field and suggested roles as chips.
class TargetRoleField extends StatelessWidget {
  final String title;
  final String subtitle;
  final String hint;
  final TextEditingController controller;
  final bool enabled;
  final List<String> suggestions;

  /// A suggested role was tapped (the screen decides: set it, or clear
  /// it when it was already chosen).
  final ValueChanged<String> onSuggestionTap;

  /// Keyboard "done" (null = nothing extra).
  final ValueChanged<String>? onSubmitted;

  /// Shows an "x" to clear the text.
  final bool showClear;

  const TargetRoleField({
    super.key,
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.suggestions,
    required this.onSuggestionTap,
    this.hint = 'e.g. Junior Data Analyst',
    this.enabled = true,
    this.onSubmitted,
    this.showClear = false,
  });

  static OutlineInputBorder _border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final text = controller.text.trim();
    return SurfaceCard(
      children: [
        SectionTitle(title, subtitle: subtitle),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
          textInputAction: onSubmitted == null ? null : TextInputAction.done,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            prefixIcon: const Icon(Icons.work_outline, color: AppColors.primary),
            suffixIcon: !showClear || controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    onPressed: enabled ? controller.clear : null,
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  ),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: _border(AppColors.border),
            enabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.primary, 1.2),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in suggestions)
              ChoiceChip(
                label: Text(role),
                selected: text == role,
                onSelected: enabled ? (_) => onSuggestionTap(role) : null,
                selectedColor: AppColors.primarySoft,
                backgroundColor: AppColors.surfaceAlt,
                side: BorderSide(color: text == role ? AppColors.primary : AppColors.border),
                labelStyle: TextStyle(
                  color: text == role ? AppColors.primary : AppColors.textDark,
                  fontWeight: text == role ? FontWeight.w700 : FontWeight.w500,
                ),
                showCheckmark: false,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
          ],
        ),
      ],
    );
  }
}

/// The big button at the bottom of a career tool, with a spinner and an
/// optional "this can take a while" line while it runs.
class CareerToolRunBar extends StatelessWidget {
  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final String busyLabel;

  /// Shown above the button while [busy] (null = nothing).
  final String? busyHint;

  const CareerToolRunBar({
    super.key,
    required this.busy,
    required this.enabled,
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.busyLabel,
    this.busyHint,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy && busyHint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  busyHint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: enabled ? onPressed : null,
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(icon),
                label: Text(busy ? busyLabel : label),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.disabled,
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One past result: score box, title, a line under it, and Delete.
class CareerToolHistoryTile extends StatelessWidget {
  final String score;
  final Color scoreColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// null = the delete button is disabled.
  final VoidCallback? onDelete;

  /// Smaller for longer scores like "85%".
  final double scoreFontSize;

  const CareerToolHistoryTile({
    super.key,
    required this.score,
    required this.scoreColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onDelete,
    this.scoreFontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    score,
                    style: TextStyle(
                      color: scoreColor,
                      fontWeight: FontWeight.w800,
                      fontSize: scoreFontSize,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
