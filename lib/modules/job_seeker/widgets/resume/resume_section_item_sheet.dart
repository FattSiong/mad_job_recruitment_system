import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/resume_model.dart';
import '../profile/profile_sheet_helpers.dart';

/// Field labels for each optional section.
class _Fields {
  final String title;
  final String? subtitle;
  final String? period;
  final String? description;

  const _Fields(this.title, {this.subtitle, this.period, this.description});
}

const Map<ResumeSectionType, _Fields> _fieldsByType = {
  ResumeSectionType.projects: _Fields(
    'Project name*',
    subtitle: 'Your role or tools used',
    period: 'When (e.g. Jan 2025 - Mar 2025)',
    description: 'What you did and the result',
  ),
  ResumeSectionType.awards: _Fields(
    'Award*',
    subtitle: 'Given by',
    period: 'Year',
    description: 'Details (optional)',
  ),
  ResumeSectionType.certifications: _Fields(
    'Certificate*',
    subtitle: 'Issued by',
    period: 'Year',
    description: 'Details (optional)',
  ),
  ResumeSectionType.volunteer: _Fields(
    'Role*',
    subtitle: 'Organisation',
    period: 'When',
    description: 'What you did',
  ),
  ResumeSectionType.languages: _Fields('Language*'),
};

const List<String> _languageLevels = ['Native', 'Fluent', 'Professional', 'Conversational', 'Basic'];

/// Add or edit one item of an optional section. Returns the item, or null.
Future<ResumeSectionItem?> showResumeSectionItemSheet(
  BuildContext context, {
  required ResumeSectionType type,
  ResumeSectionItem? initial,
}) {
  return showModalBottomSheet<ResumeSectionItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SectionItemSheet(type: type, initial: initial),
  );
}

class _SectionItemSheet extends StatefulWidget {
  final ResumeSectionType type;
  final ResumeSectionItem? initial;

  const _SectionItemSheet({required this.type, this.initial});

  @override
  State<_SectionItemSheet> createState() => _SectionItemSheetState();
}

class _SectionItemSheetState extends State<_SectionItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(text: widget.initial?.title);
  late final TextEditingController _subtitle = TextEditingController(text: widget.initial?.subtitle);
  late final TextEditingController _period = TextEditingController(text: widget.initial?.period);
  late final TextEditingController _description =
      TextEditingController(text: widget.initial?.description);
  late String? _languageLevel = widget.initial?.subtitle;

  bool get _isLanguage => widget.type == ResumeSectionType.languages;

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _period.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    String? clean(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    Navigator.pop(
      context,
      ResumeSectionItem(
        title: _title.text.trim(),
        subtitle: _isLanguage ? _languageLevel : clean(_subtitle),
        period: _isLanguage ? null : clean(_period),
        description: _isLanguage ? null : clean(_description),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fieldsByType[widget.type] ?? const _Fields('Title*');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${widget.initial == null ? 'Add' : 'Edit'} ${widget.type.label}',
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 120,
                decoration: profileSheetInputDecoration(fields.title, Icons.title_rounded)
                    .copyWith(counterText: ''),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              if (_isLanguage) ...[
                const Text('Level', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _languageLevels.map((level) {
                    final selected = _languageLevel == level;
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
                      onSelected: (_) => setState(() => _languageLevel = selected ? null : level),
                    );
                  }).toList(),
                ),
              ] else ...[
                if (fields.subtitle != null) ...[
                  TextFormField(
                    controller: _subtitle,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 120,
                    decoration: profileSheetInputDecoration(fields.subtitle!, Icons.badge_outlined)
                        .copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 14),
                ],
                if (fields.period != null) ...[
                  TextFormField(
                    controller: _period,
                    maxLength: 40,
                    decoration: profileSheetInputDecoration(fields.period!, Icons.calendar_today_outlined)
                        .copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 14),
                ],
                if (fields.description != null)
                  TextFormField(
                    controller: _description,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 800,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: profileSheetInputDecoration(fields.description!, Icons.notes_rounded)
                        .copyWith(helperText: 'Start a line with "-" to make a bullet point.'),
                  ),
              ],
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  widget.initial == null ? 'Add' : 'Save Changes',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
