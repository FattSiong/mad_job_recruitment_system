import 'package:flutter/material.dart';
import '../../../services/community_service.dart';
import '../../../models/community_post_model.dart';
import 'community_dashboard.dart'; // We import this to reuse your PostCard!

class MyPostsScreen extends StatefulWidget {
  final String currentUserID;

  const MyPostsScreen({Key? key, required this.currentUserID}) : super(key: key);

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final CommunityService _communityService = CommunityService();

  Future<void> _refresh() async => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Posts'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: FutureBuilder<List<CommunityPostModel>>(
        future: _communityService.getCommunityPosts(),
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

          // 👈 THE FILTER: Only keep posts created by the current user
          final myPosts = snapshot.data!.where((post) {
            return post.authorID.trim() == widget.currentUserID.trim();
          }).toList();

          // If the user hasn't posted anything yet
          if (myPosts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("You haven't created any posts yet.", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            );
          }

          // Display the filtered list
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: myPosts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return PostCard(
                post: myPosts[index],
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