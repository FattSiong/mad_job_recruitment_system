import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/skill_model.dart';
import '../../controllers/resume_builder_controller.dart';
import 'resume_record_steps.dart';

/// Skills step: add skills with an optional level; tap a skill to change it.
class ResumeSkillsStep extends StatefulWidget {
  final ResumeBuilderController controller;

  const ResumeSkillsStep({super.key, required this.controller});

  @override
  State<ResumeSkillsStep> createState() => _ResumeSkillsStepState();
}

class _ResumeSkillsStepState extends State<ResumeSkillsStep> {
  final TextEditingController _input = TextEditingController();
  String? _level;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final error = widget.controller.addSkill(_input.text, _level);
    setState(() => _error = error);
    if (error == null) {
      _input.clear();
      setState(() => _level = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skills = widget.controller.resume.skills;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                maxLength: 50,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(
                  hintText: 'e.g. Flutter, Customer Service',
                  errorText: _error,
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _add,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Add'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SkillModel.proficiencyLevels.map((level) {
            final selected = _level == level;
            return ChoiceChip(
              label: Text(level),
              selected: selected,
              showCheckmark: false,
              selectedColor: AppColors.primarySoft,
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
              onSelected: (_) => setState(() => _level = selected ? null : level),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        if (skills.isEmpty)
          const ResumeEmptyHint(text: 'No skills yet. Add at least a few that match the jobs you want.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < skills.length; i++)
                InputChip(
                  label: Text(
                    skills[i].level == null ? skills[i].name : '${skills[i].name} · ${skills[i].level}',
                  ),
                  backgroundColor: AppColors.surfaceAlt,
                  side: const BorderSide(color: AppColors.border),
                  labelStyle: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600),
                  onPressed: () => _changeLevel(i),
                  onDeleted: () => widget.controller.removeSkill(i),
                  deleteIconColor: AppColors.textMuted,
                ),
            ],
          ),
        if (skills.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Tap a skill to change its level.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Future<void> _changeLevel(int index) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final level in SkillModel.proficiencyLevels)
              ListTile(
                title: Text(level),
                onTap: () => Navigator.pop(sheetContext, level),
              ),
            ListTile(
              title: const Text('No level'),
              onTap: () => Navigator.pop(sheetContext, ''),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    widget.controller.setSkillLevel(index, choice.isEmpty ? null : choice);
  }
}
