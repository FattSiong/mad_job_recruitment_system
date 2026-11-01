import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/education_model.dart';
import 'profile_sheet_helpers.dart';

/// Bottom sheet for adding an education record.
/// Returns the new record, or null if the user closes the sheet.
/// The screen saves it through ProfileController.
Future<EducationModel?> showAddEducationSheet(BuildContext context) {
  final formKey = GlobalKey<FormState>();
  final institutionController = TextEditingController();
  final fieldOfStudyController = TextEditingController();
  final descController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  bool isCurrent = false;
  String? startDateErrorText;
  String? endDateErrorText;


  final List<String> degreeOptions = [
    'High School / SPM',
    'Certificate',
    'Diploma',
    "Bachelor's Degree",
    "Master's Degree",
    'Doctorate / PhD',
    'Other',
  ];
  String? selectedDegree;

  bool isDiplomaOrAbove(String? degree) {
    return degree == 'Diploma' ||
        degree == "Bachelor's Degree" ||
        degree == "Master's Degree" ||
        degree == 'Doctorate / PhD';
  }

  return showModalBottomSheet<EducationModel>(
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
                  const Text(
                    'Add Education',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: institutionController,
                    decoration: profileSheetInputDecoration(
                      'Institution Name*',
                      Icons.school,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: profileSheetInputDecoration(
                      'Degree/Qualification*',
                      Icons.history_edu,
                    ),
                    initialValue: selectedDegree,
                    items: degreeOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setModalState(() {
                        selectedDegree = newValue;
                        if (!isDiplomaOrAbove(newValue)) {
                          fieldOfStudyController.clear();
                        }
                      });
                    },
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  if (isDiplomaOrAbove(selectedDegree)) ...[
                    TextFormField(
                      controller: fieldOfStudyController,
                      decoration: profileSheetInputDecoration(
                        'Field of Study*',
                        Icons.menu_book,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                  ],
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
                          onTap: isCurrent
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
                              fillColor: isCurrent
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
                              isCurrent
                                  ? 'Current'
                                  : (endDate == null
                                  ? 'Select'
                                  : DateFormat('yMd').format(endDate!)),
                              style: TextStyle(
                                color: (endDate == null && !isCurrent)
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
                        value: isCurrent,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (v) {
                          setModalState(() {
                            isCurrent = v ?? false;
                            if (isCurrent) {
                              endDate = null;
                              endDateErrorText = null;
                            }
                          });
                        },
                      ),
                      const Text(
                        'I am currently studying here',
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
                      'Description / Achievements',
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
                            if (!isCurrent && endDate == null) {
                              endDateErrorText = 'Required';
                            } else if (!isCurrent &&
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

                        final newEdu = EducationModel(
                          institutionName: institutionController.text.trim(),
                          degree: selectedDegree!,
                          fieldOfStudy: isDiplomaOrAbove(selectedDegree)
                              ? fieldOfStudyController.text.trim()
                              : null,
                          description: descController.text.trim(),
                          startDate: startDate!,
                          endDate: endDate,
                          isCurrent: isCurrent,
                        );

                        Navigator.pop(context, newEdu);
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
                    child: const Text(
                      'Add Education',
                      style: TextStyle(
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
