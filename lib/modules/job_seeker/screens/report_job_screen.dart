import 'package:flutter/material.dart';
import '../../../models/job_model.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../controllers/report_controller.dart';
import '../../../core/theme/app_colors.dart';

class ReportJobScreen extends StatefulWidget {
  final JobModel job;

  const ReportJobScreen({super.key, required this.job});

  @override
  State<ReportJobScreen> createState() => _ReportJobScreenState();
}

class _ReportJobScreenState extends State<ReportJobScreen> {
  // Theme Colors
  static const Color _primary = AppColors.primary;
  static const Color _primarySoft = AppColors.primarySoft;
  static const Color _textPrimary = AppColors.textDark;
  static const Color _textMuted = AppColors.textMuted;
  static const Color _surfaceAlt = AppColors.surfaceAlt;
  static const Color _border = AppColors.border;

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

  Future<void> _submitReport() async {
    if (_selectedCategory == null) {
      SnackBarHelper.showStyled(
        context,
        message: 'Please select a reason for reporting.',
        icon: Icons.info_outline_rounded,
        accentColor: const Color(0xFFE27D60),
      );
      return;
    }

    if (_selectedCategory == 'Other' && _detailsController.text.trim().isEmpty) {
      SnackBarHelper.showStyled(
        context,
        message: 'Please provide details when selecting Other.',
        icon: Icons.info_outline_rounded,
        accentColor: const Color(0xFFE27D60),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await _reportController.submitJobReport(
      jobId: widget.job.jobID!,
      category: _selectedCategory!,
      details: _detailsController.text,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        SnackBarHelper.showStyled(
          context,
          message: 'Report submitted successfully.',
          icon: Icons.check_circle_outline_rounded,
          accentColor: const Color(0xFF1E8F8B),
        );
        Navigator.pop(context); // Go back to job details
      } else {
        SnackBarHelper.showStyled(
          context,
          message: 'Failed to submit report. Please try again.',
          icon: Icons.error_outline_rounded,
          accentColor: const Color(0xFFE27D60),
        );
      }
    }
  }

  Widget _buildHeroActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildRadioOption(String option) {
    final isSelected = _selectedCategory == option;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategory = option);
        FocusScope.of(context).unfocus(); // Hide keyboard if open
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? _primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFB8D1EE) : _border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? _primary : Colors.grey.shade400,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? _textPrimary : _textMuted,
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
                          // 👉 Hero Header
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
                                    _buildHeroActionButton(
                                      icon: Icons.arrow_back_rounded,
                                      tooltip: 'Back',
                                      onTap: () => Navigator.pop(context),
                                    ),
                                    const Spacer(),
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
                                            Icons.flag_outlined,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Report Issue',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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

                          // 👉 Report Options Card
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
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Select the option that best describes the issue with this job posting.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _textMuted,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ..._reportOptions.map((option) => _buildRadioOption(option)),

                                const SizedBox(height: 12),
                                const Divider(color: _border),
                                const SizedBox(height: 16),

                                // 👉 Details Text Field
                                const Text(
                                  'Additional details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _detailsController,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText: 'Describe your problem below...',
                                    filled: true,
                                    fillColor: _surfaceAlt,
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
                                      borderSide: const BorderSide(color: _primary, width: 1.5),
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

            // 👉 Sticky Bottom Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
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
                      backgroundColor: _primary,
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
            ),
          ],
        ),
      ),
    );
  }
}