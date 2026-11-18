import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The app's button looks, so every screen's buttons match.
class AppButtonStyles {
  AppButtonStyles._();

  static const EdgeInsetsGeometry _padding = EdgeInsets.symmetric(vertical: 15, horizontal: 18);

  /// Filled button with white text ([color]: e.g. green for Accept, red for Delete).
  static ButtonStyle filled({
    Color color = AppColors.primary,
    EdgeInsetsGeometry padding = _padding,
    double radius = 16,
    TextStyle? textStyle,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: padding,
      textStyle: textStyle,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    );
  }

  /// White outlined button in [color] (navy text with a light blue border by default).
  static ButtonStyle outlined({
    Color color = AppColors.primary,
    Color? borderColor,
    EdgeInsetsGeometry padding = _padding,
    double radius = 16,
    TextStyle? textStyle,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      backgroundColor: Colors.white,
      elevation: 0,
      padding: padding,
      textStyle: textStyle,
      side: BorderSide(color: borderColor ?? (color == AppColors.primary ? AppColors.borderActive : color)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    );
  }

  /// Grey outlined button for Cancel / Back.
  static ButtonStyle neutral({EdgeInsetsGeometry padding = _padding, double radius = 16}) =>
      outlined(color: AppColors.textDark, borderColor: AppColors.border, padding: padding, radius: radius);
}
