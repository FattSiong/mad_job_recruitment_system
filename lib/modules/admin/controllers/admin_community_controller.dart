import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../models/chat_room_model.dart';
import '../../../models/moderation_item_model.dart';
import '../../../services/user_directory.dart';

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
  List<ModerationItem> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _reportsCapped = false;
  String? _error;
  int _reportedPosts = 0;
  int _reportedComments = 0;
  final Set<String> _busy = {};
  int _loadToken = 0;
  bool _disposed = false;

  ModerationKind get kind => _kind;
  ModerationView get view => _view;
  List<ModerationItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

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
    _items = [];
    load();
  }

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  /// Loads the list again from the start (and the tab badges).
  Future<void> load() async {
    final token = ++_loadToken;
    final kind = _kind;
    _isLoading = _items.isEmpty;
    _error = null;
    _notify();
    try {
      final page = _view == ModerationView.reported ? await _loadReported(kind) : await _loadPage(kind, 0);
      if (token != _loadToken) return; // a newer load (or another tab) started
      _items = page.items;
      _hasMore = page.hasMore;
      _reportsCapped = page.capped;
    } catch (e) {
      if (token != _loadToken) return;
      debugPrint('Admin community load failed: $e');
      _error = 'Unable to load community content. Please check your connection and try again.';
    } finally {
      if (token == _loadToken) {
        _isLoading = false;
        _notify();
      }
    }
    _loadCounts();
  }

  /// Next page of the All list.
  Future<void> loadMore() async {
    if (_view != ModerationView.all || !_hasMore || _isLoadingMore || _isLoading) return;
    final token = _loadToken;
    _isLoadingMore = true;
    _notify();
    try {
      final page = await _loadPage(_kind, _items.length);
      if (token != _loadToken) return;
      final known = _items.map((i) => i.id).toSet();
      _items = [..._items, ...page.items.where((i) => !known.contains(i.id))];
      _hasMore = page.hasMore;
    } catch (e) {
      debugPrint('Admin community load more failed: $e'); // the button stays: try again
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
    if (ids.isEmpty) return _Page(const [], hasMore: false, capped: capped);

    final rows = await _fetchTargets(kind, ids);
    final byId = {for (final r in rows) r[target].toString(): r};
    final items = await _build(kind, [for (final id in ids) if (byId[id] != null) byId[id]!], reportRows);
    return _Page(items, hasMore: false, capped: capped);
  }

  /// One page of visible posts / comments, newest first.
  Future<_Page> _loadPage(ModerationKind kind, int offset) async {
    final List<Map<String, dynamic>> rows;
    if (kind == ModerationKind.post) {
      rows = List<Map<String, dynamic>>.from(await _supabase
          .from(TableConstants.communityPost)
          .select(_postColumns)
          .eq('status', 'active')
          .eq('isDraft', false)
          .order('createdAt', ascending: false)
          .range(offset, offset + pageSize - 1));
    } else {
      // Only comments on posts that are still visible
      rows = List<Map<String, dynamic>>.from(await _supabase
          .from(TableConstants.postComment)
          .select('$_commentColumns, CommunityPost!inner(content, status)')
          .eq('status', 'active')
          .eq('CommunityPost.status', 'active')
          .order('createdAt', ascending: false)
          .range(offset, offset + pageSize - 1));
    }
    if (rows.isEmpty) return const _Page([], hasMore: false, capped: false);

    final target = _targetColumn(kind);
    final ids = rows.map((r) => r[target].toString()).toList();
    final reportRows = <Map<String, dynamic>>[];
    for (final chunk in _chunks(ids)) {
      reportRows.addAll(List<Map<String, dynamic>>.from(await _supabase
          .from(_reportTable(kind))
          .select(_reportColumns(kind))
          .eq('status', 'pending')
          .inFilter(target, chunk)
          .order('reportedAt', ascending: false)));
    }
    return _Page(await _build(kind, rows, reportRows), hasMore: rows.length == pageSize, capped: false);
  }

  /// The posts / comments with these IDs (any status but removed, so the
  /// admin also sees reported content its author deleted).
  Future<List<Map<String, dynamic>>> _fetchTargets(ModerationKind kind, List<String> ids) async {
    final rows = <Map<String, dynamic>>[];
    for (final chunk in _chunks(ids)) {
      final result = kind == ModerationKind.post
          ? await _supabase.from(TableConstants.communityPost).select(_postColumns).inFilter('postID', chunk)
          : await _supabase
              .from(TableConstants.postComment)
              .select('$_commentColumns, CommunityPost(content, status)')
              .inFilter('commentID', chunk);
      rows.addAll(List<Map<String, dynamic>>.from(result));
    }
    return rows.where((r) => r['status']?.toString() != 'deleted').toList();
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

  /// Splits IDs into groups so the request address stays short.
  static Iterable<List<String>> _chunks(List<String> ids, [int size = 100]) sync* {
    for (var i = 0; i < ids.length; i += size) {
      yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
    }
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
        'p_note': _cleanNote(note),
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
  /// closes its reports. Returns an error message, or null when it worked.
  Future<String?> remove(ModerationItem item, {String? note}) async {
    if (!_busy.add(item.id)) return null;
    _notify();
    try {
      await _supabase.rpc(
        item.isPost ? 'admin_remove_post' : 'admin_remove_comment',
        params: {(item.isPost ? 'p_post_id' : 'p_comment_id'): item.id, 'p_note': _cleanNote(note)},
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

  String? _cleanNote(String? note) {
    final text = note?.trim() ?? '';
    return text.isEmpty ? null : text;
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
        return 'The database needs an update first (migration 20261117000000).';
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
    super.dispose();
  }
}

/// One loaded list.
class _Page {
  final List<ModerationItem> items;
  final bool hasMore;
  final bool capped;

  const _Page(this.items, {required this.hasMore, required this.capped});
}
