import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/safe_notifier.dart';
import '../../../models/content_report_model.dart';
import 'moderation_query_utils.dart';

/// Which items an admin moderation list shows.
enum ModerationView {
  /// Items with open reports, most recently reported first.
  reported,

  /// Everything still visible, newest first (reported ones marked).
  all,
}

/// One loaded list (Reported) or one page of the All list.
class ModerationPage<T> {
  final List<T> items;
  final bool hasMore;

  /// True when there were more open reports than [ModerationListController.maxReports].
  final bool capped;

  /// Time of the last row (All list), where the next page starts.
  final DateTime? cursor;

  const ModerationPage(this.items, {this.hasMore = false, this.capped = false, this.cursor});
}

/// What Admin > Community and Admin > Jobs share: Reported / All lists,
/// search, sort, paging by time, the busy state of each card and the
/// Dismiss / Remove flow. A subclass only says how to read its rows and
/// which database functions to call.
///
/// The actions are database functions, so each one checks the caller is
/// an admin, runs in one transaction and says when nothing was changed.
abstract class ModerationListController<T extends ReportSummary> extends ChangeNotifier with SafeNotifier {
  @protected
  final SupabaseClient supabase = Supabase.instance.client;

  /// Rows per page of the All list.
  static const int pageSize = 20;

  /// Open reports read at most (the newest ones).
  static const int maxReports = 500;

  ModerationView _view = ModerationView.reported;
  ModerationSort _sort = ModerationSort.newest;
  String _search = '';
  Timer? _searchDebounce;
  List<T> _items = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _loadMoreFailed = false;
  DateTime? _cursor; // All list: the next page starts after this time
  bool _reportsCapped = false;
  String? _error;
  final Set<String> _busy = {};
  int _loadToken = 0;

  // ---------------------------------------------------------------------
  // For the subclasses
  // ---------------------------------------------------------------------

  /// Start of log lines, e.g. "Admin jobs".
  @protected
  String get logName;

  /// Shown when the list can't be loaded.
  @protected
  String get loadErrorMessage;

  /// Shown when a non-admin tries an action.
  @protected
  String get notAdminMessage;

  /// Migrations that add the database functions (shown when they are missing).
  @protected
  String get migrationNames;

  @protected
  String idOf(T item);

  /// [item] after its reports were dismissed.
  @protected
  T withoutReports(T item);

  /// Shown when [item] was deleted meanwhile.
  @protected
  String goneMessage(T item);

  /// Search and sort of the Reported list (it is loaded in one go).
  @protected
  List<T> searchAndSortReported(List<T> items, String search, ModerationSort sort);

  /// Every item with open reports, in order of its newest report.
  @protected
  Future<ModerationPage<T>> loadReported();

  /// One page of the All list, after [before].
  @protected
  Future<ModerationPage<T>> loadPage({DateTime? before});

  /// Refreshes the report counts in the header (failures only logged).
  @protected
  Future<void> loadCounts();

  /// Closes the open reports on [item]; returns how many it closed.
  @protected
  Future<int> closeReports(T item, String? note);

  /// Hides [item] and closes its reports ([notify]: tell the people involved).
  @protected
  Future<void> removeItem(T item, String? note, bool notify);

  /// IDs that leave the list when [item] is removed (a comment takes its replies).
  @protected
  Set<String> idsRemovedWith(T item) => {idOf(item)};

  /// The loaded items as they are (no search or sort).
  @protected
  List<T> get loadedItems => _items;

  // ---------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------

  ModerationView get view => _view;
  ModerationSort get sort => _sort;
  String get search => _search;
  bool get isSearching => _search.trim().isNotEmpty;
  bool get isLoading => _isLoading;

  /// Loading again while the old list is still shown (thin progress bar).
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;

  /// The last "load more" failed (it is not retried while scrolling).
  bool get loadMoreFailed => _loadMoreFailed;
  String? get error => _error;

  /// True when there were more open reports than [maxReports].
  bool get reportsCapped => _reportsCapped;

  /// True while an action on [item] is running.
  bool isBusy(T item) => _busy.contains(idOf(item));

  /// Sorts offered for the current view ("Most reported" only for Reported).
  List<ModerationSort> get sortOptions => _view == ModerationView.reported
      ? ModerationSort.values
      : const [ModerationSort.newest, ModerationSort.oldest];

