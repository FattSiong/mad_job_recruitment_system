import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data_load_exception.dart';

/// Thrown when an action needs a logged-in user but the session has ended
/// (signed out on another device, refresh token expired, etc.).
/// It is a [DataLoadException], so screens that already show load errors
/// display this message without extra code.
class SessionExpiredException extends DataLoadException {
  SessionExpiredException() : super('Your session has expired. Please log in again.');
}

class SessionHelper {
  SessionHelper._();

  static bool _manualSignOut = false;

  /// ID of the logged-in user, or null when signed out.
  static String? get currentUserId => Supabase.instance.client.auth.currentUser?.id;

  /// Email of the logged-in user, or null.
  static String? get currentEmail => Supabase.instance.client.auth.currentUser?.email;

  /// Calls [onEnded] when the user is signed out: by Logout ([wasManual] =
  /// true), on another device, or because the session expired. Cancel the
  /// returned subscription in dispose().
  static StreamSubscription<AuthState> onSessionEnded(void Function(bool wasManual) onEnded) {
    return Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (data.event == AuthChangeEvent.signedOut) onEnded(consumeManualSignOut());
      },
      onError: (Object e) => debugPrint('Auth state error: $e'),
    );
  }

  /// ID of the logged-in user, or throws [SessionExpiredException].
  static String requireUserId() {
    final id = Supabase.instance.client.auth.currentUser?.id;
    if (id == null) throw SessionExpiredException();
    return id;
  }

  /// Call just before the user taps Logout, so the dashboard doesn't show
  /// "session expired" for a sign-out the user asked for.
  static void markManualSignOut() => _manualSignOut = true;

  /// Returns true (once) if the last sign-out was started by the user.
  static bool consumeManualSignOut() {
    final wasManual = _manualSignOut;
    _manualSignOut = false;
    return wasManual;
  }
}
