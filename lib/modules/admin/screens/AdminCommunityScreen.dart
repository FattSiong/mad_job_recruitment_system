import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/community_post_model.dart';

// --- SHARED ADMIN STYLING ---
const Color _backgroundColor = Color(0xFFF4F7FB);
const Color _surfaceColor = Colors.white;
const Color _heroStart = Color(0xFF12343B); // Forest Green
const Color _heroEnd = Color(0xFF2A6B66);   // Teal Green
const Color _textPrimary = Color(0xFF1B2433);
const Color _textSecondary = Color(0xFF687588);
const Color _alertRed = Color(0xFFE15A4F);
const Color _selectedBg = Color(0xFFD9ECE8); // Teal highlight

class AdminCommunityScreen extends StatefulWidget {
  const AdminCommunityScreen({super.key});

  @override
  State<AdminCommunityScreen> createState() => _AdminCommunityScreenState();
}

class _AdminCommunityScreenState extends State<AdminCommunityScreen> {
  final supabase = Supabase.instance.client;
  String _activeTab = "Posts";

  // 🔥 REFRESH KEY: Incrementing this forces FutureBuilders to reload data
  int _refreshKey = 0;

  // 👉 Soft Delete Logic
  Future<void> _softDelete(String table, String idField, String id) async {
    try {
      // 1. Update the content status
      await supabase.from(table).update({'status': 'deleted'}).match({idField: id});

      // 2. Update the corresponding report status to 'deleted' as well
      String reportTable = (table == 'CommunityPost') ? 'ReportedPost' : 'ReportedComment';
      await supabase.from(reportTable).update({'status': 'deleted'}).match({idField: id});

      if (mounted) {
        setState(() {
          _refreshKey++; // 🔥 This is the "magic" that triggers the UI update
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Content removed successfully")),
        );
      }
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  void _showConfirm(String id, String preview, String table, String idField) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text("Soft Delete", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Confirm removal of this item?\n\nPreview: \"$preview\""),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              _softDelete(table, idField, id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _alertRed, elevation: 0),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: CustomScrollView(
        slivers: [
          // --- HERO HEADER ---
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_heroStart, _heroEnd]),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderChip(Icons.forum_outlined, "Community Moderation"),
                  const SizedBox(height: 20),
                  const Text("Manage Interaction", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  const Text("Review reported community posts and comments for safety.", style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
          ),

          // --- PILL TAB FILTERS ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildTabPill("Posts"),
                  const SizedBox(width: 12),
                  _buildTabPill("Comments"),
                ],
              ),
            ),
          ),

          // --- CONTENT LIST ---
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: _activeTab == "Posts" ? _buildPostList() : _buildCommentList(),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildTabPill(String label) {
    bool isSelected = _activeTab == label;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _selectedBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _heroEnd.withOpacity(0.2) : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? _heroStart : _textSecondary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 16), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))]),
    );
  }

  // --- CONTENT BUILDERS ---

  Widget _buildPostList() {
    return FutureBuilder<List<dynamic>>(
      key: ValueKey(_refreshKey), // 🔥 Listens to the refresh key to restart the Future
      future: Future.wait([
        supabase.from('CommunityPost').select('*, User!CommunityPost_authorID_fkey(*), PostLike(*), PostComment(*), PostSaved(*)').neq('status', 'deleted'),
        supabase.from('ReportedPost').select('postID').eq('status', 'pending')
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));

        final posts = snapshot.data![0] as List<dynamic>;
        final flaggedIDs = (snapshot.data![1] as List<dynamic>).map((r) => r['postID'].toString()).toSet();

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, i) {
              final post = CommunityPostModel.fromJson(posts[i]);
              final bool isFlagged = flaggedIDs.contains(post.postID);
              return _buildModerationCard(
                title: "Author: ${post.username}",
                content: post.content,
                isFlagged: isFlagged,
                onDelete: () => _showConfirm(post.postID, post.content, 'CommunityPost', 'postID'),
              );
            },
            childCount: posts.length,
          ),
        );
      },
    );
  }

  Widget _buildCommentList() {
    return FutureBuilder<List<dynamic>>(
      key: ValueKey(_refreshKey), // 🔥 Listens to the refresh key to restart the Future
      future: Future.wait([
        supabase.from('PostComment').select('*, User(*)').neq('status', 'deleted'),
        supabase.from('ReportedComment').select('commentID').eq('status', 'pending')
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));

        final comments = snapshot.data![0] as List<dynamic>;
        final flaggedIDs = (snapshot.data![1] as List<dynamic>).map((r) => r['commentID'].toString()).toSet();

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, i) {
              final data = comments[i];
              final String cid = data['commentID'].toString();
              final String username = data['User']?['username'] ?? "Unknown";
              final String content = data['content'] ?? "";
              final bool isFlagged = flaggedIDs.contains(cid);

              return _buildModerationCard(
                title: "Comment by: $username",
                content: content,
                isFlagged: isFlagged,
                onDelete: () => _showConfirm(cid, content, 'PostComment', 'commentID'),
              );
            },
            childCount: comments.length,
          ),
        );
      },
    );
  }

  Widget _buildModerationCard({required String title, required String content, required bool isFlagged, required VoidCallback onDelete}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: isFlagged ? Border.all(color: _alertRed.withOpacity(0.3), width: 1.5) : Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isFlagged ? _alertRed.withOpacity(0.1) : _heroEnd.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(isFlagged ? Icons.report_gmailerrorred : Icons.person_outline, color: isFlagged ? _alertRed : _heroEnd, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _textPrimary)),
                    if (isFlagged) const Text("USER REPORTED", style: TextStyle(color: _alertRed, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, color: _alertRed)),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: const TextStyle(fontSize: 15, color: _textPrimary, height: 1.4)),
        ],
      ),
    );
  }
}