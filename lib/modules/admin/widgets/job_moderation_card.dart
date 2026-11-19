import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../core/utils/app_date_format.dart';
import '../../../models/job_moderation_item_model.dart';
import '../../community_hub/community_formatters.dart';
import 'moderation_parts.dart';

/// One job post in Admin > Jobs: the job, who posted it, the open reports,
/// and the Dismiss / Remove buttons.
class JobModerationCard extends StatelessWidget {
  final JobModerationItem item;
  final bool busy;
  final VoidCallback onRemove;
  final VoidCallback? onDismiss;

  const JobModerationCard({
    super.key,
    required this.item,
    required this.busy,
    required this.onRemove,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final flagged = item.isReported;
    final job = item.job;
    final description = job.description.trim();
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (flagged) ReportedBadge(reporterCount: item.reporterCount),
              if (item.isRemoved)
                const ModerationBadge(icon: Icons.block_rounded, label: 'Already removed', color: AdminColors.textSecondary)
              else
                ModerationBadge(icon: Icons.circle, label: item.statusLabel, color: _statusColor()),
            ],
          ),
          const SizedBox(height: 12),
          _facts(),
          const SizedBox(height: 12),
          if (description.isEmpty)
            const Text('No description.',
                style: TextStyle(fontSize: 14, color: AdminColors.textSecondary, fontStyle: FontStyle.italic))
          else
            ExpandableText(
              text: description,
              collapsedLines: 4,
              style: const TextStyle(fontSize: 14, color: AdminColors.textPrimary, height: 1.4),
            ),
          if (flagged) ...[
            const SizedBox(height: 14),
            ReportSummaryPanel(item: item),
          ],
          const SizedBox(height: 14),
          ModerationActions(
            busy: busy,
            onRemove: onRemove,
            onDismiss: onDismiss,
            removeIcon: item.isRemoved ? Icons.done_all_rounded : Icons.delete_outline_rounded,
            removeLabel: item.isRemoved ? 'Close reports' : 'Remove job',
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final flagged = item.isReported;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (flagged ? AdminColors.alertRed : AdminColors.heroEnd).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            flagged ? Icons.report_problem_rounded : Icons.work_outline_rounded,
            color: flagged ? AdminColors.alertRed : AdminColors.heroEnd,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminColors.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(
                '${item.companyName} · ${item.employer.displayName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AdminColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Salary, place / type, posted and closing dates.
  Widget _facts() {
    final job = item.job;
    final rows = <(IconData, String)>[
      (Icons.payments_outlined, job.salaryRange.trim().isEmpty ? 'Salary not given' : job.salaryRange.trim()),
      if (item.workSummary.isNotEmpty) (Icons.place_outlined, item.workSummary),
      (
        Icons.schedule_rounded,
        [
          if (job.createdAt != null) 'Posted ${CommunityFormatters.relative(job.createdAt!.toLocal())}',
          if (job.expiresAt != null) 'closes ${AppDateFormat.day.format(job.expiresAt!.toLocal())}',
          '${job.vacancies} ${job.vacancies == 1 ? 'vacancy' : 'vacancies'}',
        ].join(' · '),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (icon, text) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AdminColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(text, style: const TextStyle(fontSize: 13, color: AdminColors.textPrimary)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _statusColor() {
    switch (item.statusLabel) {
      case 'ACTIVE':
        return const Color(0xFF1D6F6A);
      case 'EXPIRED':
        return const Color(0xFFD97706);
      default:
        return AdminColors.textSecondary;
    }
  }
}
