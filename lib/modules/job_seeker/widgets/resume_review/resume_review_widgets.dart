import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../../../models/resume_review_model.dart';

/// Green / amber / red for a 0-100 score (same bands as the score label).
Color resumeScoreColor(int score) {
  if (score >= 70) return AppColors.successGreen;
  if (score >= 50) return AppColors.warning;
  return AppColors.errorRed;
}

/// Red / amber / teal for high / medium / low priority.
Color _priorityColor(String priority) => switch (priority) {
      'high' => AppColors.errorRed,
      'low' => AppColors.teal,
      _ => AppColors.warning,
    };

/// "High priority", "Medium priority" or "Nice to have".
String _priorityLabel(String priority) => switch (priority) {
      'high' => 'High priority',
      'low' => 'Nice to have',
      _ => 'Medium priority',
    };

/// Round score with a coloured progress ring.
class ResumeScoreRing extends StatelessWidget {
  final int score;
  final double size;

  const ResumeScoreRing({super.key, required this.score, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final color = resumeScoreColor(score);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score / 100),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CircularProgressIndicator(
              value: value,
              strokeWidth: size * 0.09,
              strokeCap: StrokeCap.round,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: size * 0.3,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    height: 1,
                  ),
                ),
                Text(
                  '/ 100',
                  style: TextStyle(fontSize: size * 0.12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One scoring area with a bar and the AI's comment.
class ReviewCategoryBar extends StatelessWidget {
  final ReviewCategoryScore category;

  const ReviewCategoryBar({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final color = resumeScoreColor(category.score);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category.label,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
              ),
              Text(
                '${category.score}',
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: category.score / 100,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (category.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              category.comment,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// One suggested change; shows a before/after rewrite with a Copy button.
class ResumeImprovementCard extends StatelessWidget {
  final ResumeImprovement item;

  const ResumeImprovementCard({super.key, required this.item});

  /// Copies the suggested rewrite.
  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: item.after));
    if (!context.mounted) return;
    SnackBarHelper.showStyled(
      context,
      message: 'Copied. Replace any [placeholders] with your real details.',
      icon: Icons.copy_rounded,
      accentColor: AppColors.primary,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(item.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _pill(_priorityLabel(item.priority), color),
              _pill(item.section, AppColors.primary),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.issue,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, height: 1.35),
          ),
          if (item.suggestion.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.suggestion,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13.5, height: 1.45),
            ),
          ],
          if (item.hasRewrite) ...[
            const SizedBox(height: 14),
            _rewriteBox(
              label: 'Before',
              text: item.before,
              background: Colors.white,
              textColor: AppColors.textMuted,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: Icon(Icons.arrow_downward_rounded, size: 18, color: AppColors.textMuted),
              ),
            ),
            _rewriteBox(
              label: 'Suggested',
              text: item.after,
              background: AppColors.primarySoft,
              textColor: AppColors.textDark,
              trailing: IconButton(
                tooltip: 'Copy',
                visualDensity: VisualDensity.compact,
                onPressed: () => _copy(context),
                icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Small coloured label.
  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );

  /// Box with the "Before" or "Suggested" text.
  Widget _rewriteBox({
    required String label,
    required String text,
    required Color background,
    required Color textColor,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, 10, trailing == null ? 12 : 2, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(text, style: TextStyle(color: textColor, height: 1.45)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
