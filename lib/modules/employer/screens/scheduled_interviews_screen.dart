import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // 👉 You may need to run: flutter pub add url_launcher
import '../../../models/interveiw_schedule_model.dart';
import '../../../services/employer_service.dart';

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
        _interviews = data;
        _isLoading = false;
      });
    }
  }

  // Helper to open meeting URLs
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString.startsWith('http') ? urlString : 'https://$urlString');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open meeting link')));
      }
    }
  }

  // Helper to get a nice month abbreviation (e.g., "MAY")
  String _getMonthAbbr(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7), // Morandi background
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

          // Parse the data using our Model!
          final schedule = InterviewScheduleModel.fromJson(data);

          // Safely extract the joined Applicant/Seeker data
          final applicant = data['JobApplicant'] ?? {};
          final seeker = applicant['JobSeeker'] ?? {};
          final jobPost = applicant['Job'] ?? {};

          final candidateName = seeker['fullName'] ?? 'Unknown Candidate';
          final jobTitle = jobPost['title'] ?? 'Unknown Job';

          // Format times
          final timeString = '${schedule.startTime.format(context)} - ${schedule.endTime.format(context)}';
          final isOnline = schedule.meetingMethod == 'online';

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
                // 👉 LEFT SIDE: Date Box
                Container(
                  width: 80,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2A4D), // Deep Blue from your header
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
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

                // 👉 RIGHT SIDE: Interview Details
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
                                isOnline ? Icons.videocam : (schedule.meetingMethod == 'internal' ? Icons.chat : Icons.location_on),
                                size: 16,
                                color: Colors.grey.shade600
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                schedule.meetingMethod == 'internal'
                                    ? 'App Internal Interview'
                                    : (schedule.meetingLink ?? 'No link provided'),
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        // 👉 ACTION BUTTON: If it's an online link, give them a quick button to launch it
                        if (isOnline && schedule.meetingLink != null && schedule.meetingLink!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _launchURL(schedule.meetingLink!),
                              icon: const Icon(Icons.link, size: 18),
                              label: const Text('Join Meeting'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blueAccent,
                                side: BorderSide(color: Colors.blueAccent.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ]
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