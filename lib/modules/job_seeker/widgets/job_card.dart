import 'package:flutter/material.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/job_model.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/bookmarked_controller.dart';

/// A job in the Home list: title, company, location, salary and a bookmark
/// button.
class JobCard extends StatefulWidget {
  final JobModel job;
  final VoidCallback onTap;

  const JobCard({super.key, required this.job, required this.onTap});

  @override
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {
  final BookmarkedController _bookmarkedController = BookmarkedController();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    // One shared query for all cards (no-op if already loaded)
    _bookmarkedController.ensureBookmarksLoaded();
  }

  /// Bookmarks or un-bookmarks the job and says which (or that it failed).
  Future<void> _handleBookmarkTap() async {
    final jobId = widget.job.jobID;
    if (jobId == null || _isUpdating) return;

    final previousState = BookmarkedController.bookmarkedIds.value.contains(jobId);
    setState(() => _isUpdating = true);

    final newState = await _bookmarkedController.toggleBookmark(jobId, previousState);

    if (!mounted) return;
    setState(() => _isUpdating = false);

    if (newState == previousState) {
      SnackBarHelper.showStyled(
        context,
        message: 'Could not update bookmark. Please try again.',
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.coral,
      );
      return;
    }

    SnackBarHelper.showStyled(
      context,
      message: newState ? 'Job bookmarked!' : 'Bookmark removed.',
      icon: newState ? Icons.bookmark_added_rounded : Icons.bookmark_remove_rounded,
      accentColor: newState ? AppColors.teal : AppColors.textMuted,
    );
  }

  /// "RM3000 / month", or "/ hour" for part-time jobs.
  String _formatSalary(String range, String? type) {
    if (type == 'Part-time') {
      return '$range / hour';
    } else {
      return '$range / month';
    }
  }

  /// "No longer available" (removed) or "Applications closed" (inactive or
  /// past its closing date); null for an open job. Search only lists open
  /// jobs, so this shows on bookmarked ones.
  String? get _closedLabel {
    final status = widget.job.status.trim().toLowerCase();
    if (status == 'deleted') return 'No longer available';
    if (status != 'active' || widget.job.isExpired) return 'Applications closed';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final closedLabel = _closedLabel;
    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.job.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  GestureDetector(
                    onTap: _handleBookmarkTap,
                    // Rebuilds only this icon when the shared bookmark set changes
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: BookmarkedController.bookmarkedIds,
                      builder: (context, ids, _) {
                        final isBookmarked = ids.contains(widget.job.jobID);
                        return Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: isBookmarked ? AppColors.primary : Colors.grey.shade500,
                          size: 26,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.job.companyName ?? 'Unknown Company',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.job.locationName ?? 'Location unavailable',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (closedLabel != null)
                    _buildChip(closedLabel, Icons.block_rounded, color: AppColors.statusInactive),
                  _buildChip(widget.job.jobType, Icons.work_outline),
                  _buildChip(_formatSalary(widget.job.salaryRange, widget.job.jobType), Icons.attach_money),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Small chip with an icon (job type, salary, closed).
  Widget _buildChip(String label, IconData icon, {Color color = AppColors.primary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}