import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../shared_widgets/reset_password_screen.dart';
import 'notification_service.dart';

/// Opens "Set a new password" when the user taps the reset link in their email.
///
/// The link (myapp://reset-password) opens the app; supabase_flutter signs the
/// user in with a recovery session and sends [AuthChangeEvent.passwordRecovery].
class PasswordRecoveryService {
  PasswordRecoveryService._();

  /// Where the reset email link sends the user. Must also be listed in
  /// Supabase -> Authentication -> URL Configuration -> Redirect URLs.
  static const String redirectUrl = 'myapp://reset-password';

  /// Set when the link arrives before the start-up screen (AuthGate) has
  /// decided where to go; AuthGate then opens the reset screen itself.
  static bool pending = false;

  /// True once AuthGate has left the start-up screen.
  static bool appReady = false;

  static StreamSubscription<AuthState>? _subscription;

  static void initialize() {
    _subscription ??= Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event != AuthChangeEvent.passwordRecovery) return;
      if (!appReady) {
        pending = true; // AuthGate will open the screen
        return;
      }
      _openResetScreen();
    });
  }

  static void _openResetScreen() {
    final navigator = NotificationService.navigatorKey.currentState;
    if (navigator == null) {
      pending = true;
      return;
    }
    pending = false;
    navigator.push(MaterialPageRoute(builder: (_) => const ResetPasswordScreen()));
  }
}
