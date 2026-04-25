import 'package:flutter/material.dart';
import '../../../services/community_service.dart';
import '../../../models/community_post_model.dart';
import 'community_dashboard.dart'; // We reuse the PostCard from your dashboard!

class SavedPostsScreen extends StatefulWidget {
  final String currentUserID;

  const SavedPostsScreen({Key? key, required this.currentUserID}) : super(key: key);

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final CommunityService _communityService = CommunityService();

  Future<void> _refresh() async => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Posts'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: FutureBuilder<List<CommunityPostModel>>(
        future: _communityService.getCommunityPosts(), // Fetch all posts
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No posts available."));
          }

          // FILTER: Only keep the posts where this user's ID is in the saved list!
          final savedPosts = snapshot.data!.where((post) {
            return post.isSavedBy(widget.currentUserID);
          }).toList();

          if (savedPosts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("You haven't saved any posts yet.", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: savedPosts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return PostCard(
                post: savedPosts[index],
                currentUserID: widget.currentUserID,
                onDelete: _refresh,
              );
            },
          );
        },
      ),
    );
  }
}