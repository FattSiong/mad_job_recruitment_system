import 'package:flutter/material.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/job_model.dart';
import '../controllers/application_controller.dart';
import '../controllers/bookmarked_controller.dart';
import 'job_application_screen.dart';
import 'report_job_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared_widgets/hero_icon_button.dart';

/// Full job details with Apply, Bookmark and Report.
/// [disableApplyButton] hides applying (e.g. opened from My Jobs > Applied).
class JobDetailsScreen extends StatefulWidget {
  final JobModel job;
  final bool disableApplyButton;

  const JobDetailsScreen({
    super.key,
    required this.job,
    this.disableApplyButton = false,
  });

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  final BookmarkedController _bookmarkController = BookmarkedController();
  final ApplicationController _applicationController = ApplicationController();

  // Blocks applying twice, whichever screen the job was opened from
  bool _hasApplied = false;
  bool _withdrawn = false; // applied before, then withdrew (can't apply again)
  bool _isCheckingApplied = true;

  bool _isBookmarked = false;
  bool _isBookmarkUpdating = false;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _checkBookmarkStatus();
    _checkAppliedStatus();
  }

  /// Checks whether the user already applied (or withdrew), to set the Apply button.
  Future<void> _checkAppliedStatus() async {
    if (widget.disableApplyButton || widget.job.jobID == null) {
      _isCheckingApplied = false; // still inside initState, so no setState needed
      return;
    }
    final status = await _applicationController.appliedStatus(widget.job.jobID!);
    if (mounted) {
      setState(() {
        _hasApplied = status != null;
        _withdrawn = status == 'withdrawn';
        _isCheckingApplied = false;
      });
    }
  }

  bool get _alreadyApplied => widget.disableApplyButton || _hasApplied;

  /// Closed by the employer or past its expiry date (e.g. opened from Bookmarks).
  /// The server would refuse the application anyway, after the whole form.
  bool get _isClosed =>
      widget.job.status.trim().toLowerCase() != 'active' || widget.job.isExpired;

  /// Opens the application form; afterwards the button shows "Applied".
  Future<void> _openApplication() async {
    final applied = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => JobApplicationScreen(job: widget.job),
      ),
    );
    if (applied == true && mounted) {
      setState(() => _hasApplied = true);
    }
  }

  @override
  void dispose() {
    _applicationController.dispose();
    super.dispose();
  }

  /// Shows whether this job is bookmarked.
  Future<void> _checkBookmarkStatus() async {
    if (widget.job.jobID != null) {
      final isBookmarked =
      await _bookmarkController.isJobBookmarked(widget.job.jobID!);
      if (mounted) {
        setState(() => _isBookmarked = isBookmarked);
      }
    }
  }

  /// Bookmarks or un-bookmarks the job (the icon changes straight away and
  /// is put back if saving fails).
  Future<void> _toggleBookmark() async {
    if (widget.job.jobID == null || _isBookmarkUpdating) return;

    final previousState = _isBookmarked;
    final intendedState = !previousState;

    setState(() {
      _isBookmarkUpdating = true;
      _isBookmarked = intendedState;
    });

    final actualState = await _bookmarkController.toggleBookmark(
      widget.job.jobID!,
      previousState,
    );

    if (!mounted) return;

    final operationSucceeded = actualState == intendedState;

    setState(() {
      _isBookmarkUpdating = false;
      _isBookmarked = actualState;
    });

    if (!operationSucceeded) {
      SnackBarHelper.showStyled(
        context,
        message: 'Failed to update bookmark.',
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.coral,
      );
      return;
    }

    SnackBarHelper.showStyled(
      context,
      message: actualState ? 'Job bookmarked!' : 'Bookmark removed.',
      icon: actualState
          ? Icons.bookmark_added_rounded
          : Icons.bookmark_remove_rounded,
      accentColor:
      actualState ? AppColors.teal : AppColors.textMuted,
    );

  }

  /// "RM3000 - 4000 a month" ("an hour" for part-time jobs).
  String _formatSalaryOnly() {
    final salary = widget.job.salaryRange;
    if (salary.isEmpty) return 'Salary not specified';

    final period =
    widget.job.jobType.toLowerCase().contains('part') ? 'an hour' : 'a month';
    return '$salary $period';
  }

  /// "Posted 2 weeks ago", "Posted 3 days ago", ...
  String _formatPostedDate() {
    final createdAt = widget.job.createdAt;
    if (createdAt == null) return 'Recently posted';

    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays >= 7) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? 'Posted 1 week ago' : 'Posted $weeks weeks ago';
    }
    if (difference.inDays >= 1) {
      return difference.inDays == 1
          ? 'Posted 1 day ago'
          : 'Posted ${difference.inDays} days ago';
    }
    if (difference.inHours >= 1) {
      return difference.inHours == 1
          ? 'Posted 1 hour ago'
          : 'Posted ${difference.inHours} hours ago';
    }
    return 'Posted recently';
  }

  /// Opens the Report Job screen.
  void _handleReportJob() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportJobScreen(job: widget.job),
      ),
    );
  }

  /// Small see-through chip in the header (location, job type, ...).
  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// One coloured detail tile (salary, job type, ...).
  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// White card with a title, optional subtitle and content.
  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  /// The job description, cut to 8 lines with Show more / Show less when it is long.
  Widget _buildDescriptionSection() {
    return _buildSectionCard(
      title: 'Full Job Description',
      subtitle: 'Review the responsibilities and role details before applying.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textSpan = TextSpan(
            text: widget.job.description,
            style: const TextStyle(
              fontSize: 15,
              height: 1.75,
              color: AppColors.textDark,
            ),
          );

          final textPainter = TextPainter(
            text: textSpan,
            maxLines: _isDescriptionExpanded ? null : 8,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout(maxWidth: constraints.maxWidth);

          final needsExpansion = textPainter.didExceedMaxLines;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.job.description,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.75,
                  color: AppColors.textDark,
                ),
                maxLines: _isDescriptionExpanded ? null : 8,
                overflow:
                _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.fade,
              ),
              if (needsExpansion || _isDescriptionExpanded) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _isDescriptionExpanded = !_isDescriptionExpanded);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    _isDescriptionExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _isDescriptionExpanded ? 'Show less' : 'Show more',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Salary, job type, location and other key details.
  Widget _buildAboutRoleSection() {
    return _buildSectionCard(
      title: 'Role Snapshot',
      subtitle: 'A quick overview of the key job details.',
      child: Column(
        children: [
          _buildInfoTile(
            icon: Icons.attach_money_rounded,
            title: 'Salary',
            value: _formatSalaryOnly(),
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          _buildInfoTile(
            icon: Icons.work_outline_rounded,
            title: 'Job Type',
            value: widget.job.jobType,
            color: AppColors.teal,
          ),
          const SizedBox(height: 12),
          _buildInfoTile(
            icon: Icons.location_on_outlined,
            title: 'Location',
            value: widget.job.locationName ?? 'Location unavailable',
            color: AppColors.coral,
          ),
          const SizedBox(height: 12),
          _buildInfoTile(
            icon: Icons.timeline_rounded,
            title: 'Experience',
            value: widget.job.minExperienceYears <= 0
                ? 'No minimum experience required'
                : '${widget.job.minExperienceYears} year(s) minimum',
            color: AppColors.statusPending,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomContentSpacing = 120.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      bottomContentSpacing,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryLight],
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
                                  HeroIconButton(
                                    icon: Icons.arrow_back_rounded,
                                    tooltip: 'Back',
                                    onTap: () => Navigator.pop(context),
                                  ),
                                  const Spacer(),
                                  HeroIconButton(
                                    icon: _isBookmarked
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                    tooltip: 'Save Job',
                                    onTap: _toggleBookmark,
                                    isActive: _isBookmarked,
                                  ),
                                  const SizedBox(width: 12),
                                  HeroIconButton(
                                    icon: Icons.flag_outlined,
                                    tooltip: 'Report Job',
                                    onTap: _handleReportJob,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.work_outline_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Job Details',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                widget.job.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.job.companyName ?? 'Unknown Company',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _buildMetaChip(
                                    Icons.location_on_outlined,
                                    widget.job.locationName ??
                                        'Location unavailable',
                                  ),
                                  _buildMetaChip(
                                    Icons.work_outline_rounded,
                                    widget.job.jobType,
                                  ),
                                  _buildMetaChip(
                                    Icons.schedule_outlined,
                                    _formatPostedDate(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildAboutRoleSection(),
                        const SizedBox(height: 24),
                        _buildDescriptionSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    offset: const Offset(0, -4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: SafeArea(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_alreadyApplied || _isCheckingApplied || _isClosed)
                              ? null
                              : _openApplication,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _isCheckingApplied
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  _withdrawn
                                      ? Icons.undo_rounded
                                      : (_alreadyApplied
                                          ? Icons.check_circle_outline
                                          : (_isClosed ? Icons.block_rounded : Icons.send_rounded)),
                                ),
                          label: Text(
                            _withdrawn
                                ? 'Application Withdrawn'
                                : (_alreadyApplied
                                    ? 'Already Applied'
                                    : (_isClosed ? 'Applications Closed' : 'Apply Now')),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
    );
  }
}