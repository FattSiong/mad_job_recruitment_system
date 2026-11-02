import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/skill_model.dart';

/// Read-only list of skills as chips ("Flutter · Advanced").
/// Used on the seeker's own profile, the public (QR) profile and the
/// employer's applicant detail screen.
class SkillChips extends StatelessWidget {
  final List<SkillModel> skills;

  const SkillChips({super.key, required this.skills});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills.map((skill) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: skill.skillName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                if (skill.proficiency != null)
                  TextSpan(
                    text: '  ·  ${skill.proficiency}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
