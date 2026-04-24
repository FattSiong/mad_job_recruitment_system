import 'package:flutter/material.dart';
// Note: Adjust these imports based on your actual folder structure
import 'active_chat_screen.dart';
import '../../../services/community_service.dart';
import 'create_post_screen.dart';

// ------------------------------------------------------------------------
// Global Helper Function for Time Formatting
// ------------------------------------------------------------------------
String getRelativeTime(String? dateString) {
  if (dateString == null) return 'Just now';

  try {
    final DateTime postDate = DateTime.parse(dateString).toLocal();
    final Duration difference = DateTime.now().difference(postDate);

    if (difference.isNegative) {
      return 'Just now';
    }

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else {
      return '${(difference.inDays / 365).floor()}y ago';
    }
  } catch (e) {
    return 'Just now';
  }
}

// ------------------------------------------------------------------------
// The Main Dashboard
// ------------------------------------------------------------------------
class CommunityDashboard extends StatefulWidget {
  final String currentUserID;

  const CommunityDashboard({super.key, required this.currentUserID});

  @override
  State<CommunityDashboard> createState() => _CommunityDashboardState();
}

class _CommunityDashboardState extends State<CommunityDashboard> {
  void _refreshFeed() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Community Hub'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dynamic_feed), text: 'Posts'),
              Tab(icon: Icon(Icons.forum), text: 'Messages'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            CommunityFeedTab(key: UniqueKey(), currentUserID: widget.currentUserID),
            ChatListScreen(currentUserID: widget.currentUserID),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreatePostScreen(currentUserID: widget.currentUserID),
              ),
            );
            _refreshFeed();
          },
          tooltip: 'Create New Post',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------
// TAB 1: The Community Feed Screen
// ------------------------------------------------------------------------
class CommunityFeedTab extends StatefulWidget {
  final String currentUserID;

  const CommunityFeedTab({super.key, required this.currentUserID});

  @override
  State<CommunityFeedTab> createState() => _CommunityFeedTabState();
}

class _CommunityFeedTabState extends State<CommunityFeedTab> {
  final CommunityService _communityService = CommunityService();

  Future<void> _handleRefresh() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _communityService.getCommunityPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 100),
                Center(child: Text("No posts yet. Be the first to share!")),
              ],
            );
          }

          final posts = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: posts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return PostCard(
                post: posts[index],
                currentUserID: widget.currentUserID,
                onDelete: () {
                  print("Refresh callback triggered!");
                  // This calls your _handleRefresh method which runs setState()
                  _handleRefresh();
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------------
// TAB 2: The Chat List Screen
// ------------------------------------------------------------------------
class ChatListScreen extends StatefulWidget {
  final String currentUserID;

  const ChatListScreen({super.key, required this.currentUserID});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final CommunityService _communityService = CommunityService();

  // --- NEW: Search State Variables ---
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
              controller: _searchController, // <-- Bind the controller
              onChanged: (value) {
                // <-- Update state when user types
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

                // --- NEW: Filter Logic ---
                final filteredRooms = chatRooms.where((room) {
                  final userMap = room['User'] ?? {};
                  final otherUserName = (userMap['fullName'] ?? userMap['username'] ?? 'Unknown User').toString().toLowerCase();

                  final messageList = room['Message'] as List<dynamic>? ?? [];
                  final latestMessage = messageList.isNotEmpty ? messageList[0]['content'].toString().toLowerCase() : '';

                  // Keep the room if the username OR the message contains the search query
                  return otherUserName.contains(_searchQuery) || latestMessage.contains(_searchQuery);
                }).toList();

                // Show a message if search yields no results
                if (filteredRooms.isEmpty) {
                  return const Center(
                      child: Text("No messages match your search.", style: TextStyle(color: Colors.grey))
                  );
                }

                return ListView.separated(
                  itemCount: filteredRooms.length, // <-- Use the filtered list length
                  separatorBuilder: (context, index) => Divider(color: Colors.grey[200], height: 1, indent: 76),
                  itemBuilder: (context, index) {
                    final room = filteredRooms[index]; // <-- Use the filtered list items

                    final userMap = room['User'] ?? {};
                    final otherUserName = userMap['fullName'] ?? userMap['username'] ?? 'Unknown User';
                    final otherUserRole = userMap['role'] ?? 'Member';

                    final messageList = room['Message'] as List<dynamic>? ?? [];
                    final latestMessage = messageList.isNotEmpty ? messageList[0]['content'] : 'Started a chat';
                    final isUnread = messageList.isNotEmpty ? !(messageList[0]['isRead'] as bool) : false;
                    final sentAt = messageList.isNotEmpty ? messageList[0]['sentAt'] : null;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),

                      // THE AVATAR (Green dot removed)
                      leading: const CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.blueAccent,
                        child: Icon(Icons.person, color: Colors.white, size: 30),
                      ),

                      // THE NAME
                      title: Text(
                        otherUserName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                      ),

                      // THE MESSAGE PREVIEW & ROLE
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            latestMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[800], fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            otherUserRole,
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey[400]),
                          ),
                        ],
                      ),

                      // THE TIME & UNREAD BADGE
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            getRelativeTime(sentAt),
                            style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
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
                        );
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

