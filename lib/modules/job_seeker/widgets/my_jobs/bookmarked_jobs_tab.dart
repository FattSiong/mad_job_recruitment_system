import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/job_model.dart';
import '../../controllers/bookmarked_controller.dart';
import '../../screens/job_details_screen.dart';
import '../../screens/unavailable_job_notice_screen.dart';
import '../job_card.dart';
import '../load_error_view.dart';
import 'my_jobs_empty_state.dart';

/// My Jobs > Bookmarked tab.
class BookmarkedJobsTab extends StatelessWidget {
  const BookmarkedJobsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: BookmarkedController.bookmarkNotifier,
      builder: (context, value, child) {
        return _BookmarkedJobsList(key: ValueKey(value));
      },
    );
  }
}

/// The bookmarked jobs list (built again whenever a bookmark changes).
class _BookmarkedJobsList extends StatefulWidget {
  const _BookmarkedJobsList({super.key});

  @override
  State<_BookmarkedJobsList> createState() => _BookmarkedJobsListState();
}

class _BookmarkedJobsListState extends State<_BookmarkedJobsList> {
  final BookmarkedController _bookmarkedController = BookmarkedController();
  late Future<List<JobModel>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _jobsFuture = _bookmarkedController.fetchBookmarkedJobs();
  }

  /// Loads the bookmarked jobs again.
  void _reload() {
    setState(() => _jobsFuture = _bookmarkedController.fetchBookmarkedJobs());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JobModel>>(
      future: _jobsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError) {
          return LoadErrorView(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }

        final jobs = snapshot.data ?? [];

        if (jobs.isEmpty) {
          return const MyJobsEmptyState(
            icon: Icons.bookmark_border_rounded,
            title: 'No bookmarked jobs yet',
            subtitle: 'Save roles you like so you can come back to them anytime.',
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await _bookmarkedController.ensureBookmarksLoaded(force: true);
            BookmarkedController.bookmarkNotifier.value =
            !BookmarkedController.bookmarkNotifier.value;
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              // Removed by the employer or an admin (e.g. reported as a
              // scam): don't show its details any more, only a notice.
              final removed = job.status.trim().toLowerCase() == 'deleted';
              return JobCard(
                job: job,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => removed
                          ? UnavailableJobNoticeScreen(isDeleted: true, jobTitle: job.title)
                          : JobDetailsScreen(job: job),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
