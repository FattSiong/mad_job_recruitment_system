import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../models/chat_room_model.dart';
import '../../../models/feed_post_model.dart';
import '../../chat/controllers/chat_user_directory.dart';

/// Which posts a [PostListController] shows.
enum PostListMode {
  /// Everyone's active posts, newest first, loaded a page at a time.
  feed,

  /// The current user's posts, including ones removed by an admin.
  mine,

  /// Posts the current user bookmarked.
  saved,
}

/// Loads a list of community posts and handles like / save / delete on them.
/// Used by the Feed tab, the My Posts tab and the Saved Posts screen.
class PostListController extends ChangeNotifier {
  final PostListMode mode;
  final String currentUserID;

  PostListController({required this.mode, required this.currentUserID});

  final _supabase = Supabase.instance.client;

  static const int pageSize = 15;
  static const String _columns =
      'postID, authorID, content, mediaURL, status, createdAt, '
      'PostLike(userID), PostSaved(userID), PostComment(commentID, status)';

  List<FeedPostModel> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String? _error;
  bool _disposed = false;

  List<FeedPostModel> get posts => List.unmodifiable(_posts);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  bool get isEmpty => _posts.isEmpty;

  // My Posts summary
  int get totalCount => _posts.length;
  int get removedCount => _posts.where((p) => p.isRemoved).length;
  int get visibleCount => totalCount - removedCount;

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  Future<void> load() async {
    _isLoading = _posts.isEmpty;
    _error = null;
    _notify();
    try {
      final rows = await _fetch(offset: 0);
      _posts = await _toModels(rows);
      _hasMore = mode == PostListMode.feed && rows.length == pageSize;
    } catch (e) {
      debugPrint('PostListController($mode) load failed: $e');
      _error = 'Unable to load posts. Pull down to try again.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Next page of the feed (called near the end of the list).
  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    _isLoadingMore = true;
    _notify();
    try {
      final rows = await _fetch(offset: _posts.length);
      final known = _posts.map((p) => p.postID).toSet();
      final more = (await _toModels(rows)).where((p) => !known.contains(p.postID));
      _posts = [..._posts, ...more];
      _hasMore = rows.length == pageSize;
    } catch (e) {
      debugPrint('PostListController loadMore failed: $e');
    } finally {
      _isLoadingMore = false;
      _notify();
    }
  }

  Future<List<Map<String, dynamic>>> _fetch({required int offset}) async {
    switch (mode) {
      case PostListMode.feed:
        final rows = await _supabase
            .from(TableConstants.communityPost)
            .select(_columns)
            .eq('status', 'active')
            .order('createdAt', ascending: false)
            .range(offset, offset + pageSize - 1);
        return List<Map<String, dynamic>>.from(rows);

      case PostListMode.mine:
        final rows = await _supabase
            .from(TableConstants.communityPost)
            .select(_columns)
            .eq('authorID', currentUserID)
            .order('createdAt', ascending: false);
        return List<Map<String, dynamic>>.from(rows);

      case PostListMode.saved:
        final saved = await _supabase
            .from(TableConstants.postSaved)
            .select('postID')
            .eq('userID', currentUserID);
        final ids = List<Map<String, dynamic>>.from(saved)
            .map((r) => r['postID'].toString())
            .toSet()
            .toList();
        if (ids.isEmpty) return [];
        final rows = await _supabase
            .from(TableConstants.communityPost)
            .select(_columns)
            .inFilter('postID', ids)
            .eq('status', 'active')
            .order('createdAt', ascending: false);
        return List<Map<String, dynamic>>.from(rows);
    }
  }

  Future<List<FeedPostModel>> _toModels(List<Map<String, dynamic>> rows) async {
    final authors = await ChatUserDirectory.fetch(rows.map((r) => r['authorID']?.toString() ?? ''));
    return rows.map((row) {
      final authorID = row['authorID']?.toString() ?? '';
      return FeedPostModel.fromJson(
        row,
        currentUserID: currentUserID,
        author: authors[authorID] ??
            ChatParticipant(userID: authorID, displayName: 'Unknown user', role: 'member'),
      );
    }).toList();
  }

  // ---------------------------------------------------------------------
  // Actions (optimistic: the screen updates first, and is undone on error)
  // ---------------------------------------------------------------------

  /// Returns an error message, or null when it worked.
  Future<String?> toggleLike(FeedPostModel post) async {
    if (post.isRemoved) return null;
    final liked = !post.isLiked;
    _replace(post.copyWith(isLiked: liked, likeCount: post.likeCount + (liked ? 1 : -1)));
    try {
      if (liked) {
        await _supabase
            .from(TableConstants.postLike)
            .insert({'postID': post.postID, 'userID': currentUserID});
      } else {
        await _supabase
            .from(TableConstants.postLike)
            .delete()
            .match({'postID': post.postID, 'userID': currentUserID});
      }
      return null;
    } catch (e) {
      debugPrint('toggleLike failed: $e');
      _replace(post);
      return 'Unable to update your like. Please try again.';
    }
  }

  /// Returns an error message, or null when it worked.
  Future<String?> toggleSave(FeedPostModel post) async {
    if (post.isRemoved) return null;
    final saved = !post.isSaved;
    final index = _posts.indexWhere((p) => p.postID == post.postID);

    if (mode == PostListMode.saved && !saved) {
      _posts.removeWhere((p) => p.postID == post.postID); // unsaved: leave the list
      _notify();
    } else {
      _replace(post.copyWith(isSaved: saved, savedCount: post.savedCount + (saved ? 1 : -1)));
    }

    try {
      if (saved) {
        await _supabase
            .from(TableConstants.postSaved)
            .insert({'postID': post.postID, 'userID': currentUserID});
      } else {
        await _supabase
            .from(TableConstants.postSaved)
            .delete()
            .match({'postID': post.postID, 'userID': currentUserID});
      }
      return null;
    } catch (e) {
      debugPrint('toggleSave failed: $e');
      if (mode == PostListMode.saved && !saved && index >= 0) {
        _posts.insert(index.clamp(0, _posts.length), post);
        _notify();
      } else {
        _replace(post);
      }
      return 'Unable to update saved posts. Please try again.';
    }
  }

  /// Deletes the post with its likes, saves and comments.
  /// Returns an error message, or null when it worked.
  Future<String?> deletePost(FeedPostModel post) async {
    if (!post.isOwnedBy(currentUserID)) return 'You can only delete your own posts.';
    try {
      await _supabase.from(TableConstants.postLike).delete().eq('postID', post.postID);
      await _supabase.from(TableConstants.postSaved).delete().eq('postID', post.postID);
      await _supabase.from(TableConstants.postComment).delete().eq('postID', post.postID);
      final deleted = await _supabase
          .from(TableConstants.communityPost)
          .delete()
          .eq('postID', post.postID)
          .eq('authorID', currentUserID)
          .select('postID');
      if ((deleted as List).isEmpty) {
        return 'Unable to delete this post.';
      }
      _posts.removeWhere((p) => p.postID == post.postID);
      _notify();
      return null;
    } catch (e) {
      debugPrint('deletePost failed: $e');
      return 'Unable to delete this post. Please try again.';
    }
  }

  /// After the comments sheet closes, show its new comment count.
  void setCommentCount(String postID, int count) {
    final i = _posts.indexWhere((p) => p.postID == postID);
    if (i == -1 || _posts[i].commentCount == count) return;
    _posts[i] = _posts[i].copyWith(commentCount: count);
    _notify();
  }

  void _replace(FeedPostModel post) {
    final i = _posts.indexWhere((p) => p.postID == post.postID);
    if (i == -1) return;
    _posts[i] = post;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