// ------------------------------------------------------------------------
// The Smart Post Card Widget
// ------------------------------------------------------------------------
class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String currentUserID;
  final VoidCallback onDelete; // Used to refresh the feed after a deletion

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserID,
    required this.onDelete,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final CommunityService _communityService = CommunityService();

  late int _commentCount;
  late int _likeCount;
  late int _savedCount;
  late bool _isLiked;
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    // Initialize interaction counts and states
    _likeCount = (widget.post['PostLike'] as List?)?.length ?? 0;
    _savedCount = (widget.post['PostSaved'] as List?)?.length ?? 0;
    _commentCount = (widget.post['PostComment'] as List?)?.length ?? 0;

    final likesList = widget.post['PostLike'] as List<dynamic>? ?? [];
    final savedList = widget.post['PostSaved'] as List<dynamic>? ?? [];

    _isLiked = likesList.any((like) => like['userID'].toString() == widget.currentUserID.toString());
    _isSaved = savedList.any((save) => save['userID'].toString() == widget.currentUserID.toString());
  }

  // --- Post Actions (Like/Save) ---
  void _handleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    try {
      await _communityService.toggleLike(widget.post['postID'], widget.currentUserID, !_isLiked);
    } catch (e) {
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update like: $e')));
    }
  }

  void _handleSave() async {
    setState(() {
      _isSaved = !_isSaved;
      _savedCount += _isSaved ? 1 : -1;
    });
    try {
      await _communityService.toggleSave(widget.post['postID'], widget.currentUserID, !_isSaved);
    } catch (e) {
      setState(() {
        _isSaved = !_isSaved;
        _savedCount += _isSaved ? 1 : -1;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update save: $e')));
    }
  }

  // --- Delete Logic ---
  void _showDeleteConfirmationDialog(BuildContext context, String postID) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close the dialog
                try {
                  await _communityService.deletePost(postID);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post deleted successfully.')),
                    );
                    widget.onDelete(); // Trigger refresh in parent feed
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50]),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // --- Report Logic ---
  void _showReportDialog(BuildContext context, String postID) {
    String selectedCategory = 'Spam';
    final TextEditingController detailsController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('Report Post'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        items: ['Spam', 'Inappropriate Content', 'Harassment', 'Other']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) => setDialogState(() => selectedCategory = val!),
                        decoration: const InputDecoration(labelText: 'Reason'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: detailsController,
                        decoration: const InputDecoration(
                          labelText: 'Additional Details (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                        setDialogState(() => isSubmitting = true);
                        try {
                          await _communityService.reportPost(
                            postID: postID,
                            reporterID: widget.currentUserID,
                            category: selectedCategory,
                            details: detailsController.text.trim(),
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Report submitted.'))
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to report: $e'))
                            );
                          }
                        } finally {
                          setDialogState(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[50]),
                      child: isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Submit Report', style: TextStyle(color: Colors.orange)),
                    ),
                  ],
                );
              }
          );
        }
    );
  }

  Widget _buildClickableAction(IconData icon, String count, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 6),
            Text(count, style: TextStyle(color: color, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.post['User'] ?? {};
    final String timeAgo = getRelativeTime(widget.post['createdAt']);

    final String postAuthorID = (widget.post['authorID'] ?? user['userID'] ?? '').toString();
    final String currentUID = widget.currentUserID.toString().trim();
    final String creatorID = postAuthorID.trim();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // --- NEW: Clickable Profile Picture ---
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    // Prevent the user from messaging themselves
                    if (currentUID == creatorID) return;

                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),
                            Container(
                              height: 4, width: 40,
                              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                            ),
                            const SizedBox(height: 20),

                            // Profile Info
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                              child: const Icon(Icons.person, color: Colors.blueAccent, size: 40),
                            ),
                            const SizedBox(height: 12),
                            Text(user['username'] ?? 'Unknown User', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(user['role'] ?? 'Member', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                            const SizedBox(height: 24),

                            // Contact Me Button
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  Navigator.pop(context); // Close bottom sheet

                                  try {
                                    // Generate or fetch Room ID
                                    String roomID = await _communityService.getOrCreateChatRoom(currentUID, creatorID);

                                    if (context.mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ActiveChatScreen(
                                            roomID: roomID,
                                            currentUserID: currentUID,
                                            otherUserName: user['username'] ?? 'Unknown User',
                                            otherUserID: creatorID,
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                    }
                                  }
                                },
                                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                                label: const Text('Contact Me', style: TextStyle(color: Colors.white, fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  minimumSize: const Size(double.infinity, 48),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[200],
                    child: const Icon(Icons.person, color: Colors.grey, size: 30),
                  ),
                ),
                // --- END Clickable Profile Picture ---

                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(user['username'] ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz, color: Colors.grey),
                            onSelected: (value) {
                              if (value == 'report') {
                                _showReportDialog(context, widget.post['postID']);
                              } else if (value == 'delete') {
                                _showDeleteConfirmationDialog(context, widget.post['postID']);
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              if (currentUID == creatorID && creatorID.isNotEmpty) // Logic check
                                const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      SizedBox(width: 8),
                                      Text('Delete Post', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),

                              const PopupMenuItem<String>(
                                value: 'report',
                                child: Row(
                                  children: [
                                    Icon(Icons.flag_outlined, color: Colors.orange, size: 20),
                                    SizedBox(width: 8),
                                    Text('Report Post', style: TextStyle(color: Colors.orange)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(user['role'] ?? 'Member', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(timeAgo, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_likeCount > 5)
              Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.deepOrange[400], size: 18),
                  const SizedBox(width: 4),
                  Text('Trending', style: TextStyle(color: Colors.deepOrange[400], fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            const SizedBox(height: 8),

            Text(widget.post['content'] ?? '', style: const TextStyle(fontSize: 15, height: 1.4)),
            const SizedBox(height: 16),
            Divider(color: Colors.grey[200], height: 1, thickness: 1),

            Row(
              children: [
                _buildClickableAction(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  _likeCount.toString(),
                  _isLiked ? Colors.red : Colors.grey[600]!,
                  _handleLike,
                ),
                const SizedBox(width: 16),

                _buildClickableAction(
                  Icons.chat_bubble_outline,
                  _commentCount.toString(),
                  Colors.grey[600]!,
                      () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (context) => CommentSheet(
                        postID: widget.post['postID'],
                        currentUserID: widget.currentUserID,
                        onCommentAdded: () {
                          setState(() {
                            _commentCount++;
                          });
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),

                _buildClickableAction(
                  Icons.share_outlined,
                  '0',
                  Colors.grey[600]!,
                      () {},
                ),

                const Spacer(),

                IconButton(
                  icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
                  color: _isSaved ? Colors.blue : Colors.grey[600],
                  onPressed: _handleSave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------
// The Comment Bottom Sheet
// ------------------------------------------------------------------------
class CommentSheet extends StatefulWidget {
  final String postID;
  final String currentUserID;
  final VoidCallback onCommentAdded;

  const CommentSheet({
    super.key,
    required this.postID,
    required this.currentUserID,
    required this.onCommentAdded,
  });

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final CommunityService _communityService = CommunityService();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();

  bool _isPosting = false;
  String? _activeReplyCommentID;

  final Set<String> _expandedThreads = {};

  void _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    _postData(_commentController.text.trim(), null);
  }

  void _submitReply(String parentID) async {
    if (_replyController.text.trim().isEmpty) return;
    _postData(_replyController.text.trim(), parentID);

    setState(() {
      _expandedThreads.add(parentID);
    });
  }

  Future<void> _postData(String content, String? parentID) async {
    setState(() => _isPosting = true);

    try {
      await _communityService.addComment(
        postID: widget.postID,
        userID: widget.currentUserID,
        content: content,
        parentCommentID: parentID,
      );

      _commentController.clear();
      _replyController.clear();
      _activeReplyCommentID = null;

      widget.onCommentAdded();
      setState(() {});

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isPosting = false);
    }
  }

  // --- NEW: The Comment Report Dialog ---
  void _showReportCommentDialog(BuildContext context, String commentID) {
    String selectedCategory = 'Spam';
    final TextEditingController detailsController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('Report Comment'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        items: ['Spam', 'Inappropriate Content', 'Harassment', 'Other']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) => setDialogState(() => selectedCategory = val!),
                        decoration: const InputDecoration(labelText: 'Reason'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: detailsController,
                        decoration: const InputDecoration(
                          labelText: 'Additional Details (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                        setDialogState(() => isSubmitting = true);
                        try {
                          await _communityService.reportComment(
                            commentID: commentID,
                            reporterID: widget.currentUserID,
                            category: selectedCategory,
                            details: detailsController.text.trim(),
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Comment reported successfully.'))
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to report: $e'))
                            );
                          }
                        } finally {
                          setDialogState(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50]),
                      child: isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Submit Report', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                );
              }
          );
        }
    );
  }

  Widget _buildCommentRow(Map<String, dynamic> comment, {bool isReply = false}) {
    final user = comment['User'] ?? {};
    final timeAgo = getRelativeTime(comment['createdAt']);
    final commentID = comment['commentID'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: isReply ? 12 : 16,
          backgroundColor: Colors.grey[200],
          child: Icon(Icons.person, color: Colors.grey, size: isReply ? 16 : 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(user['username'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isReply ? 12 : 13)),
                      const SizedBox(width: 8),
                      Text(timeAgo, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    ],
                  ),

                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (value) {
                      if (value == 'report') {
                        _showReportCommentDialog(context, commentID);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.flag_outlined, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Report Comment', style: TextStyle(color: Colors.red, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(comment['content'] ?? '', style: TextStyle(fontSize: isReply ? 13 : 14)),

              if (!isReply)
                InkWell(
                  onTap: () {
                    setState(() {
                      _activeReplyCommentID = _activeReplyCommentID == commentID ? null : commentID;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 4.0, right: 16.0),
                    child: Text(
                      'Reply',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 4,
            width: 40,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _communityService.getComments(widget.postID),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text("Database Error:\n\n${snapshot.error}", style: const TextStyle(color: Colors.red)),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No comments yet. Start the conversation!"));
                }

                final allComments = snapshot.data!;

                final topLevelComments = allComments.where((c) => c['parentCommentID'] == null).toList();

                final Map<String, List<Map<String, dynamic>>> repliesMap = {};
                for (var comment in allComments) {
                  if (comment['parentCommentID'] != null) {
                    final parentID = comment['parentCommentID'];
                    repliesMap.putIfAbsent(parentID, () => []).add(comment);
                  }
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: topLevelComments.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final parentComment = topLevelComments[index];
                    final commentID = parentComment['commentID'];
                    final replies = repliesMap[commentID] ?? [];
                    final isExpanded = _expandedThreads.contains(commentID);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCommentRow(parentComment, isReply: false),

                        if (_activeReplyCommentID == commentID)
                          Padding(
                            padding: const EdgeInsets.only(left: 44.0, top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.blueAccent,
                                      child: Icon(Icons.person, color: Colors.white, size: 16),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _replyController,
                                        autofocus: true,
                                        decoration: const InputDecoration(
                                          hintText: 'Add a reply...',
                                          hintStyle: TextStyle(fontSize: 14),
                                          isDense: true,
                                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black54)),
                                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _activeReplyCommentID = null;
                                          _replyController.clear();
                                        });
                                      },
                                      child: const Text('Cancel', style: TextStyle(color: Colors.black)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _isPosting ? null : () => _submitReply(commentID),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey[200],
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      child: const Text('Reply', style: TextStyle(color: Colors.black)),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),

                        if (replies.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 44.0, top: 4.0),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedThreads.remove(commentID);
                                  } else {
                                    _expandedThreads.add(commentID);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.blue, size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      isExpanded ? 'Hide replies' : '${replies.length} replies',
                                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        if (isExpanded && replies.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 44.0, top: 8.0),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(left: BorderSide(color: Colors.grey.shade300, width: 2)),
                              ),
                              padding: const EdgeInsets.only(left: 12.0),
                              child: Column(
                                children: replies.map((reply) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: _buildCommentRow(reply, isReply: true),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isPosting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.blue),
                  onPressed: _isPosting ? null : _submitComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}