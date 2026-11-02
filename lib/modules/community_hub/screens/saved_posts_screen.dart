import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../controllers/post_list_controller.dart';
import '../widgets/community_state_card.dart';
import '../widgets/post_list_view.dart';

/// Posts the current user bookmarked.
class SavedPostsScreen extends StatefulWidget {
  final String currentUserID;

  const SavedPostsScreen({super.key, required this.currentUserID});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  late final PostListController _controller =
      PostListController(mode: PostListMode.saved, currentUserID: widget.currentUserID)..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Saved Posts',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark),
        ),
      ),
      body: SafeArea(
        top: false,
        child: PostListView(
          controller: _controller,
          emptyState: const CommunityStateCard(
            icon: Icons.bookmark_border_rounded,
            title: 'No saved posts',
            message: 'Tap Save on any post to keep it here for later.',
          ),
        ),
      ),
    );
  }
}
