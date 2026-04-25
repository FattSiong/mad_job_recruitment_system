import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import '../../../services/employer_service.dart';
import 'interview_scheduling_screen.dart';
// 👉 NEW IMPORTS: Add these at the top!
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/community_service.dart';
import '../../community/screens/active_chat_screen.dart'; // Adjust path if necessary

class ApplicantDetailScreen extends StatefulWidget {
  final Map<String, dynamic> applicantData;
  final String jobTitle;

  const ApplicantDetailScreen({super.key, required this.applicantData, required this.jobTitle});

  @override
  State<ApplicantDetailScreen> createState() => _ApplicantDetailScreenState();
}

class _ApplicantDetailScreenState extends State<ApplicantDetailScreen> {
  final _employerService = EmployerService();
  List<Map<String, dynamic>> _answers = [];
  bool _isLoadingAnswers = true;
  bool _isUpdating = false;

  // 👉 NEW: Tracks if a file is currently downloading so we can show a spinner
  bool _isDownloadingFile = false;

  late String _currentStatus;

  bool _hasBeenScheduled = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.applicantData['applicationStatus'] ?? 'pending';

    // If they load the screen and it's already past pending, lock out the undo feature
    if (_currentStatus != 'pending' && _currentStatus != 'rejected') {
      _hasBeenScheduled = true;
    }
    _loadAnswers();
  }

  Future<void> _loadAnswers() async {
    final answers = await _employerService.getApplicantAnswers(widget.applicantData['applicantID']);
    if (mounted) {
      setState(() {
        _answers = answers;
        _isLoadingAnswers = false;
      });
    }
  }

  Future<void> _openChat(String targetUserID, String targetUserName) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    // Show a loading spinner while the backend checks for a chat room
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final communityService = CommunityService();

      // 👉 Calls the method that already exists in your community_service.dart!
      final roomID = await communityService.getOrCreateChatRoom(currentUser.id, targetUserID);

      if (mounted) Navigator.pop(context); // Close the loading spinner

      if (mounted) {
        // Navigate directly to your ActiveChatScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActiveChatScreen(
              roomID: roomID,
              currentUserID: currentUser.id,
              otherUserName: targetUserName,
              otherUserID: targetUserID,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close the loading spinner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 👉 REPLACED: The robust Download & Open logic!
  Future<void> _downloadAndOpenFile(String url, String fallbackName) async {
    setState(() => _isDownloadingFile = true);

    // Show a snackbar so the user knows something is happening
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading file... Please wait.'), duration: Duration(seconds: 2)),
    );

    try {
      // 1. Get the file extension from the URL (e.g., .pdf, .jpg, .dart)
      String fileName = url.split('/').last.split('?').first;
      if (!fileName.contains('.')) {
        fileName = fallbackName;
      }

      // 2. Find the device's temporary folder
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/$fileName';
      final file = File(savePath);

      // 3. Download the file if it hasn't been downloaded yet
      if (!await file.exists()) {
        final response = await http.get(Uri.parse(url));
        await file.writeAsBytes(response.bodyBytes);
      }

      // 4. Check if it is a readable text/code file
      final textExtensions = ['.txt', '.dart', '.json', '.py', '.js', '.html', '.css', '.cpp', '.java', '.php', '.sql'];
      final isTextFile = textExtensions.any((ext) => fileName.toLowerCase().endsWith(ext));

      if (isTextFile) {
        // 👉 OPTION 1: THE IN-APP VIEWER LOGIC
        final fileContent = await file.readAsString();

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                fileName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                // Wrapping the text in a SingleChildScrollView so long code scrolls smoothly
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      fileContent,
                      // Using a monospace font makes it look like a real code editor
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close')
                ),
              ],
            ),
          );
        }
      } else {
        // 👉 FALLBACK: Let the OS handle PDFs, Images, and ZIPs
        final result = await OpenFilex.open(savePath);

        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open file. You may need an app to read this format.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print("Download/Open error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error downloading or opening file.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingFile = false);
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    final success = await _employerService.updateApplicationStatus(widget.applicantData['applicantID'], newStatus);

    if (mounted) {
      setState(() {
        _isUpdating = false;
        if (success) _currentStatus = newStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Status updated to ${newStatus.toUpperCase()}' : 'Failed to update status'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled': return Colors.blue;       // Picked a date
      case 'interviewed': return Colors.teal;     // Interview complete
      case 'accepted': return Colors.green;       // Hired!
      case 'rejected': return Colors.red;         // Passed
      default: return Colors.grey;                // Pending
    }
  }

  // 👉 NEW: Opens calendar and clock, then updates status to 'scheduled'
  Future<void> _scheduleInterview() async {
    // 1. Pick the Date
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate == null) return; // User canceled

    if (!mounted) return;

    // 2. Pick the Time
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );

    if (selectedTime == null) return; // User canceled

    // 3. Update the status!
    // (Note for FYP: If you want to save this exact date/time to display later,
    // you will need to add an 'interviewAt' column to your JobApplicant Supabase table!)
    await _updateStatus('scheduled');
  }

  @override
  Widget build(BuildContext context) {
    final seeker = widget.applicantData['JobSeeker'] ?? {};
    final resumeUrl = widget.applicantData['submittedResumeURL'];
    final aiScore = widget.applicantData['aiRankingScore'];

    return Scaffold(
      appBar: AppBar(title: const Text('Applicant Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. BASIC INFO ---
            Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.person, size: 40, color: Colors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(seeker['fullName'] ?? 'Unknown', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(seeker['email'] ?? 'No email', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                    ],
                  ),
                ),

                // 👉 NEW: The Chat Button!
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    tooltip: 'Message Candidate',
                    icon: const Icon(Icons.chat_bubble, color: Colors.blue),
                    onPressed: () => _openChat(
                        widget.applicantData['seekerID'],
                        seeker['fullName'] ?? 'Applicant'
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- 2. RESUME & AI SCORE ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    // 👉 Connect the new download method here
                    onPressed: (_isDownloadingFile || resumeUrl == null)
                        ? null
                        : () => _downloadAndOpenFile(resumeUrl, 'resume.pdf'),
                    icon: _isDownloadingFile
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download),
                    label: Text(_isDownloadingFile ? 'Downloading...' : 'Download Resume'),
                  ),
                ),
                if (aiScore != null) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text('AI Match: $aiScore%', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
                      ],
                    ),
                  ),
                ]
              ],
            ),
            const Divider(height: 48),

            // --- 3. STATUS CONTROLLER ---
            const Text('Application Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _getStatusColor(_currentStatus).withOpacity(0.1),
                border: Border.all(color: _getStatusColor(_currentStatus)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Current Status:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  Text(_currentStatus.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(_currentStatus), fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_isUpdating)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [

                  // STAGE 1: PENDING
                  if (_currentStatus == 'pending')
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // 👉 Navigate to the new scheduling screen!
                              final didSchedule = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InterviewSchedulingScreen(
                                    applicantId: widget.applicantData['applicantID'],
                                    applicantName: seeker['fullName'] ?? 'Applicant',
                                  ),
                                ),
                              );

                              // If they successfully saved the schedule, update the UI
                              if (didSchedule == true) {
                                setState(() {
                                  _currentStatus = 'scheduled';
                                  _hasBeenScheduled = true;
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_month),
                            label: const Text('Schedule'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _updateStatus('rejected'),
                            icon: const Icon(Icons.cancel),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 16)),
                          ),
                        ),
                      ],
                    )

                  // STAGE 2: SCHEDULED
                  else if (_currentStatus == 'scheduled')
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _updateStatus('interviewed'),
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Mark as Interviewed'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                          ),
                        ),
                      ],
                    )

                  // STAGE 3: INTERVIEWED
                  else if (_currentStatus == 'interviewed')
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _updateStatus('accepted'),
                              icon: const Icon(Icons.thumb_up),
                              label: const Text('Accept'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _updateStatus('rejected'),
                              icon: const Icon(Icons.thumb_down),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 16)),
                            ),
                          ),
                        ],
                      )

                    // STAGE 4: DECISION MADE (Accepted, or Rejected post-interview)
                    else if (_currentStatus == 'accepted' || (_currentStatus == 'rejected' && _hasBeenScheduled))
                        Container(
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                          child: Text('Candidate ${_currentStatus.toUpperCase()}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),

                  // 👉 UNDO BUTTON (Only shows if they were rejected straight from Pending)
                  if (_currentStatus == 'rejected' && !_hasBeenScheduled) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _updateStatus('pending'),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Undo & Reset to Pending'),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),

            const Divider(height: 48),

            // --- 4. PRE-SCREENING ANSWERS ---
            const Text('Pre-Screening Answers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            _isLoadingAnswers
                ? const Center(child: CircularProgressIndicator())
                : _answers.isEmpty
                ? const Text('No pre-screening questions were required for this job.', style: TextStyle(color: Colors.grey))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _answers.length,
              itemBuilder: (context, index) {
                final ans = _answers[index];
                final question = ans['PreScreeningQuestion'] ?? {};
                final qText = question['questionText'] ?? 'Unknown Question';
                final isFile = question['questionType'] == 'File';
                final answerFileUrl = ans['answerFileURL'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Q: $qText', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (isFile && answerFileUrl != null)
                      // 👉 Connect the new download method here too!
                        OutlinedButton.icon(
                          onPressed: _isDownloadingFile
                              ? null
                              : () => _downloadAndOpenFile(answerFileUrl, 'applicant_answer_${index + 1}.pdf'),
                          icon: const Icon(Icons.download),
                          label: const Text('Download Uploaded File'),
                        )
                      else
                        Text(ans['answerText'] ?? 'No answer provided.', style: TextStyle(color: Colors.grey.shade800)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}