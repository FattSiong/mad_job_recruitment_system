import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/work_experience_model.dart';
import 'profile_sheet_helpers.dart';

/// Bottom sheet for adding a work experience, or editing [initial] when given.
/// Returns the record (keeping [initial]'s ID when editing), or null if the user
/// closes the sheet. The screen saves it through ProfileController.
Future<WorkExperienceModel?> showAddExperienceSheet(
  BuildContext context, {
  WorkExperienceModel? initial,
}) {
  final isEditing = initial != null;
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController(text: initial?.jobTitle);
  final companyController = TextEditingController(text: initial?.companyName);
  final descController = TextEditingController(text: initial?.description);
  DateTime? startDate = initial?.startDate;
  DateTime? endDate = initial?.endDate;
  bool isCurrentRole = initial?.isCurrent ?? false;
  String? startDateErrorText;
  String? endDateErrorText;

  return showModalBottomSheet<WorkExperienceModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    isEditing ? 'Edit Work Experience' : 'Add Work Experience',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: titleController,
                    decoration: profileSheetInputDecoration('Job Title*', Icons.work),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: companyController,
                    decoration: profileSheetInputDecoration('Company Name*', Icons.business),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await pickProfileDate(context, startDate);
                            if (date != null) {
                              setModalState(() {
                                startDate = date;
                                startDateErrorText = null;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: profileSheetInputDecoration(
                              'Start Date*',
                              Icons.calendar_today,
                            ).copyWith(
                              errorText: startDateErrorText,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: startDateErrorText != null
                                      ? AppColors.errorRed
                                      : Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: startDateErrorText != null
                                      ? AppColors.errorRed
                                      : AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.errorRed),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.errorRed,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: Text(
                              startDate == null
                                  ? 'Select'
                                  : DateFormat('yMd').format(startDate!),
                              style: TextStyle(
                                color: startDate == null
                                    ? Colors.grey.shade600
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: isCurrentRole
                              ? null
                              : () async {
                            final date = await pickProfileDate(context, endDate);
                            if (date != null) {
                              setModalState(() {
                                endDate = date;
                                endDateErrorText = null;
                              });
                            }

                          },
                          child: InputDecorator(
                            decoration: profileSheetInputDecoration(
                              'End Date',
                              Icons.calendar_today,
                            ).copyWith(
                              filled: true,
                              fillColor: isCurrentRole
                                  ? Colors.grey.shade200
                                  : Colors.grey.shade50,
                              errorText: endDateErrorText,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: endDateErrorText != null
                                      ? AppColors.errorRed
                                      : Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: endDateErrorText != null
                                      ? AppColors.errorRed
                                      : AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.errorRed),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.errorRed,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: Text(
                              isCurrentRole
                                  ? 'Present'
                                  : (endDate == null
                                  ? 'Select'
                                  : DateFormat('yMd').format(endDate!)),
                              style: TextStyle(
                                color: (endDate == null && !isCurrentRole)
                                    ? Colors.grey.shade600
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: isCurrentRole,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (v) {
                          setModalState(() {
                            isCurrentRole = v ?? false;
                            if (isCurrentRole) {
                              endDate = null;
                              endDateErrorText = null;
                            }
                          });
                        },
                      ),
                      const Text(
                        'I currently work here',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descController,
                    decoration: profileSheetInputDecoration(
                      'Description',
                      Icons.description,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        setModalState(() {
                          if (startDate == null) {
                            startDateErrorText = 'Required';
                          } else {
                            startDateErrorText = null;
                          }

                          if (startDate != null) {
                            if (!isCurrentRole && endDate == null) {
                              endDateErrorText = 'Required';
                            } else if (!isCurrentRole &&
                                endDate != null &&
                                endDate!.isBefore(startDate!)) {
                              endDateErrorText = 'Invalid end date';
                            } else {
                              endDateErrorText = null;
                            }
                          } else {
                            endDateErrorText = null;
                          }
                        });

                        if (startDateErrorText != null || endDateErrorText != null) return;

                        final newExp = WorkExperienceModel(
                          experienceID: initial?.experienceID,
                          seekerID: initial?.seekerID ?? '',
                          companyName: companyController.text.trim(),
                          jobTitle: titleController.text.trim(),
                          startDate: startDate!,
                          endDate: endDate,
                          isCurrent: isCurrentRole,
                          description: descController.text.trim(),
                        );

                        Navigator.pop(context, newExp);
                      } else if (startDate == null) {
                        setModalState(() {});
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isEditing ? 'Save Changes' : 'Add Experience',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
