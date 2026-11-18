import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/chat_room_model.dart';
import '../../../../shared_widgets/hero_card.dart';
import '../../../../shared_widgets/hero_icon_button.dart';
import '../../../../shared_widgets/notification_bell_button.dart';
import '../../../../shared_widgets/user_avatar.dart';

/// Top of the Home tab: the user's photo with "Hi, [name]", the
/// notification and Scan QR buttons, and the search bar (which opens the
/// job search).
class HomeHeader extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final VoidCallback onAvatarTap;
  final VoidCallback onSearchTap;
  final VoidCallback onScanTap;
  final VoidCallback? onNotificationsReturned;

  const HomeHeader({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.onAvatarTap,
    required this.onSearchTap,
    required this.onScanTap,
    this.onNotificationsReturned,
  });

  @override
  Widget build(BuildContext context) {
    return HeroCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Find your next role today',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              NotificationBellButton(onReturned: onNotificationsReturned),
              const SizedBox(width: 10),
              HeroIconButton(icon: Icons.qr_code_scanner, tooltip: 'Scan QR', onTap: onScanTap),
            ],
          ),
          const SizedBox(height: 20),
          _buildSearchBar(),
        ],
      ),
    );
  }

  /// The user's photo (or initial); tapping it opens the Profile tab.
  Widget _buildAvatar() {
    return Tooltip(
      message: 'My profile',
      child: GestureDetector(
        onTap: onAvatarTap,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
          ),
          child: UserAvatar(
            size: 46,
            user: ChatParticipant(userID: '', displayName: name, role: 'job_seeker', photoUrl: photoUrl),
          ),
        ),
      ),
    );
  }

  /// Looks like a search box; tapping it opens the job search.
  Widget _buildSearchBar() {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onSearchTap,
        borderRadius: BorderRadius.circular(18),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(16, 15, 14, 15),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.textMuted),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search job title, company or location',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textHint, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
