import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/job_applicant_model.dart';
import '../../../../models/job_model.dart';
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
  String? _loadError;

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

  void _retry() {
    setState(() => _isLoading = true);
    _loadAppliedJobs();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.statusPending;
      case 'scheduled':
        return AppColors.statusScheduled;
      case 'interviewed':
        return AppColors.statusInterviewed;
      case 'accepted':
        return AppColors.statusAccepted;
      case 'rejected':
        return AppColors.statusRejected;
      case 'inactive':
        return AppColors.statusInactive;
      case 'deleted':
        return AppColors.textMuted;
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
        subtitle: 'Once you apply for a role, it will appear here with its latest status.',
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
          final job = _appliedJobs[index]['job'] as JobModel?;
          final isJobDeleted =
              _appliedJobs[index]['isJobDeleted'] as bool? ?? job == null;
          final isJobInactive =
              _appliedJobs[index]['isJobInactive'] as bool? ?? false;

          final status = application.applicationStatus;
          final appliedDate =
              application.appliedAt?.toLocal().toIso8601String().substring(0, 10) ??
                  'Unknown date';

          final showUnavailableNotice = isJobDeleted || isJobInactive;

          final displayStatus = isJobDeleted
              ? 'deleted'
              : (isJobInactive ? 'inactive' : status);

          final statusLabel = isJobDeleted
              ? 'JOB DELETED'
              : (isJobInactive ? 'JOB INACTIVE' : status.toUpperCase());

          final statusColor = _getStatusColor(displayStatus);

          final displayTitle = isJobDeleted
              ? 'Deleted Job Post'
              : (isJobInactive
              ? (job?.title ?? 'Inactive Job Post')
              : (job?.title ?? 'Unknown Job'));

          final displayCompany = isJobDeleted
              ? 'This posting is no longer available'
              : (isJobInactive
              ? 'This job posting is inactive'
              : (job?.companyName ?? 'Unknown Company'));

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
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
                          child: Icon(Icons.work_outline_rounded, color: statusColor),
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
