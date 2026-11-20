import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/storage_url_helper.dart';
import '../../../models/skill_model.dart';
import '../../../services/employer_service.dart';
import '../../../shared_widgets/skill_chips.dart';
import '../../chat/chat_navigation.dart';
import '../../job_seeker/controllers/skill_controller.dart';
import 'interview_scheduling_screen.dart';
import '../../../models/post_interview_report_model.dart';
import 'post_interview_ai_report_screen.dart';

class ApplicantDetailScreen extends StatefulWidget {
  final Map<String, dynamic> applicantData;
  final String jobTitle;
  final String jobStatus;
  final String? jobId;
  final int? jobVacancies;

  const ApplicantDetailScreen({
    super.key,
    required this.applicantData,
    required this.jobTitle,
    required this.jobStatus,
    this.jobId,
    this.jobVacancies,
  });

  @override
  State<ApplicantDetailScreen> createState() => _ApplicantDetailScreenState();
}

class _ApplicantDetailScreenState extends State<ApplicantDetailScreen> {
  final EmployerService _employerService = EmployerService();
  final SkillController _skillController = SkillController();

  List<SkillModel> _skills = [];
  bool _isLoadingSkills = true;

  List<Map<String, dynamic>> _answers = [];
  bool _isLoadingAnswers = true;
  bool _isAutoGradingAnswers = false;
  bool _isPreScreeningExpanded = false;
  final Set<int> _collapsedQuestionIndices = <int>{};
  final Set<String> _savingAnswerIds = <String>{};
  bool _isUpdating = false;
  bool _isDownloadingFile = false;

  late String _currentStatus;
  bool _hasBeenScheduled = false;
  String _scheduleCandidateStatus = 'pending';
  String? _scheduleRejectionReason;
  String? _schedulePreferredTime;
  PostInterviewReportModel? _postInterviewReport;
  late String _effectiveJobStatus;
  int _vacancies = 1;
  int _acceptedOtherCount = 0;
  String? _offerSalary;
  DateTime? _offerStartDate;
  String? _offerMessage;
  String? _offerLetterUrl;
  String? _offerDeclineReason;

  String get _resolvedJobId =>
      (widget.jobId ?? widget.applicantData['jobID'] ?? '').toString().trim();

  int get _currentAcceptedTotal =>
      _acceptedOtherCount +
      (_currentStatus.toLowerCase() == 'accepted' ? 1 : 0);

