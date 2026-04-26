import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

// IMPORTANT: Replace these imports with your actual project paths
import '../../../services/community_service.dart';
import '../../../models/community_post_model.dart';
import 'active_chat_screen.dart';
import 'chat_list_screen.dart';
import 'edit_screen.dart';
import 'report_screen.dart';
import 'saved_posts_screen.dart';
import 'my_posts_screen.dart';

// ------------------------------------------------------------------------
// Global Helper Function for Time Formatting
// ------------------------------------------------------------------------
String getRelativeTime(String? dateString) {
  if (dateString == null) return 'Just now';
  try {
    final DateTime postDate = DateTime.parse(dateString).toLocal();
    final Duration difference = DateTime.now().difference(postDate);
    if (difference.isNegative) return 'Just now';
    if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()}w ago';
    if (difference.inDays < 365) return '${(difference.inDays / 30).floor()}mo ago';
    return '${(difference.inDays / 365).floor()}y ago';
  } catch (e) {
    return 'Just now';
  }
}

// ========================================================================
// 1. MAIN DASHBOARD SCREEN
// ========================================================================
class CommunityDashboard extends StatefulWidget {
  final String currentUserID;
  const CommunityDashboard({super.key, required this.currentUserID});

  @override
  State<CommunityDashboard> createState() => _CommunityDashboardState();
}

class _CommunityDashboardState extends State<CommunityDashboard> {
  void _refreshFeed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE6E9FA), // Soft lavender/blue
            Color(0xFFD4E0F9), // Light blue
            Color(0xFFE2DDF5), // Soft purple tint
          ],
        ),
      ),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Community Hub',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            actions: [
              // The person icon has been removed from here
              _buildAppBarIcon(Icons.bookmarks_outlined, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SavedPostsScreen(currentUserID: widget.currentUserID)),
                ).then((_) => _refreshFeed());
              }),
              const SizedBox(width: 16),
            ],
            bottom: const TabBar(
              indicatorColor: Color(0xFF6B8BFE),
              labelColor: Color(0xFF6B8BFE),
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(icon: Icon(Icons.dynamic_feed), text: 'Posts'),
                Tab(icon: Icon(Icons.person_outline), text: 'My Posts'), // Changed from Messages to My Posts
              ],
            ),
          ),
          body: TabBarView(
            children: [
              CommunityFeedTab(key: UniqueKey(), currentUserID: widget.currentUserID, onPostCreated: _refreshFeed),
              // Replaced ChatListScreen with MyPostsScreen
              MyPostsScreen(currentUserID: widget.currentUserID),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.black87, size: 22),
      ),
    );
  }
}

// ========================================================================
// 2. COMMUNITY FEED TAB
// ========================================================================
class CommunityFeedTab extends StatefulWidget {
  final String currentUserID;
  final VoidCallback onPostCreated;
  const CommunityFeedTab({super.key, required this.currentUserID, required this.onPostCreated});

  @override
  State<CommunityFeedTab> createState() => _CommunityFeedTabState();
}

class _CommunityFeedTabState extends State<CommunityFeedTab> {
  final CommunityService _communityService = CommunityService();

