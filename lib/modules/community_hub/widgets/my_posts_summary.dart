import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../controllers/post_list_controller.dart';

/// "Total / Visible / Removed" counts at the top of My Posts.
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
            _tile('${controller.totalCount}', 'Total', Icons.article_outlined, AppColors.primary),
            const SizedBox(width: 10),
            _tile('${controller.visibleCount}', 'Visible', Icons.visibility_outlined, AppColors.teal),
            const SizedBox(width: 10),
            _tile('${controller.removedCount}', 'Removed', Icons.block_rounded, AppColors.danger),
          ],
        ),
      ),
    );
  }

  Widget _tile(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
