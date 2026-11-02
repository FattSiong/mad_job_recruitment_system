import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/chat_room_model.dart';
import '../chat_formatters.dart';
import 'chat_avatar.dart';

/// One conversation on the chat list.
class ChatListTile extends StatelessWidget {
  final ChatRoomModel room;
  final String currentUserID;
  final VoidCallback onTap;

  const ChatListTile({
    super.key,
    required this.room,
    required this.currentUserID,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = room.unreadCount > 0;
    final unreadLabel = room.unreadCount > 99 ? '99+' : '${room.unreadCount}';

    return Material(
      color: isUnread ? AppColors.surfaceAlt : AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ChatAvatar(user: room.otherUser, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            room.otherUser.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ChatFormatters.listTime(room.lastActivity),
                          style: TextStyle(
                            fontSize: 12,
                            color: isUnread ? AppColors.primary : AppColors.textMuted,
                            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        room.otherUser.roleLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            room.previewText(currentUserID),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: isUnread ? AppColors.textDark : AppColors.textMuted,
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 24),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.teal,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              unreadLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
