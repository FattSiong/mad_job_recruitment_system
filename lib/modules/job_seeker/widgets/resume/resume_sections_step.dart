import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/resume_model.dart';
import '../../controllers/resume_builder_controller.dart';
import '../../../../shared_widgets/empty_hint.dart';
import 'resume_record_steps.dart';
import 'resume_section_item_sheet.dart';
import '../../../../shared_widgets/confirm_dialog.dart';
import '../../../../shared_widgets/action_sheet.dart';
import '../../../../core/theme/app_input_decoration.dart';

/// Last step: optional sections (summary, projects, awards, languages...).
class ResumeSectionsStep extends StatelessWidget {
  final ResumeBuilderController controller;

  const ResumeSectionsStep({super.key, required this.controller});

  /// Lets the user pick an optional section to add.
  Future<void> _addSection(BuildContext context) async {
    final types = controller.availableSectionTypes;
    if (types.isEmpty) return;

    final type = await showActionSheet<ResumeSectionType>(
      context,
      title: 'Add a section',
      actions: [
        for (final t in types) SheetAction(t, t.label, icon: _iconFor(t), subtitle: t.hint),
      ],
    );
    if (type == null) return;
    controller.addSection(type);
    if (!type.isTextOnly && context.mounted) {
      final item = await showResumeSectionItemSheet(context, type: type);
      if (item != null) controller.addSectionItem(type, item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = controller.resume.sections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sections.isEmpty)
          const EmptyHint(
            margin: EdgeInsets.only(bottom: 14),
            text: 'Optional: add a summary, projects, awards, languages and more. '
                'You can also finish now.',
          ),
        for (final section in sections)
          _SectionCard(
            key: ValueKey(section.type),
            section: section,
            controller: controller,
          ),
        if (controller.availableSectionTypes.isNotEmpty)
          ResumeAddButton(label: 'Add Section', onPressed: () => _addSection(context)),
      ],
    );
  }
}

/// The icon for each optional section.
IconData _iconFor(ResumeSectionType type) {
  switch (type) {
    case ResumeSectionType.summary:
      return Icons.person_pin_outlined;
    case ResumeSectionType.projects:
      return Icons.rocket_launch_outlined;
    case ResumeSectionType.awards:
      return Icons.emoji_events_outlined;
    case ResumeSectionType.certifications:
      return Icons.verified_outlined;
    case ResumeSectionType.languages:
      return Icons.translate_rounded;
    case ResumeSectionType.volunteer:
      return Icons.volunteer_activism_outlined;
    case ResumeSectionType.additional:
      return Icons.notes_rounded;
  }
}

/// One optional section: its text or list of items, and a remove button.
class _SectionCard extends StatefulWidget {
  final ResumeSection section;
  final ResumeBuilderController controller;

  const _SectionCard({super.key, required this.section, required this.controller});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  late final TextEditingController _text = TextEditingController(text: widget.section.text);

  ResumeSectionType get _type => widget.section.type;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  // Saved into the resume straight away, so Next/Finish never miss text.
  /// Saves the section text as it is typed.
  void _onTextChanged(String value) => widget.controller.setSectionText(_type, value);

  /// Removes the section after asking.
  Future<void> _confirmRemove() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Remove ${_type.label}?',
      message: 'This section and everything in it will be removed from your resume.',
      confirmLabel: 'Remove',
    );
    if (ok) widget.controller.removeSection(_type);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.section.items;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_iconFor(_type), color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _type.label,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark),
                ),
              ),
              IconButton(
                tooltip: 'Remove section',
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
                onPressed: _confirmRemove,
              ),
            ],
          ),
          if (_type.isTextOnly)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextField(
                controller: _text,
                onChanged: _onTextChanged,
                minLines: 3,
                maxLines: 8,
                maxLength: 1200,
                textCapitalization: TextCapitalization.sentences,
                decoration: filledInputDecoration(hint: _type == ResumeSectionType.summary
                      ? 'e.g. Final-year IT student with hands-on Flutter experience...'
                      : 'Anything else an employer should know', fillColor: AppColors.surface, radius: 14),
              ),
            )
          else ...[
            for (var i = 0; i < items.length; i++)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 0, right: 0),
                title: Text(items[i].title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  [items[i].subtitle, items[i].period]
                      .whereType<String>()
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                ),
                onTap: () async {
                  final updated =
                      await showResumeSectionItemSheet(context, type: _type, initial: items[i]);
                  if (updated != null) widget.controller.replaceSectionItem(_type, i, updated);
                },
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => widget.controller.removeSectionItem(_type, i),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final item = await showResumeSectionItemSheet(context, type: _type);
                  if (item != null) widget.controller.addSectionItem(_type, item);
                },
                icon: const Icon(Icons.add_rounded),
                label: Text('Add to ${_type.label}'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
