import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../models/chat_room_model.dart';
import '../../../models/moderation_item_model.dart';
import '../../../services/user_directory.dart';
import 'moderation_list_controller.dart';
import 'moderation_query_utils.dart';

/// Admin > Community: reported and all posts / comments, and the admin's
/// actions on them (dismiss the reports, or remove the content). Lists,
/// search, sort and the actions' flow come from [ModerationListController].
///
/// The database functions are in migrations 20261117000000 and 20261117010000.
class AdminCommunityController extends ModerationListController<ModerationItem> {
  ModerationKind _kind = ModerationKind.post;
  final Map<String, List<String>> _authorMatches = {}; // search text -> user IDs
  int _reportedPosts = 0;
  int _reportedComments = 0;

  ModerationKind get kind => _kind;

  /// Posts / comments with open reports (for the tab badges).
  int get reportedPosts => _reportedPosts;
  int get reportedComments => _reportedComments;

  static String _reportTable(ModerationKind k) =>
      k == ModerationKind.post ? TableConstants.reportedPost : TableConstants.reportedComment;
  static String _targetColumn(ModerationKind k) => k == ModerationKind.post ? 'postID' : 'commentID';
  static String _reportColumns(ModerationKind k) =>
      'reportID, ${_targetColumn(k)}, reporterID, reportCategory, additionalDetails, reportedAt';

  static const String _postColumns = 'postID, authorID, content, mediaURL, status, category, createdAt';
  static const String _commentColumns =
      'commentID, postID, parentCommentID, userID, content, createdAt, status';

  @override
  String get logName => 'Admin community';

  @override
  String get loadErrorMessage => 'Unable to load community content. Please check your connection and try again.';

  @override
  String get notAdminMessage => 'Only admins can moderate the community.';

  @override
  String get migrationNames => 'migrations 20261117000000 and 20261117010000';

  @override
  String idOf(ModerationItem item) => item.id;

  @override
  ModerationItem withoutReports(ModerationItem item) => item.withoutReports();

  @override
  String goneMessage(ModerationItem item) => 'This ${item.isPost ? 'post' : 'comment'} no longer exists.';

  @override
  List<ModerationItem> searchAndSortReported(List<ModerationItem> items, String search, ModerationSort sort) =>
      ModerationItem.searchAndSortReported(items, search, sort);

