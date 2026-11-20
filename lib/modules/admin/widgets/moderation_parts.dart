import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../models/content_report_model.dart';
import '../../community_hub/community_formatters.dart';

/// Small coloured label with an icon ("Reported by 2 users", "Already removed").
class ModerationBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const ModerationBadge({super.key, required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
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
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Reported by N users" badge for an item with open reports.
class ReportedBadge extends StatelessWidget {
  final int reporterCount;

  const ReportedBadge({super.key, required this.reporterCount});

  @override
  Widget build(BuildContext context) => ModerationBadge(
        icon: Icons.report_gmailerrorred_rounded,
        label: reporterCount == 1 ? 'Reported by 1 user' : 'Reported by $reporterCount users',
        color: AdminColors.alertRed,
      );
}

/// Text cut to [collapsedLines] lines with "Show more" when it is longer.
class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int collapsedLines;

  const ExpandableText({super.key, required this.text, required this.style, this.collapsedLines = 6});

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: widget.collapsedLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final long = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            maxLines: _expanded ? null : widget.collapsedLines,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: widget.style,
          ),
          if (long)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _expanded ? 'Show less' : 'Show more',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AdminColors.heroEnd),
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// The open reports on an item: the reasons with counts, then each report
/// (reporter, reason, when, details), the newest few or all.
class ReportSummaryPanel extends StatefulWidget {
  final ReportSummary item;

  const ReportSummaryPanel({super.key, required this.item});

  @override
  State<ReportSummaryPanel> createState() => _ReportSummaryPanelState();
}

class _ReportSummaryPanelState extends State<ReportSummaryPanel> {
  static const int _collapsedReports = 3;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final reports = widget.item.reports;
    final shown = _showAll ? reports : reports.take(_collapsedReports).toList();
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
              for (final entry in widget.item.categoryCounts)
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
              onTap: () => setState(() => _showAll = !_showAll),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _showAll ? 'Show fewer reports' : 'Show all ${reports.length} reports',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AdminColors.alertRed),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dismiss (when [onDismiss] is set) and the red remove button, or a
/// spinner while an action runs.
class ModerationActions extends StatelessWidget {
  final bool busy;
  final String removeLabel;
  final IconData removeIcon;
  final VoidCallback onRemove;
  final VoidCallback? onDismiss;

  const ModerationActions({
    super.key,
    required this.busy,
    required this.removeLabel,
    required this.onRemove,
    this.removeIcon = Icons.delete_outline_rounded,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (busy) {
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
      onPressed: onRemove,
      icon: Icon(removeIcon, size: 18),
      label: Text(removeLabel),
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminColors.alertRed,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    if (onDismiss == null) {
      return Align(alignment: Alignment.centerRight, child: remove);
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onDismiss,
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
