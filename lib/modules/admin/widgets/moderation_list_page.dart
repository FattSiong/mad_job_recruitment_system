import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/content_report_model.dart';
import '../controllers/moderation_list_controller.dart';
import 'moderation_list_parts.dart';
import 'moderation_note_dialog.dart';

/// Asks with [dialog], runs [action] with the admin's choice, then shows
/// [action]'s error or [successMessage].
Future<void> confirmModerationAction(
  BuildContext context, {
  required ModerationNoteDialog dialog,
  required Future<String?> Function(ModerationDecision decision) action,
  required String Function(ModerationDecision decision) successMessage,
}) async {
  final decision = await showDialog<ModerationDecision>(context: context, builder: (_) => dialog);
  if (decision == null || !context.mounted) return;
  final error = await action(decision);
  if (!context.mounted) return;
  if (error != null) {
    SnackBarHelper.showError(context, error, duration: const Duration(seconds: 3));
  } else {
    SnackBarHelper.showSuccess(context, successMessage(decision));
  }
}

/// The page shared by Admin > Community and Admin > Jobs: hero, Reported /
/// All switch, search and sort, then the list with its loading, error,
/// empty and "load more" states. Pull to refresh; reloads when the admin
/// comes back to the app; loads the next page near the bottom.
///
/// The screen owns [controller] (and disposes it); this page loads it.
class ModerationListPage<T extends ReportSummary> extends StatefulWidget {
  final ModerationListController<T> controller;

  /// The banner at the top; [refresh] is null while loading.
  final Widget Function(VoidCallback? refresh) heroBuilder;

  /// Extra filter above the Reported / All switch (e.g. Posts / Comments).
  final Widget? extraFilter;

  /// Label of the "All" segment.
  final String allLabel;

  /// Read on every rebuild and shown on "Reported" when given.
  final int Function()? reportedCount;

  final String reportedSearchHint;
  final String allSearchHint;

  /// Shown when the list is empty; [clearSearch] empties the search box.
  final Widget Function(VoidCallback clearSearch) emptyBuilder;

  /// One card of the list.
  final Widget Function(T item) itemBuilder;

  const ModerationListPage({
    super.key,
    required this.controller,
    required this.heroBuilder,
    required this.allLabel,
    required this.reportedSearchHint,
    required this.allSearchHint,
    required this.emptyBuilder,
    required this.itemBuilder,
    this.extraFilter,
    this.reportedCount,
  });

  @override
  State<ModerationListPage<T>> createState() => _ModerationListPageState<T>();
}

