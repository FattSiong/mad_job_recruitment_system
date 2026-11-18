
import 'package:flutter/material.dart';

import '../../../core/theme/app_button_styles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_input_decoration.dart';
import '../../../models/chat_room_model.dart';
import '../controllers/chat_list_controller.dart';
import '../widgets/chat_list_tile.dart';
import '../../../shared_widgets/page_title_header.dart';
import '../../../shared_widgets/state_message_card.dart';
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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: PageTitleHeader(
                title: 'Messages',
                subtitle: 'Chat, share files and call employers and job seekers.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: _buildSearchField(),
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
        decoration: filledInputDecoration(
          hint: 'Search chats',
          icon: Icons.search_rounded,
          fillColor: AppColors.surface,
          borderColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          suffixIcon: _controller.searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    _controller.setSearchQuery('');
                  },
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
    final Widget content;

    if (_controller.error != null && !_controller.hasRooms) {
      content = StateMessageCard(
        icon: Icons.cloud_off_rounded,
        color: AppColors.danger,
        title: 'Unable to load chats',
        message: _controller.error!,
        action: ElevatedButton.icon(
          onPressed: _controller.load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try Again'),
          style: AppButtonStyles.filled(),
        ),
      );
    } else if (!_controller.hasRooms) {
      content = const StateMessageCard(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No chats yet',
        message: 'Conversations with employers and job seekers will appear here.',
      );
    } else if (rooms.isEmpty) {
      content = const StateMessageCard(
        icon: Icons.search_off_rounded,
        color: AppColors.textMuted,
        title: 'No chats match your search',
        message: 'Try another name or keyword.',
      );
    } else {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _controller.load,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: rooms.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [content],
      ),
    );
  }
}
