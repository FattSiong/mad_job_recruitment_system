import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/community_post_model.dart'; // 请确保路径正确

class AdminCommunityScreen extends StatefulWidget {
  const AdminCommunityScreen({super.key});

  @override
  State<AdminCommunityScreen> createState() => _AdminCommunityScreenState();
}

class _AdminCommunityScreenState extends State<AdminCommunityScreen> {
  final supabase = Supabase.instance.client;

  // 👉 软删除逻辑
  Future<void> _softDelete(String table, String idField, String id) async {
    try {
      await supabase
          .from(table)
          .update({'status': 'deleted'})
          .match({idField: id});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$table removed (Soft Delete)")),
        );

        // 👉 ADD THIS: Trigger a rebuild so the FutureBuilder fetches the updated list
        setState(() {});
      }
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const TabBar(
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: [
            Tab(text: "Manage Posts", icon: Icon(Icons.article)),
            Tab(text: "Manage Comments", icon: Icon(Icons.comment)),
          ],
        ),
        body: TabBarView(
          children: [
            _buildPostModeration(),
            _buildCommentModeration(),
          ],
        ),
      ),
    );
  }

  // 1️⃣ Post 管理：带举报匹配逻辑 (Updated to FutureBuilder for SQL Joins)
  Widget _buildPostModeration() {
    return FutureBuilder<List<dynamic>>(
      // Run both queries simultaneously
      future: Future.wait([
        // Query 1: Fetch Posts WITH joined User and Interaction tables
        supabase
            .from('CommunityPost')
            .select('*, User!CommunityPost_authorID_fkey(*), PostLike(*), PostComment(*), PostSaved(*)')            .neq('status', 'deleted'), // Filter out deleted directly in DB

        // Query 2: Fetch Reports
        supabase
            .from('ReportedPost')
            .select('postID') // We only need the postID to check if it's flagged
            .eq('status', 'pending')
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error fetching data: ${snapshot.error}"));
        }

        // Extract the results from the Future.wait array
        final activePosts = snapshot.data![0] as List<dynamic>;
        final reportData = snapshot.data![1] as List<dynamic>;

        // 🛡️ 核心修复：清理举报表中的 ID
        final flaggedPostIDs = reportData
            .map((r) => r['postID']?.toString().trim().toLowerCase())
            .where((id) => id != null && id != 'null') // Extra safety check
            .toSet();

        // Wrap in RefreshIndicator so admins can pull-to-refresh
        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activePosts.length,
            itemBuilder: (context, index) {
              final data = activePosts[index] as Map<String, dynamic>;
              final String pid = data['postID']?.toString() ?? "";
              final bool isFlagged = flaggedPostIDs.contains(pid.trim().toLowerCase());

              try {
                final post = CommunityPostModel.fromJson(data);

                // 👉 BRANCH THE UI HERE
                if (isFlagged) {
                  return _buildFlaggedCard(
                    title: "Author: ${post.username}",
                    content: post.content,
                    onDelete: () => _showConfirm(pid, post.content, 'CommunityPost', 'postID'),
                  );
                } else {
                  return _buildNormalCard(
                    title: "Author: ${post.username}",
                    content: post.content,
                    onDelete: () => _showConfirm(pid, post.content, 'CommunityPost', 'postID'),
                  );
                }
              } catch (e) {
                debugPrint("Parse Error: $e");
                // Fallback for errors
                return _buildNormalCard(
                  title: "Error Parsing Post",
                  content: data['content']?.toString() ?? "",
                  onDelete: () => _showConfirm(pid, "Error Post", 'CommunityPost', 'postID'),
                );
              }
            },
          ),
        );
      },
    );
  }

  // 2️⃣ Comment 管理：带举报匹配逻辑
  // 2️⃣ Comment 管理：带举报匹配逻辑 (Updated to FutureBuilder & Distinct UI)
  Widget _buildCommentModeration() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        // Query 1: Fetch active comments WITH the joined User table
        supabase
            .from('PostComment')
        // PostComment only has one foreign key to User, so User(*) is perfectly safe here!
            .select('*, User(*)')
            .neq('status', 'deleted'),

        // Query 2: Fetch ONLY pending comment reports
        supabase
            .from('ReportedComment')
            .select('commentID')
            .eq('status', 'pending')
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error fetching data: ${snapshot.error}"));
        }

        final activeComments = snapshot.data![0] as List<dynamic>;
        final reportData = snapshot.data![1] as List<dynamic>;

        // 🛡️ Map the flagged IDs safely, stripping whitespace and matching casing
        final flaggedCommentIDs = reportData
            .map((r) => r['commentID']?.toString().trim().toLowerCase())
            .where((id) => id != null && id != 'null')
            .toSet();

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activeComments.length,
            itemBuilder: (context, index) {
              final data = activeComments[index] as Map<String, dynamic>;
              final String cid = data['commentID']?.toString() ?? "";

              final String cleanCid = cid.trim().toLowerCase();
              final bool isFlagged = flaggedCommentIDs.contains(cleanCid);

              // Extract the username from the joined User JSON object
              final String username = data['User']?['username'] ?? "Unknown User";
              final String content = data['content'] ?? "";

              // 👉 Branch the UI to use your new distinct cards
              if (isFlagged) {
                return _buildFlaggedCard(
                  title: "Comment by: $username",
                  content: content,
                  onDelete: () => _showConfirm(cid, content, 'PostComment', 'commentID'),
                );
              } else {
                return _buildNormalCard(
                  title: "Comment by: $username",
                  content: content,
                  onDelete: () => _showConfirm(cid, content, 'PostComment', 'commentID'),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildNormalCard({
    required String title,
    required String content,
    required VoidCallback onDelete
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white, // Standard background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(content, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  // 🔴 Flagged Post UI (Distinct banner and tinted background)
  Widget _buildFlaggedCard({
    required String title,
    required String content,
    required VoidCallback onDelete
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      clipBehavior: Clip.antiAlias, // Ensures the banner stays inside the rounded corners
      color: Colors.red.shade50, // Soft red tint for the whole card
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⚠️ Warning Banner Header
          Container(
            width: double.infinity,
            color: Colors.red.shade400,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  "USER REPORTED POST",
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ],
            ),
          ),

          // Content Area
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(content, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  // Slightly stronger delete button for flagged items
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 👉 软删除弹窗
  void _showConfirm(String id, String preview, String table, String idField) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Soft Delete"),
        content: Text("Confirm removal of this item?\n\nPreview: \"$preview\""),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              _softDelete(table, idField, id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}