class _ModerationListPageState<T extends ReportSummary> extends State<ModerationListPage<T>> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refresh = GlobalKey<RefreshIndicatorState>();
  final TextEditingController _searchText = TextEditingController();

  /// Reloads when the admin comes back to the app (new reports may be in).
  late final AppLifecycleListener _lifecycle;

  ModerationListController<T> get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _lifecycle = AppLifecycleListener(onResume: _c.load);
    _c.load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _searchText.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// Loads the next page of the All list near the bottom.
  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 400) _c.loadMore();
  }

  void _clearSearch() {
    _searchText.clear();
    _c.setSearch('');
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) => RefreshIndicator(
          key: _refresh,
          color: AdminColors.heroEnd,
          onRefresh: _c.load,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: widget.heroBuilder(_c.isLoading ? null : () => _refresh.currentState?.show()),
              ),
              SliverToBoxAdapter(child: _filters()),
              ..._body(),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filters() {
    final reported = _c.view == ModerationView.reported;
    final count = widget.reportedCount?.call() ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.extraFilter != null) ...[widget.extraFilter!, const SizedBox(height: 12)],
          SegmentedButton<ModerationView>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AdminColors.selectedBg,
              selectedForegroundColor: AdminColors.heroStart,
              foregroundColor: AdminColors.textSecondary,
            ),
            segments: [
              ButtonSegment(
                value: ModerationView.reported,
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(count > 0 ? 'Reported (${count > 99 ? '99+' : count})' : 'Reported'),
              ),
              ButtonSegment(
                value: ModerationView.all,
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: Text(widget.allLabel),
              ),
            ],
            selected: {_c.view},
            onSelectionChanged: (s) => _c.setView(s.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ModerationSearchField(
                  controller: _searchText,
                  hint: reported ? widget.reportedSearchHint : widget.allSearchHint,
                  hasText: _c.isSearching,
                  onChanged: _c.setSearch,
                  onClear: _clearSearch,
                ),
              ),
              const SizedBox(width: 10),
              ModerationSortButton(
                selected: _c.sort,
                options: _c.sortOptions,
                onSelected: _c.setSort,
                labelFor: (s) => s == ModerationSort.oldest && reported ? 'Waiting longest' : s.label,
              ),
            ],
          ),
          if (_c.isRefreshing)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(minHeight: 2, color: AdminColors.heroEnd),
            ),
        ],
      ),
    );
  }

  List<Widget> _body() {
    final items = _c.items; // searched and sorted once per build
    if (_c.isLoading) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(color: AdminColors.heroEnd)),
          ),
        ),
      ];
    }
    if (_c.error != null && items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: ModerationStateCard(
            icon: Icons.cloud_off_rounded,
            title: 'Couldn\'t load',
            message: _c.error!,
            action: TextButton.icon(
              onPressed: _c.load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ),
      ];
    }
    if (items.isEmpty) return [SliverToBoxAdapter(child: widget.emptyBuilder(_clearSearch))];

    return [
      if (_c.error != null) const SliverToBoxAdapter(child: ModerationRefreshFailedBanner()),
      if (_c.reportsCapped)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text(
              'Showing the newest ${ModerationListController.maxReports} reports. Handle some, then refresh for more.',
              style: TextStyle(fontSize: 12.5, color: AdminColors.textSecondary),
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => widget.itemBuilder(items[i]),
            childCount: items.length,
          ),
        ),
      ),
      if (_c.isLoadingMore || _c.hasMore)
        SliverToBoxAdapter(
          child: ModerationLoadMore(
            loading: _c.isLoadingMore,
            failed: _c.loadMoreFailed,
            onPressed: () => _c.loadMore(retry: true),
          ),
        ),
    ];
  }
}

/// The empty card of a moderation list: "no results" while searching
/// (with Clear search), otherwise [reportedEmpty] or [allEmpty].
class ModerationEmptyState extends StatelessWidget {
  final bool isSearching;
  final String search;
  final bool reported;
  final VoidCallback onClearSearch;

  /// "No results" message for the current view.
  final String noResultsMessage;

  /// Shown on the Reported view when nothing is waiting.
  final String reportedEmptyTitle;

  /// Shown on the All view when there is nothing at all.
  final IconData allEmptyIcon;
  final String allEmptyTitle;
  final String allEmptyMessage;

  const ModerationEmptyState({
    super.key,
    required this.isSearching,
    required this.search,
    required this.reported,
    required this.onClearSearch,
    required this.noResultsMessage,
    required this.reportedEmptyTitle,
    required this.allEmptyIcon,
    required this.allEmptyTitle,
    required this.allEmptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return ModerationStateCard(
        icon: Icons.search_off_rounded,
        title: 'No results for "${search.trim()}"',
        message: noResultsMessage,
        action: TextButton.icon(
          onPressed: onClearSearch,
          icon: const Icon(Icons.close_rounded),
          label: const Text('Clear search'),
        ),
      );
    }
    return reported
        ? ModerationStateCard(
            icon: Icons.verified_user_outlined,
            title: reportedEmptyTitle,
            message: 'Everything reported has been handled.',
          )
        : ModerationStateCard(icon: allEmptyIcon, title: allEmptyTitle, message: allEmptyMessage);
  }
}
