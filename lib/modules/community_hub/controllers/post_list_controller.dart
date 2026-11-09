import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/storage_url_helper.dart';
import '../../../models/chat_room_model.dart';
import '../../../models/feed_post_model.dart';
import '../../../models/post_filter.dart';
import '../../../services/user_directory.dart';

/// Which posts a [PostListController] shows.
enum PostListMode {
  /// Everyone's active posts, a page at a time, narrowed by a [PostFilter].
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
      'postID, authorID, content, mediaURL, status, category, createdAt, '
      'PostLike(userID), PostSaved(userID), PostComment(commentID, status)';

  List<FeedPostModel> _posts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String? _error;
  bool _disposed = false;
  PostFilter _filter = PostFilter.none; // feed only
  MyPostsStatus _status = MyPostsStatus.all; // My Posts only
  int _loadToken = 0; // a newer load makes older results obsolete
  int _nextOffset = 0; // feed: how many results the database has given so far

  /// The posts to show (for My Posts: only those matching [statusFilter]).
  List<FeedPostModel> get posts {
    switch (_status) {
      case MyPostsStatus.all:
        return List.unmodifiable(_posts);
      case MyPostsStatus.visible:
        return _posts.where((p) => !p.isRemoved).toList();
      case MyPostsStatus.removed:
        return _posts.where((p) => p.isRemoved).toList();
    }
  }

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  bool get isEmpty => posts.isEmpty;

  PostFilter get filter => _filter;
  MyPostsStatus get statusFilter => _status;

  /// True when posts may be hidden by a filter, so an empty list means
  /// "nothing matches" rather than "nothing posted yet".
  bool get isFiltered =>
      _filter.isActive || (_status != MyPostsStatus.all && _posts.isNotEmpty);

  // My Posts summary (all own posts, whatever the status filter)
  int get totalCount => _posts.length;
  int get removedCount => _posts.where((p) => p.isRemoved).length;
  int get visibleCount => totalCount - removedCount;

  // ---------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------

  /// Feed: applies [filter] on the server and reloads from the first page.
  void setFilter(PostFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    _posts = []; // show the spinner, not posts from the old filter
    _hasMore = false;
    load();
  }

  void clearFilter() => setFilter(PostFilter.none);

  /// My Posts: show all, visible or removed posts.
  void setStatusFilter(MyPostsStatus status) {
    if (status == _status) return;
    _status = status;
    _notify();
  }

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  Future<void> load() async {
    final token = ++_loadToken;
    _isLoading = _posts.isEmpty;
    _isLoadingMore = false;
    _error = null;
    _notify();
    try {
      final page = await _fetch(offset: 0);
      final models = await _toModels(page.rows);
      if (token != _loadToken) return; // a newer filter / reload took over
      _posts = models;
      _nextOffset = page.count;
      _hasMore = mode == PostListMode.feed && page.full;
    } catch (e) {
      if (token != _loadToken) return;
      debugPrint('PostListController($mode) load failed: $e');
      _error = 'Unable to load posts. Pull down to try again.';
    } finally {
      if (token == _loadToken) {
        _isLoading = false;
        _notify();
      }
    }
  }

