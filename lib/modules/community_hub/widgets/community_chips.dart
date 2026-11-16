import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/post_topic.dart';

/// Small coloured label showing a post's topic. Tappable when [onTap] is set
/// (e.g. on the feed: show more posts on this topic).
class TopicChip extends StatelessWidget {
  final PostTopic topic;
  final VoidCallback? onTap;

  const TopicChip({super.key, required this.topic, this.onTap});

  /// The label colour for each topic.
  static Color colorOf(PostTopic topic) {
    switch (topic) {
      case PostTopic.general:
        return AppColors.textMuted;
      case PostTopic.jobTips:
        return AppColors.warning;
      case PostTopic.hiring:
        return AppColors.teal;
      case PostTopic.interview:
        return AppColors.statusInterviewed;
      case PostTopic.question:
        return AppColors.coral;
      case PostTopic.careerAdvice:
        return AppColors.primary;
      case PostTopic.showcase:
        return AppColors.statusScheduled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorOf(topic);
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(topic.icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                topic.label,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One choice in a row of options (topics, sort order, date, ...).
class OptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const OptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textDark;
    return ChoiceChip(
      label: Text(label),
      avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? Colors.white : AppColors.primary),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.borderSoft),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w600, fontSize: 13),
      visualDensity: VisualDensity.compact,
    );
  }
}