  Future<void> _handleRefresh() async => setState(() {});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: FutureBuilder<List<CommunityPostModel>>(
        future: _communityService.getCommunityPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final posts = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: posts.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return CreatePostHeaderWidget(
                    currentUserID: widget.currentUserID,
                    onPostCreated: widget.onPostCreated
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PostCard(
                  post: posts[index - 1],
                  currentUserID: widget.currentUserID,
                  onDelete: _handleRefresh,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ========================================================================
// 3. CREATE POST HEADER TRIGGER WIDGET
// ========================================================================
class CreatePostHeaderWidget extends StatelessWidget {
  final String currentUserID;
  final VoidCallback onPostCreated;

  const CreatePostHeaderWidget({
    super.key,
    required this.currentUserID,
    required this.onPostCreated,
  });

  void _openCreatePostScreen(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => CreatePostScreen(currentUserID: currentUserID),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.05);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

          return FadeTransition(
            opacity: animation.drive(fadeTween),
            child: SlideTransition(
              position: animation.drive(tween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) => onPostCreated());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Added horizontal margins so it aligns perfectly with the post cards below it
      margin: const EdgeInsets.only(bottom: 24, top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      // The single input field button
      child: InkWell(
        onTap: () => _openCreatePostScreen(context),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.edit_square, color: Color(0xFF6B8BFE), size: 22),
              const SizedBox(width: 12),
              Text(
                  "What do you wanna post?",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15)
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================================================================
// 4. POST CARD WIDGET
// ========================================================================
class PostCard extends StatefulWidget {
  final CommunityPostModel post;
  final String currentUserID;
  final VoidCallback onDelete;

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
    _likeCount = widget.post.likeCount;
    _savedCount = widget.post.savedCount;
    _commentCount = widget.post.commentCount;
    _isLiked = widget.post.isLikedBy(widget.currentUserID);
    _isSaved = widget.post.isSavedBy(widget.currentUserID);
  }

  void _handleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    try {
      await _communityService.toggleLike(widget.post.postID, widget.currentUserID, !_isLiked);
    } catch (e) {
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _handleSave() async {
    final bool wasSaved = _isSaved;
    setState(() {
      _isSaved = !_isSaved;
      _savedCount += _isSaved ? 1 : -1;
    });
    try {
      await _communityService.toggleSave(widget.post.postID, widget.currentUserID, wasSaved);
    } catch (e) {
      setState(() {
        _isSaved = wasSaved;
        _savedCount += _isSaved ? 1 : -1;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save post: $e')));
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context, String postID) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await _communityService.deletePost(postID);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted successfully.')));
                    widget.onDelete();
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInteractionPill(IconData icon, String count, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(24)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            if (count.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(count, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String timeAgo = getRelativeTime(widget.post.createdAt.toIso8601String());
    final String currentUID = widget.currentUserID.trim();
    final String creatorID = widget.post.authorID.trim();

    // Check if the post is deleted
    final bool isDeleted = widget.post.status.trim().toLowerCase() == 'deleted';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    if (currentUID == creatorID) return;
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),
                            Container(height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                            const SizedBox(height: 20),
                            CircleAvatar(radius: 36, backgroundColor: Colors.blueAccent.withValues(alpha: 0.1), child: const Icon(Icons.person, color: Colors.blueAccent, size: 40)),
                            const SizedBox(height: 12),
                            Text(widget.post.username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(widget.post.role, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  try {
                                    String roomID = await _communityService.getOrCreateChatRoom(currentUID, creatorID);
                                    if (context.mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => ActiveChatScreen(roomID: roomID, currentUserID: currentUID, otherUserName: widget.post.username, otherUserID: creatorID)),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                  }
                                },
                                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                                label: const Text('Contact', style: TextStyle(color: Colors.white, fontSize: 16)),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B8BFE), minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey[200],
                    child: const Icon(Icons.person, color: Colors.grey, size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.post.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 2),
                      Text('${widget.post.role} • $timeAgo', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),

                // --- iPhone Styled 3-Dot Menu ---
                // The menu button is ALWAYS visible now, but the items change.
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  color: const Color(0xFFF9F9F9).withValues(alpha: 0.95),
                  elevation: 8,
                  offset: const Offset(0, 40),
                  onSelected: (value) async {
                    if (value == 'report') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ReportScreen(targetID: widget.post.postID, currentUserID: widget.currentUserID, isPost: true)));
                    } else if (value == 'delete') {
                      _showDeleteConfirmationDialog(context, widget.post.postID);
                    } else if (value == 'edit') {
                      bool? wasEdited = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditScreen(targetID: widget.post.postID, initialContent: widget.post.content, initialMediaURL: widget.post.mediaURL, currentUserID: widget.currentUserID, isPost: true)));
                      if (wasEdited == true) widget.onDelete();
                    }
                  },
                  itemBuilder: (BuildContext context) => [

                    // 👇 RULE 1: If the post is deleted -> Show ONLY Delete
                    if (isDeleted) ...[
                      const PopupMenuItem<String>(
                          value: 'delete',
                          height: 48,
                          child: Row(children: [Icon(Icons.remove_circle_outline, color: Colors.red, size: 22), SizedBox(width: 12), Text('Delete Post', style: TextStyle(color: Colors.red, fontSize: 16))])
                      ),
                    ]

                    // 👇 RULE 2: If it's your post (and not deleted) -> Show Edit and Delete
                    else if (currentUID == creatorID) ...[
                      const PopupMenuItem<String>(
                          value: 'edit',
                          height: 48,
                          child: Row(children: [Icon(Icons.edit_outlined, color: Colors.black87, size: 22), SizedBox(width: 12), Text('Edit Post', style: TextStyle(color: Colors.black87, fontSize: 16))])
                      ),
                      const PopupMenuDivider(height: 0),
                      const PopupMenuItem<String>(
                          value: 'delete',
                          height: 48,
                          child: Row(children: [Icon(Icons.remove_circle_outline, color: Colors.red, size: 22), SizedBox(width: 12), Text('Delete Post', style: TextStyle(color: Colors.red, fontSize: 16))])
                      ),
                    ]

                    // 👇 RULE 3: If it's someone else's post (and not deleted) -> Show Report only
                    else ...[
                        const PopupMenuItem<String>(
                            value: 'report',
                            height: 48,
                            child: Row(children: [Icon(Icons.flag_outlined, color: Colors.black87, size: 22), SizedBox(width: 12), Text('Report Post', style: TextStyle(color: Colors.black87, fontSize: 16))])
                        ),
                      ],

                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Content Text
            Text(widget.post.content, style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87)),

            if (widget.post.mediaURL != null) ...[
              const SizedBox(height: 12),
              if (widget.post.mediaURL!.toLowerCase().contains('.pdf'))
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                  child: Row(
                    children: const [
                      Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text("Attached PDF Document", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                    ],
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    widget.post.mediaURL!,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
            ],

            const SizedBox(height: 16),

            // Footer Interaction Buttons
            Row(
              children: [
                _buildInteractionPill(_isLiked ? Icons.thumb_up : Icons.thumb_up_outlined, _likeCount.toString(), _isLiked ? Colors.blue : Colors.black87, _handleLike),
                const SizedBox(width: 12),
                _buildInteractionPill(Icons.chat_bubble_outline, _commentCount.toString(), Colors.black87, () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (context) => CommentSheet(
                      postID: widget.post.postID,
                      currentUserID: widget.currentUserID,
                      onCommentAdded: () => setState(() => _commentCount++),
                    ),
                  );
                }),
                const Spacer(),
                _buildInteractionPill(_isSaved ? Icons.bookmark : Icons.bookmark_border, "", _isSaved ? Colors.blue : Colors.black87, _handleSave),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================================================
// 5. COMMENT BOTTOM SHEET
// ========================================================================
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
  final TextEditingController _editController = TextEditingController(); // 👈 Added edit controller

  bool _isPosting = false;
  String? _activeReplyCommentID;
  String? _activeEditCommentID; // 👈 Tracks which comment is being edited
  final Set<String> _expandedThreads = {};

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    _postData(_commentController.text.trim(), null);
  }

  void _submitReply(String parentID) async {
    if (_replyController.text.trim().isEmpty) return;
    _postData(_replyController.text.trim(), parentID);
    setState(() => _expandedThreads.add(parentID));
  }

  Future<void> _postData(String content, String? parentID) async {
    setState(() => _isPosting = true);
    try {
      await _communityService.addComment(postID: widget.postID, userID: widget.currentUserID, content: content, parentCommentID: parentID);
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

  // 👈 NEW: Submits the inline edit changes to the database
  Future<void> _submitEdit(String commentID) async {
    final updatedContent = _editController.text.trim();
    if (updatedContent.isEmpty) return;

    setState(() => _isPosting = true);
    try {
      await _communityService.editComment(commentID, updatedContent);
      _activeEditCommentID = null;
      _editController.clear();
      setState(() {}); // Refresh list
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating comment: $e')));
    } finally {
      setState(() => _isPosting = false);
    }
  }

  void _showDeleteCommentConfirmationDialog(BuildContext context, String commentID) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete Comment'),
          content: const Text('Are you sure you want to delete this comment? This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _communityService.deleteComment(commentID);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment deleted successfully.')));
                    setState(() {});
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommentRow(Map<String, dynamic> comment, {bool isReply = false, String? repliedToUsername}) {
    final user = comment['User'] ?? {};
    final timeAgo = getRelativeTime(comment['createdAt']);
    final commentID = comment['commentID'];
    final String commentCreatorID = comment['userID'] ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[200],
            child: Icon(Icons.person, color: Colors.grey[500], size: 24)
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Header Row (Username, Time, Menu) ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(fontSize: 14, fontFamily: 'Roboto'),
                        children: [
                          TextSpan(
                              text: user['username'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)
                          ),
                          if (isReply && repliedToUsername != null) ...[
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFFF9500),
                                      borderRadius: BorderRadius.circular(3)
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 11,
                                  ),
                                ),
                              ),
                            ),
                            TextSpan(
                                text: repliedToUsername,
                                style: const TextStyle(color: Color(0xFF6B8BFE), fontWeight: FontWeight.bold)
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(timeAgo, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  const SizedBox(width: 4),

                  // --- iPhone Styled 3-Dot Menu ---
                  if (_activeEditCommentID != commentID) // Hide menu while editing
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      color: const Color(0xFFF9F9F9).withValues(alpha: 0.95),
                      elevation: 8,
                      offset: const Offset(0, 30),
                      onSelected: (value) async {
                        if (value == 'report') {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ReportScreen(targetID: commentID, currentUserID: widget.currentUserID, isPost: false)));
                        } else if (value == 'delete') {
                          _showDeleteCommentConfirmationDialog(context, commentID);
                        } else if (value == 'edit') {
                          // 👈 Trigger the inline edit state
                          setState(() {
                            _activeEditCommentID = commentID;
                            _editController.text = comment['content'] ?? '';
                            _activeReplyCommentID = null; // Close reply box if open
                          });
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        if (widget.currentUserID == commentCreatorID) ...[
                          const PopupMenuItem<String>(
                              value: 'edit',
                              height: 44,
                              child: Row(children: [Icon(Icons.edit_outlined, color: Colors.black87, size: 20), SizedBox(width: 12), Text('Edit Comment', style: TextStyle(color: Colors.black87, fontSize: 15))])
                          ),
                          const PopupMenuDivider(height: 0),
                          const PopupMenuItem<String>(
                              value: 'delete',
                              height: 44,
                              child: Row(children: [Icon(Icons.remove_circle_outline, color: Colors.red, size: 20), SizedBox(width: 12), Text('Delete Comment', style: TextStyle(color: Colors.red, fontSize: 15))])
                          ),
                          const PopupMenuDivider(height: 0),
                        ],
                        const PopupMenuItem<String>(
                            value: 'report',
                            height: 44,
                            child: Row(children: [Icon(Icons.flag_outlined, color: Colors.black87, size: 20), SizedBox(width: 12), Text('Report Comment', style: TextStyle(color: Colors.black87, fontSize: 15))])
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 4),

              // --- Conditional UI: Show Edit Box OR Text Content ---
              if (_activeEditCommentID == commentID)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
                        child: TextField(
                          controller: _editController,
                          autofocus: true,
                          maxLines: null,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                              hintText: 'Edit your comment...',
                              border: InputBorder.none,
                              isDense: true
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                              onPressed: () => setState(() { _activeEditCommentID = null; _editController.clear(); }),
                              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                              onPressed: _isPosting ? null : () => _submitEdit(commentID),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B8BFE), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 20)),
                              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                          ),
                        ],
                      )
                    ],
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comment['content'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
                    // --- Reply Button ---
                    if (!isReply)
                      InkWell(
                        onTap: () => setState(() {
                          _activeReplyCommentID = _activeReplyCommentID == commentID ? null : commentID;
                          _activeEditCommentID = null; // Close edit box if open
                        }),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0, right: 16.0),
                          child: Text('Reply', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
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
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 12), height: 5, width: 48, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _communityService.getComments(widget.postID),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(16.0), child: Text("Database Error:\n\n${snapshot.error}", style: const TextStyle(color: Colors.red)));
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text("No comments yet. Start the conversation!", style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                      ],
                    ),
                  );
                }

