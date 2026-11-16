import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/moderation_item_model.dart';
import '../controllers/admin_community_controller.dart';
import '../widgets/moderation_card.dart';
import '../widgets/moderation_note_dialog.dart';

/// Admin > Community: reported (or all) posts and comments, with the
/// reasons people gave, and Dismiss / Remove for each one.
class AdminCommunityScreen extends StatefulWidget {
  const AdminCommunityScreen({super.key});

  @override
  State<AdminCommunityScreen> createState() => _AdminCommunityScreenState();
}

class _AdminCommunityScreenState extends State<AdminCommunityScreen> {
  final AdminCommunityController _controller = AdminCommunityController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _controller.load();
  }

  @override
  void dispose() {
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

  Future<void> _dismiss(ModerationItem item) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => ModerationNoteDialog(
        title: 'Dismiss reports?',
        message: item.deletedByAuthor
            ? 'The reports are closed. It stays hidden because its author deleted it.'
            : 'The reports are closed and the ${item.isPost ? 'post' : 'comment'} stays visible.',
        confirmLabel: 'Dismiss',
        confirmColor: AdminColors.heroEnd,
      ),
    );
    if (note == null || !mounted) return;
    final error = await _controller.dismiss(item, note: note);
    if (!mounted) return;
    if (error != null) {
      SnackBarHelper.showError(context, error, duration: const Duration(seconds: 3));
    } else {
      SnackBarHelper.showSuccess(context, 'Reports dismissed');
    }
  }

  Future<void> _remove(ModerationItem item) async {
    final what = item.isPost ? 'post' : 'comment';
    final note = await showDialog<String>(
      context: context,
      builder: (_) => ModerationNoteDialog(
        title: item.deletedByAuthor ? 'Confirm removal?' : 'Remove this $what?',
        message: item.deletedByAuthor
            ? 'Its author already deleted it. This closes the reports and records that it broke the rules.'
            : item.isPost
                ? 'The post is hidden from everyone, with its comments. Its author sees it as removed.'
                : 'The comment and all replies under it are hidden from everyone.',
        confirmLabel: 'Remove',
        confirmColor: AdminColors.alertRed,
      ),
    );
    if (note == null || !mounted) return;
    final error = await _controller.remove(item, note: note);
    if (!mounted) return;
    if (error != null) {
      SnackBarHelper.showError(context, error, duration: const Duration(seconds: 3));
    } else {
      SnackBarHelper.showSuccess(context, item.isPost ? 'Post removed' : 'Comment removed');
    }
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
    final posts = _controller.reportedPosts;
    final comments = _controller.reportedComments;
    final waiting = posts + comments;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AdminColors.heroStart, AdminColors.heroEnd]),
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
                  Icon(Icons.forum_outlined, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Community Moderation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ]),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _controller.isLoading ? null : _controller.load,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Manage Interaction',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            waiting == 0
                ? 'No reports waiting. Pull down to check again.'
                : '${_plural(posts, 'post')} and ${_plural(comments, 'comment')} reported and waiting for review.',
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pill('Posts', _controller.reportedPosts, _controller.kind == ModerationKind.post,
                  () => _controller.setKind(ModerationKind.post)),
              const SizedBox(width: 12),
              _pill('Comments', _controller.reportedComments, _controller.kind == ModerationKind.comment,
                  () => _controller.setKind(ModerationKind.comment)),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<ModerationView>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AdminColors.selectedBg,
              selectedForegroundColor: AdminColors.heroStart,
              foregroundColor: AdminColors.textSecondary,
            ),
            segments: const [
              ButtonSegment(value: ModerationView.reported, icon: Icon(Icons.flag_outlined, size: 18), label: Text('Reported')),
              ButtonSegment(value: ModerationView.all, icon: Icon(Icons.list_alt_rounded, size: 18), label: Text('All')),
            ],
            selected: {_controller.view},
            onSelectionChanged: (s) => _controller.setView(s.first),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, int count, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AdminColors.selectedBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AdminColors.heroEnd.withValues(alpha: 0.2) : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: selected ? AdminColors.heroStart : AdminColors.textSecondary,
                    fontWeight: FontWeight.bold)),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AdminColors.alertRed, borderRadius: BorderRadius.circular(10)),
                child: Text(count > 99 ? '99+' : '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _body() {
    final c = _controller;
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
    if (c.error != null && c.items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _stateCard(
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
    if (c.items.isEmpty) {
      final what = c.kind == ModerationKind.post ? 'posts' : 'comments';
      return [
        SliverToBoxAdapter(
          child: c.view == ModerationView.reported
              ? _stateCard(
                  icon: Icons.verified_user_outlined,
                  title: 'No reported $what',
                  message: 'Everything reported has been handled.',
                )
              : _stateCard(
                  icon: Icons.forum_outlined,
                  title: 'No $what yet',
                  message: 'Published $what will appear here.',
                ),
        ),
      ];
    }
    return [
      if (c.reportsCapped)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text(
              'Showing the newest ${AdminCommunityController.maxReports} reports. Handle some, then refresh for more.',
              style: const TextStyle(fontSize: 12.5, color: AdminColors.textSecondary),
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final item = c.items[i];
              return ModerationCard(
                key: ValueKey('${item.kind.name}-${item.id}'),
                item: item,
                busy: c.isBusy(item),
                onRemove: () => _remove(item),
                onDismiss: item.isReported ? () => _dismiss(item) : null,
              );
            },
            childCount: c.items.length,
          ),
        ),
      ),
      if (c.isLoadingMore || c.hasMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: c.isLoadingMore
                  ? const CircularProgressIndicator(color: AdminColors.heroEnd)
                  : TextButton(onPressed: c.loadMore, child: const Text('Load more')),
            ),
          ),
        ),
    ];
  }

  Widget _stateCard({required IconData icon, required String title, required String message, Widget? action}) {
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
          if (action != null) ...[const SizedBox(height: 8), action],
        ],
      ),
    );
  }

  static String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
}
