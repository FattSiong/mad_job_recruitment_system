import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../models/job_moderation_item_model.dart';
import '../controllers/admin_job_moderation_controller.dart';
import '../controllers/moderation_list_controller.dart';
import '../widgets/job_moderation_card.dart';
import '../widgets/moderation_list_page.dart';
import '../widgets/moderation_list_parts.dart';
import '../widgets/moderation_note_dialog.dart';

/// Admin > Jobs: reported (or all) job posts, with the reasons people gave,
/// and Dismiss / Remove for each one.
class AdminJobModerationScreen extends StatefulWidget {
  const AdminJobModerationScreen({super.key});

  @override
  State<AdminJobModerationScreen> createState() => _AdminJobModerationScreenState();
}

class _AdminJobModerationScreenState extends State<AdminJobModerationScreen> {
  final AdminJobModerationController _controller = AdminJobModerationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  Future<void> _dismiss(JobModerationItem item) => confirmModerationAction(
        context,
        dialog: const ModerationNoteDialog(
          title: 'Dismiss reports?',
          message: 'The reports are closed and the job stays as it is.',
          confirmLabel: 'Dismiss',
          confirmColor: AdminColors.heroEnd,
        ),
        action: (d) => _controller.dismiss(item, note: d.note),
        successMessage: (_) => 'Reports dismissed',
      );

  Future<void> _remove(JobModerationItem item) {
    final done = item.isRemoved ? 'Reports closed' : 'Job removed';
    return confirmModerationAction(
      context,
      dialog: ModerationNoteDialog(
        title: item.isRemoved ? 'Close these reports?' : 'Remove "${item.title}"?',
        message: item.isRemoved
            ? 'This job was already removed. Its remaining reports are closed as handled.'
            : 'The job is hidden from job seekers and can no longer be applied for. '
                'Its reports are closed.',
        confirmLabel: item.isRemoved ? 'Close reports' : 'Remove',
        confirmColor: AdminColors.alertRed,
        // Nobody to tell about a job that is already gone
        offerNotify: !item.isRemoved,
        notifyTitle: 'Tell the employer and applicants',
        notifySubtitle: 'The employer gets the report reasons; people who applied are told the job is no '
            'longer available. Your note is not shown.',
      ),
      action: (d) => _controller.remove(item, note: d.note, notify: d.notifyAuthor),
      successMessage: (d) => d.notifyAuthor ? '$done · employer told' : done,
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return ModerationListPage<JobModerationItem>(
      controller: c,
      heroBuilder: _hero,
      allLabel: 'All jobs',
      reportedCount: () => c.reportedJobs,
      reportedSearchHint: 'Search job, company, reason…',
      allSearchHint: 'Search job, company or employer',
      emptyBuilder: (clearSearch) {
        final reported = c.view == ModerationView.reported;
        return ModerationEmptyState(
          isSearching: c.isSearching,
          search: c.search,
          reported: reported,
          onClearSearch: clearSearch,
          noResultsMessage: reported
              ? 'No reported jobs match. Try another word, or search in All jobs.'
              : 'No jobs match. Try another word, a company or an employer name.',
          reportedEmptyTitle: 'No reported jobs',
          allEmptyIcon: Icons.work_outline_rounded,
          allEmptyTitle: 'No job posts yet',
          allEmptyMessage: 'Jobs posted by employers will appear here.',
        );
      },
      itemBuilder: (item) => JobModerationCard(
        key: ValueKey(item.id),
        item: item,
        busy: c.isBusy(item),
        onRemove: () => _remove(item),
        // Already removed: only "Close reports" (Remove) is offered
        onDismiss: item.isReported && !item.isRemoved ? () => _dismiss(item) : null,
      ),
    );
  }

  Widget _hero(VoidCallback? refresh) {
    final waiting = _controller.reportedJobs;
    return ModerationHero(
      labelIcon: Icons.shield_outlined,
      label: 'Security & Moderation',
      title: 'Manage Job Listings',
      subtitle: waiting == 0
          ? 'No reported jobs waiting. Pull down to check again.'
          : '$waiting reported ${waiting == 1 ? 'job is' : 'jobs are'} waiting for review.',
      onRefresh: refresh,
    );
  }
}
