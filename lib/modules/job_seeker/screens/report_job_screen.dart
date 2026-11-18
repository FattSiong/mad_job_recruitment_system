import 'package:flutter/material.dart';
import '../../../models/job_model.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../controllers/report_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared_widgets/hero_icon_button.dart';
import '../../../shared_widgets/hero_card.dart';
import '../../../shared_widgets/bottom_action_bar.dart';

/// Report a job post to the admins (reason + optional details).
class ReportJobScreen extends StatefulWidget {
  final JobModel job;

  const ReportJobScreen({super.key, required this.job});

  @override
  State<ReportJobScreen> createState() => _ReportJobScreenState();
}

class _ReportJobScreenState extends State<ReportJobScreen> {
  final ReportController _reportController = ReportController();
  final TextEditingController _detailsController = TextEditingController();

  String? _selectedCategory;
  bool _isSubmitting = false;

  final List<String> _reportOptions = [
    "It's offensive and/or discriminatory",
    "Asking for money or seems like a fake job",
    "Incorrect company, location, or job details",
    "I think it's trying to sell something unrelated to the job",
    "Other"
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  /// Checks a reason is chosen and sends the report.
  Future<void> _submitReport() async {
    if (_selectedCategory == null) {
      SnackBarHelper.showStyled(
        context,
        message: 'Please select a reason for reporting.',
        icon: Icons.info_outline_rounded,
        accentColor: AppColors.coral,
      );
      return;
    }

    if (_selectedCategory == 'Other' && _detailsController.text.trim().isEmpty) {
      SnackBarHelper.showStyled(
        context,
        message: 'Please provide details when selecting Other.',
        icon: Icons.info_outline_rounded,
        accentColor: AppColors.coral,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await _reportController.submitJobReport(
      jobId: widget.job.jobID!,
      category: _selectedCategory!,
      details: _detailsController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    switch (result) {
      case JobReportResult.submitted:
        SnackBarHelper.showStyled(
          context,
          message: 'Report submitted successfully.',
          icon: Icons.check_circle_outline_rounded,
          accentColor: AppColors.teal,
        );
        Navigator.pop(context); // Go back to job details
      case JobReportResult.alreadyReported:
        SnackBarHelper.showStyled(
          context,
          message: 'You have already reported this job. Our team will review it soon.',
          icon: Icons.info_outline_rounded,
          accentColor: AppColors.coral,
          duration: const Duration(seconds: 3),
        );
        Navigator.pop(context);
      case JobReportResult.failed:
        SnackBarHelper.showStyled(
          context,
          message: 'Failed to submit report. Please try again.',
          icon: Icons.error_outline_rounded,
          accentColor: AppColors.coral,
        );
    }
  }

  /// One selectable reason (radio style).
  Widget _buildRadioOption(String option) {
    final isSelected = _selectedCategory == option;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategory = option);
        FocusScope.of(context).unfocus(); // hide the keyboard
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.borderActive : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppColors.primary : Colors.grey.shade400,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.textDark : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: Column(
                        children: [
                          // Header
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
                                    const HeroPill(icon: Icons.flag_outlined, label: 'Report Issue'),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  widget.job.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.job.companyName ?? 'Unknown Company',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Reasons
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Choose a problem',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Select the option that best describes the issue with this job posting.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textMuted,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ..._reportOptions.map((option) => _buildRadioOption(option)),

                                const SizedBox(height: 12),
                                const Divider(color: AppColors.border),
                                const SizedBox(height: 16),

                                // Additional details
                                const Text(
                                  'Additional details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _detailsController,
                                  maxLines: 4,
                                  maxLength: ReportController.maxDetailsLength,
                                  decoration: InputDecoration(
                                    hintText: 'Describe your problem below...',
                                    filled: true,
                                    fillColor: AppColors.surfaceAlt,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Submit bar (stays at the bottom)
            BottomActionBar(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitReport,
                  icon: _isSubmitting
                      ? const SizedBox.shrink()
                      : const Icon(Icons.send_rounded),
                  label: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}