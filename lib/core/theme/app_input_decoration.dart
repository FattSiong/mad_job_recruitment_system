import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The app's filled, rounded text box: light fill, thin grey border, navy
/// border while typing and red when [errorText] is set.
InputDecoration filledInputDecoration({
  String? hint,
  String? label,
  IconData? icon,
  Color iconColor = AppColors.textMuted,
  Widget? prefixIcon,
  BoxConstraints? prefixIconConstraints,
  Widget? suffixIcon,
  String? errorText,
  String? counterText,
  Color fillColor = AppColors.surfaceAlt,
  Color borderColor = AppColors.border,
  double radius = 16,
  EdgeInsetsGeometry? contentPadding,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    hintText: hint,
    labelText: label,
    prefixIcon: prefixIcon ?? (icon == null ? null : Icon(icon, color: iconColor)),
    prefixIconConstraints: prefixIconConstraints,
    suffixIcon: suffixIcon,
    errorText: errorText,
    counterText: counterText,
    filled: true,
    fillColor: fillColor,
    contentPadding: contentPadding,
    border: border(borderColor),
    enabledBorder: border(borderColor),
    focusedBorder: border(AppColors.primary, 1.5),
    errorBorder: border(AppColors.errorRed),
    focusedErrorBorder: border(AppColors.errorRed, 1.5),
  );
}