                final allComments = snapshot.data!;
                final topLevelComments = allComments.where((c) => c['parentCommentID'] == null).toList();
                final Map<String, List<Map<String, dynamic>>> repliesMap = {};

                for (var comment in allComments) {
                  if (comment['parentCommentID'] != null) {
                    repliesMap.putIfAbsent(comment['parentCommentID'], () => []).add(comment);
                  }
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: topLevelComments.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    final parentComment = topLevelComments[index];
                    final commentID = parentComment['commentID'];
                    final replies = repliesMap[commentID] ?? [];
                    final isExpanded = _expandedThreads.contains(commentID);
                    final String parentAuthorName = parentComment['User']?['username'] ?? 'Unknown';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCommentRow(parentComment, isReply: false),

                        // Active Reply Input Box
                        if (_activeReplyCommentID == commentID)
                          Padding(
                            padding: const EdgeInsets.only(left: 48.0, top: 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(radius: 12, backgroundColor: Color(0xFFE6E9FA), child: Icon(Icons.person, color: Color(0xFF6B8BFE), size: 16)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
                                        child: TextField(
                                          controller: _replyController,
                                          autofocus: true,
                                          style: const TextStyle(fontSize: 14),
                                          decoration: const InputDecoration(hintText: 'Add a reply...', hintStyle: TextStyle(fontSize: 14), border: InputBorder.none, isDense: true),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(onPressed: () => setState(() { _activeReplyCommentID = null; _replyController.clear(); }), child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                        onPressed: _isPosting ? null : () => _submitReply(commentID),
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B8BFE), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 20)),
                                        child: const Text('Reply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),

                        // "Hide/View Replies" Toggle
                        if (replies.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 48.0, top: 4.0),
                            child: InkWell(
                              onTap: () => setState(() { isExpanded ? _expandedThreads.remove(commentID) : _expandedThreads.add(commentID); }),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0.0),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('—', style: TextStyle(color: Color(0xFF6B8BFE), fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(width: 8),
                                      Text(isExpanded ? 'Hide replies' : 'View replies', style: const TextStyle(color: Color(0xFF6B8BFE), fontWeight: FontWeight.w600, fontSize: 13))
                                    ]
                                ),
                              ),
                            ),
                          ),

                        // Nested Reply List
                        if (isExpanded && replies.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 48.0, top: 8.0),
                            child: Container(
                              decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey.shade200, width: 2))),
                              padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                              child: Column(children: replies.map((reply) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: _buildCommentRow(reply, isReply: true, repliedToUsername: parentAuthorName)
                              )).toList()),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // --- Redesigned Bottom Input Area ---
          Container(
            padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                        )
                    )
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: _isPosting ? null : _submitComment,
                  borderRadius: BorderRadius.circular(24),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: _isPosting ? Colors.grey[300] : const Color(0xFF6B8BFE),
                    child: _isPosting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ========================================================================
