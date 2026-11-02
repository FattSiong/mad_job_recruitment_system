import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/interview_schedule_model.dart';
import '../../../models/post_interview_report_model.dart';
import 'post_interview_ai_report_screen.dart';
import '../../../services/employer_service.dart';
import '../../../services/interview_service.dart';
import '../../community/screens/interview_lobby_screen.dart';
import 'interview_scheduling_screen.dart';

class ScheduledInterviewsScreen extends StatefulWidget {
  const ScheduledInterviewsScreen({super.key});

  @override
  State<ScheduledInterviewsScreen> createState() =>
      _ScheduledInterviewsScreenState();
}

class _ScheduledInterviewsScreenState extends State<ScheduledInterviewsScreen> {
  final _employerService = EmployerService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _interviews = [];
  Map<String, PostInterviewReportModel> _reportsByScheduleId = {};

  @override
  void initState() {
    super.initState();
    _loadInterviews();
  }

  Future<void> _loadInterviews() async {
    setState(() => _isLoading = true);
    final data = await _employerService.getScheduledInterviews();
    final scheduleIds = data
        .map((e) => (e['scheduleID'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
    final reportsMap = await _employerService
        .getPostInterviewReportsForSchedules(scheduleIds);

    if (mounted) {
      setState(() {
        _reportsByScheduleId = reportsMap;
        _interviews = data.where((item) {
          final applicant = item['JobApplicant'] ?? {};
          final job = applicant['Job'] ?? {};
          final jobStatus = (job['status'] ?? '').toString().toLowerCase();

          return applicant['applicationStatus'] == 'scheduled' &&
              jobStatus != 'deleted';
        }).toList();

        _isLoading = false;
      });
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(
      urlString.startsWith('http') ? urlString : 'https://$urlString',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open meeting link')),
        );
      }
    }
  }

  Future<void> _pushLobbyAndRefresh(
    BuildContext navContext,
    Route<dynamic> route,
  ) async {
    await Navigator.push(navContext, route);
    if (mounted) {
      await _loadInterviews();
    }
  }

  Future<void> _startInternalInterview(String? scheduleID) async {
    if (scheduleID == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final interviewService = InterviewService();
      final roomData = await interviewService.getRoomByScheduleId(scheduleID);

      if (mounted) Navigator.pop(context);

      if (roomData != null && mounted) {
        final String? actualRoomID =
            roomData['interviewRoomID'] ?? roomData['roomID'] ?? roomData['id'];

        if (actualRoomID != null) {
          await _pushLobbyAndRefresh(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  InterviewLobbyScreen(roomID: actualRoomID, isEmployer: true),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Database Error: Could not read the room ID column.',
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Could not find interview room.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _openReschedule({
    required String applicantId,
    required String candidateName,
    required String seekerId,
    String? preferredTime,
    String? rejectionReason,
  }) async {
    if (seekerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not identify candidate profile for rescheduling.'),
        ),
      );
      return;
    }

    final didSchedule = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InterviewSchedulingScreen(
          applicantId: applicantId,
          applicantName: candidateName,
          seekerId: seekerId,
          initialPreferredTime: preferredTime,
          rejectionReason: rejectionReason,
        ),
      ),
    );

    if (didSchedule == true && mounted) {
      await _loadInterviews();
    }
  }

  Future<void> _markAsCompleted(String applicantId, String? scheduleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Completed?'),
        content: const Text(
          'This will permanently close the interview room and update the candidate\'s ATS status to "Interviewed".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final success = await _employerService.markInterviewAsCompleted(
      applicantId,
      scheduleId,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interview marked as completed!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadInterviews();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getMonthAbbr(int month) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 16),
                  _buildHeroCard(),
                  const SizedBox(height: 24),
                  if (_interviews.isEmpty)
                    _buildEmptyState()
                  else ...[
                    _buildSectionHeader(),
                    const SizedBox(height: 16),
                    ..._interviews.map((data) {
                      final schedule = InterviewScheduleModel.fromJson(data);

                      final applicant = data['JobApplicant'] ?? {};
                      final applicantId =
                          (applicant['applicantID'] ?? '').toString();
                      final seekerId =
                          (applicant['seekerID'] ?? '').toString();
                      final seeker = applicant['JobSeeker'] ?? {};
                      final jobPost = applicant['Job'] ?? {};

                      final candidateName =
                          seeker['fullName'] ?? 'Unknown Candidate';
                      final jobTitle = jobPost['title'] ?? 'Unknown Job';

                      final timeString =
                          '${schedule.startTime.format(context)} - ${schedule.endTime.format(context)}';
                      final isOnline = schedule.meetingMethod == 'online';
                      final isInternal = schedule.meetingMethod == 'internal';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildInterviewCard(
                          schedule: schedule,
                          candidateName: candidateName,
                          jobTitle: jobTitle,
                          applicantId: applicantId,
                          seekerId: seekerId,
                          timeString: timeString,
                          isOnline: isOnline,
                          isInternal: isInternal,
                        ),
                      );
                    }),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.arrow_back_rounded, color: Color(0xFF163B65)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Scheduled Interviews',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
        ),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: _loadInterviews,
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.refresh_rounded, color: Color(0xFF163B65)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  'Interview Pipeline',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _interviews.isEmpty
                ? 'No upcoming interviews'
                : '${_interviews.length} interview${_interviews.length > 1 ? 's' : ''} currently scheduled',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Track candidate confirmations, review reschedule requests, and launch accepted calls.',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interview Schedule',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B2433),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Check whether the candidate has accepted the proposed time before starting the interview.',
          style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF687588)),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFDCEBFB),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              size: 36,
              color: Color(0xFF163B65),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No upcoming interviews scheduled',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'When candidates are scheduled for interview, they will appear here for quick access.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF687588),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateResponseBadge(String status) {
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
        label = 'Awaiting Candidate';
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

  Widget _buildInterviewCard({
    required InterviewScheduleModel schedule,
    required String candidateName,
    required String jobTitle,
    required String applicantId,
    required String seekerId,
    required String timeString,
    required bool isOnline,
    required bool isInternal,
  }) {
    final String month = _getMonthAbbr(schedule.date.month);
    final String candidateStatus = schedule.candidateStatus.toLowerCase();
    final bool isAccepted = candidateStatus == 'accepted';
    final bool isRejected = candidateStatus == 'rejected';
    final bool isPending = !isAccepted && !isRejected;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF163B65),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Text(
                        month,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        schedule.date.day.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidateName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B2433),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        jobTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF687588),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildCandidateResponseBadge(candidateStatus),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildInterviewInfoRow(
              icon: Icons.access_time_rounded,
              text: timeString,
            ),
            const SizedBox(height: 10),
            _buildInterviewInfoRow(
              icon: isInternal
                  ? Icons.video_camera_front_rounded
                  : (isOnline
                      ? Icons.videocam_rounded
                      : Icons.location_on_rounded),
              text: isInternal
                  ? 'App Internal Interview'
                  : (schedule.meetingLink ?? 'No link provided'),
            ),
            if (schedule.scheduleID != null &&
                _reportsByScheduleId[schedule.scheduleID!] != null) ...[
              const SizedBox(height: 14),
              _buildAiReportBanner(_reportsByScheduleId[schedule.scheduleID!]!),
            ],
            if (isPending) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF6E6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF5D491)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 18,
                      color: Color(0xFFB47814),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Waiting for the candidate to accept this interview schedule before the session can start.',
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
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openReschedule(
                    applicantId: applicantId,
                    candidateName: candidateName,
                    seekerId: seekerId,
                  ),
                  icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                  label: const Text('Change Proposed Time'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF163B65),
                    side: const BorderSide(color: Color(0xFF163B65)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ] else if (isRejected) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF3B8B8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.event_busy_rounded,
                          size: 18,
                          color: Color(0xFFC24E4E),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Candidate Declined This Slot',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFC24E4E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (schedule.rejectionReason != null &&
                              schedule.rejectionReason!.trim().isNotEmpty)
                          ? 'Reason: "${schedule.rejectionReason!.trim()}"'
                          : 'No specific reason provided.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7A2C2C),
                      ),
                    ),
                    if (schedule.preferredTime != null &&
                        schedule.preferredTime!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.78),
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
                                'Preferred Time: ${schedule.preferredTime!.trim()}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF163B65),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openReschedule(
                    applicantId: applicantId,
                    candidateName: candidateName,
                    seekerId: seekerId,
                    preferredTime: schedule.preferredTime,
                    rejectionReason: schedule.rejectionReason,
                  ),
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('Reschedule Interview'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF163B65),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ] else if (isAccepted) ...[
              const SizedBox(height: 20),
              if (isOnline &&
                  schedule.meetingLink != null &&
                  schedule.meetingLink!.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchURL(schedule.meetingLink!),
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('Join External Meeting'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF163B65),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                )
              else if (isInternal)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _startInternalInterview(schedule.scheduleID),
                    icon: const Icon(Icons.video_camera_front_rounded),
                    label: const Text('Start Video Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF163B65),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _markAsCompleted(applicantId, schedule.scheduleID),
                  icon: const Icon(Icons.task_alt_rounded),
                  label: const Text('Mark as Interviewed'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2D8A5D),
                    side: const BorderSide(color: Color(0xFFCDE9D8)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiReportBanner(PostInterviewReportModel report) {
    final Color scoreCol = report.overallScore >= 75
        ? const Color(0xFF2D8A5D)
        : (report.overallScore >= 50
            ? const Color(0xFFC28A22)
            : const Color(0xFFC24E4E));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4D9FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: Color(0xFF6B4FD3),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI Report · ${report.recommendation}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2433),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreCol.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${report.overallScore}/100',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: scoreCol,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await _pushLobbyAndRefresh(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PostInterviewAiReportScreen(initialReport: report),
                  ),
                );
              },
              icon: const Icon(Icons.analytics_outlined, size: 17),
              label: const Text('View AI Interview Report'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6B4FD3),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD5C4FF)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterviewInfoRow({
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF687588)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF4F5C6C),
            ),
          ),
        ),
      ],
    );
  }
}
