import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modules/community/screens/incoming_call_screen.dart';

class NotificationService {
  NotificationService._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const String _oneSignalAppId = '595705d0-3319-4ced-90ab-22185bb761dc';

  static bool _isInitialized = false;
  static String? _lastHandledCallID;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(_oneSignalAppId);

    _registerAuthStateListener();
    _registerPushSubscriptionObserver();
    _registerNotificationClickListener();

    await OneSignal.Notifications.requestPermission(true);
    await syncPushTokenToCurrentUser();
  }

  static void _registerAuthStateListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      syncPushTokenToCurrentUser();
    });
  }

  static void _registerPushSubscriptionObserver() {
    OneSignal.User.pushSubscription.addObserver((state) {
      final token = state.current.id;
      if (token != null && token.isNotEmpty) {
        syncPushTokenToCurrentUser();
      }
    });
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

    if (session == null || token == null || token.isEmpty) return;

    try {
      await Supabase.instance.client.from('User').update({'notification_token': token}).eq('userID', session.user.id);
      debugPrint('OneSignal token synced for user ${session.user.id}');
    } catch (e) {
      debugPrint('Failed to sync OneSignal token: $e');
    }
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