  /// The list to show. Reported: all open reports are loaded, so search and
  /// sort happen here. All: the database already searched and sorted.
  List<T> get items {
    if (_view == ModerationView.all) return List.unmodifiable(_items);
    return List.unmodifiable(searchAndSortReported(_items, _search, _sort));
  }

  // ---------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------

  /// Reported only, or everything.
  void setView(ModerationView view) {
    if (view == _view) return;
    _view = view;
    if (!sortOptions.contains(_sort)) _sort = ModerationSort.newest;
    reload();
  }

  /// Search text. Reported: filters at once. All: searches the database
  /// after the admin stops typing.
  void setSearch(String text) {
    if (text == _search) return;
    _search = text;
    _searchDebounce?.cancel();
    if (_view == ModerationView.reported) {
      notifySafely();
    } else {
      _searchDebounce = Timer(const Duration(milliseconds: 400), load);
    }
  }

  /// Changes the order (All: loads again from the start).
  void setSort(ModerationSort sort) {
    if (sort == _sort || !sortOptions.contains(sort)) return;
    _sort = sort;
    if (_view == ModerationView.reported) {
      notifySafely();
    } else {
      reload();
    }
  }

  /// Empties the list and loads it again (another tab or order).
  @protected
  void reload() {
    _items = [];
    load();
  }

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  /// Loads the list again from the start (and the counts).
  Future<void> load() async {
    _searchDebounce?.cancel();
    final token = ++_loadToken;
    _isLoading = _items.isEmpty;
    _isRefreshing = !_isLoading;
    _isLoadingMore = false; // a "load more" still running is now out of date
    _loadMoreFailed = false;
    _error = null;
    notifySafely();
    try {
      final page = _view == ModerationView.reported ? await loadReported() : await loadPage();
      if (token != _loadToken) return; // a newer load (or another tab) started
      _items = page.items;
      _hasMore = page.hasMore;
      _cursor = page.cursor;
      _reportsCapped = page.capped;
    } catch (e) {
      if (token != _loadToken) return;
      debugPrint('$logName load failed: $e');
      _error = loadErrorMessage;
    } finally {
      if (token == _loadToken) {
        _isLoading = false;
        _isRefreshing = false;
        notifySafely();
      }
    }
    loadCounts();
  }

  /// Next page of the All list. After a failure it only runs again when
  /// [retry] is true (the button), not on every scroll.
  Future<void> loadMore({bool retry = false}) async {
    if (_view != ModerationView.all || !_hasMore || _isLoadingMore || _isLoading) return;
    if (_loadMoreFailed && !retry) return;
    final token = _loadToken;
    _isLoadingMore = true;
    _loadMoreFailed = false;
    notifySafely();
    try {
      final page = await loadPage(before: _cursor);
      if (token != _loadToken) return;
      final known = _items.map(idOf).toSet();
      _items = [..._items, ...page.items.where((i) => !known.contains(idOf(i)))];
      _hasMore = page.hasMore;
      _cursor = page.cursor ?? _cursor;
    } catch (e) {
      debugPrint('$logName load more failed: $e');
      if (token == _loadToken) _loadMoreFailed = true;
    } finally {
      if (token == _loadToken) {
        _isLoadingMore = false;
        notifySafely();
      }
    }
  }

  // ---------------------------------------------------------------------
  // Query helpers for the subclasses
  // ---------------------------------------------------------------------

  /// The newest open reports in [table] (at most [maxReports]).
  @protected
  Future<List<Map<String, dynamic>>> newestOpenReports(String table, String columns) async =>
      List<Map<String, dynamic>>.from(await supabase
          .from(table)
          .select(columns)
          .eq('status', 'pending')
          .order('reportedAt', ascending: false)
          .limit(maxReports));

  /// Open reports on the items with these IDs, newest first.
  @protected
  Future<List<Map<String, dynamic>>> openReportsFor(
    String table,
    String columns,
    String targetColumn,
    List<String> ids,
  ) async {
    final rows = <Map<String, dynamic>>[];
    for (final chunk in chunkIds(ids)) {
      rows.addAll(List<Map<String, dynamic>>.from(await supabase
          .from(table)
          .select(columns)
          .eq('status', 'pending')
          .inFilter(targetColumn, chunk)
          .order('reportedAt', ascending: false)));
    }
    return rows;
  }

