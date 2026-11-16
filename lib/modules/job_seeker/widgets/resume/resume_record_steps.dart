import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../controllers/resume_builder_controller.dart';
import '../profile/add_education_sheet.dart';
import '../profile/add_experience_sheet.dart';
import '../profile/profile_record_card.dart';
import '../profile/profile_sheet_helpers.dart';

/// Education step: the resume's own list (edits don't change the profile).
class ResumeEducationStep extends StatelessWidget {
  final ResumeBuilderController controller;

  const ResumeEducationStep({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final items = controller.resume.education;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items.isEmpty)
          const ResumeEmptyHint(text: 'No education added yet.')
        else
          for (var i = 0; i < items.length; i++)
            ProfileRecordCard(
              icon: Icons.school_outlined,
              iconColor: Colors.orange,
              title: (items[i].fieldOfStudy?.isNotEmpty ?? false)
                  ? '${items[i].degree} - ${items[i].fieldOfStudy}'
                  : items[i].degree,
              subtitle: items[i].institutionName,
              dateRange: formatProfileDateRange(items[i].startDate, items[i].endDate, items[i].isCurrent),
              description: items[i].description,
              onEdit: () async {
                final updated = await showAddEducationSheet(context, initial: items[i]);
                if (updated != null) controller.replaceEducation(i, updated);
              },
              onDelete: () => controller.removeEducation(i),
            ),
        ResumeAddButton(
          label: 'Add Education',
          onPressed: () async {
            final added = await showAddEducationSheet(context);
            if (added != null) controller.addEducation(added);
          },
        ),
      ],
    );
  }
}

/// Work experience step.
class ResumeExperienceStep extends StatelessWidget {
  final ResumeBuilderController controller;

  const ResumeExperienceStep({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final items = controller.resume.experience;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items.isEmpty)
          const ResumeEmptyHint(
            text: 'No work experience yet. Internships and part-time jobs count too, '
                'or skip this step.',
          )
        else
          for (var i = 0; i < items.length; i++)
            ProfileRecordCard(
              icon: Icons.work_outline_rounded,
              iconColor: AppColors.primary,
              title: items[i].jobTitle,
              subtitle: items[i].companyName,
              dateRange: formatProfileDateRange(items[i].startDate, items[i].endDate, items[i].isCurrent),
              description: items[i].description,
              onEdit: () async {
                final updated = await showAddExperienceSheet(context, initial: items[i]);
                if (updated != null) controller.replaceExperience(i, updated);
              },
              onDelete: () => controller.removeExperience(i),
            ),
        ResumeAddButton(
          label: 'Add Work Experience',
          onPressed: () async {
            final added = await showAddExperienceSheet(context);
            if (added != null) controller.addExperience(added);
          },
        ),
      ],
    );
  }
}

/// Hint card shown while a resume step has no entries yet.
class ResumeEmptyHint extends StatelessWidget {
  final String text;

  const ResumeEmptyHint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outlined "Add ..." button under a resume step's list.
class ResumeAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const ResumeAddButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: AppColors.borderActive),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
