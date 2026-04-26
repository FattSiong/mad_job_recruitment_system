import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/job_applicant_model.dart';
import '../../../models/job_model.dart';
import '../../../services/interview_service.dart';
import '../../community/screens/interview_lobby_screen.dart';
import '../controllers/applied_jobs_controller.dart';
import '../controllers/bookmarked_controller.dart';
import '../widgets/job_card.dart';
import 'job_details_screen.dart';

class MyJobsScreen extends StatelessWidget {
  const MyJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF163B65), Color(0xFF335D8A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.work_outline_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'My Jobs Workspace',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Track every opportunity',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Review bookmarked roles, follow your applications, and keep interview updates in one place.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const TabBar(
                            dividerColor: Colors.transparent,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicatorPadding: EdgeInsets.symmetric(horizontal: 4),
                            indicator: BoxDecoration(
                              color: Color(0xFFDCEBFB),
                              borderRadius: BorderRadius.all(Radius.circular(16)),
                            ),
                            labelColor: Color(0xFF163B65),
                            unselectedLabelColor: Color(0xFF687588),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            tabs: [
                              Tab(text: 'Bookmarked'),
                              Tab(text: 'Applied'),
                              Tab(text: 'Interviews'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: const TabBarView(
              children: [
                BookmarkedJobsTab(),
                AppliedJobsTab(),
                InterviewsTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JobModel>>(
      future: _jobsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryBlue),
          );
        }

        final jobs = snapshot.data ?? [];

        if (jobs.isEmpty) {
          return const _MyJobsEmptyState(
            icon: Icons.bookmark_border_rounded,
            title: 'No bookmarked jobs yet',
            subtitle: 'Save roles you like so you can come back to them anytime.',
          );
        }

        return RefreshIndicator(
          color: AppColors.primaryBlue,
          onRefresh: () async {
            BookmarkedController.bookmarkNotifier.value =
            !BookmarkedController.bookmarkNotifier.value;
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return JobCard(
                job: job,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JobDetailsScreen(job: job),
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
    if (mounted) {
      setState(() {
        _appliedJobs = jobs;
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFE4A73B);
      case 'scheduled':
        return const Color(0xFF4C6EF5);
      case 'interviewed':
        return const Color(0xFF7B61FF);
      case 'accepted':
        return const Color(0xFF1E8F8B);
      case 'rejected':
        return const Color(0xFFE27D60);
      case 'inactive':
        return const Color(0xFF9AA5B1);
      case 'deleted':
        return const Color(0xFF687588);
      default:
        return const Color(0xFF687588);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      );
    }

    if (_appliedJobs.isEmpty) {
      return const _MyJobsEmptyState(
        icon: Icons.assignment_ind_outlined,
        title: 'No applications yet',
        subtitle: 'Once you apply for a role, it will appear here with its latest status.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryBlue,
      onRefresh: _loadAppliedJobs,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: _appliedJobs.length,
        itemBuilder: (context, index) {
          final application =
          _appliedJobs[index]['application'] as JobApplicantModel;
          final job = _appliedJobs[index]['job'] as JobModel?;
          final isJobDeleted =
              _appliedJobs[index]['isJobDeleted'] as bool? ?? job == null;
          final isJobInactive =
              _appliedJobs[index]['isJobInactive'] as bool? ?? false;

          final status = application.applicationStatus;
          final appliedDate =
              application.appliedAt?.toIso8601String().substring(0, 10) ??
                  'Unknown date';

          final showUnavailableNotice = isJobDeleted || isJobInactive;

          final displayStatus = isJobDeleted
              ? 'deleted'
              : (isJobInactive ? 'inactive' : status);

          final statusLabel = isJobDeleted
              ? 'JOB DELETED'
              : (isJobInactive ? 'JOB INACTIVE' : status.toUpperCase());

          final statusColor = _getStatusColor(displayStatus);

          final displayTitle = isJobDeleted
              ? 'Deleted Job Post'
              : (isJobInactive
              ? (job?.title ?? 'Inactive Job Post')
              : (job?.title ?? 'Unknown Job'));

          final displayCompany = isJobDeleted
              ? 'This posting is no longer available'
              : (isJobInactive
              ? 'This job posting is inactive'
              : (job?.companyName ?? 'Unknown Company'));

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => showUnavailableNotice
                        ? _UnavailableJobNoticeScreen(
                      isDeleted: isJobDeleted,
                      jobTitle: job?.title,
                    )
                        : JobDetailsScreen(
                      job: job!,
                      disableApplyButton: true,
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.work_outline_rounded, color: statusColor),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTitle,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1B2433),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                displayCompany,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF687588),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule_outlined,
                            size: 18,
                            color: Color(0xFF687588),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Applied on $appliedDate',
                              style: const TextStyle(
                                color: Color(0xFF687588),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF687588),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
      debugPrint('Error fetching interviews: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _joinInternalInterview(String? scheduleID) async {
    if (scheduleID == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
      const Center(child: CircularProgressIndicator()),
    );

    try {
      final interviewService = InterviewService();
      final roomData = await interviewService.getRoomByScheduleId(scheduleID);

      if (mounted) Navigator.pop(context);

      if (roomData != null && mounted) {
        final String? actualRoomID =
            roomData['interviewRoomID'] ?? roomData['roomID'] ?? roomData['id'];

        if (actualRoomID != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InterviewLobbyScreen(
                roomID: actualRoomID,
                isEmployer: false,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database Error: Could not read the room ID.'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Error: Could not find interview room. The employer may not have set it up yet.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _normalizeMeetingMethod(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  String _meetingMethodLabel(String method) {
    switch (method) {
      case 'internal':
        return 'App Internal Interview';
      case 'online':
        return 'Online Interview';
      case 'offline':
        return 'Offline Interview';
      default:
        return method.isEmpty ? 'TBA' : method;
    }
  }

  IconData _meetingMethodIcon(String method) {
    switch (method) {
      case 'internal':
        return Icons.video_camera_front_rounded;
      case 'online':
        return Icons.link_rounded;
      case 'offline':
        return Icons.location_on_rounded;
      default:
        return Icons.event_note_rounded;
    }
  }

  Future<void> _launchMeetingLink(String rawValue) async {
    final value = rawValue.trim();
    if (value.isEmpty) return;

    final uri = Uri.tryParse(
      value.startsWith('http') ? value : 'https://$value',
    );

    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid meeting link.')),
      );
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open meeting link.')),
      );
    }
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      );
    }

    if (_interviews.isEmpty) {
      return const _MyJobsEmptyState(
        icon: Icons.event_busy_outlined,
        title: 'No scheduled interviews yet',
        subtitle: 'Interview invitations and meeting details will appear here when employers schedule them.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryBlue,
      onRefresh: _fetchInterviews,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: _interviews.length,
        itemBuilder: (context, index) {
          final interview = _interviews[index];

          final applicantData =
          interview['JobApplicant'] as Map<String, dynamic>?;
          final jobData = applicantData?['Job'] as Map<String, dynamic>?;
          final companyData = jobData?['Company'] as Map<String, dynamic>?;

          final jobTitle = jobData?['title'] ?? 'Unknown Job';
          final companyName = companyData?['name'] ?? 'Unknown Company';
          final date = interview['date'] ?? 'N/A';
          final startTime =
              interview['startTime']?.toString().substring(0, 5) ?? '';
          final endTime =
              interview['endTime']?.toString().substring(0, 5) ?? '';

          final meetingMethod =
          _normalizeMeetingMethod(interview['meetingMethod']);
          final meetingValue =
              interview['meetingLink']?.toString().trim() ?? '';

          final scheduleID = interview['scheduleID'] ?? interview['id'];

          final isInternal = meetingMethod == 'internal';
          final isOnline = meetingMethod == 'online';
          final isOffline = meetingMethod == 'offline';


          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4A73B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: Color(0xFFE4A73B),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            jobTitle,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B2433),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            companyName,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF687588),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoPill(
                      icon: Icons.calendar_today_rounded,
                      label: date,
                      color: const Color(0xFF163B65),
                    ),
                    _buildInfoPill(
                      icon: Icons.access_time_rounded,
                      label: '$startTime - $endTime',
                      color: const Color(0xFF1E8F8B),
                    ),
                    _buildInfoPill(
                      icon: _meetingMethodIcon(meetingMethod),
                      label: _meetingMethodLabel(meetingMethod),
                      color: const Color(0xFFE27D60),
                    ),
                  ],
                ),
                if (isInternal) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _joinInternalInterview(scheduleID),
                      icon: const Icon(Icons.meeting_room_rounded),
                      label: const Text(
                        'Enter Interview Lobby',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF163B65),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ] else if (isOnline && meetingValue.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.link_rounded,
                              size: 18,
                              color: Color(0xFF687588),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Meeting Link',
                              style: TextStyle(
                                color: Color(0xFF687588),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _launchMeetingLink(meetingValue),
                          child: Text(
                            meetingValue,
                            style: const TextStyle(
                              color: Color(0xFF163B65),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isOffline && meetingValue.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 18,
                          color: Color(0xFF687588),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Interview Location',
                                style: TextStyle(
                                  color: Color(0xFF687588),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                meetingValue,
                                style: const TextStyle(
                                  color: Color(0xFF163B65),
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (interview['interviewNote'] != null &&
                    interview['interviewNote'].toString().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: Color(0xFF687588),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            interview['interviewNote'],
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF687588),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MyJobsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MyJobsEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCEBFB),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  icon,
                  size: 34,
                  color: const Color(0xFF163B65),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B2433),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF687588),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailableJobNoticeScreen extends StatelessWidget {
  final bool isDeleted;
  final String? jobTitle;

  const _UnavailableJobNoticeScreen({
    required this.isDeleted,
    this.jobTitle,
  });

  @override
  Widget build(BuildContext context) {
    final title = isDeleted
        ? 'This job post has been deleted'
        : 'This job post is inactive';

    final message = isDeleted
        ? 'The employer removed this job posting after you applied, so the job details are no longer available.'
        : 'This job posting is no longer active. You can still review your application status in My Jobs, but this role is no longer open for viewing.';

    final badgeLabel = isDeleted ? 'Deleted Posting' : 'Inactive Posting';
    final icon = isDeleted
        ? Icons.delete_outline_rounded
        : Icons.pause_circle_outline_rounded;
    final accentColor = isDeleted
        ? const Color(0xFF687588)
        : const Color(0xFF9AA5B1);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Job Details'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B2433),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    icon,
                    size: 36,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (jobTitle != null && jobTitle!.trim().isNotEmpty) ...[
                  Text(
                    jobTitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2433),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2433),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF687588),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF163B65),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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