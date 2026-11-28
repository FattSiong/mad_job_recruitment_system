import 'package:flutter/material.dart';

import '../../../../models/education_model.dart';
import 'profile_sheet_helpers.dart';

const List<String> _degreeOptions = [
  'High School / SPM',
  'Certificate',
  'Diploma',
  "Bachelor's Degree",
  "Master's Degree",
  'Doctorate / PhD',
  'Other',
];

/// True for Diploma and higher (these ask for a field of study).
bool _isDiplomaOrAbove(String? degree) =>
    degree == 'Diploma' ||
    degree == "Bachelor's Degree" ||
    degree == "Master's Degree" ||
    degree == 'Doctorate / PhD';

/// Bottom sheet for adding an education record, or editing [initial] when given.
/// Returns the record (keeping [initial]'s ID when editing), or null if the user
/// closes the sheet. The screen saves it through ProfileController.
Future<EducationModel?> showAddEducationSheet(
  BuildContext context, {
  EducationModel? initial,
}) {
  final formKey = GlobalKey<FormState>();
  final institutionController = TextEditingController(text: initial?.institutionName);
  final fieldOfStudyController = TextEditingController(text: initial?.fieldOfStudy);
  final descController = TextEditingController(text: initial?.description);
  DateTime? startDate = initial?.startDate;
  DateTime? endDate = initial?.endDate;
  bool isCurrent = initial?.isCurrent ?? false;
  String? startDateErrorText;
  String? endDateErrorText;

  final savedDegree = initial?.degree;
  String? selectedDegree = savedDegree;
  // Keep an older/custom degree value selectable when editing.
  final degreeOptions = [
    ..._degreeOptions,
    if (savedDegree != null && !_degreeOptions.contains(savedDegree)) savedDegree,
  ];

  return showProfileFormSheet<EducationModel>(
    context,
    formKey: formKey,
    title: initial != null ? 'Edit Education' : 'Add Education',
    submitLabel: initial != null ? 'Save Changes' : 'Add Education',
    fields: (setSheetState) => [
      TextFormField(
        controller: institutionController,
        decoration: profileSheetInputDecoration('Institution Name*', Icons.school),
        validator: limitedField(profileNameMaxLength, required: true),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        decoration: profileSheetInputDecoration('Degree/Qualification*', Icons.history_edu),
        initialValue: selectedDegree,
        items: degreeOptions.map((value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
        onChanged: (newValue) {
          setSheetState(() {
            selectedDegree = newValue;
            if (!_isDiplomaOrAbove(newValue)) fieldOfStudyController.clear();
          });
        },
        validator: requiredField,
      ),
      const SizedBox(height: 16),
      if (_isDiplomaOrAbove(selectedDegree)) ...[
        TextFormField(
          controller: fieldOfStudyController,
          decoration: profileSheetInputDecoration('Field of Study*', Icons.menu_book),
          validator: limitedField(profileNameMaxLength, required: true),
        ),
        const SizedBox(height: 16),
      ],
      ProfileDateRangeFields(
        start: startDate,
        end: endDate,
        isCurrent: isCurrent,
        startError: startDateErrorText,
        endError: endDateErrorText,
        currentLabel: 'I am currently studying here',
        onStartPicked: (d) => setSheetState(() {
          startDate = d;
          startDateErrorText = null;
        }),
        onEndPicked: (d) => setSheetState(() {
          endDate = d;
          endDateErrorText = null;
        }),
        onCurrentChanged: (v) => setSheetState(() {
          isCurrent = v;
          if (v) {
            endDate = null;
            endDateErrorText = null;
          }
        }),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: descController,
        decoration: profileSheetInputDecoration('Description / Achievements', Icons.description),
        maxLines: 4,
        validator: limitedField(profileDescriptionMaxLength),
      ),
    ],
    onSubmit: (sheetContext, setSheetState) {
      final formOk = formKey.currentState!.validate();
      // A course can end in the future (expected graduation)
      final dates = validateProfileDates(start: startDate, end: endDate, isCurrent: isCurrent);
      setSheetState(() {
        startDateErrorText = dates.start;
        endDateErrorText = dates.end;
      });
      if (!formOk || dates.start != null || dates.end != null) return;

      Navigator.pop(
        sheetContext,
        EducationModel(
          educationID: initial?.educationID,
          seekerID: initial?.seekerID,
          institutionName: institutionController.text.trim(),
          degree: selectedDegree!,
          fieldOfStudy: _isDiplomaOrAbove(selectedDegree) ? fieldOfStudyController.text.trim() : null,
          description: descController.text.trim(),
          startDate: startDate!,
          endDate: endDate,
          isCurrent: isCurrent,
        ),
      );
    },
  );
}
