import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../models/job_model.dart';
import '../controllers/bookmarked_controller.dart';
import '../controllers/report_controller.dart';
import 'job_application_screen.dart';

class JobDetailsScreen extends StatefulWidget {
  final JobModel job;

  const JobDetailsScreen({super.key, required this.job});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  final BookmarkedController _bookmarkedController = BookmarkedController();
  final ReportController _reportController = ReportController();

  bool _isBookmarked = false;
  bool _isLoading = true;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _checkInitialBookmarkState();
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
    setState(() {
      _isBookmarked = !_isBookmarked;
      _isLoading = true;
    });

    final newState = await _bookmarkedController.toggleBookmark(widget.job.jobID!, !_isBookmarked);

    if (mounted) {
      setState(() {
        _isBookmarked = newState;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBookmarked ? 'Job Saved!' : 'Job Removed from Saves'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _shareJob() {
    final String shareText = '''
Check out this job!
💼 Role: ${widget.job.title}
🏢 Company: ${widget.job.companyName ?? 'Unknown Company'}
💰 Salary: ${widget.job.salaryRange}
Apply now on our Recruitment Platform!
''';
    Share.share(shareText, subject: 'Job Opportunity: ${widget.job.title}');
  }

  void _showReportDialog() {
    String selectedCategory = 'Scam/Fraud';
    final detailsController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Report Job'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Why are you reporting this job posting?'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: ['Scam/Fraud', 'Offensive Content', 'Fake Company', 'Wrong Category']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: isSubmitting ? null : (val) => setDialogState(() => selectedCategory = val!),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: detailsController,
                      maxLines: 3,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Additional Details (Optional)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    if (widget.job.jobID == null) return;
                    setDialogState(() => isSubmitting = true);
                    final success = await _reportController.submitJobReport(
                      jobId: widget.job.jobID!,
                      category: selectedCategory,
                      details: detailsController.text,
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Report submitted successfully.' : 'Failed to submit report.'),
                          backgroundColor: success ? Colors.green : AppColors.errorRed,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white),
                  child: isSubmitting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Report'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDescriptionLong = widget.job.description.length > 200;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? AppColors.primaryBlue : Colors.grey.shade700,
            ),
            onPressed: _handleBookmarkTap,
          ),
          IconButton(icon: Icon(Icons.share, color: Colors.grey.shade700), onPressed: _shareJob),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(UiConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.job.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.job.companyName ?? 'Company Name Unavailable', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12.0,
              runSpacing: 12.0,
              children: [
                _buildDetailChip(Icons.monetization_on, widget.job.salaryRange),
                _buildDetailChip(Icons.work, 'Full-Time'),
                _buildDetailChip(Icons.location_on, 'Kuala Lumpur, MY'),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Job Description', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              widget.job.description,
              style: const TextStyle(fontSize: 16, height: 1.5),
              maxLines: _isDescriptionExpanded ? null : 4,
              overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (isDescriptionLong)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(
                    _isDescriptionExpanded ? 'Show less' : 'Show more',
                    style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(UiConstants.defaultPadding, UiConstants.defaultPadding, UiConstants.defaultPadding, 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => JobApplicationScreen(job: widget.job))),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiConstants.cornerRadius)),
                  ),
                  child: const Text('Apply Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _showReportDialog,
                  icon: const Icon(Icons.flag_outlined, color: Colors.black, size: 20),
                  label: const Text('Report this job', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.backgroundLight,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UiConstants.cornerRadius)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(UiConstants.cornerRadius)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}