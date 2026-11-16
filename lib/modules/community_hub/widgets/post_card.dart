import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/feed_post_model.dart';
import '../../../models/post_topic.dart';
import '../../../shared_widgets/user_avatar.dart';
import '../community_formatters.dart';
import 'community_chips.dart';
import 'post_media_view.dart';

/// Menu actions on a post.
enum PostAction { edit, publish, delete, message, report }

/// One post in a list: author, text, attachment, and like / comment / save.
/// Drafts (My Posts only) show a "Draft" tag and a Publish button instead.
class PostCard extends StatefulWidget {
  final FeedPostModel post;
  final String currentUserID;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onSave;
  final ValueChanged<PostAction> onAction;

  /// Tapping the topic label (e.g. show more posts on this topic).
  final ValueChanged<PostTopic>? onTopicTap;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserID,
    required this.onLike,
    required this.onComments,
    required this.onSave,
    required this.onAction,
    this.onTopicTap,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  static const int _collapsedLength = 280;
  bool _expanded = false;

  FeedPostModel get post => widget.post;
  bool get _isMine => post.isOwnedBy(widget.currentUserID);

  @override
  Widget build(BuildContext context) {
    final longText = post.content.length > _collapsedLength;
    final text = !longText || _expanded
        ? post.content
        : '${post.content.substring(0, _collapsedLength).trimRight()}…';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (post.topic != PostTopic.general) ...[
            const SizedBox(height: 12),
            TopicChip(
              topic: post.topic,
              onTap: widget.onTopicTap == null ? null : () => widget.onTopicTap!(post.topic),
            ),
          ],
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              text,
              style: const TextStyle(color: AppColors.textDark, fontSize: 15, height: 1.55),
            ),
            if (longText)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _expanded ? 'Show less' : 'Read more',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
          if (post.hasMedia) ...[
            const SizedBox(height: 14),
            PostMediaView(post: post),
          ],
          if (post.isRemoved) ...[
            const SizedBox(height: 14),
            _buildRemovedNotice(),
          ],
          const SizedBox(height: 16),
          if (post.isDraft) _buildDraftBar() else _buildActions(),
        ],
      ),
    );
  }

  /// Author photo, name, role, topic and time.
  Widget _buildHeader() {
    return Row(
      children: [
        UserAvatar(user: post.author, size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isMine ? '${post.author.displayName} (You)' : post.author.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (post.isDraft)
                    _pill('Draft', AppColors.warning)
                  else
                    _rolePill(post.author.role, post.author.roleLabel),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _timeLabel(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildMenu(),
      ],
    );
  }

  /// "2h", or "2h · Edited" once a published post was changed.
  String _timeLabel() {
    final time = CommunityFormatters.relative(post.createdAt);
    return post.isEdited ? '$time · Edited' : time;
  }

  /// "Employer" / "Job Seeker" label in the role's colour.
  Widget _rolePill(String role, String label) =>
      _pill(label, role == 'employer' ? AppColors.teal : AppColors.primary);

  /// Small rounded label.
  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// The ⋯ menu: publish / edit / delete for own posts, report and message for others.
  Widget _buildMenu() {
    final items = <PopupMenuEntry<PostAction>>[
      if (_isMine && post.isDraft)
        _menuItem(PostAction.publish, Icons.send_rounded, 'Publish now'),
      if (_isMine && !post.isRemoved)
        _menuItem(PostAction.edit, Icons.edit_outlined, post.isDraft ? 'Edit draft' : 'Edit post'),
      if (_isMine)
        _menuItem(PostAction.delete, Icons.delete_outline_rounded,
            post.isDraft ? 'Delete draft' : 'Delete post', danger: true),
      if (!_isMine && !post.isRemoved)
        _menuItem(PostAction.message, Icons.chat_bubble_outline_rounded, 'Message author'),
      if (!_isMine && !post.isRemoved)
        _menuItem(PostAction.report, Icons.flag_outlined, 'Report post', danger: true),
    ];
    if (items.isEmpty) return const SizedBox(width: 8);

    return PopupMenuButton<PostAction>(
      onSelected: widget.onAction,
      itemBuilder: (_) => items,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textMuted),
    );
  }

  /// One row of the ⋯ menu (red when [danger]).
  PopupMenuItem<PostAction> _menuItem(PostAction value, IconData icon, String label,
      {bool danger = false}) {
    final color = danger ? AppColors.danger : AppColors.textDark;
    return PopupMenuItem<PostAction>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  /// Red notice on a post removed by an admin.
  Widget _buildRemovedNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.danger),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Removed by an admin. Only you can see this post now, and you can still delete it.',
              style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  /// Instead of like / comment / save on a draft.
  Widget _buildDraftBar() {
    return Row(
      children: [
        const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Only you can see this draft.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        FilledButton.icon(
          onPressed: () => widget.onAction(PostAction.publish),
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Publish'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  /// Like, comment and save buttons with their counts.
  Widget _buildActions() {
    final enabled = post.isInteractive;
    return Row(
      children: [
        _actionPill(
          icon: post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: CommunityFormatters.count(post.likeCount),
          color: post.isLiked ? AppColors.coral : AppColors.textMuted,
          onTap: enabled ? widget.onLike : null,
          tooltip: post.isLiked ? 'Unlike' : 'Like',
        ),
        const SizedBox(width: 10),
        _actionPill(
          icon: Icons.chat_bubble_outline_rounded,
          label: CommunityFormatters.count(post.commentCount),
          color: AppColors.primary,
          onTap: enabled ? widget.onComments : null,
          tooltip: 'Comments',
        ),
        const Spacer(),
        _actionPill(
          icon: post.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          label: post.isSaved ? 'Saved' : 'Save',
          color: post.isSaved ? AppColors.primary : AppColors.textMuted,
          onTap: enabled ? widget.onSave : null,
          tooltip: post.isSaved ? 'Remove from saved' : 'Save post',
        ),
      ],
    );
  }

  /// One like / comment / save button (greyed out when [onTap] is null).
  Widget _actionPill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: onTap == null ? AppColors.statusInactive : color, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: onTap == null ? AppColors.statusInactive : color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