  /// Next page of the feed (called near the end of the list).
  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    final token = _loadToken;
    _isLoadingMore = true;
    _notify();
    try {
      final page = await _fetch(offset: _nextOffset);
      final models = await _toModels(page.rows);
      if (token != _loadToken) return;
      final known = _posts.map((p) => p.postID).toSet();
      _posts = [..._posts, ...models.where((p) => !known.contains(p.postID))];
      _nextOffset += page.count;
      _hasMore = page.full;
    } catch (e) {
      debugPrint('PostListController loadMore failed: $e');
    } finally {
      if (token == _loadToken) {
        _isLoadingMore = false;
        _notify();
      }
    }
  }

  /// One page of rows. [count] is how many results the page used up (for the
  /// next offset); [full] means there may be more after it.
  Future<({List<Map<String, dynamic>> rows, int count, bool full})> _fetch({
    required int offset,
  }) async {
    switch (mode) {
      case PostListMode.feed:
        // The database function filters, sorts and pages; it returns post IDs.
        final result = await _supabase.rpc(
          'search_community_posts',
          params: _filter.toParams(limit: pageSize, offset: offset),
        );
        final ids = List<Map<String, dynamic>>.from(result as List)
            .map((r) => r['post_id'].toString())
            .toList();
        if (ids.isEmpty) return (rows: <Map<String, dynamic>>[], count: 0, full: false);

        final rows = await _supabase
            .from(TableConstants.communityPost)
            .select(_columns)
            .inFilter('postID', ids);
        // Keep the order the function chose.
        final byId = {for (final r in rows) r['postID'].toString(): r};
        return (
          rows: [for (final id in ids) if (byId[id] != null) byId[id]!],
          count: ids.length,
          full: ids.length == pageSize,
        );

      case PostListMode.mine:
        final rows = await _supabase
            .from(TableConstants.communityPost)
            .select(_columns)
            .eq('authorID', currentUserID)
            .order('createdAt', ascending: false);
        return (rows: List<Map<String, dynamic>>.from(rows), count: rows.length, full: false);

      case PostListMode.saved:
        final saved = await _supabase
            .from(TableConstants.postSaved)
            .select('postID')
            .eq('userID', currentUserID);
        final ids = List<Map<String, dynamic>>.from(saved)
            .map((r) => r['postID'].toString())
            .toSet()
            .toList();
        if (ids.isEmpty) return (rows: <Map<String, dynamic>>[], count: 0, full: false);
        final rows = await _supabase
            .from(TableConstants.communityPost)
            .select(_columns)
            .inFilter('postID', ids)
            .eq('status', 'active')
            .order('createdAt', ascending: false);
        return (rows: List<Map<String, dynamic>>.from(rows), count: rows.length, full: false);
    }
  }

  Future<List<FeedPostModel>> _toModels(List<Map<String, dynamic>> rows) async {
    final authors = await UserDirectory.fetch(rows.map((r) => r['authorID']?.toString() ?? ''));
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
  /// Posts with a like / save still being sent: a second quick tap is ignored,
  /// so the request can't race and leave a double like or a wrong count.
  final Set<String> _likeBusy = {};
  final Set<String> _saveBusy = {};

  Future<String?> toggleLike(FeedPostModel post) async {
    if (post.isRemoved || !_likeBusy.add(post.postID)) return null;
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
    } finally {
      _likeBusy.remove(post.postID);
    }
  }

  /// Returns an error message, or null when it worked.
  Future<String?> toggleSave(FeedPostModel post) async {
    if (post.isRemoved || !_saveBusy.add(post.postID)) return null;
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
    } finally {
      _saveBusy.remove(post.postID);
    }
  }

  /// Deletes the post with its comments, likes, saves and reports.
  /// Done by the database function `delete_my_post`, which checks the caller
  /// owns the post (the app can't delete other people's likes or comments).
  /// Returns an error message, or null when it worked.
  Future<String?> deletePost(FeedPostModel post) async {
    if (!post.isOwnedBy(currentUserID)) return 'You can only delete your own posts.';
    try {
      await _supabase.rpc('delete_my_post', params: {'p_post_id': post.postID});
      _posts.removeWhere((p) => p.postID == post.postID);
      _notify();
      // The post is gone, so its photo / PDF is no longer needed
      await StorageUrlHelper.removeOwnFile(post.mediaURL, bucket: 'post_media', userId: currentUserID);
      return null;
    } on PostgrestException catch (e) {
      debugPrint('deletePost failed: ${e.code} ${e.message}');
      if (e.message.contains('not_owner')) return 'You can only delete your own posts.';
      return 'Unable to delete this post. Please try again.';
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
