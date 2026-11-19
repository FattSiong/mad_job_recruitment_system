import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_model.dart';
import '../modules/employer/screens/applicant_detail_screen.dart';
import '../modules/employer/screens/subscription_screen.dart';
import '../modules/job_seeker/controllers/applied_jobs_controller.dart';
import '../modules/job_seeker/screens/my_jobs_screen.dart';
import '../shared_widgets/notifications_screen.dart';
import 'employer_service.dart';
import 'push_service.dart';

/// In-app notifications (the bell): unread count, live updates and opening
/// a notification. Pushes to the phone (chat, calls, recruitment updates,
/// plan expiry) are sent by the send-push Edge Function over FCM and shown
/// by [PushService].
class NotificationService {
  NotificationService._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Live unread count for the in-app Notification Bell badge.
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  /// Incremented whenever a new recruitment notification arrives or read state changes.
  static final ValueNotifier<int> refreshTrigger = ValueNotifier<int>(0);

  static RealtimeChannel? _recruitmentChannel;
  static String? _subscribedUserId;

  static bool _isInitialized = false;

  /// Starts the live notification listener for whoever is logged in (and
  /// restarts it on login / logout). Call once at app start.
  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _setupRecruitmentRealtimeForCurrentUser();
    });
    _setupRecruitmentRealtimeForCurrentUser();
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

    if (item.type == 'subscription_expiring') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
      );
      return;
    }

    // Post, comment or job post removed by an admin: the whole message is
    // already in the list, and there is nothing to open.
    if (item.isModerationNotice) return;

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

    // Moderation notice from a push banner: show the bell list, where the
    // full message can be read.
    if (model.isModerationNotice) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
      return;
    }

    await openRecruitmentNotification(context, model);
  }
}
