import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/call_service.dart';
import '../../../services/community_service.dart';
import 'active_chat_screen.dart';
import 'community_dashboard.dart';
import 'incoming_call_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String currentUserID;

  const ChatListScreen({super.key, required this.currentUserID});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final CommunityService _communityService = CommunityService();
  final CallService _callService = CallService();

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  RealtimeChannel? _messageSubscription;
  StreamSubscription? _incomingCallSubscription;
  String? _currentlyRingingCallID;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListener();
    _listenForCalls();
  }

  void _listenForCalls() {
    _incomingCallSubscription = _callService
        .listenForIncomingCalls(widget.currentUserID)
        .listen((calls) async {
      if (calls.isEmpty) return;

      final incomingCall = calls.first;
      if (_currentlyRingingCallID == incomingCall.callID) return;

      _currentlyRingingCallID = incomingCall.callID;

      String realCallerName = 'Unknown Caller';
      try {
        final callerData = await Supabase.instance.client
            .from('User')
            .select('name')
            .eq('userID', incomingCall.callerID)
            .maybeSingle();

        if (callerData != null && callerData['name'] != null) {
          realCallerName = callerData['name'];
        }
      } catch (e) {
        debugPrint('Could not fetch caller name: $e');
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(
            callID: incomingCall.callID,
            roomCode: incomingCall.roomCode,
            callerName: realCallerName,
          ),
        ),
      );
    });
  }

  void _setupRealtimeListener() {
    _messageSubscription = Supabase.instance.client
        .channel('public:Message')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'Message',
          callback: (payload) {
            if (mounted) {
              setState(() {});
            }
          },
        )
        .subscribe();
  }

  Future<void> _refreshChats() async {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageSubscription?.unsubscribe();
    _incomingCallSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F7FB),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Direct Messages',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2433),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildSearchField(),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshChats,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _communityService.getChatRooms(widget.currentUserID),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                        children: [
                          _buildMessageStateCard(
                            icon: Icons.error_outline_rounded,
                            title: 'Unable to load messages',
                            message:
                                'There was a problem loading your chats. Pull to refresh and try again.\n\n${snapshot.error}',
                            accentColor: const Color(0xFFC24E4E),
                            backgroundColor: const Color(0xFFFCE9E9),
                          ),
                        ],
                      );
                    }

                    final chatRooms = snapshot.data ?? [];
                    if (chatRooms.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                        children: [
                          _buildMessageStateCard(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'No active chats yet',
                            message:
                                'Once you start a conversation from the community, it will show up here.',
                            accentColor: const Color(0xFF163B65),
                            backgroundColor: Colors.white,
                          ),
                        ],
                      );
                    }

                    final filteredRooms = chatRooms.where((room) {
                      final isUser1 = room['user1_ID'] == widget.currentUserID;
                      final userMap = isUser1
                          ? (room['user2'] ?? {})
                          : (room['user1'] ?? {});

                      final otherUserName = (userMap['username'] ?? 'Unknown User')
                          .toString()
                          .toLowerCase();
                      final messageList = room['Message'] as List<dynamic>? ?? [];
                      final latestMessage = messageList.isNotEmpty
                          ? messageList[0]['content'].toString().toLowerCase()
                          : '';

                      return otherUserName.contains(_searchQuery) ||
                          latestMessage.contains(_searchQuery);
                    }).toList();

                    if (filteredRooms.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                        children: [
                          _buildMessageStateCard(
                            icon: Icons.search_off_rounded,
                            title: 'No messages match your search',
                            message:
                                'Try another name or keyword to find the conversation you need.',
                            accentColor: const Color(0xFF687588),
                            backgroundColor: Colors.white,
                          ),
                        ],
                      );
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      itemCount: filteredRooms.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final room = filteredRooms[index];
                        final isUser1 = room['user1_ID'] == widget.currentUserID;
                        final otherUserID =
                            isUser1 ? room['user2_ID'] : room['user1_ID'];
                        final otherUserMap = isUser1
                            ? (room['user2'] ?? {})
                            : (room['user1'] ?? {});

                        final otherUserName =
                            otherUserMap['username'] ?? 'Unknown User';
                        final otherUserRole = otherUserMap['role'] ?? 'Member';
                        final otherUserProfilePictureUrl =
                            otherUserMap['profilePictureURL']?.toString();

                        final messageList =
                            room['Message'] as List<dynamic>? ?? [];
                        final latestMessage = messageList.isNotEmpty
                            ? messageList[0]['content']
                            : 'Started a chat';
                        final sentAt = messageList.isNotEmpty
                            ? messageList[0]['sentAt']
                            : null;
                        final senderID = messageList.isNotEmpty
                            ? messageList[0]['senderID']
                            : null;
                        final isMessageRead = messageList.isNotEmpty
                            ? (messageList[0]['isRead'] as bool)
                            : true;
                        final unreadCount =
                            (room['unreadCount'] as num?)?.toInt() ?? 0;

                        final isUnread =
                            unreadCount > 0 ||
                            (!isMessageRead && senderID != widget.currentUserID);

                        return _buildChatCard(
                          roomID: room['roomID'],
                          otherUserID: otherUserID,
                          otherUserName: otherUserName.toString(),
                          otherUserRole: otherUserRole.toString(),
                          profilePictureUrl: otherUserProfilePictureUrl,
                          latestMessage: latestMessage.toString(),
                          sentAt: sentAt?.toString(),
                          isUnread: isUnread,
                          unreadCount: unreadCount,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchQuery = value.toLowerCase());
        },
        decoration: InputDecoration(
          hintText: 'Search Chat',
          hintStyle: const TextStyle(color: Color(0xFF9AA5B5)),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF687588),
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF687588),
                  ),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(
              color: Color(0xFF163B65),
              width: 1.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageStateCard({
    required IconData icon,
    required String title,
    required String message,
    required Color accentColor,
    required Color backgroundColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 34, color: accentColor),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF687588),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatCard({
    required String roomID,
    required String otherUserID,
    required String otherUserName,
    required String otherUserRole,
    required String? profilePictureUrl,
    required String latestMessage,
    required String? sentAt,
    required bool isUnread,
    required int unreadCount,
  }) {
    final avatarLetter = otherUserName.trim().isEmpty
        ? 'U'
        : otherUserName.trim().substring(0, 1).toUpperCase();
    final hasProfilePicture =
        profilePictureUrl != null && profilePictureUrl.trim().isNotEmpty;
    final unreadLabel = unreadCount > 99 ? '99+' : unreadCount.toString();

    return Material(
      color: isUnread ? const Color(0xFFF9FCFF) : Colors.white,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ActiveChatScreen(
                roomID: roomID,
                currentUserID: widget.currentUserID,
                otherUserName: otherUserName,
                otherUserID: otherUserID,
                otherUserProfilePictureUrl: profilePictureUrl,
              ),
            ),
          ).then((_) => _refreshChats());
        },
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCEBFB),
                  borderRadius: BorderRadius.circular(18),
                  image: hasProfilePicture
                      ? DecorationImage(
                          image: NetworkImage(profilePictureUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Center(
                  child: !hasProfilePicture
                      ? Text(
                          avatarLetter,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF163B65),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            otherUserName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B2433),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          getRelativeTime(sentAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: isUnread
                                ? const Color(0xFF163B65)
                                : const Color(0xFF9AA5B5),
                            fontWeight:
                                isUnread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildRoleBadge(otherUserRole),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1BAA5D),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      latestMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: isUnread
                            ? const Color(0xFF1B2433)
                            : const Color(0xFF687588),
                        fontWeight:
                            isUnread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (unreadCount > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 28),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1BAA5D),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: isUnread
                          ? const Color(0xFF163B65)
                          : const Color(0xFF9AA5B5),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role,
        style: const TextStyle(
          color: Color(0xFF687588),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
