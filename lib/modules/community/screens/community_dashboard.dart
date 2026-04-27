import 'package:flutter/material.dart';

// IMPORTANT: Replace these imports with your actual project paths
import '../../../services/community_service.dart';
import '../../../models/community_post_model.dart';
import 'active_chat_screen.dart';
import 'create_post_screen.dart';
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

const Color _communityInk = Color(0xFF172033);
const Color _communityPrimary = Color(0xFF1E4C8F);
const Color _communityAccent = Color(0xFF4C83D8);
const Color _communityMuted = Color(0xFF6B7890);
const Color _communitySoft = Color(0xFFEAF2FF);
const Color _communityBorder = Color(0xFFD5E2F3);
const Color _communityBackground = Color(0xFFF4F7FB);
const Color _communitySurface = Color(0xFFF8FBFF);

class _CommunityHeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CommunityHeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CommunityMetricCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFE9F1FB),
                Color(0xFFF4F7FB),
                Color(0xFFF8FAFD),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Community Hub',
                                  style: TextStyle(
                                    color: Color(0xFF1B2433),
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 6),
                              ],
                            ),
                          ),
                          _buildAppBarIcon(Icons.bookmarks_rounded, () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SavedPostsScreen(
                                  currentUserID: widget.currentUserID,
                                ),
                              ),
                            ).then((_) => _refreshFeed());
                          }),
                        ],
                      ),

                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const TabBar(
                          dividerColor: Colors.transparent,
                          indicator: BoxDecoration(
                            color: Color(0xFF163B65),
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: Colors.white,
                          unselectedLabelColor: Color(0xFF687588),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          tabs: [
                            Tab(text: 'Community Feed'),
                            Tab(text: 'My Posts'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    children: [
                      CommunityFeedTab(
                        key: UniqueKey(),
                        currentUserID: widget.currentUserID,
                        onPostCreated: _refreshFeed,
                      ),
                      MyPostsScreen(currentUserID: widget.currentUserID),
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

  Widget _buildAppBarIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: const Color(0xFF163B65), size: 22),
        ),
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

          if (posts.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                CreatePostHeaderWidget(
                  currentUserID: widget.currentUserID,
                  onPostCreated: widget.onPostCreated,
                ),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCEBFB),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_motion_rounded,
                          size: 34,
                          color: Color(0xFF163B65),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Start the feed',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1B2433),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Share your first thought, update, or question and give the community something to respond to.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Color(0xFF687588),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
      margin: const EdgeInsets.only(bottom: 24, top: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF8FBFF),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Start a conversation',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _openCreatePostScreen(context),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD9E4F1)),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFDCEBFB),
                    child: Icon(
                      Icons.edit,
                      color: Color(0xFF163B65),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'What do you want to share today?',
                      style: TextStyle(
                        color: Color(0xFF687588),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF163B65),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ComposerHintChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ComposerHintChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF687588)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF687588),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();

  late int _commentCount;
  late int _likeCount;
  late int _savedCount;
  late bool _isLiked;
  late bool _isSaved;
  Future<List<Map<String, dynamic>>>? _commentsFuture;
  final Set<String> _expandedThreads = <String>{};
  String? _activeReplyCommentID;
  StateSetter? _commentsSheetSetState;
  bool _isSubmittingComment = false;
  bool _isSubmittingReply = false;

  bool get _isDeletedPost =>
      widget.post.status.trim().toLowerCase() == 'deleted';

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likeCount;
    _savedCount = widget.post.savedCount;
    _commentCount = widget.post.commentCount;
    _isLiked = widget.post.isLikedBy(widget.currentUserID);
    _isSaved = widget.post.isSavedBy(widget.currentUserID);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _handleLike() async {
    if (_isDeletedPost) return;
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
    if (_isDeletedPost) return;
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

  void _refreshCommentSheet([VoidCallback? updates]) {
    if (!mounted) return;
    setState(() {
      updates?.call();
    });
    _commentsSheetSetState?.call(() {});
  }

  void _reloadCommentsSheet([VoidCallback? updates]) {
    _refreshCommentSheet(() {
      _commentsFuture = _communityService.getComments(widget.post.postID);
      updates?.call();
    });
  }

  Future<void> _openCommentSheet() async {
    if (_isDeletedPost) return;
    _commentsFuture = _communityService.getComments(widget.post.postID);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) {
          _commentsSheetSetState = modalSetState;
          return _buildCommentsSheet(context);
        },
      ),
    );
    _commentsSheetSetState = null;
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSubmittingComment) return;

    _refreshCommentSheet(() => _isSubmittingComment = true);
    try {
      await _communityService.addComment(
        postID: widget.post.postID,
        userID: widget.currentUserID,
        content: content,
      );
      _commentController.clear();
      _reloadCommentsSheet(() {
        _commentCount += 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add comment: $e')));
      }
    } finally {
      if (mounted) {
        _refreshCommentSheet(() => _isSubmittingComment = false);
      }
    }
  }

  Future<void> _submitReply(Map<String, dynamic> targetComment) async {
    final rawContent = _replyController.text.trim();
    if (rawContent.isEmpty || _isSubmittingReply) return;

    final targetCommentID = targetComment['commentID']?.toString() ?? '';
    final directParentCommentID = targetComment['parentCommentID']?.toString();
    final effectiveParentCommentID =
        (directParentCommentID != null && directParentCommentID.isNotEmpty)
            ? directParentCommentID
            : targetCommentID;
    final targetUsername =
        targetComment['User']?['username']?.toString().trim() ?? '';
    final content =
        targetUsername.isNotEmpty && !rawContent.startsWith('@$targetUsername ')
            ? '@$targetUsername $rawContent'
            : rawContent;

    _refreshCommentSheet(() => _isSubmittingReply = true);
    try {
      await _communityService.addComment(
        postID: widget.post.postID,
        userID: widget.currentUserID,
        content: content,
        parentCommentID: effectiveParentCommentID,
      );
      _replyController.clear();
      _reloadCommentsSheet(() {
        _activeReplyCommentID = null;
        _expandedThreads.add(effectiveParentCommentID);
        _commentCount += 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add reply: $e')));
      }
    } finally {
      if (mounted) {
        _refreshCommentSheet(() => _isSubmittingReply = false);
      }
    }
  }

  Future<void> _handlePostMenuSelection(String value) async {
    switch (value) {
      case 'edit':
        if (_isDeletedPost) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This post was removed by admin and can no longer be edited.',
                ),
              ),
            );
          }
          return;
        }
        final didUpdate = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => EditScreen(
              targetID: widget.post.postID,
              initialContent: widget.post.content,
              initialMediaURL: widget.post.mediaURL,
              currentUserID: widget.currentUserID,
              isPost: true,
            ),
          ),
        );
        if (didUpdate == true) {
          widget.onDelete();
        }
        break;
      case 'delete':
        _showDeleteConfirmationDialog(context, widget.post.postID);
        break;
      case 'report':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportScreen(
              targetID: widget.post.postID,
              currentUserID: widget.currentUserID,
              isPost: true,
            ),
          ),
        );
        break;
      case 'message':
        try {
          final roomID = await _communityService.getOrCreateChatRoom(
            widget.currentUserID,
            widget.post.authorID,
          );
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ActiveChatScreen(
                roomID: roomID,
                currentUserID: widget.currentUserID,
                otherUserName: widget.post.username,
                otherUserID: widget.post.authorID,
              ),
            ),
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Unable to open chat: $e')),
            );
          }
        }
        break;
    }
  }

  Future<void> _handleCommentMenuSelection(Map<String, dynamic> comment, String value) async {
    final commentID = comment['commentID']?.toString();
    if (commentID == null || commentID.isEmpty) return;

    switch (value) {
      case 'edit':
        final didUpdate = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => EditScreen(
              targetID: commentID,
              initialContent: comment['content']?.toString() ?? '',
              currentUserID: widget.currentUserID,
              isPost: false,
            ),
          ),
        );
        if (didUpdate == true && mounted) {
          _reloadCommentsSheet();
        }
        break;
      case 'delete':
        final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Delete Comment'),
            content: const Text('Are you sure you want to delete this comment?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (shouldDelete == true) {
          try {
            await _communityService.deleteComment(commentID);
            if (!mounted) return;
            _reloadCommentsSheet(() {
              _activeReplyCommentID = _activeReplyCommentID == commentID ? null : _activeReplyCommentID;
              _expandedThreads.remove(commentID);
              if (_commentCount > 0) {
                _commentCount -= 1;
              }
            });
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to delete comment: $e')),
              );
            }
          }
        }
        break;
      case 'report':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportScreen(
              targetID: commentID,
              currentUserID: widget.currentUserID,
              isPost: false,
            ),
          ),
        );
        break;
    }
  }

  Widget _buildMediaPreview() {
    final mediaUrl = widget.post.mediaURL;
    if (mediaUrl == null || mediaUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final isImage =
        mediaUrl.endsWith('.png') ||
        mediaUrl.endsWith('.jpg') ||
        mediaUrl.endsWith('.jpeg') ||
        mediaUrl.contains('image');

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          color: _communitySoft,
          child: isImage
              ? Image.network(
                  mediaUrl,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildMediaFallback(mediaUrl),
                )
              : _buildMediaFallback(mediaUrl),
        ),
      ),
    );
  }

  Widget _buildMediaFallback(String mediaUrl) {
    final fileName = mediaUrl.split('/').last.split('?').first;
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              mediaUrl.endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
              color: _communityPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _communityInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar({
    required String displayName,
    String? profilePictureUrl,
    required double radius,
    double? fontSize,
  }) {
    final trimmedName = displayName.trim();
    final avatarLetter =
        trimmedName.isEmpty ? 'U' : trimmedName.substring(0, 1).toUpperCase();
    final hasProfilePicture =
        profilePictureUrl != null && profilePictureUrl.trim().isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: _communitySoft,
      backgroundImage: hasProfilePicture ? NetworkImage(profilePictureUrl!) : null,
      child: hasProfilePicture
          ? null
          : Text(
              avatarLetter,
              style: TextStyle(
                color: _communityPrimary,
                fontWeight: FontWeight.w800,
                fontSize: fontSize ?? radius,
              ),
            ),
    );
  }

  Widget _buildCommentsSheet(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: _communityBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF163B65),
                  Color(0xFF27528D),
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                Container(
                  height: 5,
                  width: 52,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Comments',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _commentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: _communityPrimary,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading comments...',
                          style: TextStyle(
                            color: _communityMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _communityBorder),
                        ),
                        child: Text(
                          "Database Error:\n\n${snapshot.error}",
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: _communityBorder),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: _communitySoft,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 34,
                              color: _communityPrimary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'No comments yet',
                            style: TextStyle(
                              color: _communityInk,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Start the conversation with the first comment on this post.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _communityMuted,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final allComments = snapshot.data!;
                final topLevelComments =
                    allComments
                        .where((comment) {
                          final parentCommentID = comment['parentCommentID']?.toString();
                          return parentCommentID == null || parentCommentID.isEmpty;
                        })
                        .toList();
                final Map<String, List<Map<String, dynamic>>> repliesMap = {};

                for (final comment in allComments) {
                  final parentCommentID = comment['parentCommentID']?.toString();
                  if (parentCommentID != null && parentCommentID.isNotEmpty) {
                    repliesMap.putIfAbsent(parentCommentID, () => []).add(comment);
                  }
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  itemCount: topLevelComments.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 18),
                  itemBuilder: (context, index) {
                    return _buildCommentThread(
                      comment: topLevelComments[index],
                      repliesMap: repliesMap,
                      depth: 0,
                    );
                  },
                );
              },
            ),
          ),
          _buildCommentComposer(context),
        ],
      ),
    );
  }

  Widget _buildCommentThread({
    required Map<String, dynamic> comment,
    required Map<String, List<Map<String, dynamic>>> repliesMap,
    required int depth,
  }) {
    final commentID = comment['commentID']?.toString() ?? '';
    final replies = repliesMap[commentID] ?? [];
    final isExpanded = _expandedThreads.contains(commentID);
    final double indent = ((depth * 26.0).clamp(0.0, 78.0)) as double;

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentRow(
            comment,
            isReply: depth > 0,
          ),
          if (_activeReplyCommentID == commentID)
            Padding(
              padding: const EdgeInsets.only(left: 50, top: 12),
              child: _buildReplyComposer(comment),
            ),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 50, top: 10),
              child: InkWell(
                onTap: () => _refreshCommentSheet(() {
                  if (isExpanded) {
                    _expandedThreads.remove(commentID);
                  } else {
                    _expandedThreads.add(commentID);
                  }
                }),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _communityBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: _communityPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isExpanded
                            ? 'Hide replies'
                            : 'View replies (${replies.length})',
                        style: const TextStyle(
                          color: _communityPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (isExpanded && replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 50, top: 12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: _communityBorder.withValues(alpha: 0.9),
                      width: 2,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(left: 14, top: 4),
                child: Column(
                  children: replies
                      .map(
                        (reply) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildCommentThread(
                            comment: reply,
                            repliesMap: repliesMap,
                            depth: depth + 1,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentRow(
    Map<String, dynamic> comment, {
    required bool isReply,
  }) {
    final authorData = Map<String, dynamic>.from(comment['User'] ?? {});
    final authorName =
        authorData['username']?.toString().trim().isNotEmpty == true
            ? authorData['username'].toString().trim()
            : 'Unknown User';
    final authorRole = authorData['role']?.toString() ?? 'Member';
    final authorProfilePictureUrl = authorData['profilePictureURL']?.toString();
    final authorID = comment['userID']?.toString();
    final commentID = comment['commentID']?.toString() ?? '';
    final createdAt = getRelativeTime(comment['createdAt']?.toString());
    final content = comment['content']?.toString() ?? '';
    final isOwner = authorID == widget.currentUserID;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserAvatar(
          displayName: authorName,
          profilePictureUrl: authorProfilePictureUrl,
          radius: isReply ? 16 : 18,
          fontSize: isReply ? 13 : 14,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _communityBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _communityInk,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _communitySoft,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  authorRole,
                                  style: const TextStyle(
                                    color: _communityPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                createdAt,
                                style: const TextStyle(
                                  color: _communityMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleCommentMenuSelection(comment, value),
                      itemBuilder: (context) => [
                        if (isOwner)
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                        if (isOwner)
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        if (!isOwner)
                          const PopupMenuItem<String>(
                            value: 'report',
                            child: Text('Report'),
                          ),
                      ],
                      icon: const Icon(Icons.more_horiz_rounded, color: _communityMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: _communityInk,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    children: _buildCommentContentSpans(content),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    _refreshCommentSheet(() {
                      if (_activeReplyCommentID == commentID) {
                        _activeReplyCommentID = null;
                        _replyController.clear();
                      } else {
                        _activeReplyCommentID = commentID;
                        _replyController.clear();
                      }
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: _communityPrimary,
                  ),
                  icon: const Icon(Icons.reply_rounded, size: 16),
                  label: const Text(
                    'Reply',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<TextSpan> _buildCommentContentSpans(String content) {
    final trimmedContent = content.trimLeft();
    final mentionMatch = RegExp(r'^@\S+').firstMatch(trimmedContent);

    if (mentionMatch == null) {
      return [TextSpan(text: content)];
    }

    final mention = mentionMatch.group(0) ?? '';
    final remainingText = trimmedContent.substring(mention.length);

    return [
      TextSpan(
        text: '$mention ',
        style: const TextStyle(
          color: _communityPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      TextSpan(text: remainingText.trimLeft()),
    ];
  }

  Widget _buildReplyComposer(Map<String, dynamic> targetComment) {
    final targetUsername =
        targetComment['User']?['username']?.toString().trim() ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _communityBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: targetUsername.isNotEmpty
                    ? 'Reply to @$targetUsername...'
                    : 'Write a reply...',
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: _isSubmittingReply ? null : () => _submitReply(targetComment),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _communityPrimary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: _isSubmittingReply
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentComposer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: _communityBorder.withValues(alpha: 0.9)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: _communitySurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _communityBorder),
                ),
                child: TextField(
                  controller: _commentController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _isSubmittingComment ? null : _submitComment,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _communityPrimary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: _isSubmittingComment
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final postAuthorName = widget.post.username.trim().isNotEmpty
        ? widget.post.username.trim()
        : 'Unknown User';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _communityBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF163B65).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserAvatar(
                displayName: postAuthorName,
                profilePictureUrl: widget.post.profilePictureURL,
                radius: 24,
                fontSize: 18,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      postAuthorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _communityInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _communitySoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                      child: Text(
                        widget.post.role,
                        style: const TextStyle(
                          color: _communityPrimary,
                          fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          getRelativeTime(widget.post.createdAt.toIso8601String()),
                          style: const TextStyle(
                            color: _communityMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: _handlePostMenuSelection,
                itemBuilder: (context) => [
                  if (widget.post.authorID == widget.currentUserID && !_isDeletedPost)
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit post'),
                    ),
                  if (widget.post.authorID == widget.currentUserID)
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete post'),
                    ),
                  if (widget.post.authorID != widget.currentUserID && !_isDeletedPost)
                    const PopupMenuItem<String>(
                      value: 'message',
                      child: Text('Message author'),
                    ),
                  if (widget.post.authorID != widget.currentUserID && !_isDeletedPost)
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: Text('Report post'),
                    ),
                ],
                icon: const Icon(Icons.more_horiz_rounded, color: _communityMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.post.content,
            style: const TextStyle(
              color: _communityInk,
              fontSize: 15,
              height: 1.55,
            ),
          ),
          _buildMediaPreview(),
          if (_isDeletedPost) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.18),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFFB84444),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Removed by admin. This post is read-only now, but you can still delete it from your history.',
                      style: TextStyle(
                        color: Color(0xFF8E2C2C),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              _buildInteractionPill(
                _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                _likeCount.toString(),
                _isLiked ? Colors.redAccent : _communityMuted,
                _isDeletedPost ? () {} : _handleLike,
              ),
              const SizedBox(width: 10),
              _buildInteractionPill(
                Icons.chat_bubble_outline_rounded,
                _commentCount.toString(),
                _communityPrimary,
                _isDeletedPost ? () {} : _openCommentSheet,
              ),
              const SizedBox(width: 10),
              _buildInteractionPill(
                _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                _savedCount.toString(),
                _isSaved ? _communityPrimary : _communityMuted,
                _isDeletedPost ? () {} : _handleSave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
