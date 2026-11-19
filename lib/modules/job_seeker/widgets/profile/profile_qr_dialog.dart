import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_button_styles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared_widgets/hero_card.dart';
import '../../../../shared_widgets/sheet_handle.dart';

/// Shows the job seeker's profile QR code (scanned by recruiters) in a
/// bottom sheet styled like the other profile sheets.
Future<void> showProfileQrDialog(BuildContext context, String seekerId, {String? name}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _ProfileQrSheet(seekerId: seekerId, name: name),
  );
}

class _ProfileQrSheet extends StatelessWidget {
  final String seekerId;
  final String? name;

  const _ProfileQrSheet({required this.seekerId, this.name});

  @override
  Widget build(BuildContext context) {
    final displayName = (name ?? '').trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SizedBox(height: 16),
          HeroCard(
            child: Column(
              children: [
                const HeroPill(icon: Icons.qr_code_2_rounded, label: 'My Profile QR'),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: QrImageView(
                    data: 'profile:$seekerId',
                    version: QrVersions.auto,
                    size: 200,
                    padding: EdgeInsets.zero,
                    backgroundColor: AppColors.surface,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.primary),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (displayName.isNotEmpty) ...[
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                ],
                const Text(
                  'Let recruiters scan this to view your resume and experience.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _QrTip(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: AppButtonStyles.filled(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// How a recruiter scans the code.
class _QrTip extends StatelessWidget {
  const _QrTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Recruiters tap Scan QR in the app and point the camera at this code.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
