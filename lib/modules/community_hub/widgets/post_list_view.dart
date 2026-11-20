import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/feed_post_model.dart';
import '../../chat/chat_navigation.dart';
import '../controllers/content_report_controller.dart';
import '../controllers/post_list_controller.dart';
import '../screens/post_editor_screen.dart';
import '../screens/report_content_screen.dart';
import '../../../shared_widgets/state_message_card.dart';
import 'post_card.dart';
import 'post_comments_sheet.dart';
import '../../../shared_widgets/confirm_dialog.dart';
import '../../../shared_widgets/button_spinner.dart';

/// Scrollable list of posts for a [PostListController], with pull to refresh,
/// "load more" for the feed, and all post actions (like, save, comments,
/// edit, delete, report, message author).
class PostListView extends StatelessWidget {
  final PostListController controller;

  /// Shown above the posts (e.g. the "Start a conversation" card).
  final List<Widget> header;

  final Widget emptyState;

  /// Shown instead of [emptyState] when filters hide every post.
  final Widget? filteredEmptyState;

  /// Called after a post was edited or deleted, so other lists can reload.
  final VoidCallback? onPostsChanged;

  final EdgeInsets padding;

  const PostListView({
    super.key,
    required this.controller,
    required this.emptyState,
    this.filteredEmptyState,
    this.header = const [],
    this.onPostsChanged,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 32),
  });

  String get _me => controller.currentUserID;

  /// Red snackbar when [message] is not null.
  void _showError(BuildContext context, String? message) {
    if (message == null) return;
    SnackBarHelper.showError(context, message, duration: const Duration(seconds: 3));
  }

  /// Likes or unlikes [post].
  Future<void> _like(BuildContext context, FeedPostModel post) async {
    final error = await controller.toggleLike(post);
    if (context.mounted) _showError(context, error);
  }

  /// Saves or unsaves [post] and says so.
  Future<void> _save(BuildContext context, FeedPostModel post) async {
    final error = await controller.toggleSave(post);
    if (!context.mounted) return;
    if (error != null) {
      _showError(context, error);
    } else {
      SnackBarHelper.showStyled(
        context,
        message: post.isSaved ? 'Removed from saved posts.' : 'Saved. Find it under Saved Posts.',
        icon: post.isSaved ? Icons.bookmark_remove_outlined : Icons.bookmark_added_outlined,
        accentColor: AppColors.primary,
      );
    }
  }

  /// Opens the comments, then shows the new comment count on the card.
  Future<void> _comments(BuildContext context, FeedPostModel post) async {
    final count = await showPostComments(context, post: post, currentUserID: _me);
    controller.setCommentCount(post.postID, count);
  }

  /// Handles a choice from a post's ⋯ menu.
  Future<void> _onAction(BuildContext context, FeedPostModel post, PostAction action) async {
    switch (action) {
      case PostAction.edit:
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => PostEditorScreen(currentUserID: _me, post: post)),
        );
        if (saved == true) {
          await controller.load();
          onPostsChanged?.call();
        }
      case PostAction.publish:
        final error = await controller.publishDraft(post);
        if (!context.mounted) return;
        if (error != null) {
          _showError(context, error);
        } else {
          SnackBarHelper.showSuccess(context, 'Post published.');
          onPostsChanged?.call();
        }
      case PostAction.delete:
        final ok = await showConfirmDialog(
          context,
          title: post.isDraft ? 'Delete draft?' : 'Delete post?',
          message: post.isDraft
              ? 'This draft will be permanently deleted.'
              : 'The post, its comments and likes will be permanently deleted.',
        );
        if (!ok) return;
        final error = await controller.deletePost(post);
        if (!context.mounted) return;
        if (error != null) {
          _showError(context, error);
        } else {
          SnackBarHelper.showSuccess(context, 'Post deleted.');
          onPostsChanged?.call();
        }
      case PostAction.message:
        await openChatWith(context, post.authorID);
      case PostAction.report:
        final reported = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ReportContentScreen(
              target: ReportTarget.post,
              targetID: post.postID,
              reporterID: _me,
              preview: post.content,
            ),
          ),
        );
        // Reported posts are hidden from the reporter
        if (reported == true) controller.hidePost(post.postID);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final List<Widget> top = [...header];
        if (controller.error != null && controller.isEmpty) {
          top.add(StateMessageCard(
            icon: Icons.cloud_off_rounded,
            title: 'Unable to load posts',
            message: controller.error!,
            color: AppColors.danger,
            action: TextButton.icon(
              onPressed: controller.load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ));
        } else if (controller.isEmpty) {
          top.add(controller.isFiltered && filteredEmptyState != null
              ? filteredEmptyState!
              : emptyState);
        }

        final posts = controller.posts;
        final showFooter = controller.hasMore || controller.isLoadingMore || controller.loadMoreFailed;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: controller.load,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) controller.loadMore();
              return false;
            },
            child: ListView.builder(
              key: PageStorageKey('community-${controller.mode.name}'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              itemCount: top.length + posts.length + (showFooter ? 1 : 0),
              itemBuilder: (context, i) {
                if (i < top.length) return top[i];
                final index = i - top.length;
                if (index == posts.length) {
                  if (controller.loadMoreFailed) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: controller.retryLoadMore,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text("Couldn't load more posts. Tap to retry"),
                        ),
                      ),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: ButtonSpinner(size: 24, color: AppColors.primary),
                    ),
                  );
                }
                final post = posts[index];
                return Padding(
                  key: ValueKey(post.postID),
                  padding: const EdgeInsets.only(bottom: 16),
                  child: PostCard(
                    post: post,
                    currentUserID: _me,
                    onLike: () => _like(context, post),
                    onSave: () => _save(context, post),
                    onComments: () => _comments(context, post),
                    onAction: (a) => _onAction(context, post, a),
                    // On the feed, tapping a topic shows more posts on it.
                    onTopicTap: controller.mode == PostListMode.feed
                        ? (topic) => controller.setFilter(controller.filter.copyWith(topic: topic))
                        : null,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
