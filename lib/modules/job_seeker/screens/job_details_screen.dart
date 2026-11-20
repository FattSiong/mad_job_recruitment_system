import 'package:flutter/material.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/job_model.dart';
import '../controllers/application_controller.dart';
import '../controllers/bookmarked_controller.dart';
import 'job_application_screen.dart';
import 'report_job_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared_widgets/bottom_action_bar.dart';
import '../../../shared_widgets/button_spinner.dart';
import '../../../shared_widgets/hero_icon_button.dart';
import '../../../shared_widgets/hero_card.dart';

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

  /// Whether the description is longer than 8 lines, worked out once per
  /// width (not on every rebuild, e.g. when the bookmark changes).
  double? _descriptionMeasuredWidth;
  bool _descriptionIsLong = false;

  static const TextStyle _descriptionStyle = TextStyle(
    fontSize: 15,
    height: 1.75,
    color: AppColors.textDark,
  );
  static const int _collapsedDescriptionLines = 8;

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

  /// "Remote (work from home)", "Hybrid (home and office)" or
  /// "On-site (work at the office)".
  String _formatWorkplace() {
    switch (widget.job.workplaceType.trim().toLowerCase()) {
      case 'remote':
        return 'Remote (work from home)';
      case 'hybrid':
        return 'Hybrid (home and office)';
      default:
        return 'On-site (work at the office)';
    }
  }

  /// True when the description needs "Show more" at [width].
  bool _isDescriptionLong(double width) {
    if (width == _descriptionMeasuredWidth) return _descriptionIsLong;
    final painter = TextPainter(
      text: TextSpan(text: widget.job.description, style: _descriptionStyle),
      maxLines: _collapsedDescriptionLines,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    _descriptionIsLong = painter.didExceedMaxLines;
    painter.dispose();
    _descriptionMeasuredWidth = width;
    return _descriptionIsLong;
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
          final showToggle = _isDescriptionExpanded || _isDescriptionLong(constraints.maxWidth);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.job.description,
                style: _descriptionStyle,
                maxLines: _isDescriptionExpanded ? null : _collapsedDescriptionLines,
                overflow:
                _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.fade,
              ),
              if (showToggle) ...[
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
            icon: Icons.home_work_outlined,
            title: 'Workplace',
            value: _formatWorkplace(),
            color: AppColors.statusScheduled,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: BottomActionBar(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: _buildApplyButton(),
      ),
      body: SafeArea(
        bottom: false, // the Apply bar is below
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeroCard(child: Column(
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
                    const HeroPill(icon: Icons.work_outline_rounded, label: 'Job Details'),
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
                        HeroPill(
                          icon: Icons.location_on_outlined,
                          label: widget.job.locationName ?? 'Location unavailable',
                          shrinkLabel: true,
                        ),
                        HeroPill(
                          icon: Icons.work_outline_rounded,
                          label: widget.job.jobType,
                          shrinkLabel: true,
                        ),
                        HeroPill(
                          icon: Icons.schedule_outlined,
                          label: _formatPostedDate(),
                          shrinkLabel: true,
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
    );
  }

  /// Apply Now, or why applying isn't possible (already applied, withdrawn,
  /// closed). Disabled while checking whether the user already applied.
  Widget _buildApplyButton() {
    final String label;
    final IconData icon;
    if (_withdrawn) {
      label = 'Application Withdrawn';
      icon = Icons.undo_rounded;
    } else if (_alreadyApplied) {
      label = 'Already Applied';
      icon = Icons.check_circle_outline;
    } else if (_isClosed) {
      label = 'Applications Closed';
      icon = Icons.block_rounded;
    } else {
      label = 'Apply Now';
      icon = Icons.send_rounded;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_alreadyApplied || _isCheckingApplied || _isClosed) ? null : _openApplication,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: _isCheckingApplied ? const ButtonSpinner(color: AppColors.primary) : Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
