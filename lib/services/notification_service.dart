import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_model.dart';
import '../modules/community/screens/incoming_call_screen.dart';
import '../modules/employer/screens/applicant_detail_screen.dart';
import '../modules/job_seeker/controllers/applied_jobs_controller.dart';
import '../modules/job_seeker/screens/my_jobs_screen.dart';
import 'employer_service.dart';
import 'push_service.dart';

class NotificationService {
  NotificationService._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Live unread count for the in-app Notification Bell badge.
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  /// Incremented whenever a new recruitment notification arrives or read state changes.
  static final ValueNotifier<int> refreshTrigger = ValueNotifier<int>(0);

  static RealtimeChannel? _recruitmentChannel;
  static String? _subscribedUserId;

  static const String oneSignalAppId = '16f92d86-ad69-4841-8a4f-b6c0cbb8f9f6';

  static bool _isInitialized = false;
  static String? _lastHandledCallID;
  static bool _isRetrySyncRunning = false;
  static const MethodChannel _incomingCallChannel = MethodChannel('incoming_call_bridge');
  static Map<String, dynamic>? _pendingIncomingCall;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(oneSignalAppId);

    _registerAuthStateListener();
    _registerPushSubscriptionObserver();
    _registerNotificationClickListener();
    _registerNativeIncomingCallBridge();

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
    _setupRecruitmentRealtimeForCurrentUser();
  }

  static void _registerAuthStateListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      syncPushTokenToCurrentUser();
      unawaited(_syncPushTokenWithRetry());
      _setupRecruitmentRealtimeForCurrentUser();
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

  static void _registerNativeIncomingCallBridge() {
    _incomingCallChannel.setMethodCallHandler((call) async {
      if (call.method != 'showIncomingCall') return;
      final arguments = Map<String, dynamic>.from(call.arguments as Map);
      await _openIncomingCallFromNotification(arguments);
    });

    unawaited(_consumeInitialIncomingCall());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_flushPendingIncomingCall());
    });
  }

  static Future<void> _consumeInitialIncomingCall() async {
    try {
      final initialCall = await _incomingCallChannel.invokeMethod<dynamic>('getInitialIncomingCall');
      if (initialCall is Map) {
        await _openIncomingCallFromNotification(Map<String, dynamic>.from(initialCall));
      }
    } catch (e) {
      debugPrint('No initial incoming call payload: $e');
    }
  }

  static Future<void> _flushPendingIncomingCall() async {
    final pending = _pendingIncomingCall;
    if (pending == null) return;
    _pendingIncomingCall = null;
    await _openIncomingCallFromNotification(pending);
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
    if (navigator == null) {
      _pendingIncomingCall = {
        'callID': resolvedCallID,
        'roomCode': resolvedRoomCode,
        'callerName': callerName,
        'callerProfilePic': callerProfilePic,
        'type': 'call',
      };
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_flushPendingIncomingCall());
      });
      return;
    }

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

  // =========================================================================
  // Recruitment Notifications (In-App Notification Center + Realtime + Tap Routing)
  // =========================================================================

  static void _setupRecruitmentRealtimeForCurrentUser() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _subscribedUserId = null;
      unreadCountNotifier.value = 0;
      if (_recruitmentChannel != null) {
        Supabase.instance.client.removeChannel(_recruitmentChannel!);
        _recruitmentChannel = null;
      }
      return;
    }

    if (_subscribedUserId == user.id && _recruitmentChannel != null) {
      unawaited(refreshUnreadCount());
      return;
    }

    if (_recruitmentChannel != null) {
      Supabase.instance.client.removeChannel(_recruitmentChannel!);
      _recruitmentChannel = null;
    }

    _subscribedUserId = user.id;
    unawaited(refreshUnreadCount());

    _recruitmentChannel = Supabase.instance.client
        .channel('recruitment_notifications_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Notification',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'userID',
            value: user.id,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isEmpty) return;

            final item = NotificationModel.fromJson(newRecord);
            unreadCountNotifier.value = unreadCountNotifier.value + 1;
            refreshTrigger.value = refreshTrigger.value + 1;
            AppliedJobsController.notifyChanged();

            unawaited(
              PushService.showRecruitmentLocalNotification(
                notificationId: item.notificationID,
                title: item.title,
                body: item.body,
                payloadData: {
                  'notificationID': item.notificationID,
                  'eventType': item.type,
                  'title': item.title,
                  'body': item.body,
                  'jobID': item.jobID ?? '',
                  'applicantID': item.applicantID ?? '',
                  'scheduleID': item.scheduleID ?? '',
                },
              ),
            );
          },
        )
        .subscribe();
  }

  /// Refreshes the unread count for the currently logged-in user.
  static Future<int> refreshUnreadCount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      unreadCountNotifier.value = 0;
      return 0;
    }

    try {
      final rows = await Supabase.instance.client
          .from('Notification')
          .select('notificationID')
          .eq('userID', user.id)
          .eq('isRead', false);

      final count = (rows as List).length;
      unreadCountNotifier.value = count;
      return count;
    } catch (e) {
      debugPrint('Fetch unread notification count error: $e');
      return unreadCountNotifier.value;
    }
  }

  /// Fetches recent notifications for the currently logged-in user.
  static Future<List<NotificationModel>> fetchNotifications({
    int limit = 60,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    try {
      final rows = await Supabase.instance.client
          .from('Notification')
          .select()
          .eq('userID', user.id)
          .order('createdAt', ascending: false)
          .limit(limit);

      final items = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(NotificationModel.fromJson)
          .toList();

      final unread = items.where((n) => !n.isRead).length;
      unreadCountNotifier.value = unread;
      return items;
    } catch (e) {
      debugPrint('Fetch notifications error: $e');
      return [];
    }
  }

  /// Marks a single notification as read.
  static Future<void> markAsRead(String notificationId) async {
    final cleanId = notificationId.trim();
    final user = Supabase.instance.client.auth.currentUser;
    if (cleanId.isEmpty || user == null) return;

    try {
      await Supabase.instance.client
          .from('Notification')
          .update({'isRead': true})
          .eq('notificationID', cleanId)
          .eq('userID', user.id);

      await refreshUnreadCount();
      refreshTrigger.value = refreshTrigger.value + 1;
    } catch (e) {
      debugPrint('Mark notification as read error: $e');
    }
  }

  /// Marks all notifications for the current user as read.
  static Future<void> markAllAsRead() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client
          .from('Notification')
          .update({'isRead': true})
          .eq('userID', user.id)
          .eq('isRead', false);

      unreadCountNotifier.value = 0;
      refreshTrigger.value = refreshTrigger.value + 1;
    } catch (e) {
      debugPrint('Mark all notifications as read error: $e');
    }
  }

  /// Deletes a single notification row.
  static Future<void> deleteNotification(String notificationId) async {
    final cleanId = notificationId.trim();
    final user = Supabase.instance.client.auth.currentUser;
    if (cleanId.isEmpty || user == null) return;

    try {
      await Supabase.instance.client
          .from('Notification')
          .delete()
          .eq('notificationID', cleanId)
          .eq('userID', user.id);

      await refreshUnreadCount();
      refreshTrigger.value = refreshTrigger.value + 1;
    } catch (e) {
      debugPrint('Delete notification error: $e');
    }
  }

  /// Navigates to the appropriate screen when a recruitment notification is tapped
  /// inside the app ([NotificationsScreen]).
  static Future<void> openRecruitmentNotification(
    BuildContext context,
    NotificationModel item,
  ) async {
    if (!item.isRead && item.notificationID.isNotEmpty) {
      unawaited(markAsRead(item.notificationID));
    }

    if (item.isEmployerEvent) {
      final applicantId = item.applicantID?.trim() ?? '';
      if (applicantId.isEmpty) return;

      final bundle = await EmployerService().getApplicantDetailBundle(
        applicantId,
      );
      if (!context.mounted) return;
      if (bundle == null) {
        // e.g. the candidate withdrew it (an old push banner was tapped)
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('This application is no longer available.')),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ApplicantDetailScreen(
            applicantData: bundle['applicantData'] as Map<String, dynamic>,
            jobTitle: bundle['jobTitle'] as String,
            jobStatus: bundle['jobStatus'] as String,
            jobId: bundle['jobId'] as String?,
            jobVacancies: bundle['jobVacancies'] as int?,
          ),
        ),
      );
    } else {
      AppliedJobsController.notifyChanged();
      final targetTab = item.isInterviewTabEvent ? 2 : 1;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MyJobsScreen(initialTabIndex: targetTab),
        ),
      );
    }
  }

  /// Navigates to the appropriate screen when a push/local notification banner is tapped.
  static Future<void> openRecruitmentNotificationFromPayload(
    Map<String, dynamic> data,
  ) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    if (Supabase.instance.client.auth.currentUser == null) return;

    final notifId = (data['notificationID'] ?? '').toString().trim();
    if (notifId.isNotEmpty) {
      unawaited(markAsRead(notifId));
    }

    final model = NotificationModel(
      notificationID: notifId,
      userID: Supabase.instance.client.auth.currentUser!.id,
      type: (data['eventType'] ?? data['type'] ?? 'recruitment_update')
          .toString(),
      title: (data['title'] ?? 'Recruitment Update').toString(),
      body: (data['body'] ?? '').toString(),
      jobID: (data['jobID'] ?? '').toString().trim().isEmpty
          ? null
          : data['jobID'].toString().trim(),
      applicantID: (data['applicantID'] ?? '').toString().trim().isEmpty
          ? null
          : data['applicantID'].toString().trim(),
      scheduleID: (data['scheduleID'] ?? '').toString().trim().isEmpty
          ? null
          : data['scheduleID'].toString().trim(),
      isRead: true,
      createdAt: DateTime.now(),
    );

    await openRecruitmentNotification(context, model);
  }
}
