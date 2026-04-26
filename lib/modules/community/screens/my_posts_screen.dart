import 'package:flutter/material.dart';
import '../../../models/community_post_model.dart';
import '../../../services/community_service.dart';
import 'community_dashboard.dart';

// Ensure this points to your PostCard

class MyPostsScreen extends StatefulWidget {
  final String currentUserID;

  const MyPostsScreen({Key? key, required this.currentUserID}) : super(key: key);

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final CommunityService _communityService = CommunityService();

  // This function is triggered when the user pulls down
  Future<void> _refresh() async => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Container(
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
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          title: const Text(
            'My Posts',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
        ),
        // 👇 WRAPPED THE BODY IN A REFRESH INDICATOR
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF6B8BFE), // Matches your theme blue
          child: FutureBuilder<List<CommunityPostModel>>(
            future: _communityService.getMyPostHistory(widget.currentUserID),
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

              final myPosts = snapshot.data ?? [];

              if (myPosts.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                // 👇 Added so you can always pull to refresh, even if the list is short
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: myPosts.length,
                itemBuilder: (context, index) {
                  final post = myPosts[index];

                  // Makes the check ignore uppercase letters and accidental spaces
                  final bool isDeleted = post.status.trim().toLowerCase() == 'deleted';

                  Widget postContent = PostCard(
                    post: post,
                    currentUserID: widget.currentUserID,
                    onDelete: _refresh,
                  );

                  // --- 🔴 DELETED POST UI 🔴 ---
                  if (isDeleted) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.redAccent, width: 2),
                            ),
                            child: Opacity(
                              opacity: 0.6,
                              child: postContent,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 40,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                              ),
                              child: const Text(
                                'DELETED',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 1.2
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // --- 🔵 NORMAL POST UI 🔵 ---
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: postContent,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    // 👇 Updated to CustomScrollView so the empty state is draggable/refreshable
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
                  child: Icon(Icons.article_outlined, size: 64, color: const Color(0xFF6B8BFE).withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 16),
                Text(
                    "You haven't created any posts yet.",
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