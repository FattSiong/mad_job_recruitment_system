import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modules/chat/chat_navigation.dart';
import 'call_service.dart';
import 'incoming_call_service.dart';
import 'notification_service.dart';

/// Runs in a background isolate when a push arrives while the app is in the
/// background or closed.
/// - chat messages carry a "notification" part, so Android shows them itself;
/// - calls are data-only, so we show the full-screen ringing notification here.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  final type = message.data['type'];
  if (type == 'call') {
    await CallNotifications.showIncomingCall(message.data);
  } else if (type == 'call_cancel') {
    await CallNotifications.cancel(message.data['callID']?.toString());
  } else if (type == 'recruitment_event' && message.notification == null) {
    final title =
        (message.data['title'] ?? 'Recruitment Update').toString();
    final body = (message.data['body'] ?? '').toString();
    if (body.isNotEmpty) {
      await PushService.showRecruitmentLocalNotification(
        notificationId:
            (message.data['notificationID'] ?? message.messageId ?? '')
                .toString(),
        title: title,
        body: body,
        payloadData: message.data,
      );
    }
  }
}

/// Firebase Cloud Messaging for the app:
/// - saves this phone's FCM token for the logged-in user (UserDevice table)
/// - shows chat pushes while the app is open (Android hides them otherwise)
/// - rings for incoming calls (full-screen notification + ringing screen)
/// - opens the right chat / call when a notification is tapped
///
/// The pushes themselves are sent by the server (send-push Edge Function).
class PushService {
  PushService._();

