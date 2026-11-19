import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/post_filter.dart';
import 'community_chips.dart';
import '../../../shared_widgets/sheet_handle.dart';

/// Bottom sheet with Sort by / Posted by / Date posted / Attachment.
/// Returns the new filter, or null if closed without applying.
/// The search text and topic are kept as they are.
Future<PostFilter?> showCommunityFilterSheet(BuildContext context, PostFilter current) {
  return showModalBottomSheet<PostFilter>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CommunityFilterSheet(initial: current),
  );
}

/// Content of the filter sheet (changes apply only on Apply).
class _CommunityFilterSheet extends StatefulWidget {
  final PostFilter initial;

  const _CommunityFilterSheet({required this.initial});

  @override
  State<_CommunityFilterSheet> createState() => _CommunityFilterSheetState();
}

class _CommunityFilterSheetState extends State<_CommunityFilterSheet> {
  late PostFilter _draft = widget.initial;

  /// Sets every option back to its default (not applied until Apply).
  void _reset() {
    setState(() {
      _draft = _draft.copyWith(
        sort: PostSort.newest,
        postedBy: PostAuthorFilter.everyone,
        date: PostDateRange.anyTime,
        media: PostMediaFilter.any,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filter posts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _draft.sheetCount == 0 ? null : _reset,
                  child: const Text('Reset'),
                ),
              ],
            ),
            _section<PostSort>(
              'Sort by',
              PostSort.values,
              _draft.sort,
              (v) => v.label,
              (v) => _draft.copyWith(sort: v),
            ),
            _section<PostAuthorFilter>(
              'Posted by',
              PostAuthorFilter.values,
              _draft.postedBy,
              (v) => v.label,
              (v) => _draft.copyWith(postedBy: v),
            ),
            _section<PostDateRange>(
              'Date posted',
              PostDateRange.values,
              _draft.date,
              (v) => v.label,
              (v) => _draft.copyWith(date: v),
            ),
            _section<PostMediaFilter>(
              'Attachment',
              PostMediaFilter.values,
              _draft.media,
              (v) => v.label,
              (v) => _draft.copyWith(media: v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _draft),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Show posts', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One titled group of choice chips (e.g. Sort by).
  Widget _section<T>(
    String title,
    List<T> options,
    T selected,
    String Function(T) label,
    PostFilter Function(T) apply,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                OptionChip(
                  label: label(option),
                  selected: option == selected,
                  onTap: () => setState(() => _draft = apply(option)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
