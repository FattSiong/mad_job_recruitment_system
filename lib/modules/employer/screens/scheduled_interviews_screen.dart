import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/interveiw_schedule_model.dart';
import '../../../services/employer_service.dart';
import '../../../services/interview_service.dart';
import '../../community/screens/interview_lobby_screen.dart';

class ScheduledInterviewsScreen extends StatefulWidget {
  const ScheduledInterviewsScreen({super.key});

  @override
  State<ScheduledInterviewsScreen> createState() => _ScheduledInterviewsScreenState();
}

class _ScheduledInterviewsScreenState extends State<ScheduledInterviewsScreen> {
  final _employerService = EmployerService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _interviews = [];

  @override
  void initState() {
    super.initState();
    _loadInterviews();
  }

  Future<void> _loadInterviews() async {
    setState(() => _isLoading = true);
    final data = await _employerService.getScheduledInterviews();

    if (mounted) {
      setState(() {
        // 👉 NEW: Filter the list so we ONLY show applicants who are still 'scheduled'
        // Once they are marked as 'interviewed', they will disappear from this screen!
        _interviews = data.where((item) {
          final applicant = item['JobApplicant'] ?? {};
          return applicant['applicationStatus'] == 'scheduled';
        }).toList();

        _isLoading = false;
      });
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString.startsWith('http') ? urlString : 'https://$urlString');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open meeting link')));
      }
    }
  }

  Future<void> _startInternalInterview(String? scheduleID, Map<String, dynamic> applicantData) async {
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
        final String? actualRoomID = roomData['interviewRoomID'] ?? roomData['roomID'] ?? roomData['id'];

        if (actualRoomID != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InterviewLobbyScreen(
                roomID: actualRoomID,
                isEmployer: true,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database Error: Could not read the room ID column.')));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Could not find interview room.')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // 👉 NEW: Confirmation Dialog & Logic to Mark as Completed
  Future<void> _markAsCompleted(String applicantId, String? scheduleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Completed?'),
        content: const Text('This will permanently close the interview room and update the candidate\'s ATS status to "Interviewed".'),
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

    final success = await _employerService.markInterviewAsCompleted(applicantId, scheduleId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Interview marked as completed!'), backgroundColor: Colors.green),
        );
        _loadInterviews(); // Refresh the list to remove the completed item
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getMonthAbbr(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        title: const Text('Scheduled Interviews', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _interviews.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No upcoming interviews scheduled.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _interviews.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final data = _interviews[index];
          final schedule = InterviewScheduleModel.fromJson(data);

          final applicant = data['JobApplicant'] ?? {};
          final applicantId = applicant['applicantID'];
          final seeker = applicant['JobSeeker'] ?? {};
          final jobPost = applicant['Job'] ?? {};

          final candidateName = seeker['fullName'] ?? 'Unknown Candidate';
          final jobTitle = jobPost['title'] ?? 'Unknown Job';

          final timeString = '${schedule.startTime.format(context)} - ${schedule.endTime.format(context)}';
          final isOnline = schedule.meetingMethod == 'online';
          final isInternal = schedule.meetingMethod == 'internal';

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                // LEFT SIDE: Date Box
                Container(
                  width: 80,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A2A4D),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _getMonthAbbr(schedule.date.month),
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        schedule.date.day.toString(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                      ),
                    ],
                  ),
                ),

                // RIGHT SIDE: Interview Details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            candidateName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A))
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Role: $jobTitle',
                          style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(timeString, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 6),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                                isInternal ? Icons.video_camera_front : (isOnline ? Icons.videocam : Icons.location_on),
                                size: 16,
                                color: Colors.grey.shade600
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isInternal
                                    ? 'App Internal Interview'
                                    : (schedule.meetingLink ?? 'No link provided'),
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        // --- ACTION BUTTONS ---
                        const SizedBox(height: 16),

                        // Option A: External Online Link
                        if (isOnline && schedule.meetingLink != null && schedule.meetingLink!.isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _launchURL(schedule.meetingLink!),
                              icon: const Icon(Icons.link, size: 18),
                              label: const Text('Join External Meeting'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A2A4D),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          )

                        // Option B: NATIVE APP INTERVIEW BUTTON
                        else if (isInternal)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _startInternalInterview(schedule.scheduleID, applicant),
                              icon: const Icon(Icons.video_camera_front),
                              label: const Text('Start Video Call'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A2A4D),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),

                        // 👉 NEW: Mark as Completed Button (Shows for all interview types)
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _markAsCompleted(applicantId, schedule.scheduleID),
                            icon: const Icon(Icons.task_alt),
                            label: const Text('Mark as Interviewed'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green.shade700,
                              side: BorderSide(color: Colors.green.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}