import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../models/chat_room_model.dart';
import '../../../models/job_moderation_item_model.dart';
import '../../../services/user_directory.dart';

/// Which jobs Admin > Jobs lists.
enum JobModerationView {
  /// Jobs with open reports, most recently reported first.
  reported,

  /// Every job that is not removed, newest first (reported ones marked).
  all,
}

/// Admin > Jobs: reported and all job posts, and the admin's actions on
/// them (dismiss the reports, or remove the job).
///
/// The actions are database functions (migration 20261118000000), so each
/// one checks the caller is an admin, runs in one transaction and says when
/// nothing was changed.
class AdminJobModerationController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  static const int pageSize = 20;

  /// Open reports read at most (the newest ones).
  static const int maxReports = 500;

  static const String _jobColumns =
      'jobID, companyID, employerID, title, description, salaryRange, status, createdAt, jobType, '
      'minExperienceYears, locationName, expiresAt, workplaceType, workingPeriod, qualification, '
      'vacancies, latitude, longitude, Company(name)';
  static const String _reportColumns =
      'reportJobID, jobID, reporterID, reportCategory, additionalDetails, reportedAt';

  JobModerationView _view = JobModerationView.reported;
  ModerationSort _sort = ModerationSort.newest;
  String _search = '';
  Timer? _searchDebounce;
  final Map<String, ({List<String> companies, List<String> employers})> _nameMatches = {};
  List<JobModerationItem> _items = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _loadMoreFailed = false;
  DateTime? _cursor; // All list: the next page starts after this time
  bool _reportsCapped = false;
  String? _error;
  int _reportedJobs = 0;
  final Set<String> _busy = {};
  int _loadToken = 0;
  bool _disposed = false;

  JobModerationView get view => _view;
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

  /// Jobs with open reports (for the header and the badge).
  int get reportedJobs => _reportedJobs;

  /// True while an action on [item] is running.
  bool isBusy(JobModerationItem item) => _busy.contains(item.id);

  /// Sorts offered for the current view ("Most reported" only for Reported).
  List<ModerationSort> get sortOptions => _view == JobModerationView.reported
      ? ModerationSort.values
      : const [ModerationSort.newest, ModerationSort.oldest];

  /// The list to show. Reported: all open reports are loaded, so search and
  /// sort happen here. All: the database already searched and sorted.
  List<JobModerationItem> get items {
    if (_view == JobModerationView.all) return List.unmodifiable(_items);
    return List.unmodifiable(JobModerationItem.searchAndSortReported(_items, _search, _sort));
  }

  // ---------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------

  /// Reported only, or every job.
  void setView(JobModerationView view) {
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
    if (_view == JobModerationView.reported) {
      _notify();
    } else {
      _searchDebounce = Timer(const Duration(milliseconds: 400), load);
    }
  }

  /// Changes the order (All: loads again from the start).
  void setSort(ModerationSort sort) {
    if (sort == _sort || !sortOptions.contains(sort)) return;
    _sort = sort;
    if (_view == JobModerationView.reported) {
      _notify();
    } else {
      _items = [];
      load();
    }
  }

  // ---------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------

  /// Loads the list again from the start (and the count of reported jobs).
  Future<void> load() async {
    _searchDebounce?.cancel();
    final token = ++_loadToken;
    _isLoading = _items.isEmpty;
    _isRefreshing = !_isLoading;
    _isLoadingMore = false; // a "load more" still running is now out of date
    _loadMoreFailed = false;
    _error = null;
    _notify();
    try {
      final page = _view == JobModerationView.reported ? await _loadReported() : await _loadPage();
      if (token != _loadToken) return; // a newer load started
      _items = page.items;
      _hasMore = page.hasMore;
      _cursor = page.cursor;
      _reportsCapped = page.capped;
    } catch (e) {
      if (token != _loadToken) return;
      debugPrint('Admin jobs load failed: $e');
      _error = 'Unable to load job posts. Please check your connection and try again.';
    } finally {
      if (token == _loadToken) {
        _isLoading = false;
        _isRefreshing = false;
        _notify();
      }
    }
    _loadCount();
  }

  /// Next page of the All list. After a failure it only runs again when
  /// [retry] is true (the button), not on every scroll.
  Future<void> loadMore({bool retry = false}) async {
    if (_view != JobModerationView.all || !_hasMore || _isLoadingMore || _isLoading) return;
    if (_loadMoreFailed && !retry) return;
    final token = _loadToken;
    _isLoadingMore = true;
    _loadMoreFailed = false;
    _notify();
    try {
      final page = await _loadPage(before: _cursor);
      if (token != _loadToken) return;
      final known = _items.map((i) => i.id).toSet();
      _items = [..._items, ...page.items.where((i) => !known.contains(i.id))];
      _hasMore = page.hasMore;
      _cursor = page.cursor ?? _cursor;
    } catch (e) {
      debugPrint('Admin jobs load more failed: $e');
      if (token == _loadToken) _loadMoreFailed = true;
    } finally {
      if (token == _loadToken) {
        _isLoadingMore = false;
        _notify();
      }
    }
  }

  /// How many jobs have open reports, the same way the dashboard counts
  /// them (failures only logged).
  Future<void> _loadCount() async {
    try {
      final rows = await _supabase.from(TableConstants.reportedJob).select('jobID').eq('status', 'pending');
      _reportedJobs = List<Map<String, dynamic>>.from(rows).map((r) => r['jobID'].toString()).toSet().length;
      _notify();
    } catch (e) {
      debugPrint('Admin jobs count failed: $e');
    }
  }

  /// Jobs with open reports, in order of their newest report. Jobs that
  /// were already removed are kept, so their leftover reports can be closed.
  Future<_Page> _loadReported() async {
    final reportRows = List<Map<String, dynamic>>.from(await _supabase
        .from(TableConstants.reportedJob)
        .select(_reportColumns)
        .eq('status', 'pending')
        .order('reportedAt', ascending: false)
        .limit(maxReports));
    final capped = reportRows.length >= maxReports;

    final ids = <String>[];
    final seen = <String>{};
    for (final r in reportRows) {
      final id = r['jobID'].toString();
      if (seen.add(id)) ids.add(id);
    }
    if (ids.isEmpty) return _Page(const [], hasMore: false, capped: capped, cursor: null);

    final jobRows = <Map<String, dynamic>>[];
    for (final chunk in _chunks(ids)) {
      jobRows.addAll(List<Map<String, dynamic>>.from(
          await _supabase.from(TableConstants.job).select(_jobColumns).inFilter('jobID', chunk)));
    }
    final byId = {for (final r in jobRows) r['jobID'].toString(): r};
    final items = await _build([for (final id in ids) if (byId[id] != null) byId[id]!], reportRows);
    return _Page(items, hasMore: false, capped: capped, cursor: null);
  }

  /// One page of jobs that are not removed, by time (newest or oldest
  /// first), older / newer than [before].
  Future<_Page> _loadPage({DateTime? before}) async {
    final oldestFirst = _sort == ModerationSort.oldest;
    final search = _cleanSearch(_search);
    PostgrestFilterBuilder<PostgrestList> query =
        _supabase.from(TableConstants.job).select(_jobColumns).neq('status', 'deleted');

    if (search.isNotEmpty) {
      // Title, description or place, or the company / employer name
      final names = await _namesMatching(search);
      query = query.or([
        'title.ilike.*$search*',
        'description.ilike.*$search*',
        'locationName.ilike.*$search*',
        if (names.companies.isNotEmpty) 'companyID.in.(${names.companies.join(',')})',
        if (names.employers.isNotEmpty) 'employerID.in.(${names.employers.join(',')})',
      ].join(','));
    }
    if (before != null) {
      final at = before.toUtc().toIso8601String();
      query = oldestFirst ? query.gt('createdAt', at) : query.lt('createdAt', at);
    }
    final rows = List<Map<String, dynamic>>.from(
        await query.order('createdAt', ascending: oldestFirst).limit(pageSize));
    if (rows.isEmpty) return const _Page([], hasMore: false, capped: false, cursor: null);
    final cursor = DateTime.tryParse(rows.last['createdAt']?.toString() ?? '');

    final ids = rows.map((r) => r['jobID'].toString()).toList();
    final reportRows = <Map<String, dynamic>>[];
    for (final chunk in _chunks(ids)) {
      reportRows.addAll(List<Map<String, dynamic>>.from(await _supabase
          .from(TableConstants.reportedJob)
          .select(_reportColumns)
          .eq('status', 'pending')
          .inFilter('jobID', chunk)
          .order('reportedAt', ascending: false)));
    }
    return _Page(
      await _build(rows, reportRows),
      hasMore: rows.length == pageSize && cursor != null,
      capped: false,
      cursor: cursor,
    );
  }

  /// Turns job rows into items, with employer / reporter names and the
  /// reports on each job.
  Future<List<JobModerationItem>> _build(
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> reportRows,
  ) async {
    final people = await UserDirectory.fetch([
      ...rows.map((r) => r['employerID']?.toString() ?? ''),
      ...reportRows.map((r) => r['reporterID']?.toString() ?? ''),
    ]);
    ChatParticipant person(String id, String role) =>
        people[id] ?? ChatParticipant(userID: id, displayName: 'Unknown user', role: role);

    final reportsByJob = <String, List<ContentReport>>{};
    for (final r in reportRows) {
      reportsByJob.putIfAbsent(r['jobID'].toString(), () => []).add(ContentReport.fromJson(
            r,
            idColumn: 'reportJobID',
            reporter: person(r['reporterID']?.toString() ?? '', 'job_seeker'),
          ));
    }

    final items = <JobModerationItem>[];
    for (final r in rows) {
      try {
        items.add(JobModerationItem.fromJson(
          r,
          employer: person(r['employerID']?.toString() ?? '', 'employer'),
          reports: reportsByJob[r['jobID'].toString()] ?? const [],
        ));
      } catch (e) {
        debugPrint('Admin jobs: skipped a job that could not be read ($e)'); // e.g. missing title
      }
    }
    return items;
  }

  /// Company and employer IDs whose name contains [search] (at most 50
  /// each; remembered while the screen is open).
  Future<({List<String> companies, List<String> employers})> _namesMatching(String search) async {
    final key = search.toLowerCase();
    final known = _nameMatches[key];
    if (known != null) return known;

    Future<List<String>> ids(String table, String idColumn, String nameColumn) async {
      try {
        final rows = await _supabase.from(table).select(idColumn).ilike(nameColumn, '%$search%').limit(50);
        return List<Map<String, dynamic>>.from(rows).map((r) => r[idColumn].toString()).toList();
      } catch (e) {
        debugPrint('Admin jobs name search ($table) failed: $e');
        return const [];
      }
    }

    final found = await Future.wait([
      ids(TableConstants.company, 'companyID', 'name'),
      ids(TableConstants.employer, 'employerID', 'fullName'),
    ]);
    final result = (companies: found[0], employers: found[1]);
    _nameMatches[key] = result;
    return result;
  }

  /// Search text that is safe inside the database filter (characters that
  /// mean something there are turned into spaces).
  static String _cleanSearch(String text) =>
      text.replaceAll(RegExp(r'[,()*%\\"\x27:]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Splits IDs into groups so the request address stays short.
  static Iterable<List<String>> _chunks(List<String> ids, [int size = 100]) sync* {
    for (var i = 0; i < ids.length; i += size) {
      yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
    }
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  /// Closes the open reports on [item] and keeps the job.
  /// Returns an error message, or null when it worked.
  Future<String?> dismiss(JobModerationItem item, {String? note}) async {
    if (!item.isReported || !_busy.add(item.id)) return null;
    _notify();
    try {
      final closed = await _supabase.rpc('admin_dismiss_job_reports', params: {
        'p_job_id': item.id,
        'p_note': _cleanNote(note),
      });
      _afterAction(item, removed: false);
      if ((closed as num? ?? 0) == 0) return 'These reports were already handled by another admin.';
      return null;
    } catch (e) {
      return _actionError(e, item);
    } finally {
      _busy.remove(item.id);
      _notify();
    }
  }

  /// Hides the job from everyone and closes its reports. With
  /// [notifyPeople] the employer gets the report reasons (not the note) and
  /// everyone with an open application is told the job is gone.
  /// Returns an error message, or null when it worked.
  Future<String?> remove(JobModerationItem item, {String? note, bool notifyPeople = true}) async {
    if (!_busy.add(item.id)) return null;
    _notify();
    try {
      await _supabase.rpc('admin_remove_job', params: {
        'p_job_id': item.id,
        'p_note': _cleanNote(note),
        'p_notify': notifyPeople,
      });
      _afterAction(item, removed: true);
      return null;
    } catch (e) {
      return _actionError(e, item);
    } finally {
      _busy.remove(item.id);
      _notify();
    }
  }

  /// Updates the list and the count after an action on [item].
  void _afterAction(JobModerationItem item, {required bool removed}) {
    if (removed || _view == JobModerationView.reported) {
      _items = _items.where((i) => i.id != item.id).toList();
    } else {
      _items = [for (final i in _items) i.id == item.id ? i.withoutReports() : i];
    }
    _loadCount();
  }

  String? _cleanNote(String? note) {
    final text = note?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// A message to show for a failed action.
  String _actionError(Object e, JobModerationItem item) {
    debugPrint('Admin jobs action failed: $e');
    if (e is PostgrestException) {
      final text = '${e.code} ${e.message}';
      if (text.contains('not_admin')) return 'Only admins can moderate job posts.';
      if (text.contains('not_found')) {
        _items = _items.where((i) => i.id != item.id).toList();
        _loadCount();
        return 'This job no longer exists.';
      }
      if (e.code == 'PGRST202' || e.code == '42883') {
        return 'The database needs an update first (migration 20261118000000).';
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
  final List<JobModerationItem> items;
  final bool hasMore;
  final bool capped;

  /// Time of the last row (All list), where the next page starts.
  final DateTime? cursor;

  const _Page(this.items, {required this.hasMore, required this.capped, required this.cursor});
}
