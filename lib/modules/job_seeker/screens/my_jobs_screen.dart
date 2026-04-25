import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 👉 ADDED: Required for the Interviews query
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
      length: 3,
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
              Tab(text: 'Interviews'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            BookmarkedJobsTab(),
            AppliedJobsTab(),
            InterviewsTab(), // 👉 Links to the new tab at the bottom of the file
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
// APPLIED JOBS TAB
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
                          color: _getStatusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.5)),
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

// -----------------------------------------------------
// 👉 ADDED: INTERVIEWS TAB
// -----------------------------------------------------
class InterviewsTab extends StatefulWidget {
  const InterviewsTab({super.key});

  @override
  State<InterviewsTab> createState() => _InterviewsTabState();
}

class _InterviewsTabState extends State<InterviewsTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _interviews = [];

  @override
  void initState() {
    super.initState();
    _fetchInterviews();
  }

  Future<void> _fetchInterviews() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Fetches the schedule, joins the JobApplicant table to filter by the current user,
      // and joins Job + Company to get the UI display text.
      final response = await Supabase.instance.client
          .from('InterviewSchedule')
          .select('''
            *,
            JobApplicant!inner(
              seekerID,
              Job (
                title,
                Company (name)
              )
            )
          ''')
          .eq('JobApplicant.seekerID', userId)
          .order('date', ascending: true);

      if (mounted) {
        setState(() {
          _interviews = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching interviews: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
    }

    if (_interviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No scheduled interviews yet.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(UiConstants.defaultPadding),
      itemCount: _interviews.length,
      itemBuilder: (context, index) {
        final interview = _interviews[index];

        // Safely extract the nested joined data
        final applicantData = interview['JobApplicant'] as Map<String, dynamic>?;
        final jobData = applicantData?['Job'] as Map<String, dynamic>?;
        final companyData = jobData?['Company'] as Map<String, dynamic>?;

        final jobTitle = jobData?['title'] ?? 'Unknown Job';
        final companyName = companyData?['name'] ?? 'Unknown Company';
        final date = interview['date'] ?? 'N/A';
        // Substring to remove the seconds (e.g., "14:30:00" -> "14:30")
        final startTime = interview['startTime']?.toString().substring(0, 5) ?? '';
        final endTime = interview['endTime']?.toString().substring(0, 5) ?? '';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(jobTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(companyName, style: const TextStyle(fontSize: 14, color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                const Divider(height: 24, thickness: 1),

                _buildInfoRow(Icons.calendar_today, date),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.access_time, '$startTime - $endTime'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.videocam, interview['meetingMethod'] ?? 'TBA'),

                if (interview['meetingLink'] != null && interview['meetingLink'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Link: ${interview['meetingLink']}',
                    style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                  )
                ],

                if (interview['interviewNote'] != null && interview['interviewNote'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(child: Text(interview['interviewNote'], style: TextStyle(fontSize: 13, color: Colors.grey.shade800))),
                      ],
                    ),
                  )
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
      ],
    );
  }
}