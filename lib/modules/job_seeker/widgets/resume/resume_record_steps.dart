import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared_widgets/empty_hint.dart';
import '../../controllers/resume_builder_controller.dart';
import '../profile/add_education_sheet.dart';
import '../profile/add_experience_sheet.dart';
import '../profile/profile_record_card.dart';

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
          const EmptyHint(text: 'No education added yet.', margin: EdgeInsets.only(bottom: 14))
        else
          for (var i = 0; i < items.length; i++)
            ProfileRecordCard.education(
              items[i],
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
          const EmptyHint(
            text: 'No work experience yet. Internships and part-time jobs count too, '
                'or skip this step.',
            margin: EdgeInsets.only(bottom: 14),
          )
        else
          for (var i = 0; i < items.length; i++)
            ProfileRecordCard.experience(
              items[i],
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
