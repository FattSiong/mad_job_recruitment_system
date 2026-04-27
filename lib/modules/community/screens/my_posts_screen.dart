import 'package:flutter/material.dart';

import '../../../models/community_post_model.dart';
import '../../../services/community_service.dart';
import 'community_dashboard.dart';

const Color _myPostsInk = Color(0xFF172033);
const Color _myPostsPrimary = Color(0xFF1E4C8F);
const Color _myPostsMuted = Color(0xFF6B7890);
const Color _myPostsSoft = Color(0xFFEAF2FF);
const Color _myPostsBorder = Color(0xFFD5E2F3);

class MyPostsScreen extends StatefulWidget {
  final String currentUserID;

  const MyPostsScreen({super.key, required this.currentUserID});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final CommunityService _communityService = CommunityService();

  Future<void> _refresh() async => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 14),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  color: _myPostsPrimary,
                  child: FutureBuilder<List<CommunityPostModel>>(
                    future: _communityService.getMyPostHistory(
                      widget.currentUserID,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: _myPostsPrimary,
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return _buildErrorState(snapshot.error.toString());
                      }

                      final myPosts = snapshot.data ?? [];

                      if (myPosts.isEmpty) {
                        return _buildEmptyState();
                      }

                      final activePosts = myPosts
                          .where(
                            (post) => post.status.trim().toLowerCase() != 'deleted',
                          )
                          .length;

                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                        itemCount: myPosts.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: _buildSummaryCard(
                                totalPosts: myPosts.length,
                                activePosts: activePosts,
                              ),
                            );
                          }

                          final post = myPosts[index - 1];
                          final isDeleted =
                              post.status.trim().toLowerCase() == 'deleted';

                          final postContent = PostCard(
                            post: post,
                            currentUserID: widget.currentUserID,
                            onDelete: _refresh,
                          );

                          if (isDeleted) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: Colors.redAccent.withValues(alpha: 0.55),
                                        width: 1.6,
                                      ),
                                    ),
                                    child: Opacity(
                                      opacity: 0.58,
                                      child: postContent,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: postContent,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required int totalPosts,
    required int activePosts,
  }) {
    final deletedPosts = totalPosts - activePosts;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _myPostsBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricTile(
              icon: Icons.grid_view_rounded,
              title: '$totalPosts',
              subtitle: 'Total Posts',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricTile(
              icon: Icons.check_circle_outline_rounded,
              title: '$activePosts',
              subtitle: 'Visible',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricTile(
              icon: Icons.archive_outlined,
              title: '$deletedPosts',
              subtitle: 'Deleted',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: _myPostsSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(icon, color: _myPostsPrimary, size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: _myPostsInk,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _myPostsMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _myPostsBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: _myPostsSoft,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        size: 38,
                        color: _myPostsPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      "You haven't created any posts yet.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _myPostsInk,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When you publish something in the community, it will show up here for quick review and editing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _myPostsMuted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _myPostsBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 38,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Unable to load your posts',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _myPostsInk,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _myPostsMuted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
