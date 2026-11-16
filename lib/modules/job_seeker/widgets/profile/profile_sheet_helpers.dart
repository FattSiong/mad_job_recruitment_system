import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';

// Shared bits for the profile bottom sheets and record cards.

Future<DateTime?> pickProfileDate(BuildContext context, DateTime? initialDate) {
  return showDatePicker(
    context: context,
    initialDate: initialDate ?? DateTime.now(),
    firstDate: DateTime(1970),
    lastDate: DateTime(2100),
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
