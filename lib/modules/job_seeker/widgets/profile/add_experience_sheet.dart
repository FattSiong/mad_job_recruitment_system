import 'package:flutter/material.dart';

import '../../../../models/work_experience_model.dart';
import 'profile_sheet_helpers.dart';

/// Bottom sheet for adding a work experience, or editing [initial] when given.
/// Returns the record (keeping [initial]'s ID when editing), or null if the user
/// closes the sheet. The screen saves it through ProfileController.
Future<WorkExperienceModel?> showAddExperienceSheet(
  BuildContext context, {
  WorkExperienceModel? initial,
}) {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController(text: initial?.jobTitle);
  final companyController = TextEditingController(text: initial?.companyName);
  final descController = TextEditingController(text: initial?.description);
  DateTime? startDate = initial?.startDate;
  DateTime? endDate = initial?.endDate;
  bool isCurrentRole = initial?.isCurrent ?? false;
  String? startDateErrorText;
  String? endDateErrorText;

  return showProfileFormSheet<WorkExperienceModel>(
    context,
    formKey: formKey,
    title: initial != null ? 'Edit Work Experience' : 'Add Work Experience',
    submitLabel: initial != null ? 'Save Changes' : 'Add Experience',
    fields: (setSheetState) => [
      TextFormField(
        controller: titleController,
        decoration: profileSheetInputDecoration('Job Title*', Icons.work),
        validator: limitedField(profileNameMaxLength, required: true),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: companyController,
        decoration: profileSheetInputDecoration('Company Name*', Icons.business),
        validator: limitedField(profileNameMaxLength, required: true),
      ),
      const SizedBox(height: 16),
      ProfileDateRangeFields(
        start: startDate,
        end: endDate,
        isCurrent: isCurrentRole,
        startError: startDateErrorText,
        endError: endDateErrorText,
        currentLabel: 'I currently work here',
        onStartPicked: (d) => setSheetState(() {
          startDate = d;
          startDateErrorText = null;
        }),
        onEndPicked: (d) => setSheetState(() {
          endDate = d;
          endDateErrorText = null;
        }),
        onCurrentChanged: (v) => setSheetState(() {
          isCurrentRole = v;
          if (v) {
            endDate = null;
            endDateErrorText = null;
          }
        }),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: descController,
        decoration: profileSheetInputDecoration('Description', Icons.description),
        maxLines: 4,
        validator: limitedField(profileDescriptionMaxLength),
      ),
    ],
    onSubmit: (sheetContext, setSheetState) {
      final formOk = formKey.currentState!.validate();
      // Work already done: neither date can be after today
      final dates = validateProfileDates(
        start: startDate,
        end: endDate,
        isCurrent: isCurrentRole,
        noFuture: true,
      );
      setSheetState(() {
        startDateErrorText = dates.start;
        endDateErrorText = dates.end;
      });
      if (!formOk || dates.start != null || dates.end != null) return;

      Navigator.pop(
        sheetContext,
        WorkExperienceModel(
          experienceID: initial?.experienceID,
          seekerID: initial?.seekerID ?? '',
          companyName: companyController.text.trim(),
          jobTitle: titleController.text.trim(),
          startDate: startDate!,
          endDate: endDate,
          isCurrent: isCurrentRole,
          description: descController.text.trim(),
        ),
      );
    },
  );
}
