import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/post_filter.dart';
import '../../../shared_widgets/state_message_card.dart';
import '../controllers/post_list_controller.dart';
import '../widgets/my_posts_summary.dart';
import '../widgets/post_list_view.dart';
import 'post_editor_screen.dart';
import '../../../shared_widgets/plain_app_bar.dart';

/// The current user's own posts (opened from their avatar in Community Hub):
/// counts by status, drafts, and posts removed by an admin.
class MyPostsScreen extends StatefulWidget {
  final String currentUserID;

  const MyPostsScreen({super.key, required this.currentUserID});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  late final PostListController _controller =
      PostListController(mode: PostListMode.mine, currentUserID: widget.currentUserID)..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opens the post editor; reloads the list when a post was saved.
  Future<void> _createPost() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PostEditorScreen(currentUserID: widget.currentUserID)),
    );
    if (saved == true) _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PlainAppBar(title: 'My Posts'),
      floatingActionButton: FloatingActionButton(
        heroTag: 'my-posts-new-post',
        tooltip: 'New post',
        onPressed: _createPost,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.edit_rounded),
      ),
      body: SafeArea(
        top: false,
        child: PostListView(
          controller: _controller,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          header: [MyPostsSummary(controller: _controller)],
          filteredEmptyState: StateMessageCard(
            icon: Icons.inbox_outlined,
            title: 'Nothing here',
            message: 'None of your posts match this view.',
            action: TextButton(
              onPressed: () => _controller.setStatusFilter(MyPostsStatus.all),
              child: const Text('Show all my posts'),
            ),
          ),
          emptyState: StateMessageCard(
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
      ),
    );
  }
}
