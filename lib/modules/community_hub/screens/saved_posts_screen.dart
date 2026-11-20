import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../controllers/post_list_controller.dart';
import '../../../shared_widgets/state_message_card.dart';
import '../widgets/post_list_view.dart';
import '../../../shared_widgets/plain_app_bar.dart';

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
      appBar: const PlainAppBar(title: 'Saved Posts'),
      body: SafeArea(
        top: false,
        child: PostListView(
          controller: _controller,
          emptyState: const StateMessageCard(
            icon: Icons.bookmark_border_rounded,
            title: 'No saved posts',
            message: 'Tap Save on any post to keep it here for later.',
          ),
        ),
      ),
    );
  }
}
