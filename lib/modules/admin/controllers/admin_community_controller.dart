import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../models/chat_room_model.dart';
import '../../../models/moderation_item_model.dart';
import '../../../services/user_directory.dart';
import 'moderation_query_utils.dart';

/// Which items Admin > Community lists.
enum ModerationView {
  /// Items with open reports, most recently reported first.
  reported,

  /// Every visible post or comment, newest first (reported ones marked).
  all,
}


/// Admin > Community: reported and all posts / comments, and the admin's
/// actions on them (dismiss the reports, or remove the content).
///
/// The actions are database functions (migration 20261117000000), so each
/// one checks the caller is an admin, runs in one transaction and says when
/// nothing was changed.
class AdminCommunityController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  static const int pageSize = 20;

  /// Open reports read at most (the newest ones).
  static const int maxReports = 500;

  ModerationKind _kind = ModerationKind.post;
  ModerationView _view = ModerationView.reported;
  ModerationSort _sort = ModerationSort.newest;
  String _search = '';
  Timer? _searchDebounce;
  final Map<String, List<String>> _authorMatches = {}; // search text -> user IDs
  List<ModerationItem> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  bool _hasMore = false;
  bool _loadMoreFailed = false;
  DateTime? _cursor; // All list: the next page starts after this time
  bool _reportsCapped = false;
  String? _error;
  int _reportedPosts = 0;
  int _reportedComments = 0;
  final Set<String> _busy = {};
  int _loadToken = 0;
  bool _disposed = false;

  ModerationKind get kind => _kind;
  ModerationView get view => _view;
  ModerationSort get sort => _sort;
  String get search => _search;
  bool get isSearching => _search.trim().isNotEmpty;

  /// Sorts offered for the current view ("Most reported" only for Reported).
  List<ModerationSort> get sortOptions => _view == ModerationView.reported
      ? ModerationSort.values
      : const [ModerationSort.newest, ModerationSort.oldest];

  /// The list to show. Reported: all open reports are loaded, so search and
  /// sort happen here. All: the database already searched and sorted.
  List<ModerationItem> get items {
    if (_view == ModerationView.all) return List.unmodifiable(_items);
    return List.unmodifiable(ModerationItem.searchAndSortReported(_items, _search, _sort));
  }
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;

  /// Loading again while the old list is still shown (thin progress bar).
  bool get isRefreshing => _isRefreshing;
  bool get hasMore => _hasMore;
  String? get error => _error;

  /// The last "load more" failed (it is not retried while scrolling).
  bool get loadMoreFailed => _loadMoreFailed;

  /// True when there were more open reports than [maxReports].
  bool get reportsCapped => _reportsCapped;

  /// Posts / comments with open reports (for the tab badges).
  int get reportedPosts => _reportedPosts;
  int get reportedComments => _reportedComments;

  /// True while an action on [item] is running.
  bool isBusy(ModerationItem item) => _busy.contains(item.id);

  static String _reportTable(ModerationKind k) =>
      k == ModerationKind.post ? TableConstants.reportedPost : TableConstants.reportedComment;
  static String _reportIdColumn(ModerationKind k) => k == ModerationKind.post ? 'reportPostID' : 'reportCommentID';
  static String _targetColumn(ModerationKind k) => k == ModerationKind.post ? 'postID' : 'commentID';
  static String _reportColumns(ModerationKind k) =>
      '${_reportIdColumn(k)}, ${_targetColumn(k)}, reporterID, reportCategory, additionalDetails, reportedAt';

  static const String _postColumns = 'postID, authorID, content, mediaURL, status, category, createdAt';
  static const String _commentColumns =
      'commentID, postID, parentCommentID, userID, content, createdAt, status';

  // ---------------------------------------------------------------------
  // Tabs
  // ---------------------------------------------------------------------

  /// Posts or comments.
  void setKind(ModerationKind kind) {
    if (kind == _kind) return;
    _kind = kind;
    _items = [];
    load();
  }

  /// Reported only, or everything.
  void setView(ModerationView view) {
    if (view == _view) return;
    _view = view;
    if (!sortOptions.contains(_sort)) _sort = ModerationSort.newest;
    _items = [];
    load();
  }

  /// Search text. Reported: filters at once. All: searches the database
  /// after the admin stops typing.
  void setSearch(String text) {
    if (text == _search) return;
    _search = text;
    _searchDebounce?.cancel();
    if (_view == ModerationView.reported) {
      _notify();
    } else {
      _searchDebounce = Timer(const Duration(milliseconds: 400), load);
    }
  }

  /// Changes the order (All: loads again from the start).
  void setSort(ModerationSort sort) {
    if (sort == _sort || !sortOptions.contains(sort)) return;
    _sort = sort;
    if (_view == ModerationView.reported) {
      _notify();
    } else {
      _items = [];
      load();
    }
  }

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  /// Loads the list again from the start (and the tab badges).
  Future<void> load() async {
    _searchDebounce?.cancel();
    final token = ++_loadToken;
    final kind = _kind;
    _isLoading = _items.isEmpty;
    _isRefreshing = !_isLoading;
    _isLoadingMore = false; // a "load more" still running is now out of date
    _loadMoreFailed = false;
    _error = null;
    _notify();
    try {
      final page = _view == ModerationView.reported ? await _loadReported(kind) : await _loadPage(kind);
      if (token != _loadToken) return; // a newer load (or another tab) started
      _items = page.items;
      _hasMore = page.hasMore;
      _cursor = page.cursor;
      _reportsCapped = page.capped;
    } catch (e) {
      if (token != _loadToken) return;
      debugPrint('Admin community load failed: $e');
      _error = 'Unable to load community content. Please check your connection and try again.';
    } finally {
      if (token == _loadToken) {
        _isLoading = false;
        _isRefreshing = false;
        _notify();
      }
    }
    _loadCounts();
  }

  /// Next page of the All list. After a failure it only runs again when
  /// [retry] is true (the button), not on every scroll.
  Future<void> loadMore({bool retry = false}) async {
    if (_view != ModerationView.all || !_hasMore || _isLoadingMore || _isLoading) return;
    if (_loadMoreFailed && !retry) return;
    final token = _loadToken;
    _isLoadingMore = true;
    _loadMoreFailed = false;
    _notify();
    try {
      final page = await _loadPage(_kind, before: _cursor);
      if (token != _loadToken) return;
      final known = _items.map((i) => i.id).toSet();
      _items = [..._items, ...page.items.where((i) => !known.contains(i.id))];
      _hasMore = page.hasMore;
      _cursor = page.cursor ?? _cursor;
    } catch (e) {
      debugPrint('Admin community load more failed: $e');
      if (token == _loadToken) _loadMoreFailed = true;
    } finally {
      if (token == _loadToken) {
        _isLoadingMore = false;
        _notify();
      }
    }
  }

  /// How many posts and comments have open reports (failures only logged).
  Future<void> _loadCounts() async {
    try {
      final results = await Future.wait([
        _supabase.from(TableConstants.reportedPost).select('postID').eq('status', 'pending'),
        _supabase.from(TableConstants.reportedComment).select('commentID').eq('status', 'pending'),
      ]);
      _reportedPosts = (results[0] as List).map((r) => r['postID'].toString()).toSet().length;
      _reportedComments = (results[1] as List).map((r) => r['commentID'].toString()).toSet().length;
      _notify();
    } catch (e) {
      debugPrint('Admin community counts failed: $e');
    }
  }

  /// Items with open reports, the most recently reported first.
  Future<_Page> _loadReported(ModerationKind kind) async {
    final target = _targetColumn(kind);
    final reportRows = List<Map<String, dynamic>>.from(await _supabase
        .from(_reportTable(kind))
        .select(_reportColumns(kind))
        .eq('status', 'pending')
        .order('reportedAt', ascending: false)
        .limit(maxReports));
    final capped = reportRows.length >= maxReports;

    // Reported IDs, in order of their newest report
    final ids = <String>[];
    final seen = <String>{};
    for (final r in reportRows) {
      final id = r[target].toString();
      if (seen.add(id)) ids.add(id);
    }
    if (ids.isEmpty) return _Page(const [], hasMore: false, capped: capped, cursor: null);

    final rows = await _fetchTargets(kind, ids);
    final byId = {for (final r in rows) r[target].toString(): r};
    final items = await _build(kind, [for (final id in ids) if (byId[id] != null) byId[id]!], reportRows);
    return _Page(items, hasMore: false, capped: capped, cursor: null);
  }

  /// One page of visible posts / comments, newest first, older than
  /// [before] (by time, not by position: removing items or new posts
  /// arriving can't make the next page skip or repeat any).
  Future<_Page> _loadPage(ModerationKind kind, {DateTime? before}) async {
    final oldestFirst = _sort == ModerationSort.oldest;
    final search = cleanModerationSearch(_search);
    PostgrestFilterBuilder<PostgrestList> query;
    if (kind == ModerationKind.post) {
      query = _supabase
          .from(TableConstants.communityPost)
          .select(_postColumns)
          .eq('status', 'active')
          .eq('isDraft', false);
    } else {
      // Only comments on posts that are still visible
      query = _supabase
          .from(TableConstants.postComment)
          .select('$_commentColumns, CommunityPost!inner(content, status)')
          .eq('status', 'active')
          .eq('CommunityPost.status', 'active');
    }
    if (search.isNotEmpty) {
      // The text, or written by someone whose name matches
      final authorColumn = kind == ModerationKind.post ? 'authorID' : 'userID';
      final authors = await _usersMatching(search);
      query = authors.isEmpty
          ? query.ilike('content', '%$search%')
          : query.or('content.ilike.*$search*,$authorColumn.in.(${authors.join(',')})');
    }
    if (before != null) {
      final at = before.toUtc().toIso8601String();
      query = oldestFirst ? query.gt('createdAt', at) : query.lt('createdAt', at);
    }
    final rows = List<Map<String, dynamic>>.from(
        await query.order('createdAt', ascending: oldestFirst).limit(pageSize));
    if (rows.isEmpty) return const _Page([], hasMore: false, capped: false, cursor: null);
    final cursor = DateTime.tryParse(rows.last['createdAt']?.toString() ?? '');

    final target = _targetColumn(kind);
    final ids = rows.map((r) => r[target].toString()).toList();
    final reportRows = <Map<String, dynamic>>[];
    for (final chunk in chunkIds(ids)) {
      reportRows.addAll(List<Map<String, dynamic>>.from(await _supabase
          .from(_reportTable(kind))
          .select(_reportColumns(kind))
          .eq('status', 'pending')
          .inFilter(target, chunk)
          .order('reportedAt', ascending: false)));
    }
    return _Page(
      await _build(kind, rows, reportRows),
      hasMore: rows.length == pageSize && cursor != null,
      capped: false,
      cursor: cursor,
    );
  }

  /// The posts / comments with these IDs, whatever their status: the admin
  /// also sees reported content its author deleted, and content already
  /// removed that still has open reports (sent just before it was removed,
  /// or left by the old admin screen), so those reports can be closed.
  Future<List<Map<String, dynamic>>> _fetchTargets(ModerationKind kind, List<String> ids) async {
    final rows = <Map<String, dynamic>>[];
    for (final chunk in chunkIds(ids)) {
      final result = kind == ModerationKind.post
          ? await _supabase.from(TableConstants.communityPost).select(_postColumns).inFilter('postID', chunk)
          : await _supabase
              .from(TableConstants.postComment)
              .select('$_commentColumns, CommunityPost(content, status)')
              .inFilter('commentID', chunk);
      rows.addAll(List<Map<String, dynamic>>.from(result));
    }
    return rows;
  }

  /// Turns rows into items, with names and the reports on each one.
  Future<List<ModerationItem>> _build(
    ModerationKind kind,
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> reportRows,
  ) async {
    final isPost = kind == ModerationKind.post;
    final authorKey = isPost ? 'authorID' : 'userID';
    final target = _targetColumn(kind);
    final people = await UserDirectory.fetch([
      ...rows.map((r) => r[authorKey]?.toString() ?? ''),
      ...reportRows.map((r) => r['reporterID']?.toString() ?? ''),
    ]);

    ChatParticipant person(String id) =>
        people[id] ?? ChatParticipant(userID: id, displayName: 'Unknown user', role: 'member');

    final reportsByTarget = <String, List<ContentReport>>{};
    for (final r in reportRows) {
      reportsByTarget.putIfAbsent(r[target].toString(), () => []).add(ContentReport.fromJson(
            r,
            idColumn: _reportIdColumn(kind),
            reporter: person(r['reporterID']?.toString() ?? ''),
          ));
    }

    return rows.map((r) {
      final author = person(r[authorKey]?.toString() ?? '');
      final reports = reportsByTarget[r[target].toString()] ?? const <ContentReport>[];
      return isPost
          ? ModerationItem.fromPostJson(r, author: author, reports: reports)
          : ModerationItem.fromCommentJson(r, author: author, reports: reports);
    }).toList();
  }

  /// IDs of users whose username or full name contains [search] (at most
  /// 150; remembered while the screen is open).
  Future<List<String>> _usersMatching(String search) async {
    final key = search.toLowerCase();
    final known = _authorMatches[key];
    if (known != null) return known;

    Future<List<String>> ids(String table, String idColumn, String nameColumn) async {
      try {
        final rows = await _supabase
            .from(table)
            .select(idColumn)
            .ilike(nameColumn, '%$search%')
            .limit(50);
        return List<Map<String, dynamic>>.from(rows).map((r) => r[idColumn].toString()).toList();
      } catch (e) {
        debugPrint('Admin community name search ($table) failed: $e');
        return const [];
      }
    }

    final found = await Future.wait([
      ids(TableConstants.user, 'userID', 'username'),
      ids(TableConstants.jobSeeker, 'seekerID', 'fullName'),
      ids(TableConstants.employer, 'employerID', 'fullName'),
    ]);
    final result = found.expand((list) => list).toSet().toList();
    _authorMatches[key] = result;
    return result;
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  /// Closes the open reports on [item] and keeps it.
  /// Returns an error message, or null when it worked.
  Future<String?> dismiss(ModerationItem item, {String? note}) async {
    if (!item.isReported || !_busy.add(item.id)) return null;
    _notify();
    try {
      final closed = await _supabase.rpc('admin_dismiss_reports', params: {
        'p_kind': item.isPost ? 'post' : 'comment',
        'p_id': item.id,
        'p_note': cleanModerationNote(note),
      });
      _afterReportsClosed(item, removed: false);
      if ((closed as num? ?? 0) == 0) {
        return 'These reports were already handled by another admin.';
      }
      return null;
    } catch (e) {
      return _actionError(e, item);
    } finally {
      _busy.remove(item.id);
      _notify();
    }
  }

  /// Hides [item] from everyone (a comment together with its replies) and
  /// closes its reports. With [notifyAuthor] the author gets a notification
  /// naming the report reasons (not the note).
  /// Returns an error message, or null when it worked.
  Future<String?> remove(ModerationItem item, {String? note, bool notifyAuthor = true}) async {
    if (!_busy.add(item.id)) return null;
    _notify();
    try {
      await _supabase.rpc(
        item.isPost ? 'admin_remove_post' : 'admin_remove_comment',
        params: {
          (item.isPost ? 'p_post_id' : 'p_comment_id'): item.id,
          'p_note': cleanModerationNote(note),
          'p_notify': notifyAuthor,
        },
      );
      _afterReportsClosed(item, removed: true);
      return null;
    } catch (e) {
      return _actionError(e, item);
    } finally {
      _busy.remove(item.id);
      _notify();
    }
  }

  /// Updates the list and badges after the reports on [item] were closed.
  void _afterReportsClosed(ModerationItem item, {required bool removed}) {
    if (removed) {
      // A removed comment takes its replies (already in the list) with it
      final gone = {item.id};
      var grew = true;
      while (grew) {
        grew = false;
        for (final i in _items) {
          if (!gone.contains(i.id) && i.parentCommentID != null && gone.contains(i.parentCommentID)) {
            gone.add(i.id);
            grew = true;
          }
        }
      }
      _items = _items.where((i) => !gone.contains(i.id)).toList();
    } else if (_view == ModerationView.reported) {
      _items = _items.where((i) => i.id != item.id).toList();
    } else {
      _items = [for (final i in _items) i.id == item.id ? i.withoutReports() : i];
    }
    _loadCounts();
  }

  /// A message to show for a failed action.
  String _actionError(Object e, ModerationItem item) {
    debugPrint('Admin community action failed: $e');
    if (e is PostgrestException) {
      final text = '${e.code} ${e.message}';
      if (text.contains('not_admin')) return 'Only admins can moderate the community.';
      if (text.contains('not_found')) {
        _items = _items.where((i) => i.id != item.id).toList();
        _loadCounts();
        return 'This ${item.isPost ? 'post' : 'comment'} no longer exists.';
      }
      if (e.code == 'PGRST202' || e.code == '42883') {
        return 'The database needs an update first (migrations 20261117000000 and 20261117010000).';
      }
    }
    return 'Unable to finish this action. Please check your connection and try again.';
  }

  /// notifyListeners, unless the controller was already disposed.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();
    super.dispose();
  }
}

/// One loaded list.
class _Page {
  final List<ModerationItem> items;
  final bool hasMore;
  final bool capped;

  /// Time of the last row (All list), where the next page starts.
  final DateTime? cursor;

  const _Page(this.items, {required this.hasMore, required this.capped, required this.cursor});
}
