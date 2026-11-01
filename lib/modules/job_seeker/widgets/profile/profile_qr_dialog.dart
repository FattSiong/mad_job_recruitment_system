import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_colors.dart';

/// Shows the job seeker's profile QR code (scanned by recruiters).
Future<void> showProfileQrDialog(BuildContext context, String seekerId) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'My Profile QR',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Let recruiters scan this to view your resume and experience.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            height: 220,
            child: QrImageView(
              data: 'profile:$seekerId',
              version: QrVersions.auto,
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}
