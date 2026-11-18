import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/data_load_exception.dart';
import '../../../../core/utils/storage_url_helper.dart';
import '../../../../models/job_applicant_model.dart';
import '../../../../models/job_model.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../services/notification_service.dart';
import '../../../../shared_widgets/confirm_dialog.dart';
import '../../controllers/applied_jobs_controller.dart';
import '../../screens/job_details_screen.dart';
import '../../screens/unavailable_job_notice_screen.dart';
import '../load_error_view.dart';
import 'my_jobs_empty_state.dart';

/// My Jobs > Applied tab.
class AppliedJobsTab extends StatefulWidget {
  const AppliedJobsTab({super.key});

  @override
  State<AppliedJobsTab> createState() => _AppliedJobsTabState();
}

class _AppliedJobsTabState extends State<AppliedJobsTab> {
  final AppliedJobsController _appliedController = AppliedJobsController();
  List<Map<String, dynamic>> _appliedJobs = [];
  bool _isLoading = true;
  bool _isDownloadingPdf = false;
  String? _loadError;
  String? _withdrawingId; // application being withdrawn

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

  /// Loads the user's applications.
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

  /// Try Again after loading failed.
  void _retry() {
    setState(() => _isLoading = true);
    _loadAppliedJobs();
  }

  /// Withdraws a pending application after asking.
  Future<void> _withdraw(JobApplicantModel application, String jobTitle) async {
    final id = application.applicantID;
    if (id == null || _withdrawingId != null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Withdraw application?',
      message: 'Your application for $jobTitle will be withdrawn. The employer will no '
          'longer see it, and you won\'t be able to apply for this job again.',
      confirmLabel: 'Withdraw',
    );
    if (!confirmed || !mounted) return;

    setState(() => _withdrawingId = id);
    try {
      await _appliedController.withdrawApplication(id);
      unawaited(NotificationService.refreshUnreadCount()); // its notifications are gone
      if (mounted) SnackBarHelper.showSuccess(context, 'Application withdrawn.');
    } on DataLoadException catch (e) {
      if (mounted) SnackBarHelper.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _withdrawingId = null);
    }
  }

  /// The badge colour for an application status.
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.statusPending;
      case 'scheduled':
        return AppColors.statusScheduled;
      case 'interviewed':
        return AppColors.statusInterviewed;
      case 'offered':
        return AppColors.statusScheduled;
      case 'accepted':
        return AppColors.statusAccepted;
      case 'offer_declined':
        return AppColors.warning;
      case 'rejected':
        return AppColors.statusRejected;
      case 'inactive':
        return AppColors.statusInactive;
      case 'deleted':
        return AppColors.textMuted;
      case 'withdrawn':
        return AppColors.statusInactive;
      default:
        return AppColors.textMuted;
    }
  }

  /// The badge text for a status ("OFFER RECEIVED", "PENDING", ...).
  String _formatStatusBadgeLabel(String status) {
    switch (status.toLowerCase()) {
      case 'offered':
        return 'OFFER RECEIVED';
      case 'accepted':
        return 'OFFER ACCEPTED';
      case 'offer_declined':
        return 'OFFER DECLINED';
      default:
        return status.toUpperCase();
    }
  }

  /// Downloads the offer letter PDF and opens it.
  Future<void> _downloadAndOpenOfferPdf(String url) async {
    if (_isDownloadingPdf) return;
    setState(() => _isDownloadingPdf = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening Offer Letter PDF...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      String fileName = url.split('/').last.split('?').first;
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        fileName = 'offer_letter_${DateTime.now().millisecondsSinceEpoch}.pdf';
      }

      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/$fileName';
      final file = File(savePath);

      if (!await _isSavedPdf(file)) {
        final signedUrl = await StorageUrlHelper.resolve(url);
        final response =
            await http.get(Uri.parse(signedUrl)).timeout(const Duration(seconds: 30));
        // Never save an error page as the PDF: it would be reopened every time
        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode}');
        }
        await file.writeAsBytes(response.bodyBytes, flush: true);
      }

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done && mounted) {
        SnackBarHelper.showError(
          context,
          'Could not open the PDF. Please make sure a PDF viewer is installed.',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Unable to download the offer letter PDF.');
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingPdf = false);
      }
    }
  }

  /// True if [file] was downloaded before and really is a PDF (starts with
  /// "%PDF"). A broken earlier download is fetched again.
  static Future<bool> _isSavedPdf(File file) async {
    try {
      if (!await file.exists()) return false;
      final head = await file.openRead(0, 4).first;
      return String.fromCharCodes(head) == '%PDF';
    } catch (_) {
      return false;
    }
  }

  /// Asks why the offer is declined. Returns the reason, or null if cancelled.
  Future<String?> _promptDeclineReasonDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Decline Job Offer?',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Let the employer know why you are declining this offer (optional).',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. Accepted another offer / salary expectation...',
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext, controller.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Decline Offer',
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
  }

  /// Shows the job offer with Accept / Decline.
  Future<void> _showOfferLetterModal({
    required JobApplicantModel application,
    required Map<String, dynamic> rawData,
    required String jobTitle,
    required String companyName,
  }) async {
    final applicantId = (application.applicantID ?? '').trim();
    if (applicantId.isEmpty) return;

    final statusNorm = application.applicationStatus.trim().toLowerCase();
    final isOfferPending = statusNorm == 'offered';
    final isOfferAccepted = statusNorm == 'accepted';
    final isOfferDeclined = statusNorm == 'offer_declined';

    final rawSalary = (rawData['offerSalary'] ?? '').toString().trim();
    final salary = rawSalary.isNotEmpty ? rawSalary : 'As discussed';

    final rawStart = (rawData['offerStartDate'] ?? '').toString().trim();
    final parsedStart =
        rawStart.isNotEmpty ? DateTime.tryParse(rawStart) : null;
    final startDate = parsedStart != null
        ? parsedStart.toIso8601String().split('T').first
        : (rawStart.isNotEmpty ? rawStart : 'To be confirmed');

    final rawMessage = (rawData['offerMessage'] ?? '').toString().trim();
    final message = rawMessage.isNotEmpty
        ? rawMessage
        : 'Congratulations! We would like to extend an offer for you to join our team.';
    final pdfUrl = (rawData['offerLetterURL'] ?? '').toString().trim();

    bool isSubmitting = false;
    String? errorText;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            /// Accepts or declines the offer (spinner meanwhile; errors stay in the sheet).
            Future<void> respond({required bool accept, String? declineReason}) async {
              setSheetState(() {
                isSubmitting = true;
                errorText = null;
              });
              try {
                await _appliedController.respondToJobOffer(
                  applicantId: applicantId,
                  accept: accept,
                  declineReason: declineReason,
                );
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(accept
                          ? 'Congratulations! You have accepted the job offer.'
                          : 'You have declined the job offer.'),
                      backgroundColor: accept ? AppColors.statusAccepted : AppColors.warning,
                    ),
                  );
                }
              } on DataLoadException catch (e) {
                if (!sheetContext.mounted) return; // sheet closed meanwhile
                setSheetState(() {
                  isSubmitting = false;
                  errorText = e.message;
                });
              } catch (_) {
                if (!sheetContext.mounted) return; // sheet closed meanwhile
                setSheetState(() {
                  isSubmitting = false;
                  errorText = 'Failed to ${accept ? 'accept' : 'decline'} offer. Please try again.';
                });
              }
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Official Offer Letter',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$jobTitle • $companyName',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.payments_outlined,
                                size: 19,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Offered Salary:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  salary,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1, color: AppColors.border),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.event_available_rounded,
                                size: 19,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Proposed Start Date:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  startDate,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Offer Message & Terms',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        message,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    if (pdfUrl.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isDownloadingPdf
                              ? null
                              : () => _downloadAndOpenOfferPdf(pdfUrl),
                          icon: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: AppColors.danger,
                          ),
                          label: const Text(
                            'Download / View Attached Offer Letter PDF',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (isOfferPending)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final reason = await _promptDeclineReasonDialog();
                                      if (reason != null) await respond(accept: false, declineReason: reason);
                                    },
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text(
                                'Decline Offer',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side:
                                    const BorderSide(color: AppColors.danger),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () => respond(accept: true),
                              icon: isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_rounded, size: 18),
                              label: Text(
                                isSubmitting ? 'Submitting...' : 'Accept Offer',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.statusAccepted,
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
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isOfferAccepted
                              ? AppColors.statusAccepted.withValues(alpha: 0.12)
                              : (isOfferDeclined
                                  ? AppColors.warning.withValues(alpha: 0.12)
                                  : AppColors.surfaceAlt),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isOfferAccepted
                                  ? Icons.verified_rounded
                                  : Icons.info_outline_rounded,
                              color: isOfferAccepted
                                  ? AppColors.statusAccepted
                                  : AppColors.warning,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isOfferAccepted
                                    ? 'You accepted this offer.'
                                    : (isOfferDeclined
                                        ? 'You declined this offer.'
                                        : 'Offer status: ${application.applicationStatus.toUpperCase()}'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isOfferAccepted
                                      ? AppColors.statusAccepted
                                      : AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

    if (_appliedJobs.isEmpty) {
      return const MyJobsEmptyState(
        icon: Icons.assignment_ind_outlined,
        title: 'No applications yet',
        subtitle:
            'Once you apply for a role, it will appear here with its latest status.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadAppliedJobs,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: _appliedJobs.length,
        itemBuilder: (context, index) {
          final application =
              _appliedJobs[index]['application'] as JobApplicantModel;
          final rawData =
              (_appliedJobs[index]['raw'] as Map<String, dynamic>?) ??
                  const <String, dynamic>{};
          final job = _appliedJobs[index]['job'] as JobModel?;
          final isJobDeleted =
              _appliedJobs[index]['isJobDeleted'] as bool? ?? job == null;
          final isJobInactive =
              _appliedJobs[index]['isJobInactive'] as bool? ?? false;

          final status = application.applicationStatus;
          final normStatus = status.trim().toLowerCase();
          final isOfferStageOrFinal = normStatus == 'offered' ||
              normStatus == 'accepted' ||
              normStatus == 'offer_declined';

          final appliedDate =
              application.appliedAt?.toLocal().toIso8601String().substring(0, 10) ??
                  'Unknown date';

          final showUnavailableNotice =
              isJobDeleted || (isJobInactive && !isOfferStageOrFinal);

          final displayStatus = isJobDeleted
              ? 'deleted'
              : ((isJobInactive && !isOfferStageOrFinal) ? 'inactive' : status);

          final statusLabel = isJobDeleted
              ? 'JOB DELETED'
              : ((isJobInactive && !isOfferStageOrFinal)
                  ? 'JOB INACTIVE'
                  : _formatStatusBadgeLabel(status));

          final statusColor = _getStatusColor(displayStatus);

          final displayTitle = isJobDeleted
              ? 'Deleted Job Post'
              : (job?.title ?? 'Unknown Job');

          final displayCompany = isJobDeleted
              ? 'This posting is no longer available'
              : ((isJobInactive && !isOfferStageOrFinal)
                  ? 'This job posting is inactive'
                  : (job?.companyName ?? 'Unknown Company'));

          final hasOfferDetails = normStatus == 'offered' ||
              (rawData['offerSalary'] ?? '').toString().trim().isNotEmpty ||
              (rawData['offerMessage'] ?? '').toString().trim().isNotEmpty ||
              (rawData['offerLetterURL'] ?? '').toString().trim().isNotEmpty;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                if (normStatus == 'offered' && !isJobDeleted) {
                  _showOfferLetterModal(
                    application: application,
                    rawData: rawData,
                    jobTitle: displayTitle,
                    companyName: job?.companyName ?? 'Company',
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => showUnavailableNotice
                        ? UnavailableJobNoticeScreen(
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
                  border: normStatus == 'offered'
                      ? Border.all(
                          color: AppColors.statusScheduled.withValues(
                            alpha: 0.45,
                          ),
                          width: 1.5,
                        )
                      : null,
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
                          child: Icon(
                            normStatus == 'offered'
                                ? Icons.workspace_premium_rounded
                                : Icons.work_outline_rounded,
                            color: statusColor,
                          ),
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
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                displayCompany,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
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
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule_outlined,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Applied on $appliedDate',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                    if (AppliedJobsController.canWithdraw(status) &&
                        application.applicantID != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _withdrawingId == null
                              ? () => _withdraw(application, displayTitle)
                              : null,
                          icon: _withdrawingId == application.applicantID
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.undo_rounded, size: 18),
                          label: const Text(
                            'Withdraw Application',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.errorRed,
                            side: BorderSide(
                              color: AppColors.errorRed.withValues(alpha: 0.35),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (!isJobDeleted && hasOfferDetails) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: normStatus == 'offered'
                            ? ElevatedButton.icon(
                                onPressed: () => _showOfferLetterModal(
                                  application: application,
                                  rawData: rawData,
                                  jobTitle: displayTitle,
                                  companyName: job?.companyName ?? 'Company',
                                ),
                                icon: const Icon(
                                  Icons.mark_email_unread_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Review Offer Letter & Respond',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: () => _showOfferLetterModal(
                                  application: application,
                                  rawData: rawData,
                                  jobTitle: displayTitle,
                                  companyName: job?.companyName ?? 'Company',
                                ),
                                icon: const Icon(
                                  Icons.description_outlined,
                                  size: 18,
                                ),
                                label: const Text(
                                  'View Offer Letter Details',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                    color: AppColors.borderActive,
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
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
            ),
          );
        },
      ),
    );
  }
}
