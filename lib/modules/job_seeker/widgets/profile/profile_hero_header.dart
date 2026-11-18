import 'package:flutter/material.dart';

import '../../../../shared_widgets/hero_icon_button.dart';
import '../../../../shared_widgets/hero_card.dart';

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
    return HeroCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HeroPill(icon: Icons.person_outline_rounded, label: 'My Profile'),
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