// 6. CREATE POST SCREEN
// ========================================================================
class CreatePostScreen extends StatefulWidget {
  final String currentUserID;

  const CreatePostScreen({super.key, required this.currentUserID});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final CommunityService _communityService = CommunityService();

  bool _isLoading = false;
  File? _selectedFile;

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  void _previewDocument(BuildContext context) {
    if (_selectedFile == null) return;

    final filePath = _selectedFile!.path.toLowerCase();
    final isImage = filePath.endsWith('.jpg') || filePath.endsWith('.jpeg') || filePath.endsWith('.png');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Attachment Preview'),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.5,
            child: isImage
                ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_selectedFile!, fit: BoxFit.contain)
            )
                : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
                SizedBox(height: 16),
                Text('PDF Attached Successfully!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('(PDF preview requires physical device)', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Colors.black87))),
          ],
        );
      },
    );
  }

  void _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some text or an attachment.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? uploadedUrl;

      // 1. Upload File
      if (_selectedFile != null) {
        uploadedUrl = await _communityService.uploadPostMedia(_selectedFile!, widget.currentUserID);
        if (uploadedUrl == null) {
          throw Exception('Failed to upload attachment.');
        }
      }

      // 2. Save Post
      await _communityService.createCommunityPost(
        authorID: widget.currentUserID,
        content: content,
        mediaURL: uploadedUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post published successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Create Post', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isLoading
                ? const Center(child: Padding(padding: EdgeInsets.only(right: 16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                : TextButton(
              onPressed: _submitPost,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF6B8BFE).withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Text('Post', style: TextStyle(color: Color(0xFF6B8BFE), fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 20, backgroundColor: Colors.grey[200], child: const Icon(Icons.person, color: Colors.grey)),
                  const SizedBox(width: 12),
                  const Text('Posting to Community', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  autofocus: true,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(fontSize: 18, color: Colors.black87, height: 1.4),
                  decoration: InputDecoration(
                    hintText: 'What do you want to talk about?',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 18),
                    border: InputBorder.none,
                  ),
                ),
              ),

              if (_selectedFile != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(
                          _selectedFile!.path.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                          color: const Color(0xFF6B8BFE),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedFile!.path.split(Platform.pathSeparator).last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, color: Colors.black54),
                        onPressed: () => _previewDocument(context),
                        tooltip: 'Preview',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: () => setState(() => _selectedFile = null),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                ),

              const Divider(height: 1),

              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _pickDocument,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Row(
                          children: [
                            Icon(Icons.image_outlined, color: Color(0xFF6B8BFE)),
                            SizedBox(width: 8),
                            Text('Attach Media', style: TextStyle(color: Color(0xFF6B8BFE), fontWeight: FontWeight.w600))
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}