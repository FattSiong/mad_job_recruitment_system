import 'package:flutter/material.dart';
import '../../../services/community_service.dart';
import '../../../models/community_post_model.dart';
// Note: Make sure this import points to the file where your updated PostCard lives!
import 'community_dashboard.dart';

class SavedPostsScreen extends StatefulWidget {
  final String currentUserID;

  const SavedPostsScreen({Key? key, required this.currentUserID}) : super(key: key);

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final CommunityService _communityService = CommunityService();

  // This function is triggered when the user pulls down
  Future<void> _refresh() async => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Container(
      // The soft blue/purple gradient background matching the main feed
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE6E9FA),
            Color(0xFFD4E0F9),
            Color(0xFFE2DDF5),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Let gradient show through
        appBar: AppBar(
          title: const Text(
            'Saved Posts',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.black87),
          elevation: 0,
        ),
        // 👇 WRAPPED THE BODY IN A REFRESH INDICATOR
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF6B8BFE),
          child: FutureBuilder<List<CommunityPostModel>>(
            future: _communityService.getCommunityPosts(), // Fetch all posts
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                // Scrollable error state so you can pull to retry
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(child: Center(child: Text("Error: ${snapshot.error}"))),
                  ],
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState();
              }

              // FILTER: Only keep the posts where this user's ID is in the saved list!
              final savedPosts = snapshot.data!.where((post) {
                return post.isSavedBy(widget.currentUserID);
              }).toList();

              if (savedPosts.isEmpty) {
                return _buildEmptyState();
              }

              // Display the filtered list using the same spacing as the main feed
              return ListView.builder(
                // 👇 Added so you can always pull to refresh
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: savedPosts.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: PostCard(
                      post: savedPosts[index],
                      currentUserID: widget.currentUserID,
                      onDelete: _refresh,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // A softer, modernized empty state that allows scrolling to refresh
  Widget _buildEmptyState() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                      Icons.bookmark_border,
                      size: 64,
                      color: const Color(0xFF6B8BFE).withValues(alpha: 0.6)
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                    "You haven't saved any posts yet.",
                    style: TextStyle(color: Colors.grey[700], fontSize: 16, fontWeight: FontWeight.w500)
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}