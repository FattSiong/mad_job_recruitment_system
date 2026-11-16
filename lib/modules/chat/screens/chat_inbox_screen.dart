
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/chat_room_model.dart';
import '../controllers/chat_list_controller.dart';
import '../widgets/chat_list_tile.dart';
import 'chat_room_screen.dart';

/// Chat list (inbox). Used as a tab body by the job seeker and employer
/// dashboards, so it has no Scaffold of its own.
class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final ChatListController _controller = ChatListController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.load();
    _controller.watchIncomingCalls();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Opens a chat, then reloads the list (read status and last message may have changed).
  Future<void> _openRoom(ChatRoomModel room) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(roomID: room.roomID, otherUser: room.otherUser),
      ),
    );
    if (mounted) _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Messages',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildSearchField(),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Search box above the chat list.
  Widget _buildSearchField() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => TextField(
        controller: _searchController,
        onChanged: _controller.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'Search chats',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
          suffixIcon: _controller.searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    _controller.setSearchQuery('');
                  },
                ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.3),
          ),
        ),
      ),
    );
  }

  /// Spinner, error, empty message or the list of chats.
  Widget _buildBody() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final rooms = _controller.visibleRooms;
    Widget content;

    if (_controller.error != null && !_controller.hasRooms) {
      content = _stateCard(
        icon: Icons.cloud_off_rounded,
        title: 'Unable to load chats',
        message: _controller.error!,
        color: AppColors.danger,
        action: TextButton.icon(
          onPressed: _controller.load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try Again'),
        ),
      );
    } else if (!_controller.hasRooms) {
      content = _stateCard(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No chats yet',
        message: 'Conversations with employers and job seekers will appear here.',
        color: AppColors.primary,
      );
    } else if (rooms.isEmpty) {
      content = _stateCard(
        icon: Icons.search_off_rounded,
        title: 'No chats match your search',
        message: 'Try another name or keyword.',
        color: AppColors.textMuted,
      );
    } else {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _controller.load,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: rooms.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final room = rooms[index];
            return ChatListTile(
              key: ValueKey(room.roomID),
              room: room,
              currentUserID: _controller.currentUserID,
              isBlocked: _controller.isBlocked(room.otherUser.userID),
              onTap: () => _openRoom(room),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _controller.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [content],
      ),
    );
  }

  /// Centered card for the error and empty states.
  Widget _stateCard({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
          if (action != null) ...[const SizedBox(height: 12), action],
        ],
      ),
    );
  }
}
