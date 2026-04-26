import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modules/community/screens/incoming_call_screen.dart';

class NotificationService {
  NotificationService._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const String _oneSignalAppId = '16f92d86-ad69-4841-8a4f-b6c0cbb8f9f6';

  static bool _isInitialized = false;
  static String? _lastHandledCallID;
  static bool _isRetrySyncRunning = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(_oneSignalAppId);

    _registerAuthStateListener();
    _registerPushSubscriptionObserver();
    _registerNotificationClickListener();

    // 👇 ADD THIS BLOCK to force popouts while the user is actively inside the app
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      // Prevent the default quiet behavior
      event.preventDefault(); 
      // Force the notification banner to display over the UI
      event.notification.display();
    });

    await OneSignal.Notifications.requestPermission(true);
    await syncPushTokenToCurrentUser();
    unawaited(_syncPushTokenWithRetry());
  }

  static void _registerAuthStateListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      syncPushTokenToCurrentUser();
      unawaited(_syncPushTokenWithRetry());
    });
  }

  static void _registerPushSubscriptionObserver() {
    OneSignal.User.pushSubscription.addObserver((state) {
      final token = state.current.id;
      debugPrint('OneSignal subscription update: id=${state.current.id}, optedIn=${state.current.optedIn}, token=$token');
      if (token != null && token.isNotEmpty) {
        syncPushTokenToCurrentUser();
      } else {
        unawaited(_syncPushTokenWithRetry());
      }
    });
  }

  static Future<void> _syncPushTokenWithRetry() async {
    if (_isRetrySyncRunning) return;

    _isRetrySyncRunning = true;
    try {
      for (int attempt = 1; attempt <= 8; attempt++) {
        await syncPushTokenToCurrentUser();

        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) return;

        final row = await Supabase.instance.client
            .from('User')
            .select('notification_token')
            .eq('userID', session.user.id)
            .maybeSingle();

        final savedToken = row?['notification_token']?.toString();
        if (savedToken != null && savedToken.isNotEmpty) {
          debugPrint('Token persisted in DB after attempt $attempt');
          return;
        }

        debugPrint('Token not yet saved, retrying... attempt $attempt');
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('Retry token sync failed: $e');
    } finally {
      _isRetrySyncRunning = false;
    }
  }

  static void _registerNotificationClickListener() {
    OneSignal.Notifications.addClickListener((event) async {
      final data = Map<String, dynamic>.from(event.notification.additionalData ?? <String, dynamic>{});
      if (data['type']?.toString() == 'call') {
        await _openIncomingCallFromNotification(data);
      }
    });
  }

  static Future<void> syncPushTokenToCurrentUser() async {
    final session = Supabase.instance.client.auth.currentSession;
    final token = OneSignal.User.pushSubscription.id;
    final optedIn = OneSignal.User.pushSubscription.optedIn;

    debugPrint('--- Token sync debug ---');
    debugPrint('Current session user: ${session?.user.id}');
    debugPrint('Current OneSignal subscription ID: $token');
    debugPrint('Current OneSignal optedIn: $optedIn');

    if (session == null) return;

    try {
      OneSignal.login(session.user.id);
      debugPrint('OneSignal login linked to user ${session.user.id}');
    } catch (e) {
      debugPrint('OneSignal login failed: $e');
    }

    if (token == null || token.isEmpty) return;

    try {
      await Supabase.instance.client.from('User').update({'notification_token': token}).eq('userID', session.user.id);
      debugPrint('OneSignal token synced for user ${session.user.id}');
    } catch (e) {
      debugPrint('Failed to sync OneSignal token: $e');
    }

    debugPrint('--- Token sync debug end ---');
  }

  static Future<void> _openIncomingCallFromNotification(Map<String, dynamic> data) async {
    final String? incomingCallID = data['callID']?.toString();
    final String? incomingRoomCode = data['roomCode']?.toString();
    String callerName = data['callerName']?.toString() ?? 'Incoming Caller';
    final String? callerProfilePic = data['callerProfilePic']?.toString();

    String? callID = incomingCallID;
    String? roomCode = incomingRoomCode;

    if (callID == null || roomCode == null) {
      final fallbackCall = await _findLatestRingingCall();
      if (fallbackCall == null) return;

      callID = fallbackCall['callID']?.toString();
      roomCode = fallbackCall['roomCode']?.toString();

      final fallbackCallerName = fallbackCall['callerName']?.toString();
      if (fallbackCallerName != null && fallbackCallerName.isNotEmpty) {
        callerName = fallbackCallerName;
      }
    }

    if (callID == null || roomCode == null) return;

    final resolvedCallID = callID;
    final resolvedRoomCode = roomCode;

    if (resolvedCallID.isEmpty || resolvedRoomCode.isEmpty) return;
    if (_lastHandledCallID == resolvedCallID) return;

    final callStatus = await Supabase.instance.client.from('Calls').select('status').eq('callID', resolvedCallID).maybeSingle();
    if (callStatus == null || callStatus['status']?.toString() != 'ringing') return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    _lastHandledCallID = resolvedCallID;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callID: resolvedCallID,
          roomCode: resolvedRoomCode,
          callerName: callerName,
          callerProfilePic: callerProfilePic,
        ),
      ),
    );
  }

  static Future<Map<String, dynamic>?> _findLatestRingingCall() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return null;

    final row = await Supabase.instance.client
        .from('Calls')
        .select('callID, roomCode, callerID')
        .eq('receiverID', session.user.id)
        .eq('status', 'ringing')
        .order('startedAt', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;

    final callerID = row['callerID']?.toString();
    String callerName = 'Incoming Caller';

    if (callerID != null && callerID.isNotEmpty) {
      final callerRow = await Supabase.instance.client
          .from('User')
          .select('username')
          .eq('userID', callerID)
          .maybeSingle();

      if (callerRow != null && callerRow['username'] != null) {
        callerName = callerRow['username'].toString();
      }
    }

    return {
      ...row,
      'callerName': callerName,
    };
  }
}
