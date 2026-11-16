import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _showUnreadOnly = false;
  bool _isOpeningItem = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    NotificationService.refreshTrigger.addListener(_onRealtimeRefresh);
  }

  @override
  void dispose() {
    NotificationService.refreshTrigger.removeListener(_onRealtimeRefresh);
    super.dispose();
  }

  void _onRealtimeRefresh() {
    if (!mounted) return;
    _loadNotifications(silent: true);
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }

    final items = await NotificationService.fetchNotifications();
    if (!mounted) return;

    setState(() {
      _notifications = items;
      _isLoading = false;
    });
  }

  Future<void> _handleMarkAllAsRead() async {
    final hasUnread = _notifications.any((n) => !n.isRead);
    if (!hasUnread) return;

    setState(() {
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });
    await NotificationService.markAllAsRead();
  }

  Future<void> _handleTapNotification(NotificationModel item) async {
    if (_isOpeningItem) return;
    setState(() {
      _isOpeningItem = true;
      _notifications = _notifications
          .map(
            (n) => n.notificationID == item.notificationID
                ? n.copyWith(isRead: true)
                : n,
          )
          .toList();
    });

    try {
      await NotificationService.openRecruitmentNotification(context, item);
      if (mounted) {
        await _loadNotifications(silent: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningItem = false);
      }
    }
  }

  Future<void> _handleDeleteNotification(NotificationModel item) async {
    setState(() {
      _notifications.removeWhere(
        (n) => n.notificationID == item.notificationID,
      );
    });
    await NotificationService.deleteNotification(item.notificationID);
  }

  List<NotificationModel> get _visibleNotifications {
    if (!_showUnreadOnly) return _notifications;
    return _notifications.where((n) => !n.isRead).toList();
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  Widget build(BuildContext context) {
    final visible = _visibleNotifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Color(0xFF1B2433),
          ),
        ),
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _handleMarkAllAsRead,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text(
                  'Mark all read',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF163B65),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Row(
              children: [
                _buildFilterPill(
                  label: 'All (${_notifications.length})',
                  selected: !_showUnreadOnly,
                  onTap: () => setState(() => _showUnreadOnly = false),
                ),
                const SizedBox(width: 10),
                _buildFilterPill(
                  label: 'Unread ($_unreadCount)',
                  selected: _showUnreadOnly,
                  onTap: () => setState(() => _showUnreadOnly = true),
                ),
                const Spacer(),
                if (_isOpeningItem)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5EAF2)),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF163B65)),
                  )
                : RefreshIndicator(
                    onRefresh: _loadNotifications,
                    color: const Color(0xFF163B65),
                    child: visible.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.62,
                                child: _buildEmptyState(),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            itemCount: visible.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = visible[index];
                              return _buildNotificationCard(item);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF163B65) : const Color(0xFFF0F4FA),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF526075),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF163B65).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 38,
                color: Color(0xFF163B65),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _showUnreadOnly
                  ? 'All caught up!'
                  : 'No recruitment notifications yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B2433),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _showUnreadOnly
                  ? 'You have read all your notifications.'
                  : 'Updates for job applications, interview schedules, video rooms, and offer letters will appear here automatically.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Color(0xFF687588),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel item) {
    final style = _styleForType(item.type);

    return Dismissible(
      key: ValueKey('notif_${item.notificationID}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _handleDeleteNotification(item),
      child: Material(
        color: item.isRead ? Colors.white : const Color(0xFFEEF5FF),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _handleTapNotification(item),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: item.isRead
                    ? const Color(0xFFE5EAF2)
                    : const Color(0xFFB7D4F8),
                width: item.isRead ? 1 : 1.4,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(style.icon, color: style.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: style.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              style.stageLabel,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: style.color,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatRelativeTime(item.createdAt),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7D899B),
                            ),
                          ),
                          if (!item.isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1D6FD8),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              item.isRead ? FontWeight.w700 : FontWeight.w800,
                          color: const Color(0xFF1B2433),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: Color(0xFF4B586B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _NotificationTypeStyle _styleForType(String type) {
    switch (type) {
      case 'new_application':
        return const _NotificationTypeStyle(
          icon: Icons.person_add_alt_1_rounded,
          color: Color(0xFF1D6FD8),
          stageLabel: 'STAGE 1 · NEW APPLICANT',
        );
      case 'interview_scheduled':
        return const _NotificationTypeStyle(
          icon: Icons.calendar_month_rounded,
          color: Color(0xFF6C47D6),
          stageLabel: 'STAGE 2 · SCHEDULING',
        );
      case 'interview_accepted':
        return const _NotificationTypeStyle(
          icon: Icons.event_available_rounded,
          color: Color(0xFF15803D),
          stageLabel: 'STAGE 2 · SLOT CONFIRMED',
        );
      case 'interview_declined':
        return const _NotificationTypeStyle(
          icon: Icons.update_rounded,
          color: Color(0xFFD97706),
          stageLabel: 'STAGE 2 · RESCHEDULE REQUEST',
        );
      case 'interview_live':
        return const _NotificationTypeStyle(
          icon: Icons.videocam_rounded,
          color: Color(0xFFDC2626),
          stageLabel: 'STAGE 3 · LIVE VIDEO ROOM',
        );
      case 'interview_completed':
        return const _NotificationTypeStyle(
          icon: Icons.fact_check_rounded,
          color: Color(0xFF0E7490),
          stageLabel: 'STAGE 3 · INTERVIEW DONE',
        );
      case 'offer_sent':
        return const _NotificationTypeStyle(
          icon: Icons.card_membership_rounded,
          color: Color(0xFF047857),
          stageLabel: 'STAGE 4 · OFFER LETTER',
        );
      case 'offer_accepted':
        return const _NotificationTypeStyle(
          icon: Icons.celebration_rounded,
          color: Color(0xFF15803D),
          stageLabel: 'STAGE 5 · OFFER ACCEPTED',
        );
      case 'offer_declined':
        return const _NotificationTypeStyle(
          icon: Icons.cancel_outlined,
          color: Color(0xFFB91C1C),
          stageLabel: 'STAGE 5 · OFFER DECLINED',
        );
      case 'application_rejected':
        return const _NotificationTypeStyle(
          icon: Icons.info_outline_rounded,
          color: Color(0xFF64748B),
          stageLabel: 'APPLICATION UPDATE',
        );
      case 'subscription_expiring':
        return const _NotificationTypeStyle(
          icon: Icons.workspace_premium_rounded,
          color: Color(0xFFD97706),
          stageLabel: 'PREMIUM PLAN',
        );
      default:
        return const _NotificationTypeStyle(
          icon: Icons.notifications_active_rounded,
          color: Color(0xFF163B65),
          stageLabel: 'RECRUITMENT UPDATE',
        );
    }
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final d = dateTime.day.toString().padLeft(2, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    return '$d/$m/${dateTime.year}';
  }
}

class _NotificationTypeStyle {
  final IconData icon;
  final Color color;
  final String stageLabel;

  const _NotificationTypeStyle({
    required this.icon,
    required this.color,
    required this.stageLabel,
  });
}