  /// Reads one page of the All list from [query]: by time (newest or oldest
  /// first, as sorted), starting after [before]. Paging by time, not by
  /// position, means removed items or new posts can't make a page skip or
  /// repeat rows.
  @protected
  Future<List<Map<String, dynamic>>> readPage(
    PostgrestFilterBuilder<PostgrestList> query,
    DateTime? before,
  ) async {
    final oldestFirst = _sort == ModerationSort.oldest;
    if (before != null) {
      final at = before.toUtc().toIso8601String();
      query = oldestFirst ? query.gt('createdAt', at) : query.lt('createdAt', at);
    }
    return List<Map<String, dynamic>>.from(
        await query.order('createdAt', ascending: oldestFirst).limit(pageSize));
  }

  /// Wraps the items built from one [rows] page of the All list.
  @protected
  ModerationPage<T> pageOf(List<T> items, List<Map<String, dynamic>> rows) {
    final cursor = rows.isEmpty ? null : DateTime.tryParse(rows.last['createdAt']?.toString() ?? '');
    return ModerationPage<T>(items, hasMore: rows.length == pageSize && cursor != null, cursor: cursor);
  }

  /// IDs from [table] whose [nameColumn] contains [search] (at most 50;
  /// a failure gives none and is only logged).
  @protected
  Future<List<String>> idsWithName(String table, String idColumn, String nameColumn, String search) async {
    try {
      final rows = await supabase.from(table).select(idColumn).ilike(nameColumn, '%$search%').limit(50);
      return List<Map<String, dynamic>>.from(rows).map((r) => r[idColumn].toString()).toList();
    } catch (e) {
      debugPrint('$logName name search ($table) failed: $e');
      return const [];
    }
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  /// Closes the open reports on [item] and keeps it.
  /// Returns an error message, or null when it worked.
  Future<String?> dismiss(T item, {String? note}) async {
    if (!item.isReported) return null;
    return _run(item, () async {
      final closed = await closeReports(item, cleanModerationNote(note));
      _afterReportsClosed(item, removed: false);
      return closed == 0 ? 'These reports were already handled by another admin.' : null;
    });
  }

  /// Hides [item] and closes its reports. With [notify] the people involved
  /// are told (the note is never shown to them).
  /// Returns an error message, or null when it worked.
  Future<String?> remove(T item, {String? note, bool notify = true}) {
    return _run(item, () async {
      await removeItem(item, cleanModerationNote(note), notify);
      _afterReportsClosed(item, removed: true);
      return null;
    });
  }

  /// Runs [action] while [item]'s card shows a spinner. Does nothing when
  /// an action on it is already running.
  Future<String?> _run(T item, Future<String?> Function() action) async {
    final id = idOf(item);
    if (!_busy.add(id)) return null;
    notifySafely();
    try {
      return await action();
    } catch (e) {
      return _actionError(e, item);
    } finally {
      _busy.remove(id);
      notifySafely();
    }
  }

  /// Updates the list and the counts after the reports on [item] were closed.
  void _afterReportsClosed(T item, {required bool removed}) {
    final id = idOf(item);
    if (removed) {
      final gone = idsRemovedWith(item);
      _items = _items.where((i) => !gone.contains(idOf(i))).toList();
    } else if (_view == ModerationView.reported) {
      _items = _items.where((i) => idOf(i) != id).toList();
    } else {
      _items = [for (final i in _items) idOf(i) == id ? withoutReports(i) : i];
    }
    loadCounts();
  }

  /// A message to show for a failed action.
  String _actionError(Object e, T item) {
    debugPrint('$logName action failed: $e');
    if (e is PostgrestException) {
      final text = '${e.code} ${e.message}';
      if (text.contains('not_admin')) return notAdminMessage;
      if (text.contains('not_found')) {
        _items = _items.where((i) => idOf(i) != idOf(item)).toList();
        loadCounts();
        return goneMessage(item);
      }
      if (e.code == 'PGRST202' || e.code == '42883') {
        return 'The database needs an update first ($migrationNames).';
      }
    }
    return 'Unable to finish this action. Please check your connection and try again.';
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
