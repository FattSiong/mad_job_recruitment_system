import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modules/community/screens/incoming_call_screen.dart';
import 'notification_service.dart';

/// Opens the ringing screen for an incoming call, once per call, from
/// wherever the call was noticed (FCM push, notification tap, or the chat
/// list's live listener).
class IncomingCallService {
  IncomingCallService._();

  static final Set<String> _handledCallIDs = {};

  /// [delay] gives the login screen (AuthGate) time to open the dashboard
  /// when the app was started by the notification.
  static Future<void> show({
    required String callID,
    required String roomCode,
    required String callerName,
    String? callerPhoto,
    Duration delay = Duration.zero,
    bool autoAccept = false, // "Answer" was tapped on the notification
  }) async {
    if (callID.isEmpty || roomCode.isEmpty) return;
    if (_handledCallIDs.contains(callID)) return;
    _handledCallIDs.add(callID);

    if (delay > Duration.zero) await Future.delayed(delay);

    // Wait (up to ~10 s) for login and the app's navigator.
    for (var i = 0; i < 20; i++) {
      if (Supabase.instance.client.auth.currentUser != null &&
          NotificationService.navigatorKey.currentState != null) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    final navigator = NotificationService.navigatorKey.currentState;
    if (navigator == null || Supabase.instance.client.auth.currentUser == null) {
      _handledCallIDs.remove(callID);
      return;
    }

    // The caller may already have hung up.
    try {
      final row = await Supabase.instance.client
          .from('Calls')
          .select('status')
          .eq('callID', callID)
          .maybeSingle();
      if (row?['status']?.toString() != 'ringing') return;
    } catch (e) {
      debugPrint('IncomingCallService: status check failed: $e');
      _handledCallIDs.remove(callID);
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callID: callID,
          roomCode: roomCode,
          callerName: callerName,
          callerProfilePic: (callerPhoto == null || callerPhoto.isEmpty) ? null : callerPhoto,
          autoAccept: autoAccept,
        ),
      ),
    );
  }
}
