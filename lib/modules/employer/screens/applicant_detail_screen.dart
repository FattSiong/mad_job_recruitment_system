import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import '../../../services/employer_service.dart';
import 'interview_scheduling_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/community_service.dart';
import '../../community/screens/active_chat_screen.dart';

class ApplicantDetailScreen extends StatefulWidget {
  final Map<String, dynamic> applicantData;
  final String jobTitle;

  const ApplicantDetailScreen({
    super.key,
    required this.applicantData,
    required this.jobTitle,
  });

  @override
  State<ApplicantDetailScreen> createState() => _ApplicantDetailScreenState();
}

class _ApplicantDetailScreenState extends State<ApplicantDetailScreen> {
  final _employerService = EmployerService();
  List<Map<String, dynamic>> _answers = [];
  bool _isLoadingAnswers = true;
  bool _isUpdating = false;
  bool _isDownloadingFile = false;

  late String _currentStatus;
  bool _hasBeenScheduled = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.applicantData['applicationStatus'] ?? 'pending';

    _loadAnswers();
    _checkIfScheduled(); // 👉 NEW: Verify past history
  }

  // 👉 NEW: Checks if an interview row exists so the app remembers the state after a reload
  Future<void> _checkIfScheduled() async {
    try {
      final response = await Supabase.instance.client
          .from('InterviewSchedule')
          .select('scheduleID')
          .eq('applicantID', widget.applicantData['applicantID'])
          .limit(1);

      if (response.isNotEmpty && mounted) {
        setState(() {
          _hasBeenScheduled = true;
        });
      }
    } catch (e) {
      print('Check schedule error: $e');
    }
  }

  Future<void> _loadAnswers() async {
    final answers = await _employerService.getApplicantAnswers(
      widget.applicantData['applicantID'],
    );
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final communityService = CommunityService();
      final roomID = await communityService.getOrCreateChatRoom(
        currentUser.id,
        targetUserID,
      );

      if (mounted) Navigator.pop(context);

      if (mounted) {
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadAndOpenFile(String url, String fallbackName) async {
    setState(() => _isDownloadingFile = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloading file... Please wait.'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      String fileName = url.split('/').last.split('?').first;
      if (!fileName.contains('.')) {
        fileName = fallbackName;
      }

      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/$fileName';
      final file = File(savePath);

      if (!await file.exists()) {
        final response = await http.get(Uri.parse(url));
        await file.writeAsBytes(response.bodyBytes);
      }

      final textExtensions = [
        '.txt',
        '.dart',
        '.json',
        '.py',
        '.js',
        '.html',
        '.css',
        '.cpp',
        '.java',
        '.php',
        '.sql',
      ];
      final isTextFile = textExtensions.any(
        (ext) => fileName.toLowerCase().endsWith(ext),
      );

      if (isTextFile) {
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
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      } else {
        final result = await OpenFilex.open(savePath);
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not open file. You may need an app to read this format.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print("Download/Open error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error downloading or opening file.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingFile = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    final success = await _employerService.updateApplicationStatus(
      widget.applicantData['applicantID'],
      newStatus,
    );

    if (mounted) {
      setState(() {
        _isUpdating = false;
        if (success) _currentStatus = newStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Status updated to ${newStatus.toUpperCase()}'
                : 'Failed to update status',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'interviewed':
        return Colors.teal;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // 👉 NEW: Reschedule Confirmation Dialog
  Future<void> _showRescheduleConfirmation(Map<String, dynamic> seeker) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reschedule Interview?'),
        content: const Text(
          'This will prompt you to pick a new date and time. It will create a new meeting room for the candidate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final didSchedule = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InterviewSchedulingScreen(
            applicantId: widget.applicantData['applicantID'],
            applicantName: seeker['fullName'] ?? 'Applicant',
            seekerId: widget.applicantData['seekerID'],
          ),
        ),
      );

      if (didSchedule == true && mounted) {
        setState(() {
          _currentStatus = 'scheduled';
          _hasBeenScheduled = true;
        });
      }
    }
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
                      Text(
                        seeker['fullName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        seeker['email'] ?? 'No email',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
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
                      seeker['fullName'] ?? 'Applicant',
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
                    onPressed: (_isDownloadingFile || resumeUrl == null)
                        ? null
                        : () => _downloadAndOpenFile(resumeUrl, 'resume.pdf'),
                    icon: _isDownloadingFile
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(
                      _isDownloadingFile ? 'Downloading...' : 'Download Resume',
                    ),
                  ),
                ),
                if (aiScore != null) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text(
                          'AI Match: $aiScore%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 48),

            // --- 3. STATUS CONTROLLER ---
            const Text(
              'Application Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
                  Text(
                    'Current Status:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    _currentStatus.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(_currentStatus),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_isUpdating)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  // 👉 STAGE 1: PENDING
                  if (_currentStatus == 'pending')
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final didSchedule = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      InterviewSchedulingScreen(
                                        applicantId:
                                            widget.applicantData['applicantID'],
                                        applicantName:
                                            seeker['fullName'] ?? 'Applicant',
                                        seekerId:
                                            widget.applicantData['seekerID'],
                                      ),
                                ),
                              );

                              if (didSchedule == true) {
                                setState(() {
                                  _currentStatus = 'scheduled';
                                  _hasBeenScheduled = true;
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_month),
                            label: const Text('Schedule'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _updateStatus('rejected'),
                            icon: const Icon(Icons.cancel),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  // 👉 STAGE 2: SCHEDULED (Nothing to do here, managed in other tab)
                  else if (_currentStatus == 'scheduled')
                    Container(
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_available,
                            color: Colors.blue.shade700,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Interview Scheduled',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Please manage this interview from your "Scheduled Interviews" tab.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  // 👉 STAGE 3: INTERVIEWED (Needs final decision or reschedule)
                  else if (_currentStatus == 'interviewed')
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _updateStatus('accepted'),
                                icon: const Icon(Icons.thumb_up),
                                label: const Text('Accept'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _updateStatus('rejected'),
                                icon: const Icon(Icons.thumb_down),
                                label: const Text('Reject'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () =>
                                _showRescheduleConfirmation(seeker),
                            icon: const Icon(Icons.calendar_today),
                            label: const Text('Reschedule Interview'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  // 👉 STAGE 4: ACCEPTED (Can be changed to Rejected or Rescheduled)
                  else if (_currentStatus == 'accepted')
                    Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Candidate ACCEPTED',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _updateStatus('rejected'),
                            icon: const Icon(Icons.thumb_down),
                            label: const Text('Change Decision to Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        // 👉 NEW: Reschedule option added to Accepted stage
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () =>
                                _showRescheduleConfirmation(seeker),
                            icon: const Icon(Icons.calendar_today),
                            label: const Text('Schedule Follow-up Interview'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  // 👉 STAGE 5: REJECTED POST-INTERVIEW (Can be changed to Accepted or Rescheduled)
                  else if (_currentStatus == 'rejected' && _hasBeenScheduled)
                    Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Candidate REJECTED',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _updateStatus('accepted'),
                            icon: const Icon(Icons.thumb_up),
                            label: const Text('Change Decision to Accept'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(color: Colors.green),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        // 👉 NEW: Reschedule option added to Rejected stage
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () =>
                                _showRescheduleConfirmation(seeker),
                            icon: const Icon(Icons.calendar_today),
                            label: const Text('Reschedule Interview'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),

                  // 👉 UNDO BUTTON (Only shows if they were rejected straight from Pending)
                  if (_currentStatus == 'rejected' && !_hasBeenScheduled) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _updateStatus('pending'),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Undo & Reset to Pending'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),

            const Divider(height: 48),

            // --- 4. PRE-SCREENING ANSWERS ---
            const Text(
              'Pre-Screening Answers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _isLoadingAnswers
                ? const Center(child: CircularProgressIndicator())
                : _answers.isEmpty
                ? const Text(
                    'No pre-screening questions were required for this job.',
                    style: TextStyle(color: Colors.grey),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _answers.length,
                    itemBuilder: (context, index) {
                      final ans = _answers[index];
                      final question = ans['PreScreeningQuestion'] ?? {};
                      final qText =
                          question['questionText'] ?? 'Unknown Question';
                      final isFile = question['questionType'] == 'File';
                      final answerFileUrl = ans['answerFileURL'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Q: $qText',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (isFile && answerFileUrl != null)
                              OutlinedButton.icon(
                                onPressed: _isDownloadingFile
                                    ? null
                                    : () => _downloadAndOpenFile(
                                        answerFileUrl,
                                        'applicant_answer_${index + 1}.pdf',
                                      ),
                                icon: const Icon(Icons.download),
                                label: const Text('Download Uploaded File'),
                              )
                            else
                              Text(
                                ans['answerText'] ?? 'No answer provided.',
                                style: TextStyle(color: Colors.grey.shade800),
                              ),
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
