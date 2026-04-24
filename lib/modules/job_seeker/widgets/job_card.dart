import 'package:flutter/material.dart';
import '../../../models/job_model.dart';
import '../controllers/bookmarked_controller.dart';

class JobCard extends StatefulWidget {
  final JobModel job;
  final VoidCallback onTap;

  const JobCard({
    super.key,
    required this.job,
    required this.onTap,
  });

  @override
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {
  final BookmarkedController _bookmarkedController = BookmarkedController();

  bool _isBookmarked = false;
  bool _isLoading = true; // Prevents spam-clicking while checking the database

  @override
  void initState() {
    super.initState();
    _checkInitialBookmarkState();
  }

  // Check Supabase when the card first loads
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

  // Handle the button tap
  Future<void> _handleBookmarkTap() async {
    if (widget.job.jobID == null || _isLoading) return;

    // Immediately toggle the UI for a snappy user experience
    setState(() {
      _isBookmarked = !_isBookmarked;
      _isLoading = true;
    });

    // Update the database in the background
    final newState = await _bookmarkedController.toggleBookmark(widget.job.jobID!, !_isBookmarked);

    if (mounted) {
      setState(() {
        _isBookmarked = newState;
        _isLoading = false;
      });

      // Show a quick popup so the user knows it worked
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBookmarked ? 'Job Saved!' : 'Job Removed from Saves'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        title: Text(
            widget.job.title,
            style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              widget.job.companyName ?? 'Company Name Unavailable',
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              widget.job.salaryRange,
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              widget.job.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          // Switch the icon based on the state!
          icon: Icon(
            _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: _isBookmarked ? const Color(0xFF0A66C2) : Colors.grey,
          ),
          onPressed: _handleBookmarkTap,
        ),
        onTap: widget.onTap,
      ),
    );
  }
}