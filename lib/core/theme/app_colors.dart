import 'package:flutter/material.dart';

/// One place for the app's colours. Screens should use these instead of
/// redefining their own Color(0xFF...) constants.
class AppColors {
  AppColors._();

  // Brand (navy) – used across the job seeker module
  static const Color primary = Color(0xFF163B65);
  static const Color primaryLight = Color(0xFF335D8A); // gradient end
  static const Color primarySoft = Color(0xFFDCEBFB);  // chips, icon backgrounds

  // Surfaces
  static const Color background = Color(0xFFF4F7FB);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFF7F9FC);
  static const Color border = Color(0xFFE1E8F0);

  // Text
  static const Color textDark = Color(0xFF1B2433); // job seeker screens
  /// Shared with app_text_styles (other modules) – value unchanged.
  static const Color textPrimary = Color(0xFF191C1F);
  static const Color textMuted = Color(0xFF687588);

  // Status
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFC77700);

  /// Older bright blue, still used by the employer, community and admin screens.
  /// The job seeker module now uses [primary].
  static const Color primaryBlue = Color(0xFF0A66C2);
  static const Color backgroundLight = Color(0xFFF3F2EF);

  /// Header gradient used by most screens.
  static const LinearGradient headerGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
