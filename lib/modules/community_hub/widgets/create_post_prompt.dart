import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// "What do you want to share today?" card at the top of the feed.
class CreatePostPrompt extends StatelessWidget {
  final VoidCallback onTap;

  const CreatePostPrompt({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Start a conversation',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ask a question, share a tip, or post an update.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Material(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(Icons.edit_rounded, color: AppColors.primary, size: 18),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'What do you want to share today?',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(Icons.attach_file_rounded, color: AppColors.textMuted, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
