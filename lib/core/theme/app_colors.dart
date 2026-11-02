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
  static const Color borderSoft = Color(0xFFD9E4F1);   // light blue outlines
  static const Color borderActive = Color(0xFFB8D1EE); // selected chips, outlined buttons
  static const Color overlay = Color(0x33000000);      // dim layer while saving
  static const Color shadow = Color(0x140F172A);       // soft shadow under floating bars
  static const Color shadowFaint = Color(0x0D0F172A);  // very light shadow (chat bubbles)
  static const Color progressTrack = Color(0xFFE8EEF6); // empty part of score bars
  static const Color cameraBackground = Color(0xFF0F2440); // behind the mock interview camera

  // Text
  static const Color textDark = Color(0xFF1B2433); // job seeker screens
  /// Only used by core/theme/app_text_styles.dart.
  static const Color textPrimary = Color(0xFF191C1F);
  static const Color textMuted = Color(0xFF687588);
  static const Color textHint = Color(0xFF9AA5B5);     // placeholder text in inputs

  // Disabled / inactive
  static const Color disabled = Color(0xFFD7E3F3);     // disabled button background
  static const Color iconDisabled = Color(0xFFB0B9C5); // disabled icons, steps not reached yet
  static const Color highlight = Color(0xFFFFE08A);    // "on" icon on a dark header (saved job)

  // Status
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFC77700);
  static const Color coral = Color(0xFFE27D60);       // info / attention accents
  static const Color teal = Color(0xFF1E8F8B);        // positive accents
  static const Color danger = Color(0xFFC24E4E);      // soft error text / icons
  static const Color dangerSoft = Color(0xFFFDECEC);  // soft error background

  // Application status (job seeker "Applied" tab, job details)
  static const Color statusPending = Color(0xFFE4A73B);
  static const Color statusScheduled = Color(0xFF4C6EF5);
  static const Color statusInterviewed = Color(0xFF7B61FF);
  static const Color statusAccepted = teal;
  static const Color statusRejected = coral;
  static const Color statusInactive = Color(0xFF9AA5B1);

  /// Header gradient used by most screens.
  static const LinearGradient headerGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Light blue background behind the AI Career Advisor chat.
  static const LinearGradient chatGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEAF2FC), Color(0xFFF8FAFD)],
  );

  /// Green / amber / red for a 0-100 score (mock interview, skill gap);
  /// grey when there is no score yet.
  static Color forScore(int? score) {
    if (score == null) return textMuted;
    if (score >= 75) return successGreen;
    if (score >= 50) return warning;
    return errorRed;
  }
}