  bool get _isJobDeleted => widget.jobStatus.toLowerCase() == 'deleted';

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.applicantData['applicationStatus'] ?? 'pending';
    _offerSalary = widget.applicantData['offerSalary']?.toString();
    _offerStartDate = widget.applicantData['offerStartDate'] != null
        ? DateTime.tryParse(widget.applicantData['offerStartDate'].toString())
        : null;
    _offerMessage = widget.applicantData['offerMessage']?.toString();
    _offerLetterUrl = widget.applicantData['offerLetterURL']?.toString();
    _offerDeclineReason =
        widget.applicantData['offerDeclineReason']?.toString();
    _loadAnswers();
    _checkIfScheduled();
    _loadSkills();
    _effectiveJobStatus = widget.jobStatus;
    _vacancies = (widget.jobVacancies != null && widget.jobVacancies! >= 1)
        ? widget.jobVacancies!
        : 1;
    _loadPostInterviewReport();
    _loadHiringProgress();
  }

  Future<void> _loadSkills() async {
    final seekerId = widget.applicantData['seekerID'] as String?;
    final skills = seekerId == null
        ? <SkillModel>[]
        : await _skillController.fetchSkillsForSeeker(seekerId);
    if (!mounted) return;
    setState(() {
      _skills = skills;
      _isLoadingSkills = false;
    });
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

  Future<void> _setAnswerScore(int index, int? tappedScore) async {
    if (_isJobDeleted ||
        _isAutoGradingAnswers ||
        index < 0 ||
        index >= _answers.length) {
      return;
    }
    final ans = _answers[index];
    final answerId = (ans['answerID'] ?? '').toString().trim();
    if (answerId.isEmpty || _savingAnswerIds.contains(answerId)) return;

    final int? currentScore = (ans['score'] as num?)?.toInt();
    final int? nextScore =
        (tappedScore == null || currentScore == tappedScore) ? null : tappedScore;
    if (currentScore == nextScore) return;

    setState(() {
      _answers[index] = Map<String, dynamic>.from(ans)..['score'] = nextScore;
      _savingAnswerIds.add(answerId);
    });

    final ok = await _employerService.updateAnswerScore(answerId, nextScore);
    if (!mounted) return;

    setState(() {
      _savingAnswerIds.remove(answerId);
      if (!ok && index < _answers.length) {
        _answers[index] = Map<String, dynamic>.from(_answers[index])
          ..['score'] = currentScore;
      }
    });

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to save pre-screening mark. Please ensure the database score migration has been run.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _autoGradeAnswersWithAI() async {
    if (_isJobDeleted || _isAutoGradingAnswers || _answers.isEmpty) return;

    final applicantId =
        (widget.applicantData['applicantID'] ?? '').toString().trim();
    if (applicantId.isEmpty) return;

    setState(() => _isAutoGradingAnswers = true);

    final savedScores = await _employerService.autoGradeApplicantAnswersWithAI(
      applicantId: applicantId,
      jobId: _resolvedJobId,
      jobTitle: widget.jobTitle,
      preloadedAnswers: _answers,
      onlyUngraded: false,
    );

    if (!mounted) return;

    if (savedScores.isEmpty) {
      setState(() => _isAutoGradingAnswers = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'AI could not auto-grade the answers. Please check your connection and ensure the database score migration is applied.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      for (int i = 0; i < _answers.length; i++) {
        final ansId = (_answers[i]['answerID'] ?? '').toString().trim();
        if (savedScores.containsKey(ansId)) {
          _answers[i] = Map<String, dynamic>.from(_answers[i])
            ..['score'] = savedScores[ansId];
        }
      }
      _isAutoGradingAnswers = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'AI auto-graded ${savedScores.length} answer${savedScores.length == 1 ? '' : 's'}! You can still tap 0–5 to adjust any mark.',
        ),
        backgroundColor: const Color(0xFF2D8A5D),
      ),
    );
  }

  Future<void> _openChat(String targetUserID, String targetUserName) async {
    await openChatWith(context, targetUserID);
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
        // Resumes / answer files are private: download through a signed URL
        final response = await http.get(Uri.parse(await StorageUrlHelper.resolve(url)));
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

  Future<void> _loadHiringProgress() async {
    if (_resolvedJobId.isEmpty) return;
    final applicantId = (widget.applicantData['applicantID'] ?? '').toString();
    final progress = await _employerService.getJobHiringProgress(
      _resolvedJobId,
      excludeApplicantId: applicantId,
    );
    if (!mounted || progress == null) return;
    setState(() {
      _vacancies = (progress['vacancies'] as int?) ?? _vacancies;
      _acceptedOtherCount = (progress['acceptedOtherCount'] as int?) ?? 0;
      _effectiveJobStatus =
          (progress['jobStatus'] ?? _effectiveJobStatus).toString();
    });
  }

  Future<void> _showQuotaFullDialog(int vacancies) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
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
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3DC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.groups_2_rounded,
                  color: Color(0xFFB7791F),
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Hiring Quota Reached',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2433),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'All $vacancies ${vacancies == 1 ? 'vacancy' : 'vacancies'} for "${widget.jobTitle}" have already been filled.\n\nTo accept another candidate, increase the vacancy count in Edit Job first.',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF687588),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF163B65),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Got It',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _promptSetJobInactiveDialog({
    required int acceptedTotal,
    required int vacancies,
  }) async {
    if (!mounted || _resolvedJobId.isEmpty) return;

    final shouldDeactivate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
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
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F6ED),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF2D8A5D),
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'All Vacancies Filled!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2433),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You have accepted $acceptedTotal of $vacancies ${vacancies == 1 ? 'candidate' : 'candidates'} for "${widget.jobTitle}".\n\nWould you like to set this job posting to Inactive now so new candidates stop applying?',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF687588),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF687588),
                        side: const BorderSide(color: Color(0xFFD6DEE8)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Keep Active',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF163B65),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Set Inactive',
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

    if (shouldDeactivate == true && mounted) {
      final closed = await _employerService.updateJobStatus(
        _resolvedJobId,
        'inactive',
      );
      if (!mounted) return;
      if (closed) {
        setState(() {
          _effectiveJobStatus = 'inactive';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'All vacancies filled — job posting has been set to INACTIVE.',
            ),
            backgroundColor: Color(0xFF163B65),
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_isJobDeleted) return;
    if (_currentStatus.toLowerCase() == newStatus.toLowerCase()) return;

    setState(() => _isUpdating = true);

    final applicantId = (widget.applicantData['applicantID'] ?? '').toString();
    final isAccepting = newStatus.toLowerCase() == 'accepted';

    int vacancies = _vacancies;
    int acceptedOtherCount = _acceptedOtherCount;
    String liveJobStatus = _effectiveJobStatus;

    if (isAccepting && _resolvedJobId.isNotEmpty) {
      final progress = await _employerService.getJobHiringProgress(
        _resolvedJobId,
        excludeApplicantId: applicantId,
      );
      if (progress != null) {
        vacancies = (progress['vacancies'] as int?) ?? vacancies;
        acceptedOtherCount =
            (progress['acceptedOtherCount'] as int?) ?? acceptedOtherCount;
        liveJobStatus =
            (progress['jobStatus'] ?? liveJobStatus).toString();
      }

      if (acceptedOtherCount >= vacancies) {
        if (mounted) {
          setState(() {
            _isUpdating = false;
            _vacancies = vacancies;
            _acceptedOtherCount = acceptedOtherCount;
            _effectiveJobStatus = liveJobStatus;
          });
          await _showQuotaFullDialog(vacancies);
        }
        return;
      }
    }

    final success = await _employerService.updateApplicationStatus(
      applicantId,
      newStatus,
    );

    if (!mounted) return;

    setState(() {
      _isUpdating = false;
      if (success) {
        _currentStatus = newStatus;
        _vacancies = vacancies;
        _acceptedOtherCount = acceptedOtherCount;
        _effectiveJobStatus = liveJobStatus;
      }
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

    if (success) {
      if (isAccepting) {
        final newAcceptedTotal = acceptedOtherCount + 1;
        if (newAcceptedTotal >= vacancies &&
            liveJobStatus.toLowerCase() == 'active') {
          await _promptSetJobInactiveDialog(
            acceptedTotal: newAcceptedTotal,
            vacancies: vacancies,
          );
        }
      } else {
        await _loadHiringProgress();
      }
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
      case 'offered':
        return const Color(0xFF4C6EF5);
      case 'accepted':
        return Colors.green;
      case 'offer_declined':
        return const Color(0xFFC77700);
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatStatusDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'UNDER REVIEW (PENDING)';
      case 'scheduled':
        return 'INTERVIEW SCHEDULED';
      case 'interviewed':
        return 'INTERVIEW COMPLETED';
      case 'offered':
        return 'OFFER LETTER SENT';
      case 'accepted':
        return 'OFFER ACCEPTED (HIRED)';
      case 'offer_declined':
        return 'OFFER DECLINED BY CANDIDATE';
      case 'rejected':
        return 'REJECTED';
      default:
        return status.toUpperCase();
    }
  }

  Future<void> _showSendOfferLetterDialog(Map<String, dynamic> seeker) async {
    if (_isJobDeleted) return;

    final applicantId =
        (widget.applicantData['applicantID'] ?? '').toString().trim();
    final seekerId =
        (widget.applicantData['seekerID'] ?? '').toString().trim();
    final candidateName = (seeker['fullName'] ?? 'Candidate').toString().trim();

    if (_resolvedJobId.isNotEmpty) {
      final progress = await _employerService.getJobHiringProgress(
        _resolvedJobId,
        excludeApplicantId: applicantId,
      );
      if (progress != null && mounted) {
        final vacancies = (progress['vacancies'] as int?) ?? _vacancies;
        final acceptedOtherCount =
            (progress['acceptedOtherCount'] as int?) ?? _acceptedOtherCount;
        setState(() {
          _vacancies = vacancies;
          _acceptedOtherCount = acceptedOtherCount;
          _effectiveJobStatus =
              (progress['jobStatus'] ?? _effectiveJobStatus).toString();
        });
        if (acceptedOtherCount >= vacancies) {
          await _showQuotaFullDialog(vacancies);
          return;
        }
      }
    }

    if (!mounted) return;

    final salaryController = TextEditingController(
      text: (_offerSalary != null && _offerSalary!.trim().isNotEmpty)
          ? _offerSalary!.trim()
          : 'RM 4,000 / month',
    );
    DateTime selectedStartDate =
        _offerStartDate ?? DateTime.now().add(const Duration(days: 14));
    final messageController = TextEditingController(
      text: (_offerMessage != null && _offerMessage!.trim().isNotEmpty)
          ? _offerMessage!.trim()
          : 'Dear $candidateName,\n\nWe are pleased to offer you the position of ${widget.jobTitle}. Please review the offered compensation, start date, and attached offer letter details, then click Accept Offer or Decline Offer in the app.\n\nWarm regards,\nHiring Team',
    );

    File? pickedPdfFile;
    String? pickedPdfName;
    String? existingPdfUrl = _offerLetterUrl;
    String? formError;
    bool isDraftingAi = false;
    bool isSendingOffer = false;

    final didSend = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final startDateLabel =
                selectedStartDate.toIso8601String().split('T').first;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCE4EE),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCEBFB),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              color: Color(0xFF163B65),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Send Offer Letter',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1B2433),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'To $candidateName • ${widget.jobTitle}',
                                  overflow: TextOverflow.ellipsis,
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
                      const SizedBox(height: 18),
                      const Text(
                        'Offered Salary / Compensation *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2433),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: salaryController,
                        decoration: InputDecoration(
                          hintText: 'e.g. RM 4,200 / month',
                          prefixIcon: const Icon(
                            Icons.payments_outlined,
                            color: Color(0xFF163B65),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF7F9FC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE4EE),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE4EE),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Proposed Start Date *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2433),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: isSendingOffer
                            ? null
                            : () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: sheetContext,
                                  initialDate: selectedStartDate.isBefore(now)
                                      ? now
                                      : selectedStartDate,
                                  firstDate: now,
                                  lastDate:
                                      now.add(const Duration(days: 365 * 2)),
                                );
                                if (picked != null) {
                                  setSheetState(() {
                                    selectedStartDate = picked;
                                  });
                                }
                              },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFDCE4EE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.event_available_rounded,
                                color: Color(0xFF163B65),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  startDateLabel,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1B2433),
                                  ),
                                ),
                              ),
                              const Text(
                                'Change',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF163B65),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Offer Letter Message / Terms *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B2433),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: (isDraftingAi || isSendingOffer)
                                ? null
                                : () async {
                                    setSheetState(() => isDraftingAi = true);
                                    final drafted = await _employerService
                                        .generateOfferLetterWithAI(
                                      candidateName: candidateName,
                                      jobTitle: widget.jobTitle,
                                      offerSalary: salaryController.text.trim().isEmpty
                                          ? 'Competitive package'
                                          : salaryController.text.trim(),
                                      offerStartDate: selectedStartDate,
                                    );
                                    if (drafted != null) {
                                      messageController.text = drafted;
                                    }
                                    setSheetState(() => isDraftingAi = false);
                                  },
                            icon: isDraftingAi
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 16,
                                  ),
                            label: Text(
                              isDraftingAi ? 'Drafting...' : 'AI Draft',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextField(
                        controller: messageController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText:
                              'Write your offer terms, benefits, and instructions for the candidate...',
                          filled: true,
                          fillColor: const Color(0xFFF7F9FC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE4EE),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE4EE),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Official Offer Letter PDF (Optional)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2433),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDCE4EE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: Color(0xFFC24E4E),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                pickedPdfName ??
                                    ((existingPdfUrl != null &&
                                            existingPdfUrl!.trim().isNotEmpty)
                                        ? 'Existing Offer Letter PDF attached'
                                        : 'No PDF attached (optional)'),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: (pickedPdfName != null ||
                                          (existingPdfUrl != null &&
                                              existingPdfUrl!
                                                  .trim()
                                                  .isNotEmpty))
                                      ? const Color(0xFF1B2433)
                                      : const Color(0xFF687588),
                                ),
                              ),
                            ),
                            if (pickedPdfFile != null ||
                                (existingPdfUrl != null &&
                                    existingPdfUrl!.trim().isNotEmpty))
                              IconButton(
                                onPressed: isSendingOffer
                                    ? null
                                    : () {
                                        setSheetState(() {
                                          pickedPdfFile = null;
                                          pickedPdfName = null;
                                          existingPdfUrl = null;
                                        });
                                      },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Color(0xFF687588),
                                ),
                                tooltip: 'Remove PDF',
                              ),
                            OutlinedButton.icon(
                              onPressed: isSendingOffer
                                  ? null
                                  : () async {
                                      final res =
                                          await FilePicker.pickFiles(
                                        type: FileType.custom,
                                        allowedExtensions: const ['pdf'],
                                      );
                                      if (res != null &&
                                          res.files.isNotEmpty &&
                                          res.files.single.path != null) {
                                        setSheetState(() {
                                          pickedPdfFile = File(
                                            res.files.single.path!,
                                          );
                                          pickedPdfName = res.files.single.name;
                                        });
                                      }
                                    },
                              icon: const Icon(
                                Icons.upload_file_rounded,
                                size: 16,
                              ),
                              label: Text(
                                pickedPdfFile != null ? 'Replace' : 'Attach PDF',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF163B65),
                                side: const BorderSide(
                                  color: Color(0xFF163B65),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          formError!,
                          style: const TextStyle(
                            color: Color(0xFFC24E4E),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSendingOffer
                                  ? null
                                  : () => Navigator.pop(sheetContext, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF687588),
                                side: const BorderSide(
                                  color: Color(0xFFDCE4EE),
                                ),
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
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: isSendingOffer
                                  ? null
                                  : () async {
                                      final sal = salaryController.text.trim();
                                      final msg = messageController.text.trim();
                                      if (sal.isEmpty) {
                                        setSheetState(() {
                                          formError =
                                              'Please enter the offered salary / compensation.';
                                        });
                                        return;
                                      }
                                      if (msg.isEmpty) {
                                        setSheetState(() {
                                          formError =
                                              'Please enter the offer letter message.';
                                        });
                                        return;
                                      }
                                      setSheetState(() {
                                        formError = null;
                                        isSendingOffer = true;
                                      });

                                      final result =
                                          await _employerService.sendOfferLetter(
                                        applicantId: applicantId,
                                        seekerId: seekerId,
                                        offerSalary: sal,
                                        offerStartDate: selectedStartDate,
                                        offerMessage: msg,
                                        offerLetterFile: pickedPdfFile,
                                        existingOfferLetterUrl: existingPdfUrl,
                                      );

                                      if (result == null) {
                                        setSheetState(() {
                                          isSendingOffer = false;
                                          formError =
                                              'Failed to send offer letter. Please ensure the offer database migration has been applied.';
                                        });
                                        return;
                                      }

                                      if (mounted) {
                                        setState(() {
                                          _currentStatus = 'offered';
                                          _offerSalary = sal;
                                          _offerStartDate = selectedStartDate;
                                          _offerMessage = msg;
                                          _offerLetterUrl =
                                              result['offerLetterURL']
                                                  ?.toString();
                                          _offerDeclineReason = null;
                                        });
                                      }

                                      if (sheetContext.mounted) {
                                        Navigator.pop(sheetContext, true);
                                      }
                                    },
                              icon: isSendingOffer
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: Text(
                                isSendingOffer
                                    ? 'Sending Offer...'
                                    : 'Send Offer Letter',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF163B65),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
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
              ),
            );
          },
        );
      },
    );

    if (didSend == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Offer letter sent! Waiting for the candidate to accept or decline.',
          ),
          backgroundColor: Color(0xFF2D8A5D),
        ),
      );
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
            _buildSectionCard(
              title: 'Skills',
              subtitle: 'Skills the candidate listed on their profile.',
              child: _isLoadingSkills
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(color: Color(0xFF163B65)),
                      ),
                    )
                  : _skills.isEmpty
                      ? const Text(
                          'No skills listed.',
                          style: TextStyle(
                            color: Color(0xFF687588),
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : SkillChips(skills: _skills),
            ),
            const SizedBox(height: 18),
            if (_postInterviewReport != null) ...[
              _buildPostInterviewReportCard(_postInterviewReport!),
              const SizedBox(height: 18),
            ],
            if (aiScore != null ||
                (widget.applicantData['aiFeedback'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty) ...[
              _buildAiAnalysisCard(aiScore),
              const SizedBox(height: 18),
            ],
            _buildSectionCard(
              title: 'Pre-Screening Answers',
              subtitle:
                  'Read and grade each candidate response out of 5 marks (employer-only).',
              headerTrailing: (!_isLoadingAnswers && _answers.isNotEmpty)
                  ? _buildPreScreeningHeaderToggle()
                  : null,
              onHeaderTap: (!_isLoadingAnswers && _answers.isNotEmpty)
                  ? () {
                      setState(() {
                        _isPreScreeningExpanded = !_isPreScreeningExpanded;
                      });
                    }
                  : null,
              child: _buildAnswersSection(),
            ),
            const SizedBox(height: 18),
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

  Future<void> _loadPostInterviewReport() async {
    final applicantId = (widget.applicantData['applicantID'] ?? '').toString();
    if (applicantId.isEmpty) return;
    final report =
        await _employerService.getPostInterviewReportByApplicantId(applicantId);
    if (!mounted) return;
    setState(() => _postInterviewReport = report);
  }

  Widget _buildPostInterviewReportCard(PostInterviewReportModel report) {
    final int overall = report.overallScore;
    Color badgeFg = const Color(0xFFC28A22);
    Color badgeBg = const Color(0xFFFEF3DC);
    if (overall >= 75) {
      badgeFg = const Color(0xFF2D8A5D);
      badgeBg = const Color(0xFFE5F6ED);
    } else if (overall < 50) {
      badgeFg = const Color(0xFFC24E4E);
      badgeBg = const Color(0xFFFDECEC);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8F5FF), Color(0xFFEEF4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2D8FF)),
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
                  color: const Color(0xFF6B4FD3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Post-Interview AI Report',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B2433),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${report.recommendation} · ${report.formattedDuration}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF687588),
                      ),
                    ),
                  ],
                ),
              ),
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
                  '$overall / 100',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPostReportMiniChip('Role Fit ${report.contentScore}/100'),
              _buildPostReportMiniChip('Delivery ${report.deliveryScore}/100'),
              if (report.estimatedWpm > 0)
                _buildPostReportMiniChip('~${report.estimatedWpm} WPM'),
            ],
          ),
          if (report.summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                report.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.48,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PostInterviewAiReportScreen(initialReport: report),
                  ),
                );
              },
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text(
                'View Full AI Report & PDF',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF163B65),
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
    );
  }

  Widget _buildPostReportMiniChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD8E4F5)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF163B65),
        ),
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

  Widget _buildPipelineStepper() {
    final norm = _currentStatus.toLowerCase();
    int activeStep = 0;
    if (norm == 'scheduled') {
      activeStep = 1;
    } else if (norm == 'interviewed') {
      activeStep = 2;
    } else if (norm == 'offered') {
      activeStep = 3;
    } else if (norm == 'accepted' || norm == 'offer_declined') {
      activeStep = 4;
    } else if (norm == 'rejected') {
      activeStep = _hasBeenScheduled ? 2 : 0;
    }

    const labels = [
      'Review',
      'Schedule',
      'Interview',
      'Offer',
      'Decision',
    ];

    final isTerminalNegative =
        norm == 'rejected' || norm == 'offer_declined';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < activeStep
                          ? const Color(0xFF2D8A5D)
                          : (i == activeStep
                              ? (isTerminalNegative
                                  ? const Color(0xFFC24E4E)
                                  : (norm == 'accepted'
                                      ? const Color(0xFF2D8A5D)
                                      : const Color(0xFF163B65)))
                              : const Color(0xFFDCE4EE)),
                    ),
                    child: i < activeStep || (i == 4 && norm == 'accepted')
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : (i == activeStep && isTerminalNegative)
                            ? const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.white,
                              )
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: i <= activeStep
                                      ? Colors.white
                                      : const Color(0xFF687588),
                                ),
                              ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: i == activeStep
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: i <= activeStep
                          ? const Color(0xFF1B2433)
                          : const Color(0xFF687588),
                    ),
                  ),
                ],
              ),
            ),
            if (i < labels.length - 1)
              Container(
                width: 12,
                height: 2,
                color: i < activeStep
                    ? const Color(0xFF2D8A5D)
                    : const Color(0xFFDCE4EE),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfferDetailsSummaryCard() {
    final hasSalary =
        _offerSalary != null && _offerSalary!.trim().isNotEmpty;
    final hasStart = _offerStartDate != null;
    final hasMsg =
        _offerMessage != null && _offerMessage!.trim().isNotEmpty;
    final hasPdf =
        _offerLetterUrl != null && _offerLetterUrl!.trim().isNotEmpty;

    if (!hasSalary && !hasStart && !hasMsg && !hasPdf) {
      return const SizedBox.shrink();
    }

    final startStr = hasStart
        ? _offerStartDate!.toIso8601String().split('T').first
        : 'To be confirmed';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE4EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 18,
                color: Color(0xFF163B65),
              ),
              SizedBox(width: 8),
              Text(
                'Offer Letter Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2433),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasSalary)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Offered Salary: ${_offerSalary!.trim()}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2433),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Proposed Start Date: $startStr',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4F5C6C),
              ),
            ),
          ),
          if (hasMsg) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5ECF4)),
              ),
              child: Text(
                _offerMessage!.trim(),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Color(0xFF4F5C6C),
                ),
              ),
            ),
          ],
          if (hasPdf) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isDownloadingFile
                    ? null
                    : () => _downloadAndOpenFile(
                          _offerLetterUrl!,
                          'offer_letter.pdf',
                        ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text('Open Attached Offer Letter PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF163B65),
                  side: const BorderSide(color: Color(0xFF163B65)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPipelineStepper(),
        Container(
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
                      _formatStatusDisplay(_currentStatus),
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHiringProgressBanner(bool isQuotaFullForNewAccept) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isQuotaFullForNewAccept
            ? const Color(0xFFFEF3DC)
            : const Color(0xFFE5F6ED),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isQuotaFullForNewAccept
                ? Icons.info_outline_rounded
                : Icons.groups_2_rounded,
            size: 18,
            color: isQuotaFullForNewAccept
                ? const Color(0xFF9A640C)
                : const Color(0xFF2D8A5D),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isQuotaFullForNewAccept
                  ? 'Hiring quota full ($_currentAcceptedTotal/$_vacancies hired). Increase vacancies in Edit Job to hire more.'
                  : 'Hiring Progress: $_currentAcceptedTotal of $_vacancies ${(_vacancies == 1) ? 'vacancy' : 'vacancies'} filled (counted after candidate accepts offer)',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isQuotaFullForNewAccept
                    ? const Color(0xFF9A640C)
                    : const Color(0xFF2D8A5D),
              ),
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

    final isQuotaFullForNewAccept =
        normalizedStatus != 'accepted' && _acceptedOtherCount >= _vacancies;

    if (normalizedStatus == 'interviewed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHiringProgressBanner(isQuotaFullForNewAccept),
          const Text(
            'Interview completed. Send an Offer Letter to invite the candidate to join, or reject the application.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF687588),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showSendOfferLetterDialog(seeker),
              icon: const Icon(Icons.workspace_premium_rounded),
              label: const Text(
                'Send Offer Letter',
                style: TextStyle(fontWeight: FontWeight.w700),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _updateStatus('rejected'),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC24E4E),
                    side: const BorderSide(color: Color(0xFFC24E4E)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _showRescheduleConfirmation(seeker),
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: const Text('Reschedule'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF163B65),
                    backgroundColor: const Color(0xFFDCEBFB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (normalizedStatus == 'offered') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHiringProgressBanner(isQuotaFullForNewAccept),
          _buildStateMessageCard(
            color: const Color(0xFF4C6EF5),
            icon: Icons.mark_email_unread_rounded,
            title: 'Waiting for Candidate Offer Decision',
            description:
                'Offer letter has been sent. Once the candidate accepts the offer, they will be marked as Hired and counted toward the job vacancy quota.',
          ),
          _buildOfferDetailsSummaryCard(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSendOfferLetterDialog(seeker),
                  icon: const Icon(Icons.edit_document, size: 18),
                  label: const Text('Update Offer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF163B65),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Withdraw Offer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC24E4E),
                    side: const BorderSide(color: Color(0xFFC24E4E)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (normalizedStatus == 'accepted') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHiringProgressBanner(false),
          _buildStateMessageCard(
            color: const Color(0xFF2D8A5D),
            icon: Icons.verified_rounded,
            title: 'Candidate Accepted Offer (Hired)',
            description:
                'The candidate has officially accepted your offer letter and is counted toward the filled vacancies.',
          ),
          _buildOfferDetailsSummaryCard(),
        ],
      );
    }

    if (normalizedStatus == 'offer_declined') {
      final reason = (_offerDeclineReason ?? '').trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHiringProgressBanner(isQuotaFullForNewAccept),
          _buildStateMessageCard(
            color: const Color(0xFFC77700),
            icon: Icons.unsubscribe_rounded,
            title: 'Candidate Declined Offer Letter',
            description: reason.isNotEmpty
                ? 'Candidate reason: "$reason"\nYou can send a revised offer or close this application.'
                : 'The candidate declined the offer letter. This vacancy slot remains open.',
          ),
          _buildOfferDetailsSummaryCard(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSendOfferLetterDialog(seeker),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send Revised Offer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF163B65),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Mark Rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC24E4E),
                    side: const BorderSide(color: Color(0xFFC24E4E)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (normalizedStatus == 'rejected' && _hasBeenScheduled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHiringProgressBanner(isQuotaFullForNewAccept),
          _buildStateMessageCard(
            color: const Color(0xFFC24E4E),
            icon: Icons.cancel_rounded,
            title: 'Application Rejected',
            description:
                'This candidate was marked as rejected. You can still send an offer letter or reschedule if needed.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSendOfferLetterDialog(seeker),
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: const Text('Send Offer Instead'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF163B65),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _showRescheduleConfirmation(seeker),
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: const Text('Reschedule'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF163B65),
                    backgroundColor: const Color(0xFFDCEBFB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
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

  Widget _buildPreScreeningHeaderToggle() {
    final count = _answers.length;
    final label = count == 1 ? '1 Question' : '$count Questions';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF4FB),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFD6E3F3)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF163B65),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5FA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _isPreScreeningExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: const Color(0xFF163B65),
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

    final int totalQuestions = _answers.length;
    final int maxTotalMarks = totalQuestions * 5;
    int gradedCount = 0;
    int earnedTotal = 0;
    for (final ans in _answers) {
      final int? s = (ans['score'] as num?)?.toInt();
      if (s != null) {
        gradedCount++;
        earnedTotal += s;
      }
    }

    Color summaryBadgeBg = const Color(0xFFEFF3F8);
    Color summaryBadgeFg = const Color(0xFF687588);
    if (gradedCount > 0 && maxTotalMarks > 0) {
      final double pct = earnedTotal / maxTotalMarks;
      if (pct >= 0.7) {
        summaryBadgeBg = const Color(0xFFE5F6ED);
        summaryBadgeFg = const Color(0xFF2D8A5D);
      } else if (pct >= 0.4) {
        summaryBadgeBg = const Color(0xFFFEF3DC);
        summaryBadgeFg = const Color(0xFF9A640C);
      } else {
        summaryBadgeBg = const Color(0xFFFCE9E9);
        summaryBadgeFg = const Color(0xFFC24E4E);
      }
    }

    final String summaryMainText = gradedCount == 0
        ? '? / $maxTotalMarks'
        : '$earnedTotal / $maxTotalMarks';
    final String summarySubText = gradedCount == 0
        ? '0 of $totalQuestions reviewed • Expand below to grade'
        : '$gradedCount of $totalQuestions reviewed • Avg ${(earnedTotal / gradedCount).toStringAsFixed(1)}/5';

    final bool allIndividualCollapsed =
        _collapsedQuestionIndices.length >= totalQuestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5FA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDCE4EE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCEBFB),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.fact_check_rounded,
                      size: 20,
                      color: Color(0xFF163B65),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Pre-Screening Marks',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B2433),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          summarySubText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF687588),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: summaryBadgeBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      summaryMainText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: summaryBadgeFg,
                      ),
                    ),
                  ),
                ],
              ),
              if (!_isJobDeleted) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isAutoGradingAnswers ||
                            _savingAnswerIds.isNotEmpty
                        ? null
                        : _autoGradeAnswersWithAI,
                    icon: _isAutoGradingAnswers
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 17),
                    label: Text(
                      _isAutoGradingAnswers
                          ? 'AI Auto-Grading Answers...'
                          : (gradedCount == 0
                              ? 'AI Auto-Grade Answers (0–5)'
                              : 'Re-Run AI Auto-Grade (0–5)'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF163B65),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFDCE4EE)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isPreScreeningExpanded = !_isPreScreeningExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD6E1EE)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isPreScreeningExpanded
                                  ? Icons.visibility_off_outlined
                                  : Icons.quiz_outlined,
                              size: 16,
                              color: const Color(0xFF163B65),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _isPreScreeningExpanded
                                    ? 'Hide'
                                    : 'Show $totalQuestions ${totalQuestions == 1 ? 'Question & Answer' : 'Questions & Answers'}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF163B65),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _isPreScreeningExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: const Color(0xFF163B65),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_isPreScreeningExpanded && totalQuestions > 1) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (allIndividualCollapsed) {
                            _collapsedQuestionIndices.clear();
                          } else {
                            for (int i = 0; i < totalQuestions; i++) {
                              _collapsedQuestionIndices.add(i);
                            }
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF163B65),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        allIndividualCollapsed ? 'Expand All' : 'Collapse All',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: !_isPreScreeningExpanded
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _answers.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final ans = _answers[index];
                      final question = ans['PreScreeningQuestion'] ?? {};
                      final qText =
                          question['questionText'] ?? 'Unknown Question';
                      final isFile = question['questionType'] == 'File';
                      final answerFileUrl = ans['answerFileURL'];
                      final String answerId =
                          (ans['answerID'] ?? '').toString().trim();
                      final int? score = (ans['score'] as num?)?.toInt();
                      final bool isSaving =
                          _savingAnswerIds.contains(answerId);
                      final bool isItemCollapsed =
                          _collapsedQuestionIndices.contains(index);

                      Color scoreBadgeBg = const Color(0xFFEFF3F8);
                      Color scoreBadgeFg = const Color(0xFF687588);
                      if (score != null) {
                        if (score >= 4) {
                          scoreBadgeBg = const Color(0xFFE5F6ED);
                          scoreBadgeFg = const Color(0xFF2D8A5D);
                        } else if (score >= 2) {
                          scoreBadgeBg = const Color(0xFFFEF3DC);
                          scoreBadgeFg = const Color(0xFF9A640C);
                        } else {
                          scoreBadgeBg = const Color(0xFFFCE9E9);
                          scoreBadgeFg = const Color(0xFFC24E4E);
                        }
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5ECF4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (isItemCollapsed) {
                                    _collapsedQuestionIndices.remove(index);
                                  } else {
                                    _collapsedQuestionIndices.add(index);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCEBFB),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Q${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF163B65),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      qText,
                                      maxLines: isItemCollapsed ? 1 : null,
                                      overflow: isItemCollapsed
                                          ? TextOverflow.ellipsis
                                          : null,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1B2433),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scoreBadgeBg,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      score == null ? '?/5' : '$score/5',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: scoreBadgeFg,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    isItemCollapsed
                                        ? Icons.keyboard_arrow_down_rounded
                                        : Icons.keyboard_arrow_up_rounded,
                                    size: 20,
                                    color: const Color(0xFF687588),
                                  ),
                                ],
                              ),
                            ),
                            if (!isItemCollapsed) ...[
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
                                    side: const BorderSide(
                                      color: Color(0xFF163B65),
                                    ),
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
                              const SizedBox(height: 14),
                              const Divider(
                                height: 1,
                                color: Color(0xFFE5ECF4),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.grade_outlined,
                                        size: 16,
                                        color: Color(0xFF687588),
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'Marks:',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF687588),
                                        ),
                                      ),
                                    ],
                                  ),
                                  for (int mark = 0; mark <= 5; mark++)
                                    _buildMarkOptionPill(
                                      mark: mark,
                                      isSelected: score == mark,
                                      isDisabled: _isJobDeleted ||
                                          _isAutoGradingAnswers ||
                                          isSaving ||
                                          answerId.isEmpty,
                                      onTap: () => _setAnswerScore(index, mark),
                                    ),
                                  if (isSaving)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else if (score != null &&
                                      !_isJobDeleted &&
                                      !_isAutoGradingAnswers)
                                    InkWell(
                                      onTap: () => _setAnswerScore(index, null),
                                      borderRadius: BorderRadius.circular(999),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        child: Text(
                                          'Reset',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF687588),
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMarkOptionPill({
    required int mark,
    required bool isSelected,
    required bool isDisabled,
    required VoidCallback onTap,
  }) {
    final Color bgColor =
        isSelected ? const Color(0xFF163B65) : Colors.white;
    final Color borderColor = isSelected
        ? const Color(0xFF163B65)
        : const Color(0xFFDCE4EE);
    final Color textColor =
        isSelected ? Colors.white : const Color(0xFF1B2433);

    return Opacity(
      opacity: isDisabled && !isSelected ? 0.55 : 1.0,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              '$mark',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? headerTrailing,
    VoidCallback? onHeaderTap,
  }) {
    final headerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2433),
                ),
              ),
            ),
            if (headerTrailing != null) ...[
              const SizedBox(width: 10),
              headerTrailing,
            ],
          ],
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
      ],
    );

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
          if (onHeaderTap != null)
            InkWell(
              onTap: onHeaderTap,
              borderRadius: BorderRadius.circular(14),
              child: headerContent,
            )
          else
            headerContent,
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
      case 'offered':
        return Icons.mark_email_unread_rounded;
      case 'accepted':
        return Icons.verified_rounded;
      case 'offer_declined':
        return Icons.unsubscribe_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }
}
