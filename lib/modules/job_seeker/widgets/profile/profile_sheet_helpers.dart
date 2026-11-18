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
