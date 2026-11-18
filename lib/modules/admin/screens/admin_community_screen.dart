import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../models/moderation_item_model.dart';
import '../controllers/admin_community_controller.dart';
import '../controllers/moderation_list_controller.dart';
import '../widgets/moderation_card.dart';
import '../widgets/moderation_list_page.dart';
import '../widgets/moderation_list_parts.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  Future<void> _dismiss(ModerationItem item) => confirmModerationAction(
        context,
        dialog: ModerationNoteDialog(
          title: 'Dismiss reports?',
          message: item.deletedByAuthor
              ? 'The reports are closed. It stays hidden because its author deleted it.'
              : 'The reports are closed and the ${item.isPost ? 'post' : 'comment'} stays visible.',
          confirmLabel: 'Dismiss',
          confirmColor: AdminColors.heroEnd,
        ),
        action: (d) => _controller.dismiss(item, note: d.note),
        successMessage: (_) => 'Reports dismissed',
      );

  Future<void> _remove(ModerationItem item) {
    final what = item.isPost ? 'post' : 'comment';
    final done = item.isRemoved ? 'Reports closed' : (item.isPost ? 'Post removed' : 'Comment removed');
    return confirmModerationAction(
      context,
      dialog: ModerationNoteDialog(
        title: item.isRemoved
            ? 'Close these reports?'
            : item.deletedByAuthor
                ? 'Confirm removal?'
                : 'Remove this $what?',
        message: item.isRemoved
            ? 'This $what was already removed. Its remaining reports are closed as handled.'
            : item.deletedByAuthor
                ? 'Its author already deleted it. This closes the reports and records that it broke the rules.'
                : item.isPost
                    ? 'The post is hidden from everyone, with its comments. Its author sees it as removed.'
                    : 'The comment and all replies under it are hidden from everyone.',
        confirmLabel: item.isRemoved ? 'Close reports' : 'Remove',
        confirmColor: AdminColors.alertRed,
        // Only content that is still visible: its author hasn't seen anything yet
        offerNotify: !item.isRemoved && !item.deletedByAuthor,
      ),
      action: (d) => _controller.remove(item, note: d.note, notify: d.notifyAuthor),
      successMessage: (d) => d.notifyAuthor ? '$done · author told' : done,
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return ModerationListPage<ModerationItem>(
      controller: c,
      heroBuilder: _hero,
      extraFilter: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Row(
          children: [
            _pill('Posts', c.reportedPosts, c.kind == ModerationKind.post, () => c.setKind(ModerationKind.post)),
            const SizedBox(width: 12),
            _pill('Comments', c.reportedComments, c.kind == ModerationKind.comment,
                () => c.setKind(ModerationKind.comment)),
          ],
        ),
      ),
      allLabel: 'All',
      reportedSearchHint: 'Search text, author, reason…',
      allSearchHint: 'Search text or author',
      emptyBuilder: (clearSearch) {
        final what = c.kind == ModerationKind.post ? 'posts' : 'comments';
        final reported = c.view == ModerationView.reported;
        return ModerationEmptyState(
          isSearching: c.isSearching,
          search: c.search,
          reported: reported,
          onClearSearch: clearSearch,
          noResultsMessage: reported
              ? 'No reported $what match. Try another word, or search in All.'
              : 'No $what match. Try another word or a name.',
          reportedEmptyTitle: 'No reported $what',
          allEmptyIcon: Icons.forum_outlined,
          allEmptyTitle: 'No $what yet',
          allEmptyMessage: 'Published $what will appear here.',
        );
      },
      itemBuilder: (item) => ModerationCard(
        key: ValueKey('${item.kind.name}-${item.id}'),
        item: item,
        busy: c.isBusy(item),
        onRemove: () => _remove(item),
        // Already removed: only "Close reports" (Remove) is offered
        onDismiss: item.isReported && !item.isRemoved ? () => _dismiss(item) : null,
      ),
    );
  }

  Widget _hero(VoidCallback? refresh) {
    final posts = _controller.reportedPosts;
    final comments = _controller.reportedComments;
    return ModerationHero(
      labelIcon: Icons.forum_outlined,
      label: 'Community Moderation',
      title: 'Manage Interaction',
      subtitle: posts + comments == 0
          ? 'No reports waiting. Pull down to check again.'
          : '${_plural(posts, 'post')} and ${_plural(comments, 'comment')} reported and waiting for review.',
      onRefresh: refresh,
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

  static String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
}
