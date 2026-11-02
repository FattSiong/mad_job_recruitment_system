import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../controllers/post_list_controller.dart';
import '../widgets/community_state_card.dart';
import '../widgets/create_post_prompt.dart';
import '../widgets/my_posts_summary.dart';
import '../widgets/post_list_view.dart';
import 'post_editor_screen.dart';
import 'saved_posts_screen.dart';

/// Community tab for job seekers and employers: the feed and the user's own posts.
class CommunityHubScreen extends StatefulWidget {
  final String currentUserID;

  const CommunityHubScreen({super.key, required this.currentUserID});

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen> {
  late final PostListController _feed =
      PostListController(mode: PostListMode.feed, currentUserID: widget.currentUserID)..load();
  late final PostListController _mine =
      PostListController(mode: PostListMode.mine, currentUserID: widget.currentUserID)..load();

  @override
  void dispose() {
    _feed.dispose();
    _mine.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PostEditorScreen(currentUserID: widget.currentUserID)),
    );
    if (saved == true) {
      _feed.load();
      _mine.load();
    }
  }

  Future<void> _openSaved() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SavedPostsScreen(currentUserID: widget.currentUserID)),
    );
    // Likes / saves may have changed there.
    _feed.load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: FloatingActionButton(
          heroTag: 'community-new-post',
          tooltip: 'New post',
          onPressed: _createPost,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.edit_rounded),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Community Hub',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Ask, share and learn with job seekers and employers.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      child: IconButton(
                        tooltip: 'Saved posts',
                        onPressed: _openSaved,
                        icon: const Icon(Icons.bookmarks_outlined, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const TabBar(
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textMuted,
                    labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    tabs: [
                      Tab(text: 'Feed'),
                      Tab(text: 'My Posts'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    PostListView(
                      controller: _feed,
                      onPostsChanged: _mine.load,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                      header: [CreatePostPrompt(onTap: _createPost)],
                      emptyState: const CommunityStateCard(
                        icon: Icons.forum_outlined,
                        title: 'No posts yet',
                        message: 'Be the first to start a conversation in the community.',
                      ),
                    ),
                    PostListView(
                      controller: _mine,
                      onPostsChanged: _feed.load,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                      header: [MyPostsSummary(controller: _mine)],
                      emptyState: CommunityStateCard(
                        icon: Icons.edit_note_rounded,
                        title: 'You haven\'t posted yet',
                        message: 'Your posts will appear here so you can edit or delete them.',
                        action: TextButton.icon(
                          onPressed: _createPost,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create a post'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
