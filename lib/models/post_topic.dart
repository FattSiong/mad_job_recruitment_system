import 'package:flutter/material.dart';

/// Topic an author picks for a community post.
/// [value] is what is stored in "CommunityPost"."category".
enum PostTopic {
  general('general', 'General', Icons.forum_outlined),
  jobTips('job_tips', 'Job Tips', Icons.lightbulb_outline_rounded),
  hiring('hiring', 'Hiring', Icons.work_outline_rounded),
  interview('interview', 'Interview Experience', Icons.record_voice_over_outlined),
  question('question', 'Question', Icons.help_outline_rounded),
  careerAdvice('career_advice', 'Career Advice', Icons.trending_up_rounded),
  showcase('showcase', 'Showcase', Icons.emoji_events_outlined);

  const PostTopic(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  /// Unknown or missing values (e.g. posts made before topics existed)
  /// count as [general].
  static PostTopic fromValue(String? value) =>
      PostTopic.values.firstWhere((t) => t.value == value, orElse: () => PostTopic.general);
}
