import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/data_load_exception.dart';
import '../../../community/screens/interview_lobby_screen.dart';
import '../../controllers/applied_jobs_controller.dart';
import '../../controllers/seeker_interview_controller.dart';
import '../load_error_view.dart';
import 'my_jobs_empty_state.dart';

/// My Jobs > Interviews tab.
class InterviewsTab extends StatefulWidget {
  const InterviewsTab({super.key});

  @override
  State<InterviewsTab> createState() => _InterviewsTabState();
}

class _InterviewsTabState extends State<InterviewsTab> {
  final SeekerInterviewController _interviewController = SeekerInterviewController();
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
      final interviews = await _interviewController.fetchMyInterviews();
      if (mounted) {
        setState(() {
          _interviews = interviews;
          _loadError = null;
          _isLoading = false;
        });
      }
    } on DataLoadException catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.message;
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
      final roomData = await _interviewController.getRoomForSchedule(scheduleID);

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
    final success = await _interviewController.respondToInterview(
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
          backgroundColor: accept ? Colors.green : AppColors.textMuted,
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
                                color: AppColors.textDark,
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
                          color: AppColors.textMuted,
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
                          fillColor: AppColors.surfaceAlt,
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
                              color: AppColors.primary,
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
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: AppColors.surfaceAlt,
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
                                  color: AppColors.primary,
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
                                          ? AppColors.textMuted
                                          : AppColors.textDark,
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
                              color: AppColors.surfaceAlt,
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
                                        color: AppColors.primary,
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
                                                ? AppColors.textMuted
                                                : AppColors.textDark,
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
                              color: AppColors.surfaceAlt,
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
                                        color: AppColors.primary,
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
                                                ? AppColors.textMuted
                                                : AppColors.textDark,
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
                                foregroundColor: AppColors.textMuted,
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
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_loadError != null) {
      return LoadErrorView(message: _loadError!, onRetry: _retry);
    }

    if (_interviews.isEmpty) {
      return const MyJobsEmptyState(
        icon: Icons.event_busy_outlined,
        title: 'No scheduled interviews yet',
        subtitle: 'Interview invitations and meeting details will appear here when employers schedule them.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
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
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            companyName,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
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
                      color: AppColors.primary,
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
                      color: AppColors.surfaceAlt,
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
                              color: AppColors.textMuted,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Meeting Link',
                              style: TextStyle(
                                color: AppColors.textMuted,
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
                              color: AppColors.primary,
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
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Interview Location',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                meetingValue,
                                style: const TextStyle(
                                  color: AppColors.primary,
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
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            interview['interviewNote'],
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textMuted,
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
                        backgroundColor: AppColors.primary,
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
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Preferred time: $preferredTime',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
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
