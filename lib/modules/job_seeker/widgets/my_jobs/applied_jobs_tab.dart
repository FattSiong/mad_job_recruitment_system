import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/data_load_exception.dart';
import '../../../../models/applied_job_model.dart';
import '../../../../models/job_applicant_model.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../shared_widgets/confirm_dialog.dart';
import '../../controllers/applied_jobs_controller.dart';
import '../../screens/job_details_screen.dart';
import '../../screens/unavailable_job_notice_screen.dart';
import '../load_error_view.dart';
import 'job_offer_sheet.dart';
import 'my_jobs_empty_state.dart';
import '../../../../core/theme/app_button_styles.dart';

/// My Jobs > Applied tab.
class AppliedJobsTab extends StatefulWidget {
  const AppliedJobsTab({super.key});

  @override
  State<AppliedJobsTab> createState() => _AppliedJobsTabState();
}

class _AppliedJobsTabState extends State<AppliedJobsTab> {
  final AppliedJobsController _appliedController = AppliedJobsController();
  List<AppliedJob> _appliedJobs = [];
  bool _isLoading = true;
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
          final item = _appliedJobs[index];
          final application = item.application;
          final statusColor = _getStatusColor(item.badgeStatus);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                if (item.isOffered && !item.isJobDeleted) {
                  showJobOfferSheet(
                    context,
                    application: application,
                    jobTitle: item.title,
                    companyName: item.companyName,
                    controller: _appliedController,
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => item.isUnavailable
                        ? UnavailableJobNoticeScreen(
                            isDeleted: item.isJobDeleted,
                            jobTitle: item.job?.title,
                          )
                        : JobDetailsScreen(
                            job: item.job!,
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
                  border: item.isOffered
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
                            item.isOffered
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
                                item.title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
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
                            item.badgeLabel,
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
                              'Applied on ${item.appliedDateText}',
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
                    if (AppliedJobsController.canWithdraw(item.status) &&
                        application.applicantID != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _withdrawingId == null
                              ? () => _withdraw(application, item.title)
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
                    if (!item.isJobDeleted && item.hasOfferDetails) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: item.isOffered
                            ? ElevatedButton.icon(
                                onPressed: () => showJobOfferSheet(
                                  context,
                                  application: application,
                                  jobTitle: item.title,
                                  companyName: item.companyName,
                                  controller: _appliedController,
                                ),
                                icon: const Icon(
                                  Icons.mark_email_unread_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Review Offer Letter & Respond',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: AppButtonStyles.filled(),
                              )
                            : OutlinedButton.icon(
                                onPressed: () => showJobOfferSheet(
                                  context,
                                  application: application,
                                  jobTitle: item.title,
                                  companyName: item.companyName,
                                  controller: _appliedController,
                                ),
                                icon: const Icon(
                                  Icons.description_outlined,
                                  size: 18,
                                ),
                                label: const Text(
                                  'View Offer Letter Details',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: AppButtonStyles.outlined(padding: const EdgeInsets.symmetric(vertical: 12)),
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
