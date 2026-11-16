import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/moderation_item_model.dart';
import '../../community_hub/community_formatters.dart';
import '../../community_hub/widgets/post_media_view.dart';

/// One post or comment in Admin > Community: who wrote it, the content and
/// attachment, the open reports, and the Dismiss / Remove buttons.
class ModerationCard extends StatefulWidget {
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

  @override
  State<ModerationCard> createState() => _ModerationCardState();
}

class _ModerationCardState extends State<ModerationCard> {
  static const int _collapsedLines = 6;
  static const int _collapsedReports = 3;

  bool _showFullText = false;
  bool _showAllReports = false;

  ModerationItem get _item => widget.item;

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
            _reports(),
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
        if (_item.isReported)
          _badge(
            Icons.report_gmailerrorred_rounded,
            _item.reporterCount == 1 ? 'Reported by 1 user' : 'Reported by ${_item.reporterCount} users',
            AdminColors.alertRed,
          ),
        if (_item.deletedByAuthor)
          _badge(Icons.delete_sweep_outlined, 'Deleted by author (hidden)', AdminColors.textSecondary),
        if (_item.isPost) _badge(_item.topic.icon, _item.topic.label, AdminColors.heroEnd),
      ];

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

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
    return LayoutBuilder(builder: (context, constraints) {
      const style = TextStyle(fontSize: 15, color: AdminColors.textPrimary, height: 1.4);
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: _collapsedLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final long = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            maxLines: _showFullText ? null : _collapsedLines,
            overflow: _showFullText ? TextOverflow.visible : TextOverflow.ellipsis,
            style: style,
          ),
          if (long)
            GestureDetector(
              onTap: () => setState(() => _showFullText = !_showFullText),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _showFullText ? 'Show less' : 'Show more',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AdminColors.heroEnd),
                ),
              ),
            ),
        ],
      );
    });
  }

  /// Reasons, then each report (the newest few, or all).
  Widget _reports() {
    final reports = _item.reports;
    final shown = _showAllReports ? reports : reports.take(_collapsedReports).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.alertRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in _item.categoryCounts)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AdminColors.alertRed.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    entry.value > 1 ? '${entry.key} ×${entry.value}' : entry.key,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminColors.alertRed),
                  ),
                ),
            ],
          ),
          for (final report in shown) ...[
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: report.reporter?.displayName ?? 'Unknown user',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' · ${report.category} · ${CommunityFormatters.relative(report.reportedAt)}'),
              ]),
              style: const TextStyle(fontSize: 12.5, color: AdminColors.textPrimary),
            ),
            if (report.details != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '"${report.details}"',
                  style: const TextStyle(fontSize: 12.5, color: AdminColors.textSecondary, height: 1.35),
                ),
              ),
          ],
          if (reports.length > _collapsedReports)
            GestureDetector(
              onTap: () => setState(() => _showAllReports = !_showAllReports),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _showAllReports ? 'Show fewer reports' : 'Show all ${reports.length} reports',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AdminColors.alertRed),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions() {
    if (widget.busy) {
      return const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: AdminColors.heroEnd),
          ),
        ),
      );
    }
    final remove = ElevatedButton.icon(
      onPressed: widget.onRemove,
      icon: const Icon(Icons.delete_outline_rounded, size: 18),
      label: Text(_item.deletedByAuthor ? 'Confirm removal' : 'Remove'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminColors.alertRed,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    if (widget.onDismiss == null) {
      return Align(alignment: Alignment.centerRight, child: remove);
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.onDismiss,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text('Dismiss'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.heroEnd,
              side: BorderSide(color: AdminColors.heroEnd.withValues(alpha: 0.4)),
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: remove),
      ],
    );
  }
}
