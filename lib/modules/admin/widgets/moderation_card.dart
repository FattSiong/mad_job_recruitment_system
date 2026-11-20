import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/moderation_item_model.dart';
import '../../community_hub/community_formatters.dart';
import '../../community_hub/widgets/post_media_view.dart';
import 'moderation_parts.dart';

/// One post or comment in Admin > Community: who wrote it, the content and
/// attachment, the open reports, and the Dismiss / Remove buttons.
class ModerationCard extends StatelessWidget {
  final ModerationItem item;
  final bool busy;
  final VoidCallback onRemove;
  final VoidCallback? onDismiss;

  const ModerationCard({
    super.key,
    required this.item,
    required this.busy,
    required this.onRemove,
    this.onDismiss,
  });

  ModerationItem get _item => item;

  @override
  Widget build(BuildContext context) {
    final flagged = _item.isReported;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: flagged ? AdminColors.alertRed.withValues(alpha: 0.35) : Colors.grey.shade200,
          width: flagged ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          if (_badges().isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: _badges()),
          ],
          if (!_item.isPost && (_item.postContent?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            _postContext(),
          ],
          const SizedBox(height: 12),
          _content(),
          if (_item.isPost && _item.hasMedia) ...[
            const SizedBox(height: 12),
            PostMediaView(post: _item.toFeedPost()),
          ],
          if (flagged) ...[
            const SizedBox(height: 14),
            ReportSummaryPanel(item: _item),
          ],
          const SizedBox(height: 14),
          _actions(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Parts
  // ---------------------------------------------------------------------

  Widget _header() {
    final author = _item.author;
    final photo = author.photoUrl;
    final hasPhoto = photo != null && photo.isNotEmpty;
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AdminColors.heroEnd.withValues(alpha: 0.12),
          backgroundImage: hasPhoto ? NetworkImage(photo!) : null,
          onBackgroundImageError: hasPhoto ? (_, __) {} : null, // broken photo: plain circle
          child: hasPhoto
              ? null
              : Text(author.initial,
                  style: const TextStyle(color: AdminColors.heroEnd, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                author.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AdminColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                '${author.roleLabel} · ${_item.isPost ? 'Posted' : (_item.isReply ? 'Replied' : 'Commented')} '
                '${CommunityFormatters.relative(_item.createdAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _badges() => [
        if (_item.isReported) ReportedBadge(reporterCount: _item.reporterCount),
        if (_item.deletedByAuthor)
          const ModerationBadge(
              icon: Icons.delete_sweep_outlined, label: 'Deleted by author (hidden)', color: AdminColors.textSecondary),
        if (_item.isRemoved)
          const ModerationBadge(icon: Icons.block_rounded, label: 'Already removed', color: AdminColors.textSecondary),
        if (_item.isPost) ModerationBadge(icon: _item.topic.icon, label: _item.topic.label, color: AdminColors.heroEnd),
      ];

  /// The post a comment was written on.
  Widget _postContext() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ON THE POST',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AdminColors.textSecondary, letterSpacing: 0.6)),
          const SizedBox(height: 4),
          Text(
            _item.postContent!.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AdminColors.textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    final text = _item.content.trim();
    if (text.isEmpty) {
      return Text(
        _item.hasMedia ? 'No text, only the attachment below.' : 'No text.',
        style: const TextStyle(fontSize: 14, color: AdminColors.textSecondary, fontStyle: FontStyle.italic),
      );
    }
    return ExpandableText(
      text: text,
      style: const TextStyle(fontSize: 15, color: AdminColors.textPrimary, height: 1.4),
    );
  }

  Widget _actions() => ModerationActions(
        busy: busy,
        onRemove: onRemove,
        onDismiss: onDismiss,
        removeIcon: _item.isRemoved ? Icons.done_all_rounded : Icons.delete_outline_rounded,
        removeLabel: _item.isRemoved
            ? 'Close reports'
            : _item.deletedByAuthor
                ? 'Confirm removal'
                : 'Remove',
      );
}
