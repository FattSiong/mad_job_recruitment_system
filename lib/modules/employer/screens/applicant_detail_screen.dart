import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/community_service.dart';
import '../../../services/employer_service.dart';
import '../../community/screens/active_chat_screen.dart';
import 'interview_scheduling_screen.dart';

class ApplicantDetailScreen extends StatefulWidget {
  final Map<String, dynamic> applicantData;
  final String jobTitle;
  final String jobStatus;

  const ApplicantDetailScreen({
    super.key,
    required this.applicantData,
    required this.jobTitle,
    required this.jobStatus,
  });

  @override
  State<ApplicantDetailScreen> createState() => _ApplicantDetailScreenState();
}

class _ApplicantDetailScreenState extends State<ApplicantDetailScreen> {
  final EmployerService _employerService = EmployerService();

  List<Map<String, dynamic>> _answers = [];
  bool _isLoadingAnswers = true;
  bool _isUpdating = false;
  bool _isDownloadingFile = false;

  late String _currentStatus;
  bool _hasBeenScheduled = false;
  String _scheduleCandidateStatus = 'pending';
  String? _scheduleRejectionReason;
  String? _schedulePreferredTime;

  bool get _isJobDeleted => widget.jobStatus.toLowerCase() == 'deleted';

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.applicantData['applicationStatus'] ?? 'pending';
    _loadAnswers();
    _checkIfScheduled();
  }

  Future<void> _checkIfScheduled() async {
    try {
      final response = await Supabase.instance.client
          .from('InterviewSchedule')
          .select('scheduleID, candidateStatus, rejectionReason, preferredTime')
          .eq('applicantID', widget.applicantData['applicantID'])
          .limit(1);

      if (response.isNotEmpty && mounted) {
        final row = response.first;
        setState(() {
          _hasBeenScheduled = true;
          _scheduleCandidateStatus =
              (row['candidateStatus'] ?? 'pending').toString().toLowerCase();
          _scheduleRejectionReason = row['rejectionReason']?.toString();
          _schedulePreferredTime = row['preferredTime']?.toString();
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
                    padding: const EdgeInsets.all(8),
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
      print('Download/Open error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error downloading or opening file.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingFile = false);
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_isJobDeleted) return;

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
      case 'directrejected':
        return Colors.red;
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

  Future<void> _showRescheduleConfirmation(Map<String, dynamic> seeker) async {
    if (_isJobDeleted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
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
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCEBFB),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: Color(0xFF163B65),
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Reschedule Interview?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2433),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You will choose a new date and time for this candidate. A new interview setup will be prepared for the updated session.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF687588),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFF163B65),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Use this when the current interview time is no longer suitable.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF4F5C6C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF687588),
                        side: const BorderSide(color: Color(0xFFD6DEE8)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF163B65),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
            initialPreferredTime: _schedulePreferredTime,
            rejectionReason: _scheduleRejectionReason,
          ),
        ),
      );

      if (didSchedule == true && mounted) {
        setState(() {
          _currentStatus = 'scheduled';
          _hasBeenScheduled = true;
          _scheduleCandidateStatus = 'pending';
          _scheduleRejectionReason = null;
          _schedulePreferredTime = null;
        });
        await _checkIfScheduled();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final seeker = widget.applicantData['JobSeeker'] ?? {};
    final resumeUrl = widget.applicantData['submittedResumeURL'];
    final aiScore = widget.applicantData['aiRankingScore'];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _buildTopBar(context),
            const SizedBox(height: 16),
            _buildHeroCard(seeker, aiScore),
            if (_isJobDeleted) ...[
              const SizedBox(height: 18),
              _buildWarningCard(),
            ],
            const SizedBox(height: 18),
            _buildSectionCard(
              title: 'Profile Overview',
              subtitle:
                  'Review the candidate details, resume access, and communication actions.',
              child: Column(
                children: [
                  _buildProfileRow(
                    Icons.mail_outline_rounded,
                    'Email',
                    seeker['email'] ?? 'No email provided',
                  ),
                  const SizedBox(height: 14),
                  _buildProfileRow(
                    Icons.work_outline_rounded,
                    'Applied Role',
                    widget.jobTitle,
                  ),
                  const SizedBox(height: 14),
                  _buildProfileRow(
                    Icons.description_outlined,
                    'Resume',
                    resumeUrl == null ? 'No resume submitted' : 'Resume available',
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_isDownloadingFile || resumeUrl == null)
                              ? null
                              : () => _downloadAndOpenFile(
                                    resumeUrl,
                                    'resume.pdf',
                                  ),
                          icon: _isDownloadingFile
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.download_rounded),
                          label: Text(
                            _isDownloadingFile
                                ? 'Downloading...'
                                : 'Download Resume',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF163B65),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openChat(
                            widget.applicantData['seekerID'],
                            seeker['fullName'] ?? 'Applicant',
                          ),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: const Text('Message'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF163B65),
                            side: const BorderSide(color: Color(0xFF163B65)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (aiScore != null ||
                (widget.applicantData['aiFeedback'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty) ...[
              _buildAiAnalysisCard(aiScore),
              const SizedBox(height: 18),
            ],
            _buildSectionCard(
              title: 'Application Status',
              subtitle:
                  'Track the applicant workflow and manage the next ATS action.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentStatusBanner(),
                  const SizedBox(height: 16),
                  _buildStatusActions(seeker),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _buildSectionCard(
              title: 'Pre-Screening Answers',
              subtitle:
                  'Read the candidate responses submitted during the application process.',
              child: _buildAnswersSection(),
            ),
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
              child: Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF163B65),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Applicant Profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(Map<String, dynamic> seeker, dynamic aiScore) {
    final name = seeker['fullName'] ?? 'Unknown Applicant';
    final email = seeker['email'] ?? 'No email';
    final hasResume = widget.applicantData['submittedResumeURL'] != null;

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
          Row(
            children: [
              _buildHeroChip(
                icon: Icons.person_search_rounded,
                text: 'Candidate Review',
              ),
              const Spacer(),
              _buildStatusChip(_currentStatus),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white.withOpacity(0.16),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'A',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroMetric(
                Icons.work_outline_rounded,
                widget.jobTitle,
              ),
              if (aiScore != null)
                _buildHeroMetric(
                  Icons.auto_awesome_rounded,
                  'AI Match $aiScore%',
                ),
              _buildHeroMetric(
                Icons.description_outlined,
                hasResume ? 'Resume Ready' : 'No Resume',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE9E9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFC24E4E),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This job was deleted by admin. Applicant records remain visible for history, but employer actions are now view-only.',
              style: TextStyle(
                color: Color(0xFFC24E4E),
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAnalysisCard(dynamic aiScore) {
    final int? scoreInt = (aiScore as num?)?.round();
    final String feedback =
        (widget.applicantData['aiFeedback'] ?? '').toString().trim();

    Color badgeFg = const Color(0xFFC28A22);
    Color badgeBg = const Color(0xFFFEF3DC);
    if (scoreInt != null) {
      if (scoreInt >= 75) {
        badgeFg = const Color(0xFF2D8A5D);
        badgeBg = const Color(0xFFE5F6ED);
      } else if (scoreInt < 50) {
        badgeFg = const Color(0xFFC24E4E);
        badgeBg = const Color(0xFFFDECEC);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF4FF), Color(0xFFF8F5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8E4F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF163B65),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Smart Match Analysis',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B2433),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Resume & requirements evaluation',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF687588),
                      ),
                    ),
                  ],
                ),
              ),
              if (scoreInt != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$scoreInt% Match',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: badgeFg,
                    ),
                  ),
                ),
            ],
          ),
          if (feedback.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                feedback,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentStatusBanner() {
    final color = _getStatusColor(_currentStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _getStatusIcon(_currentStatus),
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Status',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF687588),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusActions(Map<String, dynamic> seeker) {
    final normalizedStatus = _currentStatus.toLowerCase();

    if (_isJobDeleted) {
      return const SizedBox.shrink();
    }

    if (_isUpdating) {
      return const Center(child: CircularProgressIndicator());
    }

    if (normalizedStatus == 'pending' || normalizedStatus == 'reviewed') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
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

                if (didSchedule == true) {
                  setState(() {
                    _currentStatus = 'scheduled';
                    _hasBeenScheduled = true;
                    _scheduleCandidateStatus = 'pending';
                    _scheduleRejectionReason = null;
                    _schedulePreferredTime = null;
                  });
                  await _checkIfScheduled();
                }
              },
              icon: const Icon(Icons.calendar_month_rounded),
              label: const Text('Schedule'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF163B65),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _updateStatus('rejected'),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC24E4E),
                side: const BorderSide(color: Color(0xFFC24E4E)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (normalizedStatus == 'rejected' && !_hasBeenScheduled) {
      return _buildStateMessageCard(
        color: const Color(0xFFC24E4E),
        icon: Icons.lock_outline_rounded,
        title: 'Candidate Rejected',
        description:
        'This application was rejected before interview scheduling and can no longer be changed.',
      );
    }

    if (normalizedStatus == 'scheduled') {
      final isSlotRejected = _scheduleCandidateStatus == 'rejected';
      final isSlotAccepted = _scheduleCandidateStatus == 'accepted';

      return Column(
        children: [
          _buildStateMessageCard(
            color: isSlotRejected
                ? const Color(0xFFC24E4E)
                : isSlotAccepted
                    ? const Color(0xFF2D8A5D)
                    : const Color(0xFF4A7BB7),
            icon: isSlotRejected
                ? Icons.event_busy_rounded
                : isSlotAccepted
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_top_rounded,
            title: isSlotRejected
                ? 'Candidate Declined Interview Time'
                : isSlotAccepted
                    ? 'Candidate Accepted Interview'
                    : 'Waiting for Candidate Confirmation',
            description: isSlotRejected
                ? [
                    if (_scheduleRejectionReason != null &&
                        _scheduleRejectionReason!.trim().isNotEmpty)
                      'Reason: "${_scheduleRejectionReason!.trim()}"'
                    else
                      'The candidate declined the proposed interview slot.',
                    if (_schedulePreferredTime != null &&
                        _schedulePreferredTime!.trim().isNotEmpty)
                      'Preferred Time: ${_schedulePreferredTime!.trim()}',
                  ].join('\n')
                : isSlotAccepted
                    ? 'The candidate confirmed the interview slot. Manage this session from Scheduled Interviews.'
                    : 'Interview invitation sent. Waiting for the candidate to accept or decline the proposed slot.',
          ),
          if (isSlotRejected) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showRescheduleConfirmation(seeker),
                icon: const Icon(Icons.calendar_today_rounded),
                label: const Text('Reschedule Interview'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF163B65),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    final isPostInterviewStage =
        normalizedStatus == 'interviewed' ||
        normalizedStatus == 'accepted' ||
        (normalizedStatus == 'rejected' && _hasBeenScheduled);

    if (isPostInterviewStage) {
      final isAccepted = normalizedStatus == 'accepted';
      final isRejected = normalizedStatus == 'rejected';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAccepted
                ? 'Current decision is accepted. You can still change it or reschedule.'
                : isRejected
                ? 'Current decision is rejected. You can still change it or reschedule.'
                : 'Choose the next decision for this interviewed candidate.',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF687588),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus('accepted'),
                  icon: const Icon(Icons.thumb_up_alt_rounded),
                  label: const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAccepted
                        ? const Color(0xFF2D8A5D)
                        : Colors.white,
                    foregroundColor: isAccepted
                        ? Colors.white
                        : const Color(0xFF2D8A5D),
                    elevation: 0,
                    side: BorderSide(
                      color: const Color(0xFF2D8A5D).withOpacity(
                        isAccepted ? 0 : 0.35,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus('rejected'),
                  icon: const Icon(Icons.thumb_down_alt_rounded),
                  label: const Text('Reject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRejected
                        ? const Color(0xFFC24E4E)
                        : Colors.white,
                    foregroundColor: isRejected
                        ? Colors.white
                        : const Color(0xFFC24E4E),
                    elevation: 0,
                    side: BorderSide(
                      color: const Color(0xFFC24E4E).withOpacity(
                        isRejected ? 0 : 0.35,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
              onPressed: () => _showRescheduleConfirmation(seeker),
              icon: const Icon(Icons.calendar_today_rounded),
              label: const Text('Reschedule Interview'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF163B65),
                backgroundColor: const Color(0xFFDCEBFB),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildStateMessageCard(
          color: const Color(0xFFC24E4E),
          icon: Icons.person_off_rounded,
          title: 'Candidate Rejected',
          description:
              'This application was rejected before interview scheduling.',
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _updateStatus('pending'),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Undo and Reset to Pending'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF687588),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswersSection() {
    if (_isLoadingAnswers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_answers.isEmpty) {
      return const Text(
        'No pre-screening questions were required for this job.',
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF687588),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _answers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ans = _answers[index];
        final question = ans['PreScreeningQuestion'] ?? {};
        final qText = question['questionText'] ?? 'Unknown Question';
        final isFile = question['questionType'] == 'File';
        final answerFileUrl = ans['answerFileURL'];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCEBFB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.quiz_outlined,
                      size: 18,
                      color: Color(0xFF163B65),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      qText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B2433),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (isFile && answerFileUrl != null)
                OutlinedButton.icon(
                  onPressed: _isDownloadingFile
                      ? null
                      : () => _downloadAndOpenFile(
                            answerFileUrl,
                            'applicant_answer_${index + 1}.pdf',
                          ),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download Uploaded File'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF163B65),
                    side: const BorderSide(color: Color(0xFF163B65)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                )
              else
                Text(
                  ans['answerText'] ?? 'No answer provided.',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF4F5C6C),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF687588),
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF163B65)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF687588),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Color(0xFF1B2433),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStateMessageCard({
    required Color color,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color == Colors.grey ? Colors.white : color.withOpacity(0.95),
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'directrejected':
        return Icons.lock_outline_rounded;
      case 'scheduled':
        return Icons.event_available_rounded;
      case 'interviewed':
        return Icons.record_voice_over_rounded;
      case 'accepted':
        return Icons.verified_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }
}
