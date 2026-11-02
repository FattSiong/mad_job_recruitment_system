import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/feed_post_model.dart';
import '../../../models/post_comment_model.dart';
import '../controllers/content_report_controller.dart';
import '../controllers/post_comments_controller.dart';
import '../screens/report_content_screen.dart';
import 'comment_tile.dart';
import 'community_state_card.dart';
import '../../../shared_widgets/confirm_dialog.dart';

/// Opens the comments of [post]. Returns the number of comments when closed,
/// so the post card can show the new count.
Future<int> showPostComments(
  BuildContext context, {
  required FeedPostModel post,
  required String currentUserID,
}) async {
  final controller = PostCommentsController(postID: post.postID, currentUserID: currentUserID)..load();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PostCommentsSheet(controller: controller),
  );
  final count = controller.isLoading || controller.error != null ? post.commentCount : controller.count;
  controller.dispose();
  return count;
}

class PostCommentsSheet extends StatefulWidget {
  final PostCommentsController controller;

  const PostCommentsSheet({super.key, required this.controller});

  @override
  State<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();

  PostCommentsController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _showError(String message) {
    SnackBarHelper.showError(context, message, duration: const Duration(seconds: 3));
  }

  Future<void> _send() async {
    final error = await _c.send(_input.text);
    if (!mounted) return;
    if (error != null) {
      _showError(error);
    } else {
      _input.clear();
    }
  }

  void _reply(PostCommentModel comment) {
    _c.startReply(comment);
    _focus.requestFocus();
  }

  Future<void> _onAction(PostCommentModel comment, CommentAction action) async {
    switch (action) {
      case CommentAction.edit:
        await _edit(comment);
      case CommentAction.delete:
        await _delete(comment);
      case CommentAction.report:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportContentScreen(
              target: ReportTarget.comment,
              targetID: comment.commentID,
              reporterID: _c.currentUserID,
              preview: comment.content,
            ),
          ),
        );
    }
  }

  Future<void> _edit(PostCommentModel comment) async {
    final editController = TextEditingController(text: comment.content);
    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Edit comment'),
        content: TextField(
          controller: editController,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
          maxLength: PostCommentsController.maxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, editController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Not disposed here: the dialog's TextField is still on screen while it closes.
    if (newText == null || newText.trim() == comment.content.trim()) return;
    final error = await _c.edit(comment, newText);
    if (error != null && mounted) _showError(error);
  }

  Future<void> _delete(PostCommentModel comment) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete comment?',
      message: 'This comment and any replies to it will be permanently deleted.',
    );
    if (!ok) return;
    final error = await _c.delete(comment);
    if (error != null && mounted) _showError(error);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) => Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildList()),
              _buildComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 6),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _c.isLoading ? 'Comments' : 'Comments (${_c.count})',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_c.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_c.error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CommunityStateCard(
            icon: Icons.cloud_off_rounded,
            title: 'Unable to load comments',
            message: _c.error!,
            color: AppColors.danger,
            action: TextButton.icon(
              onPressed: _c.load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ),
        ],
      );
    }
    if (_c.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          CommunityStateCard(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No comments yet',
            message: 'Be the first to share your thoughts on this post.',
          ),
        ],
      );
    }

    final threads = _c.threads;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _c.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        itemCount: threads.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) => _buildThread(threads[i]),
      ),
    );
  }

  Widget _buildThread(PostCommentModel comment) {
    final replies = _c.repliesOf(comment.commentID);
    final expanded = _c.isExpanded(comment.commentID);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommentTile(
          comment: comment,
          currentUserID: _c.currentUserID,
          onReply: () => _reply(comment),
          onAction: (a) => _onAction(comment, a),
        ),
        if (replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 46, top: 6),
            child: TextButton.icon(
              onPressed: () => _c.toggleThread(comment.commentID),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                expanded ? Icons.keyboard_arrow_up_rounded : Icons.subdirectory_arrow_right_rounded,
                size: 18,
              ),
              label: Text(
                expanded
                    ? 'Hide replies'
                    : 'View ${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        if (expanded)
          Container(
            margin: const EdgeInsets.only(left: 46, top: 6),
            padding: const EdgeInsets.only(left: 12),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.borderSoft, width: 2)),
            ),
            child: Column(
              children: replies
                  .map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CommentTile(
                          comment: r,
                          currentUserID: _c.currentUserID,
                          onReply: () => _reply(r),
                          onAction: (a) => _onAction(r, a),
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildComposer() {
    final replyingTo = _c.replyingTo;
    final canSend = _input.text.trim().isNotEmpty && !_c.isSending;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyingTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Replying to ${replyingTo.author.displayName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    GestureDetector(
                      onTap: _c.cancelReply,
                      child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: PostCommentsController.maxLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: replyingTo != null ? 'Write a reply…' : 'Add a comment…',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: canSend ? AppColors.primary : AppColors.borderActive,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: canSend ? _send : null,
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: _c.isSending
                          ? const Padding(
                              padding: EdgeInsets.all(13),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
