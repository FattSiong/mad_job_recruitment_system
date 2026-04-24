import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../models/job_model.dart';
import '../../../models/job_applicant_model.dart';
import '../controllers/bookmarked_controller.dart';
import '../controllers/applied_jobs_controller.dart';
import '../widgets/job_card.dart';
import 'job_details_screen.dart';

// 1. Changed to StatelessWidget since the Tabs handle their own state now
class MyJobsScreen extends StatelessWidget {
  const MyJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Jobs', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.primaryBlue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primaryBlue,
            tabs: [
              Tab(text: 'Bookmarked'),
              Tab(text: 'Applied'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            BookmarkedJobsTab(),
            AppliedJobsTab(),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------
// BOOKMARKED TAB
// -----------------------------------------------------
class BookmarkedJobsTab extends StatelessWidget {
  const BookmarkedJobsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // 👉 ValueListenableBuilder automatically listens to our global notifier
    return ValueListenableBuilder<bool>(
      valueListenable: BookmarkedController.bookmarkNotifier,
      builder: (context, value, child) {
        // 👉 By passing a ValueKey based on the notifier's value, we force
        // Flutter to completely DESTROY and REBUILD the list from scratch
        // every time a bookmark changes, guaranteeing fresh DB data!
        return _BookmarkedJobsList(key: ValueKey(value));
      },
    );
  }
}

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
    // Because of the ValueKey above, this initState runs fresh every time a bookmark changes globally
    _jobsFuture = _bookmarkedController.fetchBookmarkedJobs();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JobModel>>(
      future: _jobsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
        }

        final jobs = snapshot.data ?? [];

        if (jobs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('No bookmarked jobs', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Manually flip the notifier to trigger a pull-to-refresh rebuild
            BookmarkedController.bookmarkNotifier.value = !BookmarkedController.bookmarkNotifier.value;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(UiConstants.defaultPadding),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return JobCard(
                job: job,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => JobDetailsScreen(job: job)));
                },
              );
            },
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------
// APPLIED JOBS TAB (Remains exactly the same)
// -----------------------------------------------------
class AppliedJobsTab extends StatefulWidget {
  const AppliedJobsTab({super.key});
  @override
  State<AppliedJobsTab> createState() => _AppliedJobsTabState();
}

class _AppliedJobsTabState extends State<AppliedJobsTab> {
  final AppliedJobsController _appliedController = AppliedJobsController();
  List<Map<String, dynamic>> _appliedJobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppliedJobs();
  }

  Future<void> _loadAppliedJobs() async {
    final jobs = await _appliedController.fetchAppliedJobs();
    if (mounted) setState(() { _appliedJobs = jobs; _isLoading = false; });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'reviewed': return AppColors.primaryBlue;
      case 'accepted': return Colors.green;
      case 'rejected': return AppColors.errorRed;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
    if (_appliedJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_ind_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No applications yet', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAppliedJobs,
      child: ListView.builder(
        padding: const EdgeInsets.all(UiConstants.defaultPadding),
        itemCount: _appliedJobs.length,
        itemBuilder: (context, index) {
          final application = _appliedJobs[index]['application'] as JobApplicantModel;
          final job = _appliedJobs[index]['job'] as JobModel;
          final status = application.applicationStatus;
          final appliedDate = application.appliedAt?.toIso8601String().substring(0, 10) ?? 'Unknown Date';

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(job.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(job.companyName ?? 'Unknown Company', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getStatusColor(status).withOpacity(0.5)),
                        ),
                        child: Text(status.toUpperCase(), style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider()),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Applied on: $appliedDate', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}