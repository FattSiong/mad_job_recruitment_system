import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/chat_room_model.dart';

/// Rounded-square avatar: the user's photo, or their initial.
class ChatAvatar extends StatelessWidget {
  final ChatParticipant user;
  final double size;

  const ChatAvatar({super.key, required this.user, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.32);
    final photo = user.photoUrl;

    final initial = Center(
      child: Text(
        user.initial,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        color: AppColors.primarySoft,
        child: (photo == null || photo.isEmpty)
            ? initial
            : CachedNetworkImage(
                imageUrl: photo,
                fit: BoxFit.cover,
                memCacheWidth: (size * 3).round(),
                placeholder: (_, __) => initial,
                errorWidget: (_, __, ___) => initial,
              ),
      ),
    );
  }
}
