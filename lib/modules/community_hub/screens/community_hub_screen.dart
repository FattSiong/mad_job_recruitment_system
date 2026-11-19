import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared_widgets/page_title_header.dart';
import '../../../shared_widgets/state_message_card.dart';
import '../controllers/post_list_controller.dart';
import '../widgets/community_filter_bar.dart';
import '../widgets/create_post_prompt.dart';
import '../widgets/my_posts_avatar_button.dart';
import '../widgets/post_list_view.dart';
import 'my_posts_screen.dart';
import 'post_editor_screen.dart';
import 'saved_posts_screen.dart';

/// Community tab for job seekers and employers: the feed with search,
/// topics and filters. The user's avatar next to the search box opens
/// their own posts.
class CommunityHubScreen extends StatefulWidget {
  final String currentUserID;

  const CommunityHubScreen({super.key, required this.currentUserID});

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen> {
  late final PostListController _feed =
      PostListController(mode: PostListMode.feed, currentUserID: widget.currentUserID)..load();

  @override
  void dispose() {
    _feed.dispose();
    super.dispose();
  }

  /// Opens the post editor; reloads the feed when a post was saved.
  Future<void> _createPost() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PostEditorScreen(currentUserID: widget.currentUserID)),
    );
    if (saved == true) _feed.load();
  }

  /// Opens My Posts.
  Future<void> _openMyPosts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MyPostsScreen(currentUserID: widget.currentUserID)),
    );
    // Posts may have been edited, published or deleted there.
    _feed.load();
  }

  /// Opens Saved Posts.
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
    return Scaffold(
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: PageTitleHeader(
                title: 'Community Hub',
                subtitle: 'Ask, share and learn with job seekers and employers.',
                trailing: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: IconButton(
                    tooltip: 'Saved posts',
                    onPressed: _openSaved,
                    icon: const Icon(Icons.bookmarks_outlined, color: AppColors.primary),
                  ),
                ),
              ),
            ),
            CommunityFilterBar(
              controller: _feed,
              leading: ListenableBuilder(
                listenable: _feed,
                builder: (context, _) =>
                    MyPostsAvatarButton(user: _feed.currentUser, onTap: _openMyPosts),
              ),
            ),
            Expanded(
              child: PostListView(
                controller: _feed,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                header: [CreatePostPrompt(onTap: _createPost)],
                emptyState: const StateMessageCard(
                  icon: Icons.forum_outlined,
                  title: 'No posts yet',
                  message: 'Be the first to start a conversation in the community.',
                ),
                filteredEmptyState: StateMessageCard(
                  icon: Icons.search_off_rounded,
                  title: 'No matching posts',
                  message: 'Try another search or topic, or clear the filters.',
                  action: TextButton.icon(
                    onPressed: _feed.clearFilter,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Clear filters'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
