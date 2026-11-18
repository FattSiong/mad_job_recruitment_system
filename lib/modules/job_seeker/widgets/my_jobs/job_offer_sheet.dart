import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../core/theme/app_button_styles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_input_decoration.dart';
import '../../../../core/utils/data_load_exception.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../models/job_applicant_model.dart';
import '../../../../shared_widgets/button_spinner.dart';
import '../../controllers/applied_jobs_controller.dart';

/// The employer's job offer with Accept / Decline (or its final status).
Future<void> showJobOfferSheet(
  BuildContext context, {
  required JobApplicantModel application,
  required String jobTitle,
  required String companyName,
  required AppliedJobsController controller,
}) async {
  if ((application.applicantID ?? '').trim().isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _JobOfferSheet(
      application: application,
      jobTitle: jobTitle,
      companyName: companyName,
      controller: controller,
    ),
  );
}

class _JobOfferSheet extends StatefulWidget {
  final JobApplicantModel application;
  final String jobTitle;
  final String companyName;
  final AppliedJobsController controller;

  const _JobOfferSheet({
    required this.application,
    required this.jobTitle,
    required this.companyName,
    required this.controller,
  });

  @override
  State<_JobOfferSheet> createState() => _JobOfferSheetState();
}

class _JobOfferSheetState extends State<_JobOfferSheet> {
  bool _isSubmitting = false;
  bool _isOpeningPdf = false;
  String? _errorText;

  JobApplicantModel get _app => widget.application;
  String get _status => _app.applicationStatus.trim().toLowerCase();

  String _orDefault(String? value, String fallback) {
    final text = (value ?? '').trim();
    return text.isNotEmpty ? text : fallback;
  }

  /// Accepts or declines the offer (spinner meanwhile; errors stay in the sheet).
  Future<void> _respond({required bool accept, String? declineReason}) async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await widget.controller.respondToJobOffer(
        applicantId: _app.applicantID!.trim(),
        accept: accept,
        declineReason: declineReason,
      );
      if (!mounted) return;
      if (accept) {
        SnackBarHelper.showSuccess(context, 'Congratulations! You have accepted the job offer.');
      } else {
        SnackBarHelper.showStyled(
          context,
          message: 'You have declined the job offer.',
          icon: Icons.info_outline_rounded,
          accentColor: AppColors.warning,
        );
      }
      Navigator.pop(context);
    } on DataLoadException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Failed to ${accept ? 'accept' : 'decline'} offer. Please try again.');
    }
  }

  /// Shows [message] in the sheet and enables the buttons again.
  void _showError(String message) {
    if (!mounted) return; // sheet closed meanwhile
    setState(() {
      _isSubmitting = false;
      _errorText = message;
    });
  }

  /// Asks for an optional reason, then declines.
  Future<void> _decline() async {
    final reason = await _askDeclineReason(context);
    if (reason != null) await _respond(accept: false, declineReason: reason);
  }

  /// Downloads the offer letter PDF and opens it.
  Future<void> _openPdf(String url) async {
    if (_isOpeningPdf) return;
    setState(() => _isOpeningPdf = true);
    SnackBarHelper.showStyled(
      context,
      message: 'Opening Offer Letter PDF...',
      icon: Icons.picture_as_pdf_outlined,
      accentColor: AppColors.primary,
    );
    try {
      final file = await widget.controller.downloadOfferLetter(url);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        SnackBarHelper.showError(
          context,
          'Could not open the PDF. Please make sure a PDF viewer is installed.',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (_) {
      if (mounted) SnackBarHelper.showError(context, 'Unable to download the offer letter PDF.');
    } finally {
      if (mounted) setState(() => _isOpeningPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = _app.offerStartDate;
    final startDate = start != null ? start.toIso8601String().split('T').first : 'To be confirmed';
    final pdfUrl = (_app.offerLetterURL ?? '').trim();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 18),
            _buildTitle(),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: _boxDecoration(18),
              child: Column(
                children: [
                  _OfferDetailRow(
                    icon: Icons.payments_outlined,
                    label: 'Offered Salary:',
                    value: _orDefault(_app.offerSalary, 'As discussed'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                  _OfferDetailRow(icon: Icons.event_available_rounded, label: 'Proposed Start Date:', value: startDate),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Offer Message & Terms',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: _boxDecoration(16),
              child: Text(
                _orDefault(
                  _app.offerMessage,
                  'Congratulations! We would like to extend an offer for you to join our team.',
                ),
                style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textDark),
              ),
            ),
            if (pdfUrl.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isOpeningPdf ? null : () => _openPdf(pdfUrl),
                  icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.danger),
                  label: const Text(
                    'Download / View Attached Offer Letter PDF',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: AppButtonStyles.outlined(borderColor: AppColors.primary),
                ),
              ),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 20),
            if (_status == 'offered') _buildResponseButtons() else _buildFinalStatus(),
          ],
        ),
      ),
    );
  }

  BoxDecoration _boxDecoration(double radius) => BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      );

  Widget _buildTitle() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(15)),
          child: const Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Official Offer Letter',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              const SizedBox(height: 3),
              Text(
                '${widget.jobTitle} • ${widget.companyName}',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResponseButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _decline,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Decline Offer', style: TextStyle(fontWeight: FontWeight.w700)),
            style: AppButtonStyles.outlined(color: AppColors.danger),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : () => _respond(accept: true),
            icon: _isSubmitting ? const ButtonSpinner(size: 16) : const Icon(Icons.check_rounded, size: 18),
            label: Text(
              _isSubmitting ? 'Submitting...' : 'Accept Offer',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: AppButtonStyles.filled(color: AppColors.statusAccepted),
          ),
        ),
      ],
    );
  }

  /// "You accepted / declined this offer" (or the current status).
  Widget _buildFinalStatus() {
    final accepted = _status == 'accepted';
    final declined = _status == 'offer_declined';
    final color = accepted ? AppColors.statusAccepted : AppColors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accepted || declined ? color.withValues(alpha: 0.12) : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(accepted ? Icons.verified_rounded : Icons.info_outline_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              accepted
                  ? 'You accepted this offer.'
                  : (declined
                      ? 'You declined this offer.'
                      : 'Offer status: ${_app.applicationStatus.toUpperCase()}'),
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Offered Salary:   RM 4,000" row of the offer card.
class _OfferDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _OfferDetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
        ),
      ],
    );
  }
}

/// Asks why the offer is declined. Returns the reason, or null if cancelled.
Future<String?> _askDeclineReason(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _DeclineReasonDialog());

class _DeclineReasonDialog extends StatefulWidget {
  const _DeclineReasonDialog();

  @override
  State<_DeclineReasonDialog> createState() => _DeclineReasonDialogState();
}

class _DeclineReasonDialogState extends State<_DeclineReasonDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Decline Job Offer?',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Let the employer know why you are declining this offer (optional).',
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reason,
              maxLines: 3,
              decoration: filledInputDecoration(hint: 'e.g. Accepted another offer / salary expectation...'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: AppButtonStyles.outlined(color: AppColors.textMuted, borderColor: AppColors.border, radius: 14),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, _reason.text.trim()),
                    style: AppButtonStyles.filled(color: AppColors.danger, radius: 14),
                    child: const Text(
                      'Decline Offer',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
