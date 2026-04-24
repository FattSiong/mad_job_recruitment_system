import 'package:flutter/material.dart';
import '../../../services/community_service.dart';
import 'active_chat_screen.dart';
import 'community_dashboard.dart'; // Imports getRelativeTime

// ------------------------------------------------------------------------
// The Chat List Screen
// ------------------------------------------------------------------------
class ChatListScreen extends StatefulWidget {
  final String currentUserID;

  const ChatListScreen({super.key, required this.currentUserID});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final CommunityService _communityService = CommunityService();

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search messages...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _communityService.getChatRooms(widget.currentUserID),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Database Error:\n${snapshot.error}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text("No active chats yet.", style: TextStyle(color: Colors.grey))
                  );
                }

                final chatRooms = snapshot.data!;

                final filteredRooms = chatRooms.where((room) {
                  final userMap = room['User'] ?? {};
                  final otherUserName = (userMap['fullName'] ?? userMap['username'] ?? 'Unknown User').toString().toLowerCase();

                  final messageList = room['Message'] as List<dynamic>? ?? [];
                  final latestMessage = messageList.isNotEmpty ? messageList[0]['content'].toString().toLowerCase() : '';

                  return otherUserName.contains(_searchQuery) || latestMessage.contains(_searchQuery);
                }).toList();

                if (filteredRooms.isEmpty) {
                  return const Center(
                      child: Text("No messages match your search.", style: TextStyle(color: Colors.grey))
                  );
                }

                return ListView.separated(
                  itemCount: filteredRooms.length,
                  separatorBuilder: (context, index) => Divider(color: Colors.grey[200], height: 1, indent: 76),
                  itemBuilder: (context, index) {
                    final room = filteredRooms[index];

                    final userMap = room['User'] ?? {};
                    final otherUserName = userMap['fullName'] ?? userMap['username'] ?? 'Unknown User';
                    final otherUserRole = userMap['role'] ?? 'Member';

                    final messageList = room['Message'] as List<dynamic>? ?? [];

                    // Extract message data safely
                    final latestMessage = messageList.isNotEmpty ? messageList[0]['content'] : 'Started a chat';
                    final sentAt = messageList.isNotEmpty ? messageList[0]['sentAt'] : null;
                    final senderID = messageList.isNotEmpty ? messageList[0]['senderID'] : null;
                    final isMessageRead = messageList.isNotEmpty ? (messageList[0]['isRead'] as bool) : true;

                    // 🛑 THE FIX: It is ONLY unread if it is unread AND you are not the sender!
                    final isUnread = !isMessageRead && (senderID != widget.currentUserID);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: const CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.blueAccent,
                        child: Icon(Icons.person, color: Colors.white, size: 30),
                      ),
                      title: Text(
                        otherUserName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            latestMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: isUnread ? Colors.black87 : Colors.grey[600],
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            otherUserRole,
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey[400]),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            getRelativeTime(sentAt),
                            style: TextStyle(fontSize: 12, color: isUnread ? Colors.blue : Colors.grey[500], fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
                          ),
                          const SizedBox(height: 6),
                          if (isUnread)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Color(0xFF1865F2), shape: BoxShape.circle),
                              child: const Text(
                                '1',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            )
                          else
                            const SizedBox(height: 24),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ActiveChatScreen(
                              roomID: room['roomID'],
                              currentUserID: widget.currentUserID,
                              otherUserName: otherUserName,
                              otherUserID: 'other_user_uuid',
                            ),
                          ),
                        ).then((_) {
                          // Refresh the chat list when coming back to clear the badge!
                          setState(() {});
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}