import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared_widgets/hero_icon_button.dart';

/// Gradient card at the top of the Profile tab: avatar, greeting, and
/// "View as others see it" / QR buttons (hidden while editing).
class ProfileHeroHeader extends StatelessWidget {
  final String firstName;
  final Widget avatar;
  final VoidCallback? onViewPublic;
  final VoidCallback? onShowQr;

  const ProfileHeroHeader({
    super.key,
    required this.firstName,
    required this.avatar,
    this.onViewPublic,
    this.onShowQr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'My Profile',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (onViewPublic != null)
                HeroIconButton(
                  icon: Icons.visibility_outlined,
                  tooltip: 'View as others see it',
                  onTap: onViewPublic!,
                ),
              if (onViewPublic != null && onShowQr != null) const SizedBox(width: 8),
              if (onShowQr != null)
                HeroIconButton(
                  icon: Icons.qr_code_rounded,
                  tooltip: 'Show QR',
                  onTap: onShowQr!,
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Welcome back, $firstName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
