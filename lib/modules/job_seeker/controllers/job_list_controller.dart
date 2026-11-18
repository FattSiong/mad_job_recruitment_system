import 'package:flutter/foundation.dart';

import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/safe_notifier.dart';
import '../../../models/job_model.dart';
import 'job_discovery_controller.dart';

/// A list of jobs for one search, a page at a time.
/// Used by the Home "Recommended Jobs" list and the search results screen.
class JobListController extends ChangeNotifier with SafeNotifier {
  JobListController({JobSearchFilters filters = const JobSearchFilters()}) : _filters = filters;

  final JobDiscoveryController _discovery = JobDiscoveryController();

  static const int pageSize = 10;

  JobSearchFilters _filters;
  List<JobModel> _jobs = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _loadMoreFailed = false;
  bool _hasMore = false;
  String? _error;
  int _nextOffset = 0;
  int _requestId = 0; // ignores results from an older search that finishes late

  JobSearchFilters get filters => _filters;
  List<JobModel> get jobs => _jobs;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;

  /// Loading the next page failed; the list footer offers "Tap to retry".
  bool get loadMoreFailed => _loadMoreFailed;
  bool get hasMore => _hasMore;

  /// Why the first page couldn't load (shown instead of "No jobs").
  String? get error => _error;

  /// "12 jobs found", "10+ jobs found" while more pages are left.
  String get countText {
    final n = _jobs.length;
    return '$n${_hasMore ? '+' : ''} job${n == 1 && !_hasMore ? '' : 's'} found';
  }

  /// Runs a new search with [filters] (first page).
  Future<void> search(JobSearchFilters filters) {
    _filters = filters;
    return load();
  }

  /// Loads the first page again. With [keepList] (pull to refresh) the old
  /// jobs stay on screen until the new ones arrive.
  Future<void> load({bool keepList = false}) async {
    final requestId = ++_requestId;
    _isLoading = !keepList || _jobs.isEmpty;
    if (!keepList) _jobs = [];
    _error = null;
    _loadMoreFailed = false;
    _isLoadingMore = false;
    notifySafely();

    try {
      final page = await _discovery.fetchJobsPage(filters: _filters, pageSize: pageSize);
      if (isDisposed || requestId != _requestId) return;
      _jobs = page.jobs;
      _nextOffset = page.nextOffset;
      _hasMore = page.hasMore;
    } on DataLoadException catch (e) {
      if (isDisposed || requestId != _requestId) return;
      _jobs = [];
      _hasMore = false;
      _error = e.message;
    }
    _isLoading = false;
    notifySafely();
  }

  /// The next page (called when the end of the list is near).
  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore || _isLoading || _loadMoreFailed) return;

    final requestId = _requestId;
    _isLoadingMore = true;
    notifySafely();

    try {
      final page = await _discovery.fetchJobsPage(
        filters: _filters,
        offset: _nextOffset,
        pageSize: pageSize,
      );
      if (isDisposed || requestId != _requestId) return;
      // A job posted while scrolling shifts the pages by one: skip repeats.
      final shown = _jobs.map((j) => j.jobID).toSet();
      _jobs = [..._jobs, ...page.jobs.where((j) => !shown.contains(j.jobID))];
      _nextOffset = page.nextOffset;
      _hasMore = page.hasMore;
    } on DataLoadException {
      if (isDisposed || requestId != _requestId) return;
      _loadMoreFailed = true;
    }
    _isLoadingMore = false;
    notifySafely();
  }

  /// "Tap to retry" after loading more jobs failed.
  void retryLoadMore() {
    _loadMoreFailed = false;
    loadMore();
  }
}
