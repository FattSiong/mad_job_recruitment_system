import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../controllers/job_list_controller.dart';
import '../screens/job_details_screen.dart';
import 'job_card.dart';
import 'load_error_view.dart';

/// Scrolling list of [JobCard]s for a [JobListController]: [header] at the
/// top, pull to refresh, loading / error / [emptyState], and the next page
/// loaded near the end. Tapping a job opens its details.
class JobListView extends StatefulWidget {
  final JobListController controller;
  final List<Widget> header;
  final Widget emptyState;

  const JobListView({
    super.key,
    required this.controller,
    required this.emptyState,
    this.header = const [],
  });

  @override
  State<JobListView> createState() => _JobListViewState();
}

class _JobListViewState extends State<JobListView> {
  final ScrollController _scroll = ScrollController();

  JobListController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// Loads the next page when the list is scrolled near the end.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 200) _c.loadMore();
  }

  void _openJob(int index) {
    final job = _c.jobs[index];
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobDetailsScreen(job: job)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _c.load(keepList: true),
      color: AppColors.primary,
      child: ListenableBuilder(
        listenable: _c,
        builder: (context, _) => CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverList(delegate: SliverChildListDelegate(widget.header)),
            ),
            if (_c.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (_c.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: LoadErrorView(message: _c.error!, onRetry: _c.load),
              )
            else if (_c.jobs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(padding: const EdgeInsets.all(24), child: widget.emptyState),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => index == _c.jobs.length
                        ? _buildFooter()
                        : JobCard(job: _c.jobs[index], onTap: () => _openJob(index)),
                    childCount: _c.jobs.length + 1, // + the footer
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Under the last job: retry button, spinner, or "end of the list".
  Widget _buildFooter() {
    if (_c.loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: TextButton.icon(
            onPressed: _c.retryLoadMore,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text("Couldn't load more jobs. Tap to retry"),
          ),
        ),
      );
    }
    if (_c.hasMore) {
      // The footer is visible, so fetch the next page
      // (also covers short lists that can't be scrolled).
      WidgetsBinding.instance.addPostFrameCallback((_) => _c.loadMore());
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 40),
      child: Center(
        child: Text(
          "You've reached the end of the list!",
          style: TextStyle(color: Colors.grey.shade500, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
