import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/post_filter.dart';
import '../controllers/post_list_controller.dart';

/// "Total / Visible / Removed" counts at the top of My Posts.
/// Tapping one shows only those posts.
class MyPostsSummary extends StatelessWidget {
  final PostListController controller;

  const MyPostsSummary({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            _tile(MyPostsStatus.all, '${controller.totalCount}', 'Total',
                Icons.article_outlined, AppColors.primary),
            const SizedBox(width: 10),
            _tile(MyPostsStatus.visible, '${controller.visibleCount}', 'Visible',
                Icons.visibility_outlined, AppColors.teal),
            const SizedBox(width: 10),
            _tile(MyPostsStatus.removed, '${controller.removedCount}', 'Removed',
                Icons.block_rounded, AppColors.danger),
          ],
        ),
      ),
    );
  }

  Widget _tile(MyPostsStatus status, String value, String label, IconData icon, Color color) {
    final selected = controller.statusFilter == status;
    return Expanded(
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => controller.setStatusFilter(status),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
