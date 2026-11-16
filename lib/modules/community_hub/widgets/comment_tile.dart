import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/post_comment_model.dart';
import '../../../shared_widgets/user_avatar.dart';
import '../community_formatters.dart';

/// Menu actions on a comment.
enum CommentAction { edit, delete, report }

/// One comment or reply in the comments sheet.
class CommentTile extends StatelessWidget {
  final PostCommentModel comment;
  final String currentUserID;
  final VoidCallback onReply;
  final ValueChanged<CommentAction> onAction;

  const CommentTile({
    super.key,
    required this.comment,
    required this.currentUserID,
    required this.onReply,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = comment.isOwnedBy(currentUserID);
    final isReply = comment.isReply;
    final mention = comment.mention;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(user: comment.author, size: isReply ? 30 : 36),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: comment.author.displayName,
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark),
                            ),
                            TextSpan(
                              text: '  ·  ${comment.author.roleLabel}  ·  '
                                  '${CommunityFormatters.relative(comment.createdAt)}'
                                  '${comment.isEdited ? '  ·  Edited' : ''}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      height: 28,
                      child: PopupMenuButton<CommentAction>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        onSelected: onAction,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textMuted),
                        itemBuilder: (_) => [
                          if (isMine) const PopupMenuItem(value: CommentAction.edit, child: Text('Edit')),
                          if (isMine)
                            const PopupMenuItem(
                              value: CommentAction.delete,
                              child: Text('Delete', style: TextStyle(color: AppColors.danger)),
                            ),
                          if (!isMine)
                            const PopupMenuItem(
                              value: CommentAction.report,
                              child: Text('Report', style: TextStyle(color: AppColors.danger)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(color: AppColors.textDark, fontSize: 14, height: 1.45),
                      children: [
                        if (mention != null)
                          TextSpan(
                            text: '$mention ',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                        TextSpan(text: mention != null ? comment.body : comment.content),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onReply,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      'Reply',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
