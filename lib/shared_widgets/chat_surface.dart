import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Rounded light-blue panel behind a conversation (chat room, Career Buddy).
class ChatSurface extends StatelessWidget {
  final Widget child;

  const ChatSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.chatGradient,
        borderRadius: BorderRadius.circular(30),
      ),
      child: child,
    );
  }
}
