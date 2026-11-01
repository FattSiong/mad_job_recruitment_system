import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// One work-experience or education entry on the profile screen.
/// Shows a delete button when [onDelete] is given (edit mode).
class ProfileRecordCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String dateRange;
  final String? description;
  final VoidCallback? onDelete;

  const ProfileRecordCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.dateRange,
    this.description,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateRange,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textDark,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
              tooltip: 'Remove',
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
