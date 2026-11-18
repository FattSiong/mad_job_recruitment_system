import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';

// Shared bits for the profile bottom sheets and record cards.

/// Malaysian day/month/year, e.g. 18/11/2026.
final DateFormat _malaysianDate = DateFormat('dd/MM/yyyy');

/// A picked date as the user sees it in the profile sheets (dd/MM/yyyy).
String formatProfileDate(DateTime date) => _malaysianDate.format(date);

/// Date picker in the app's colours.
/// Calendar only: the typing mode follows the US month/day order, which
/// would clash with the dd/MM/yyyy shown in the sheets.
Future<DateTime?> pickProfileDate(BuildContext context, DateTime? initialDate) {
  return showDatePicker(
    context: context,
    initialDate: initialDate ?? DateTime.now(),
    firstDate: DateTime(1970),
    lastDate: DateTime(2100),
    initialEntryMode: DatePickerEntryMode.calendarOnly,
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      );
    },
  );
}

/// Style of the text boxes in the profile sheets.
InputDecoration profileSheetInputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
    filled: true,
    fillColor: Colors.grey.shade50,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
  );
}

/// "Jan 2024 - Present"
String formatProfileDateRange(DateTime start, DateTime? end, bool isCurrent) {
  final formatter = DateFormat('MMM yyyy');
  final startStr = formatter.format(start);
  final endStr = isCurrent ? 'Present' : (end != null ? formatter.format(end) : 'N/A');
  return '$startStr - $endStr';
}

/// Errors for the dates of an education / work record (null = fine).
/// With [noFuture] neither date may be after [today] (work already done).
({String? start, String? end}) validateProfileDates({
  required DateTime? start,
  required DateTime? end,
  required bool isCurrent,
  bool noFuture = false,
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  if (start == null) return (start: 'Required', end: null);

  final String? startError = noFuture && start.isAfter(day) ? 'Can\'t be in the future' : null;
  String? endError;
  if (!isCurrent) {
    if (end == null) {
      endError = 'Required';
    } else if (end.isBefore(start)) {
      endError = 'Invalid end date';
    } else if (noFuture && end.isAfter(day)) {
      endError = 'Can\'t be in the future';
    }
  }
  return (start: startError, end: endError);
}

/// Bottom sheet with a form: drag handle, [title], the [fields] and a full
/// width [submitLabel] button that calls [onSubmit] (which pops the sheet
/// with its result when everything is valid).
Future<T?> showProfileFormSheet<T>(
  BuildContext context, {
  required GlobalKey<FormState> formKey,
  required String title,
  required String submitLabel,
  required List<Widget> Function(StateSetter setSheetState) fields,
  required void Function(BuildContext sheetContext, StateSetter setSheetState) onSubmit,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
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
                    title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 24),
                  ...fields(setSheetState),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => onSubmit(sheetContext, setSheetState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      submitLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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

/// "Required" when the text box is empty.
String? requiredField(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;

/// Start date, end date and the "I'm still here" box of a profile sheet.
/// Ticking [isCurrent] clears and disables the end date.
class ProfileDateRangeFields extends StatelessWidget {
  final DateTime? start;
  final DateTime? end;
  final bool isCurrent;
  final String? startError;
  final String? endError;

  /// e.g. "I currently work here".
  final String currentLabel;
  final ValueChanged<DateTime> onStartPicked;
  final ValueChanged<DateTime> onEndPicked;
  final ValueChanged<bool> onCurrentChanged;

  const ProfileDateRangeFields({
    super.key,
    required this.start,
    required this.end,
    required this.isCurrent,
    required this.startError,
    required this.endError,
    required this.currentLabel,
    required this.onStartPicked,
    required this.onEndPicked,
    required this.onCurrentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _DateBox(label: 'Start Date*', date: start, error: startError, onPicked: onStartPicked),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateBox(
                label: 'End Date',
                date: end,
                error: endError,
                onPicked: onEndPicked,
                disabledText: isCurrent ? 'Present' : null,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (v) => onCurrentChanged(v ?? false),
            ),
            Text(currentLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}

/// One date box: opens the picker; red border and text when [error] is set.
/// With [disabledText] it is greyed out and shows that text instead.
class _DateBox extends StatelessWidget {
  final String label;
  final DateTime? date;
  final String? error;
  final ValueChanged<DateTime> onPicked;
  final String? disabledText;

  const _DateBox({
    required this.label,
    required this.date,
    required this.error,
    required this.onPicked,
    this.disabledText,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = disabledText != null;
    final hasError = error != null;
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return InkWell(
      onTap: disabled
          ? null
          : () async {
              final picked = await pickProfileDate(context, date);
              if (picked != null) onPicked(picked);
            },
      child: InputDecorator(
        decoration: profileSheetInputDecoration(label, Icons.calendar_today).copyWith(
          fillColor: disabled ? Colors.grey.shade200 : Colors.grey.shade50,
          errorText: error,
          enabledBorder: border(hasError ? AppColors.errorRed : Colors.grey.shade300),
          focusedBorder: border(hasError ? AppColors.errorRed : AppColors.primary, 1.5),
          errorBorder: border(AppColors.errorRed),
          focusedErrorBorder: border(AppColors.errorRed, 1.5),
        ),
        child: Text(
          disabledText ?? (date == null ? 'Select' : formatProfileDate(date!)),
          style: TextStyle(color: (date == null && !disabled) ? Colors.grey.shade600 : Colors.black87),
        ),
      ),
    );
  }
}
