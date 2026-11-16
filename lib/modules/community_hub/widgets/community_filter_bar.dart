import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/post_filter.dart';
import '../../../models/post_topic.dart';
import '../controllers/post_list_controller.dart';
import 'community_chips.dart';
import 'community_filter_sheet.dart';

/// Above the Feed: search box, filter button (sort, posted by, date,
/// attachment) and a row of topic chips. Changes go to [controller].
class CommunityFilterBar extends StatefulWidget {
  final PostListController controller;

  const CommunityFilterBar({super.key, required this.controller});

  @override
  State<CommunityFilterBar> createState() => _CommunityFilterBarState();
}

class _CommunityFilterBarState extends State<CommunityFilterBar> {
  late final TextEditingController _search =
      TextEditingController(text: widget.controller.filter.search);
  Timer? _debounce;

  PostListController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_syncSearchText);
  }

  @override
  void dispose() {
    _c.removeListener(_syncSearchText);
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Filters cleared somewhere else (e.g. "Clear filters" on the empty list):
  /// empty the search box too.
  void _syncSearchText() {
    final typing = _debounce?.isActive ?? false;
    if (!typing && _c.filter.search.isEmpty && _search.text.isNotEmpty) {
      _search.clear();
    }
  }

  /// Search after the user stops typing for a moment.
  void _onSearchChanged(String value) {
    setState(() {}); // show / hide the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _applySearch(value));
  }

  /// Searches for [value] now (cancels the typing delay).
  void _applySearch(String value) {
    _debounce?.cancel();
    _c.setFilter(_c.filter.copyWith(search: value));
  }

  /// Empties the search box and shows all posts again.
  void _clearSearch() {
    _search.clear();
    _applySearch('');
    setState(() {});
  }

  /// Opens the filter sheet and applies what the user chose.
  Future<void> _openFilters() async {
    FocusScope.of(context).unfocus();
    final result = await showCommunityFilterSheet(context, _c.filter);
    if (result != null) _c.setFilter(result);
  }

  /// Clears the search, topic and every filter.
  void _clearAll() {
    _debounce?.cancel();
    _search.clear();
    _c.clearFilter();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final filter = _c.filter;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _buildSearchField()),
                  const SizedBox(width: 10),
                  _buildFilterButton(filter.sheetCount),
                ],
              ),
              const SizedBox(height: 10),
              _buildTopicRow(filter.topic),
              if (filter.isActive) _buildActiveSummary(filter),
            ],
          ),
        );
      },
    );
  }

  /// "Search posts or people" box.
  Widget _buildSearchField() {
    return TextField(
      controller: _search,
      onChanged: _onSearchChanged,
      onSubmitted: _applySearch,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: AppColors.textDark),
      decoration: InputDecoration(
        hintText: 'Search posts or people',
        hintStyle: const TextStyle(color: AppColors.textHint),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: _clearSearch,
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
              ),
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// Filter button with a badge showing how many filters are on.
  Widget _buildFilterButton(int count) {
    return Material(
      color: count > 0 ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: IconButton(
        tooltip: 'Filters',
        onPressed: _openFilters,
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          backgroundColor: AppColors.coral,
          child: Icon(
            Icons.tune_rounded,
            color: count > 0 ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }

  /// Horizontal row of topic chips ("All topics" first).
  Widget _buildTopicRow(PostTopic? selected) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          OptionChip(
            label: 'All topics',
            selected: selected == null,
            onTap: () => _c.setFilter(_c.filter.copyWith(allTopics: true)),
          ),
          for (final topic in PostTopic.values) ...[
            const SizedBox(width: 8),
            OptionChip(
              label: topic.label,
              icon: topic.icon,
              selected: topic == selected,
              // Tapping the selected topic again shows all topics.
              onTap: () => _c.setFilter(topic == selected
                  ? _c.filter.copyWith(allTopics: true)
                  : _c.filter.copyWith(topic: topic)),
            ),
          ],
        ],
      ),
    );
  }

  /// "Most liked · Employers · Past 7 days    Clear all"
  Widget _buildActiveSummary(PostFilter filter) {
    final parts = [
      if (filter.sort != PostSort.newest) filter.sort.label,
      if (filter.postedBy != PostAuthorFilter.everyone) filter.postedBy.label,
      if (filter.date != PostDateRange.anyTime) filter.date.label,
      if (filter.media != PostMediaFilter.any) filter.media.label,
    ];
    return Row(
      children: [
        Expanded(
          child: Text(
            parts.isEmpty ? 'Showing filtered posts' : parts.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: _clearAll,
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          child: const Text('Clear all'),
        ),
      ],
    );
  }
}
