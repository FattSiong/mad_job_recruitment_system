import 'package:flutter/material.dart';
import '../../../models/job_model.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/bookmarked_controller.dart';

class JobCard extends StatefulWidget {
  final JobModel job;
  final VoidCallback onTap;

  const JobCard({super.key, required this.job, required this.onTap});

  @override
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {
  final BookmarkedController _bookmarkedController = BookmarkedController();
  bool _isBookmarked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkInitialBookmarkState();

    // 👉 ADDED: Listen to the global notifier so the card updates no matter what screen you are on
    BookmarkedController.bookmarkNotifier.addListener(_onGlobalBookmarkChanged);
  }

  // 👉 ADDED: This triggers whenever a bookmark is toggled anywhere in the app
  void _onGlobalBookmarkChanged() {
    if (mounted) {
      _checkInitialBookmarkState();
    }
  }

  @override
  void dispose() {
    // 👉 ADDED: Always clean up the listener to prevent memory leaks
    BookmarkedController.bookmarkNotifier.removeListener(_onGlobalBookmarkChanged);
    super.dispose();
  }

  Future<void> _checkInitialBookmarkState() async {
    if (widget.job.jobID == null) return;

    final isBookmarked = await _bookmarkedController.isJobBookmarked(widget.job.jobID!);
    if (mounted) {
      setState(() {
        _isBookmarked = isBookmarked;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleBookmarkTap() async {
    if (widget.job.jobID == null || _isLoading) return;

    // Save the old state to pass into the controller
    bool previousState = _isBookmarked;

    setState(() {
      _isBookmarked = !_isBookmarked;
      _isLoading = true;
    });

    final newState = await _bookmarkedController.toggleBookmark(widget.job.jobID!, previousState);

    if (mounted) {
      setState(() {
        _isBookmarked = newState;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBookmarked ? 'Job bookmarked!' : 'Bookmark removed.'),
          backgroundColor: _isBookmarked ? Colors.green : Colors.grey.shade800,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  String _formatSalary(String range, String? type) {
    if (type == 'Part-time') {
      return '$range / hr';
    } else {
      return '$range / mo';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    child: Icon(
                      _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: _isBookmarked ? AppColors.primaryBlue : Colors.grey.shade500,
                      size: 26,
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
                    // Replaced FutureBuilder with instant text
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

  Widget _buildChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}