  /// A removed comment takes its replies (already in the list) with it.
  @override
  Set<String> idsRemovedWith(ModerationItem item) {
    final gone = {item.id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final i in loadedItems) {
        if (!gone.contains(i.id) && i.parentCommentID != null && gone.contains(i.parentCommentID)) {
          gone.add(i.id);
          grew = true;
        }
      }
    }
    return gone;
  }

  /// Posts or comments.
  void setKind(ModerationKind kind) {
    if (kind == _kind) return;
    _kind = kind;
    reload();
  }

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  /// How many posts and comments have open reports (failures only logged).
  @override
  Future<void> loadCounts() async {
    try {
      final results = await Future.wait([
        supabase.from(TableConstants.reportedPost).select('postID').eq('status', 'pending'),
        supabase.from(TableConstants.reportedComment).select('commentID').eq('status', 'pending'),
      ]);
      _reportedPosts = (results[0] as List).map((r) => r['postID'].toString()).toSet().length;
      _reportedComments = (results[1] as List).map((r) => r['commentID'].toString()).toSet().length;
      notifySafely();
    } catch (e) {
      debugPrint('Admin community counts failed: $e');
    }
  }

  /// Items with open reports, the most recently reported first.
  @override
  Future<ModerationPage<ModerationItem>> loadReported() async {
    final kind = _kind;
    final target = _targetColumn(kind);
    final reportRows = await newestOpenReports(_reportTable(kind), _reportColumns(kind));
    final capped = reportRows.length >= ModerationListController.maxReports;

    final ids = uniqueIdsInOrder(reportRows, target);
    if (ids.isEmpty) return ModerationPage<ModerationItem>(const [], capped: capped);

    final rows = await _fetchTargets(kind, ids);
    final byId = {for (final r in rows) r[target].toString(): r};
    final items = await _build(kind, [for (final id in ids) if (byId[id] != null) byId[id]!], reportRows);
    return ModerationPage<ModerationItem>(items, capped: capped);
  }

  /// One page of visible posts / comments, by time, after [before].
  @override
  Future<ModerationPage<ModerationItem>> loadPage({ModerationCursor? before}) async {
    final kind = _kind;
    final text = cleanModerationSearch(search);
    PostgrestFilterBuilder<PostgrestList> query;
    if (kind == ModerationKind.post) {
      query = supabase
          .from(TableConstants.communityPost)
          .select(_postColumns)
          .eq('status', 'active')
          .eq('isDraft', false);
    } else {
      // Only comments on posts that are still visible
      query = supabase
          .from(TableConstants.postComment)
          .select('$_commentColumns, CommunityPost!inner(content, status)')
          .eq('status', 'active')
          .eq('CommunityPost.status', 'active');
    }
    final target = _targetColumn(kind);
    String? searchOr;
    if (text.isNotEmpty) {
      // The text, or written by someone whose name matches
      final authorColumn = kind == ModerationKind.post ? 'authorID' : 'userID';
      final authors = await _usersMatching(text);
      if (authors.isEmpty) {
        query = query.ilike('content', '%$text%');
      } else {
        searchOr = 'content.ilike.*$text*,$authorColumn.in.(${authors.join(',')})';
      }
    }
    final rows = await readPage(query, before, idColumn: target, searchOr: searchOr);
    if (rows.isEmpty) return ModerationPage<ModerationItem>(const []);

    final ids = rows.map((r) => r[target].toString()).toList();
    final reportRows = await openReportsFor(_reportTable(kind), _reportColumns(kind), target, ids);
    return pageOf(await _build(kind, rows, reportRows), rows, idColumn: target);
  }

  /// The posts / comments with these IDs, whatever their status: the admin
  /// also sees reported content its author deleted, and content already
  /// removed that still has open reports (sent just before it was removed,
  /// or left by the old admin screen), so those reports can be closed.
  Future<List<Map<String, dynamic>>> _fetchTargets(ModerationKind kind, List<String> ids) async {
    final rows = <Map<String, dynamic>>[];
    for (final chunk in chunkIds(ids)) {
      final result = kind == ModerationKind.post
          ? await supabase.from(TableConstants.communityPost).select(_postColumns).inFilter('postID', chunk)
          : await supabase
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
            idColumn: 'reportID',
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

  /// IDs of users whose username or full name contains [text] (at most
  /// 150; remembered while the screen is open).
  Future<List<String>> _usersMatching(String text) async {
    final key = text.toLowerCase();
    final known = _authorMatches[key];
    if (known != null) return known;

    final found = await Future.wait([
      idsWithName(TableConstants.user, 'userID', 'username', text),
      idsWithName(TableConstants.jobSeeker, 'seekerID', 'fullName', text),
      idsWithName(TableConstants.employer, 'employerID', 'fullName', text),
    ]);
    final result = found.expand((list) => list).toSet().toList();
    _authorMatches[key] = result;
    return result;
  }

  // ---------------------------------------------------------------------
  // Actions (database functions)
  // ---------------------------------------------------------------------

  @override
  Future<int> closeReports(ModerationItem item, String? note) async {
    final closed = await supabase.rpc('admin_dismiss_reports', params: {
      'p_kind': item.isPost ? 'post' : 'comment',
      'p_id': item.id,
      'p_note': note,
    });
    return (closed as num? ?? 0).toInt();
  }

  /// Hides [item] from everyone (a comment together with its replies) and
  /// closes its reports. With [notify] the author gets a notification
  /// naming the report reasons (not the note).
  @override
  Future<void> removeItem(ModerationItem item, String? note, bool notify) async {
    await supabase.rpc(
      item.isPost ? 'admin_remove_post' : 'admin_remove_comment',
      params: {
        (item.isPost ? 'p_post_id' : 'p_comment_id'): item.id,
        'p_note': note,
        'p_notify': notify,
      },
    );
  }
}
