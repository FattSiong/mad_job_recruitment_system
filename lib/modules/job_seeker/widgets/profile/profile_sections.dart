import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared_widgets/surface_card.dart';

/// Section title, with a "Manage" button in edit mode.
class ProfileSectionHeader extends StatelessWidget {
  final String title;

  /// Shown as "Manage" when set.
  final VoidCallback? onManage;

  const ProfileSectionHeader(this.title, {super.key, this.onManage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          if (onManage != null)
            TextButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: const Text('Manage', style: TextStyle(fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
        ],
      ),
    );
  }
}

/// "No skills added yet." style card.
class ProfileEmptyCard extends StatelessWidget {
  final String message;

  const ProfileEmptyCard(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inbox_outlined, color: AppColors.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the first [collapsedCount] records with "Show all (n)" to expand,
/// so long work / education histories don't make the profile very long.
class ExpandableRecordList extends StatefulWidget {
  final List<Widget> records;
  final String emptyMessage;
  final int collapsedCount;

  const ExpandableRecordList({
    super.key,
    required this.records,
    required this.emptyMessage,
    this.collapsedCount = 2,
  });

  @override
  State<ExpandableRecordList> createState() => _ExpandableRecordListState();
}

class _ExpandableRecordListState extends State<ExpandableRecordList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final records = widget.records;
    if (records.isEmpty) return ProfileEmptyCard(widget.emptyMessage);

    final canCollapse = records.length > widget.collapsedCount;
    final shown = canCollapse && !_expanded ? records.take(widget.collapsedCount) : records;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...shown,
        if (canCollapse)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              label: Text(_expanded ? 'Show less' : 'Show all (${records.length})'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
      ],
    );
  }
}
