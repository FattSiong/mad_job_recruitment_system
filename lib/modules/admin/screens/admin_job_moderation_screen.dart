import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/job_moderation_item_model.dart';
import '../controllers/admin_job_moderation_controller.dart';
import '../widgets/job_moderation_card.dart';
import '../widgets/moderation_list_parts.dart';
import '../widgets/moderation_note_dialog.dart';

/// Admin > Jobs: reported (or all) job posts, with the reasons people gave,
/// and Dismiss / Remove for each one.
class AdminJobModerationScreen extends StatefulWidget {
  const AdminJobModerationScreen({super.key});

  @override
  State<AdminJobModerationScreen> createState() => _AdminJobModerationScreenState();
}

class _AdminJobModerationScreenState extends State<AdminJobModerationScreen> {
  final AdminJobModerationController _controller = AdminJobModerationController();
  final ScrollController _scroll = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refresh = GlobalKey<RefreshIndicatorState>();
  final TextEditingController _searchText = TextEditingController();

  /// Reloads when the admin comes back to the app (new reports may be in).
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _lifecycle = AppLifecycleListener(onResume: _controller.load);
    _controller.load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _searchText.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Loads the next page of the All list near the bottom.
  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 400) _controller.loadMore();
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  Future<void> _dismiss(JobModerationItem item) async {
    final decision = await showDialog<ModerationDecision>(
      context: context,
      builder: (_) => const ModerationNoteDialog(
        title: 'Dismiss reports?',
        message: 'The reports are closed and the job stays as it is.',
        confirmLabel: 'Dismiss',
        confirmColor: AdminColors.heroEnd,
      ),
    );
    if (decision == null || !mounted) return;
    final error = await _controller.dismiss(item, note: decision.note);
    if (!mounted) return;
    if (error != null) {
      SnackBarHelper.showError(context, error, duration: const Duration(seconds: 3));
    } else {
      SnackBarHelper.showSuccess(context, 'Reports dismissed');
    }
  }

  Future<void> _remove(JobModerationItem item) async {
    final decision = await showDialog<ModerationDecision>(
      context: context,
      builder: (_) => ModerationNoteDialog(
        title: item.isRemoved ? 'Close these reports?' : 'Remove "${item.title}"?',
        message: item.isRemoved
            ? 'This job was already removed. Its remaining reports are closed as handled.'
            : 'The job is hidden from job seekers and can no longer be applied for. '
                'Its reports are closed.',
        confirmLabel: item.isRemoved ? 'Close reports' : 'Remove',
        confirmColor: AdminColors.alertRed,
        // Nobody to tell about a job that is already gone
        offerNotify: !item.isRemoved,
        notifyTitle: 'Tell the employer and applicants',
        notifySubtitle: 'The employer gets the report reasons; people who applied are told the job is no '
            'longer available. Your note is not shown.',
      ),
    );
    if (decision == null || !mounted) return;
    final error = await _controller.remove(item, note: decision.note, notifyPeople: decision.notifyAuthor);
    if (!mounted) return;
    if (error != null) {
      SnackBarHelper.showError(context, error, duration: const Duration(seconds: 3));
    } else {
      final done = item.isRemoved ? 'Reports closed' : 'Job removed';
      SnackBarHelper.showSuccess(context, decision.notifyAuthor ? '$done · employer told' : done);
    }
  }

  void _clearSearch() {
    _searchText.clear();
    _controller.setSearch('');
    FocusScope.of(context).unfocus();
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => RefreshIndicator(
          key: _refresh,
          color: AdminColors.heroEnd,
          onRefresh: _controller.load,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _hero()),
              SliverToBoxAdapter(child: _filters()),
              ..._body(),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    final waiting = _controller.reportedJobs;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AdminColors.heroStart, AdminColors.heroEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shield_outlined, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Security & Moderation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ]),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _controller.isLoading ? null : () => _refresh.currentState?.show(),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Manage Job Listings',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            waiting == 0
                ? 'No reported jobs waiting. Pull down to check again.'
                : '$waiting reported ${waiting == 1 ? 'job is' : 'jobs are'} waiting for review.',
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    final c = _controller;
    final reported = c.view == JobModerationView.reported;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<JobModerationView>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AdminColors.selectedBg,
              selectedForegroundColor: AdminColors.heroStart,
              foregroundColor: AdminColors.textSecondary,
            ),
            segments: [
              ButtonSegment(
                value: JobModerationView.reported,
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(c.reportedJobs > 0 ? 'Reported (${c.reportedJobs > 99 ? '99+' : c.reportedJobs})' : 'Reported'),
              ),
              const ButtonSegment(
                value: JobModerationView.all,
                icon: Icon(Icons.list_alt_rounded, size: 18),
                label: Text('All jobs'),
              ),
            ],
            selected: {c.view},
            onSelectionChanged: (s) => c.setView(s.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ModerationSearchField(
                  controller: _searchText,
                  hint: reported ? 'Search job, company, reason…' : 'Search job, company or employer',
                  hasText: c.isSearching,
                  onChanged: c.setSearch,
                  onClear: _clearSearch,
                ),
              ),
              const SizedBox(width: 10),
              ModerationSortButton(
                selected: c.sort,
                options: c.sortOptions,
                onSelected: c.setSort,
                labelFor: (s) => s == ModerationSort.oldest && reported ? 'Waiting longest' : s.label,
              ),
            ],
          ),
          if (c.isRefreshing)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(minHeight: 2, color: AdminColors.heroEnd),
            ),
        ],
      ),
    );
  }

  List<Widget> _body() {
    final c = _controller;
    final items = c.items; // searched and sorted once per build
    if (c.isLoading) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(color: AdminColors.heroEnd)),
          ),
        ),
      ];
    }
    if (c.error != null && items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: ModerationStateCard(
            icon: Icons.cloud_off_rounded,
            title: 'Couldn\'t load',
            message: c.error!,
            action: TextButton.icon(
              onPressed: c.load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ),
      ];
    }
    if (items.isEmpty) {
      final reported = c.view == JobModerationView.reported;
      return [
        SliverToBoxAdapter(
          child: c.isSearching
              ? ModerationStateCard(
                  icon: Icons.search_off_rounded,
                  title: 'No results for "${c.search.trim()}"',
                  message: reported
                      ? 'No reported jobs match. Try another word, or search in All jobs.'
                      : 'No jobs match. Try another word, a company or an employer name.',
                  action: TextButton.icon(
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Clear search'),
                  ),
                )
              : reported
                  ? const ModerationStateCard(
                      icon: Icons.verified_user_outlined,
                      title: 'No reported jobs',
                      message: 'Everything reported has been handled.',
                    )
                  : const ModerationStateCard(
                      icon: Icons.work_outline_rounded,
                      title: 'No job posts yet',
                      message: 'Jobs posted by employers will appear here.',
                    ),
        ),
      ];
    }
    return [
      if (c.error != null) const SliverToBoxAdapter(child: ModerationRefreshFailedBanner()),
      if (c.reportsCapped)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text(
              'Showing the newest ${AdminJobModerationController.maxReports} reports. Handle some, then refresh for more.',
              style: const TextStyle(fontSize: 12.5, color: AdminColors.textSecondary),
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final item = items[i];
              return JobModerationCard(
                key: ValueKey(item.id),
                item: item,
                busy: c.isBusy(item),
                onRemove: () => _remove(item),
                // Already removed: only "Close reports" (Remove) is offered
                onDismiss: item.isReported && !item.isRemoved ? () => _dismiss(item) : null,
              );
            },
            childCount: items.length,
          ),
        ),
      ),
      if (c.isLoadingMore || c.hasMore)
        SliverToBoxAdapter(
          child: ModerationLoadMore(
            loading: c.isLoadingMore,
            failed: c.loadMoreFailed,
            onPressed: () => c.loadMore(retry: true),
          ),
        ),
    ];
  }
}
