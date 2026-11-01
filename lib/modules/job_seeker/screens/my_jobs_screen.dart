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
import '../widgets/load_error_view.dart';
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
            child: CircularProgressIndicator(color: AppColors.primaryBlue),
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
          return const _MyJobsEmptyState(
            icon: Icons.bookmark_border_rounded,
            title: 'No bookmarked jobs yet',
            subtitle: 'Save roles you like so you can come back to them anytime.',
          );
        }

        return RefreshIndicator(
          color: AppColors.primaryBlue,
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
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadAppliedJobs();
    // Reload after applying for a job or when the My Jobs tab is opened
    AppliedJobsController.refreshSignal.addListener(_loadAppliedJobs);
  }

  @override
  void dispose() {
    AppliedJobsController.refreshSignal.removeListener(_loadAppliedJobs);
    super.dispose();
  }

  Future<void> _loadAppliedJobs() async {
    try {
      final jobs = await _appliedController.fetchAppliedJobs();
      if (mounted) {
        setState(() {
          _appliedJobs = jobs;
          _loadError = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _retry() {
    setState(() => _isLoading = true);
    _loadAppliedJobs();
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

    if (_loadError != null) {
      return LoadErrorView(message: _loadError!, onRetry: _retry);
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
  String? _loadError;
  List<Map<String, dynamic>> _interviews = [];

  @override
  void initState() {
    super.initState();
    _fetchInterviews();
    AppliedJobsController.refreshSignal.addListener(_fetchInterviews);
  }

  @override
  void dispose() {
    AppliedJobsController.refreshSignal.removeListener(_fetchInterviews);
    super.dispose();
  }

  void _retry() {
    setState(() => _isLoading = true);
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
          _loadError = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching interviews: $e');
      if (mounted) {
        setState(() {
          _loadError =
              'Unable to load your interviews. Please check your connection and try again.';
          _isLoading = false;
        });
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
              content: Text('This interview room isn\'t ready yet. Please try again shortly.'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'The interview room isn\'t available yet. The employer may not have opened it.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        debugPrint('Join interview error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to join the interview right now. Please try again.'),
          ),
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

  Future<void> _respondToInterview({
    required String scheduleID,
    required bool accept,
    String? rejectionReason,
    String? preferredTime,
  }) async {
    final success = await InterviewService().respondToInterviewSchedule(
      scheduleID: scheduleID,
      accept: accept,
      rejectionReason: rejectionReason,
      preferredTime: preferredTime,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Interview confirmed! You can now join at the scheduled time.'
                : 'Interview declined. Your reason and preferred time have been sent to the employer.',
          ),
          backgroundColor: accept ? Colors.green : const Color(0xFF687588),
        ),
      );
      await _fetchInterviews();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit your response. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDateLabel(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String _format24Hour(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showRejectDialog(String scheduleID) async {
    final reasonController = TextEditingController();
    DateTime? preferredDate;
    TimeOfDay? preferredStart;
    TimeOfDay? preferredEnd;
    String? reasonError;
    String? timeError;

    final Map<String, String>? result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> pickPreferredDate() async {
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate:
                    preferredDate ?? DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setDialogState(() {
                  preferredDate = picked;
                  timeError = null;
                });
              }
            }

            Future<void> pickPreferredTime({required bool isStart}) async {
              final picked = await showTimePicker(
                context: dialogContext,
                initialTime: isStart
                    ? (preferredStart ?? const TimeOfDay(hour: 10, minute: 0))
                    : (preferredEnd ?? const TimeOfDay(hour: 11, minute: 0)),
              );
              if (picked != null) {
                setDialogState(() {
                  if (isStart) {
                    preferredStart = picked;
                  } else {
                    preferredEnd = picked;
                  }
                  timeError = null;
                });
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDECEC),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.event_busy_rounded,
                              color: Color(0xFFC24E4E),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Decline & Propose Time',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B2433),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Please share why this slot does not work for you and select your preferred date and time for rescheduling.',
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: Color(0xFF687588),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: reasonController,
                        maxLines: 3,
                        onChanged: (_) {
                          if (reasonError != null) {
                            setDialogState(() => reasonError = null);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Reason for Declining',
                          hintText:
                              'e.g. I have a scheduled lecture / prior commitment at this time.',
                          alignLabelWithHint: true,
                          errorText: reasonError,
                          filled: true,
                          fillColor: const Color(0xFFF7F9FC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFF163B65),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Preferred Date & Time',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B2433),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: pickPreferredDate,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: Color(0xFF163B65),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    preferredDate == null
                                        ? 'Select Preferred Date'
                                        : _formatDateLabel(preferredDate!),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: preferredDate == null
                                          ? const Color(0xFF687588)
                                          : const Color(0xFF1B2433),
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.expand_more_rounded,
                                  color: Color(0xFF9AA5B5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Material(
                              color: const Color(0xFFF7F9FC),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: () => pickPreferredTime(isStart: true),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 13,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.schedule_rounded,
                                        size: 17,
                                        color: Color(0xFF163B65),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          preferredStart == null
                                              ? 'Start Time'
                                              : preferredStart!
                                                  .format(dialogContext),
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: preferredStart == null
                                                ? const Color(0xFF687588)
                                                : const Color(0xFF1B2433),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Material(
                              color: const Color(0xFFF7F9FC),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: () => pickPreferredTime(isStart: false),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 13,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.timelapse_rounded,
                                        size: 17,
                                        color: Color(0xFF163B65),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          preferredEnd == null
                                              ? 'End Time'
                                              : preferredEnd!
                                                  .format(dialogContext),
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: preferredEnd == null
                                                ? const Color(0xFF687588)
                                                : const Color(0xFF1B2433),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (timeError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          timeError!,
                          style: const TextStyle(
                            color: Color(0xFFC24E4E),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF687588),
                                side:
                                    const BorderSide(color: Color(0xFFD6DEE8)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final text = reasonController.text.trim();
                                bool hasError = false;

                                if (text.isEmpty) {
                                  reasonError =
                                      'Please provide a reason before declining.';
                                  hasError = true;
                                }

                                if (preferredDate == null ||
                                    preferredStart == null ||
                                    preferredEnd == null) {
                                  timeError =
                                      'Please select your preferred date, start time, and end time.';
                                  hasError = true;
                                } else {
                                  final startMinutes =
                                      preferredStart!.hour * 60 +
                                          preferredStart!.minute;
                                  final endMinutes = preferredEnd!.hour * 60 +
                                      preferredEnd!.minute;
                                  if (endMinutes <= startMinutes) {
                                    timeError =
                                        'End time must be after start time.';
                                    hasError = true;
                                  }
                                }

                                if (hasError) {
                                  setDialogState(() {});
                                  return;
                                }

                                final dateIso = preferredDate!
                                    .toIso8601String()
                                    .split('T')[0];
                                final formattedPreferred =
                                    '$dateIso | ${_format24Hour(preferredStart!)} - ${_format24Hour(preferredEnd!)}';

                                Navigator.pop(dialogContext, {
                                  'reason': text,
                                  'preferredTime': formattedPreferred,
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC24E4E),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Submit',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && (result['reason'] ?? '').isNotEmpty) {
      await _respondToInterview(
        scheduleID: scheduleID,
        accept: false,
        rejectionReason: result['reason'],
        preferredTime: result['preferredTime'],
      );
    }
  }

  Widget _buildCandidateStatusBadge(String status) {
    final normalized = status.toLowerCase();
    final Color bg;
    final Color fg;
    final String label;
    final IconData icon;

    switch (normalized) {
      case 'accepted':
        bg = const Color(0xFFE5F6ED);
        fg = const Color(0xFF2D8A5D);
        label = 'Accepted';
        icon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        bg = const Color(0xFFFDECEC);
        fg = const Color(0xFFC24E4E);
        label = 'Declined';
        icon = Icons.cancel_rounded;
        break;
      default:
        bg = const Color(0xFFFEF3DC);
        fg = const Color(0xFFC28A22);
        label = 'Pending Confirmation';
        icon = Icons.hourglass_top_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
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

    if (_loadError != null) {
      return LoadErrorView(message: _loadError!, onRetry: _retry);
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

          final scheduleID = (interview['scheduleID'] ?? interview['id'])?.toString();

          final candidateStatus =
              (interview['candidateStatus'] ??
                      interview['candidatestatus'] ??
                      'pending')
                  .toString()
                  .toLowerCase();
          final rejectionReason =
              (interview['rejectionReason'] ?? interview['rejectionreason'])
                  ?.toString()
                  .trim();
          final preferredTime =
              (interview['preferredTime'] ?? interview['preferredtime'])
                  ?.toString()
                  .trim();

          final isPendingResponse = candidateStatus == 'pending';
          final isAcceptedResponse = candidateStatus == 'accepted';
          final isRejectedResponse = candidateStatus == 'rejected';

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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(width: 8),
                    _buildCandidateStatusBadge(candidateStatus),
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
                if (isOnline && meetingValue.isNotEmpty) ...[
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
                if (isPendingResponse && scheduleID != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF6E6),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFF5D491)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          size: 18,
                          color: Color(0xFFB47814),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Please confirm whether you can attend this scheduled interview slot.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8C5B08),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRejectDialog(scheduleID),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text(
                            'Reject',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFC24E4E),
                            side: const BorderSide(color: Color(0xFFF1C5C5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _respondToInterview(
                            scheduleID: scheduleID,
                            accept: true,
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text(
                            'Accept',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D8A5D),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (isAcceptedResponse && isInternal) ...[
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
                ] else if (isRejectedResponse) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFF3B8B8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.report_problem_outlined,
                              size: 18,
                              color: Color(0xFFC24E4E),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'You Declined This Time Slot',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFC24E4E),
                              ),
                            ),
                          ],
                        ),
                        if (rejectionReason != null &&
                            rejectionReason.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Your reason: "$rejectionReason"',
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF7A2C2C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (preferredTime != null &&
                            preferredTime.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.event_available_rounded,
                                  size: 16,
                                  color: Color(0xFF163B65),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Preferred time: $preferredTime',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF163B65),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        const Text(
                          'Waiting for the employer to propose a new interview time.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7A2C2C),
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