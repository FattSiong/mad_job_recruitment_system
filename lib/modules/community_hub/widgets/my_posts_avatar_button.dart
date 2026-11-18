import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/chat_room_model.dart';
import '../../../shared_widgets/user_avatar.dart';

/// The signed-in user's photo next to the feed's search box.
/// Tapping it opens their own posts.
class MyPostsAvatarButton extends StatelessWidget {
  /// Null while the user's name and photo are still loading.
  final ChatParticipant? user;
  final VoidCallback onTap;
  final double size;

  const MyPostsAvatarButton({super.key, required this.user, required this.onTap, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.32);
    final me = user;

    return Tooltip(
      message: 'My posts',
      child: Material(
        color: AppColors.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: me == null
              ? SizedBox.square(
                  dimension: size,
                  child: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                )
              : UserAvatar(user: me, size: size),
        ),
      ),
    );
  }
}