  /// Android notification channel for chat; the server sends with the same id.
  static const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
    'chat_messages',
    'Chat messages',
    description: 'New messages from employers and job seekers',
    importance: Importance.high,
  );

  /// Android notification channel for recruitment pipeline events.
  static const AndroidNotificationChannel recruitmentChannel =
      AndroidNotificationChannel(
    'recruitment_updates',
    'Recruitment Updates',
    description: 'Application, interview, and offer letter updates',
    importance: Importance.high,
  );

  static final Set<String> _shownRecruitmentIds = <String>{};

  /// Set by ChatRoomScreen so we don't notify about the chat you're reading.
  static String? activeChatRoomID;

  static bool _initialized = false;
  static bool _available = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (e) {
      debugPrint('PushService: Firebase not available ($e)');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

    await CallNotifications.ensureInitialized(onTap: _handleNotificationTap);
    final androidPlugin = CallNotifications.plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(chatChannel);
    await androidPlugin?.createNotificationChannel(recruitmentChannel);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    FirebaseMessaging.onMessage.listen(_handleWhileOpen);
    FirebaseMessaging.onMessageOpenedApp.listen(_handlePushOpenedApp);
    messaging.onTokenRefresh.listen(_register);

    // App started by tapping a push notification (shown by Android).
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      // Give the login check (AuthGate) time to open the dashboard first.
      Future.delayed(
        const Duration(seconds: 3),
        () => _handlePushOpenedApp(initial),
      );
    }

    // App started from the ringing notification (tap, Answer, or full screen).
    final launch = await CallNotifications.plugin.getNotificationAppLaunchDetails();
    final launchResponse = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && launchResponse != null) {
      _handleNotificationTap(launchResponse, launchedApp: true);
    }

    // Save the token for whoever is logged in: now (saved login) and after
    // any later login. The auth stream may only replay its LAST event to a
    // late listener (e.g. tokenRefreshed), so don't rely on specific events.
    await syncToken();
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      final userId = state.session?.user.id;
      if (userId == null) {
        _syncedUserId = null;
      } else if (userId != _syncedUserId) {
        syncToken();
      }
    });
  }

  static String? _syncedUserId;

  // ---------------------------------------------------------------------
  // Token
  // ---------------------------------------------------------------------

  /// Saves this phone's token for the logged-in user.
  static Future<void> syncToken() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (!_available || userId == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('PushService: no FCM token (is Google Play services available?)');
        return;
      }
      if (await _register(token)) _syncedUserId = userId;
    } catch (e) {
      debugPrint('PushService: token sync failed: $e');
    }
  }

  /// Call before signing out, so this phone stops getting that user's pushes.
  static Future<void> unregisterCurrentDevice() async {
    _syncedUserId = null;
    if (!_available || Supabase.instance.client.auth.currentUser == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await Supabase.instance.client.rpc(
        'unregister_device_token',
        params: {'p_token': token},
      );
    } catch (e) {
      debugPrint('PushService: unregister failed: $e');
    }
  }

  static Future<bool> _register(String token) async {
    if (Supabase.instance.client.auth.currentUser == null) return false;
    try {
      await Supabase.instance.client.rpc(
        'register_device_token',
        params: {'p_token': token, 'p_platform': Platform.isIOS ? 'ios' : 'android'},
      );
      debugPrint('PushService: device token saved');
      return true;
    } catch (e) {
      // Usually means the push migration (register_device_token) wasn't run.
      debugPrint('PushService: saving token failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // Incoming pushes
  // ---------------------------------------------------------------------

  /// Push received while the app is open.
  static Future<void> _handleWhileOpen(RemoteMessage message) async {
    final data = message.data;
    switch (data['type']) {
      case 'call':
        // Ring (sound + notification) and open the ringing screen.
        await CallNotifications.showIncomingCall(data);
        _openCall(data);
        return;
      case 'call_cancel':
        await CallNotifications.cancel(data['callID']?.toString());
        return;
      case 'chat_message':
        if (data['roomID'] == activeChatRoomID) return; // already reading this chat
        final notification = message.notification;
        if (notification == null) return;
        await CallNotifications.plugin.show(
          (data['roomID'] ?? message.messageId ?? '').hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              chatChannel.id,
              chatChannel.name,
              channelDescription: chatChannel.description,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          payload: jsonEncode(data),
        );
        return;
      case 'recruitment_event':
        final notification = message.notification;
        final title =
            (data['title'] ?? notification?.title ?? 'Recruitment Update')
                .toString();
        final body = (data['body'] ?? notification?.body ?? '').toString();
        if (body.isEmpty) return;
        await showRecruitmentLocalNotification(
          notificationId:
              (data['notificationID'] ?? message.messageId ?? '').toString(),
          title: title,
          body: body,
          payloadData: data,
        );
        return;
    }
  }

  /// Displays a local Android banner for a recruitment event (used by both
  /// foreground FCM pushes and the real-time Notification table listener,
  /// deduplicating by [notificationId]).
  static Future<void> showRecruitmentLocalNotification({
    required String notificationId,
    required String title,
    required String body,
    required Map<String, dynamic> payloadData,
  }) async {
    final cleanId = notificationId.trim();
    if (cleanId.isNotEmpty) {
      if (_shownRecruitmentIds.contains(cleanId)) return;
      _shownRecruitmentIds.add(cleanId);
    }

    try {
      await CallNotifications.ensureInitialized(onTap: _handleNotificationTap);
      await CallNotifications.plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(recruitmentChannel);

      await CallNotifications.plugin.show(
        (cleanId.isNotEmpty ? cleanId : DateTime.now().toIso8601String())
            .hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            recruitmentChannel.id,
            recruitmentChannel.name,
            channelDescription: recruitmentChannel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode({
          'type': 'recruitment_event',
          ...payloadData,
        }),
      );
    } catch (e) {
      debugPrint('PushService: local recruitment banner error: $e');
    }
  }

  static void _handlePushOpenedApp(RemoteMessage message) {
    final data = message.data;
    if (data['type'] == 'recruitment_event') {
      NotificationService.openRecruitmentNotificationFromPayload(data);
    } else {
      _openChat(data);
    }
  }

  /// Tap on one of our local notifications (chat while open, recruitment update, or a call).
  static void _handleNotificationTap(NotificationResponse response, {bool launchedApp = false}) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
    } catch (_) {
      return;
    }

    if (data['type'] == 'call') {
      final callID = data['callID']?.toString();
      if (response.actionId == CallNotifications.declineActionId) {
        CallNotifications.cancel(callID);
        _declineWhenReady(callID);
        return;
      }
      _openCall(
        data,
        delay: launchedApp ? const Duration(seconds: 3) : Duration.zero,
        autoAccept: response.actionId == CallNotifications.answerActionId,
      );
    } else if (data['type'] == 'recruitment_event') {
      if (launchedApp) {
        Future.delayed(
          const Duration(seconds: 3),
          () => NotificationService.openRecruitmentNotificationFromPayload(data),
        );
      } else {
        NotificationService.openRecruitmentNotificationFromPayload(data);
      }
    } else {
      _openChat(data);
    }
  }

  static void _openCall(
    Map<String, dynamic> data, {
    Duration delay = Duration.zero,
    bool autoAccept = false,
  }) {
    IncomingCallService.show(
      callID: data['callID']?.toString() ?? '',
      roomCode: data['roomCode']?.toString() ?? '',
      callerName: data['callerName']?.toString() ?? 'Incoming call',
      callerPhoto: data['callerPhoto']?.toString(),
      delay: delay,
      autoAccept: autoAccept,
    );
  }

  /// "Decline" from the notification: the app may have just started, so
  /// wait for the saved login before updating the call.
  static Future<void> _declineWhenReady(String? callID) async {
    if (callID == null || callID.isEmpty) return;
    for (var i = 0; i < 20 && Supabase.instance.client.auth.currentUser == null; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await CallService().updateCallStatus(callID, 'declined');
  }

  static void _openChat(Map<String, dynamic> data) {
    if (data['type'] != 'chat_message') return;
    final senderID = data['senderID']?.toString();
    final context = NotificationService.navigatorKey.currentContext;
    if (senderID == null || context == null) return;
    if (Supabase.instance.client.auth.currentUser == null) return;
    openChatWith(context, senderID);
  }
}

/// The ringing notification for incoming calls. Works in the background
/// isolate too (no Supabase or UI needed).
class CallNotifications {
  CallNotifications._();

  static const String declineActionId = 'decline_call';
  static const String answerActionId = 'answer_call';

  static const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
    'incoming_calls',
    'Incoming calls',
    description: 'Rings when someone calls you',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> ensureInitialized({
    void Function(NotificationResponse response)? onTap,
  }) async {
    if (_ready && onTap == null) return;
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: onTap,
    );
    await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(callChannel);
    _ready = true;
  }

  static int _idFor(String callID) => callID.hashCode;

  static Future<void> showIncomingCall(Map<String, dynamic> data) async {
    final callID = data['callID']?.toString();
    if (callID == null || callID.isEmpty) return;
    await ensureInitialized();

    final callerName = data['callerName']?.toString() ?? 'Someone';
    await plugin.show(
      _idFor(callID),
      callerName,
      'Incoming voice call',
      NotificationDetails(
        android: AndroidNotificationDetails(
          callChannel.id,
          callChannel.name,
          channelDescription: callChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true, // shows over the lock screen
          ongoing: true,
          autoCancel: false,
          timeoutAfter: 45000, // stop ringing after 45 s
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT: keep ringing
          actions: const [
            AndroidNotificationAction(
              declineActionId,
              'Decline',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              answerActionId,
              'Answer',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: jsonEncode({
        'type': 'call',
        'callID': callID,
        'roomCode': data['roomCode']?.toString() ?? '',
        'callerName': callerName,
        'callerPhoto': data['callerPhoto']?.toString() ?? '',
      }),
    );
  }

  static Future<void> cancel(String? callID) async {
    if (callID == null || callID.isEmpty) return;
    await ensureInitialized();
    await plugin.cancel(_idFor(callID));
  }
}
