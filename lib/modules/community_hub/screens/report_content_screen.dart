import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../controllers/content_report_controller.dart';

/// Report a community post or comment to the admins.
class ReportContentScreen extends StatefulWidget {
  final ReportTarget target;
  final String targetID;
  final String reporterID;

  /// A short piece of the post/comment, shown so the user knows what they report.
  final String preview;

  const ReportContentScreen({
    super.key,
    required this.target,
    required this.targetID,
    required this.reporterID,
    this.preview = '',
  });

  @override
  State<ReportContentScreen> createState() => _ReportContentScreenState();
}

class _ReportContentScreenState extends State<ReportContentScreen> {
  final ContentReportController _controller = ContentReportController();
  final TextEditingController _details = TextEditingController();

  String _category = ContentReportController.categories.first;
  bool _isSubmitting = false;

  String get _what => widget.target == ReportTarget.post ? 'post' : 'comment';

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    final error = await _controller.submit(
      target: widget.target,
      targetID: widget.targetID,
      reporterID: widget.reporterID,
      category: _category,
      details: _details.text,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      SnackBarHelper.showStyled(
        context,
        message: error,
        icon: Icons.info_outline_rounded,
        accentColor: AppColors.warning,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    SnackBarHelper.showStyled(
      context,
      message: 'Thanks. Our team will review this $_what.',
      icon: Icons.check_circle_outline_rounded,
      accentColor: AppColors.successGreen,
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.target == ReportTarget.post ? 'Report Post' : 'Report Comment',
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            if (widget.preview.trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '"${widget.preview.trim()}"',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontStyle: FontStyle.italic, height: 1.4),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _card(
              title: 'What\'s wrong with this $_what?',
              subtitle: 'Choose the reason that fits best.',
              child: Column(
                children: ContentReportController.categories.map((c) {
                  final selected = c == _category;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: selected ? AppColors.primarySoft : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _isSubmitting ? null : () => setState(() => _category = c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                color: selected ? AppColors.primary : AppColors.textMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                c,
                                style: TextStyle(
                                  color: AppColors.textDark,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _card(
              title: _category == 'Other' ? 'Details (required)' : 'Details (optional)',
              subtitle: 'Anything that helps our team understand the problem.',
              child: TextField(
                controller: _details,
                enabled: !_isSubmitting,
                minLines: 3,
                maxLines: 6,
                maxLength: ContentReportController.maxDetailsLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Describe what happened…',
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Reports are private. The person won\'t know who reported them.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.flag_rounded),
            label: Text(_isSubmitting ? 'Sending…' : 'Submit Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.danger.withValues(alpha: 0.5),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
