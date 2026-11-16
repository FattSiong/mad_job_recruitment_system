import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/session_helper.dart';
import '../../../models/job_model.dart';
import '../../../shared_widgets/login_screen.dart';
import '../../../shared_widgets/notification_bell_button.dart';
import '../../chat/screens/chat_inbox_screen.dart';
import '../../community_hub/screens/community_hub_screen.dart';
import '../controllers/applied_jobs_controller.dart';
import '../controllers/job_discovery_controller.dart';
import '../controllers/profile_controller.dart';
import '../widgets/dashboard/job_search_panel.dart';
import '../widgets/job_card.dart';
import '../widgets/job_filters.dart';
import '../widgets/load_error_view.dart';
import 'job_details_screen.dart';
import 'job_map_screen.dart';
import 'location_search_screen.dart';
import 'my_jobs_screen.dart';
import 'profile_screen.dart';
import 'qr_scanner_screen.dart';

/// The job seeker's main screen: Home (job search), My Jobs, Messages,
/// Community and Profile tabs.
class SeekerDashboard extends StatefulWidget {
  const SeekerDashboard({super.key});

  @override
  State<SeekerDashboard> createState() => _SeekerDashboardState();
}

class _SeekerDashboardState extends State<SeekerDashboard> {
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final JobDiscoveryController _controller = JobDiscoveryController();

  static const int _pageSize = 10;

  List<JobModel> _jobs = [];
  bool _isLoading = true;
  String? _loadError; // shown instead of "No jobs" when loading fails
  String? _fullName;
  bool _isFetchingMore = false;
  bool _loadMoreFailed = false;
  int _currentIndex = 0;

  // Real pagination: only one page is downloaded at a time
  JobSearchFilters _activeFilters = const JobSearchFilters();
  int _nextOffset = 0;
  bool _hasMoreJobs = false;
  int _requestId = 0; // ignores results from an older search that finishes late

  String _selectedJobType = JobFilterOptions.anyJobType;
  String _selectedDatePosted = JobFilterOptions.anyDate;
  String _selectedSalary = JobFilterOptions.anySalary;

  String? get _currentUserId => SessionHelper.currentUserId;

  StreamSubscription<Object>? _authSubscription;

  bool get _hasActiveFilters =>
      _keywordController.text.isNotEmpty ||
          _locationController.text.isNotEmpty ||
          _selectedJobType != JobFilterOptions.anyJobType ||
          _selectedDatePosted != JobFilterOptions.anyDate ||
          _selectedSalary != JobFilterOptions.anySalary;

  List<JobModel> get _visibleJobs => _jobs;

  String get _firstName {
    final name = _fullName?.trim() ?? '';
    if (name.isNotEmpty) return name.split(RegExp(r'\s+')).first;

    final email = SessionHelper.currentEmail ?? '';
    if (email.isEmpty) return 'there';
    return email.split('@').first;
  }

  @override
  void initState() {
    super.initState();
    SessionHelper.consumeManualSignOut(); // fresh login: clear any old flag
    _authSubscription = SessionHelper.onSessionEnded(_handleSignedOut);
    _scrollController.addListener(_handleScroll);
    _loadJobs();
    _loadName();
  }

  /// The session ended on its own (expired, or signed out on another device):
  /// go back to Login. A normal Logout is handled by the profile screen, which
  /// opens Login itself, so it is ignored here (otherwise Login opens twice).
  void _handleSignedOut(bool wasManual) {
    if (wasManual || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Your session has expired. Please log in again.')),
    );
  }

  /// Loads the first name for the greeting (the greeting works without it).
  Future<void> _loadName() async {
    final name = await ProfileController().fetchFullName();
    if (mounted && name != null) setState(() => _fullName = name);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _keywordController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  /// Switches tab; opening My Jobs reloads its tabs.
  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    // My Jobs tab: reload Applied + Interviews so statuses are up to date
    if (index == 1) AppliedJobsController.notifyChanged();
  }

  /// Loads the next page when the list is scrolled near the end.
  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoading || _isFetchingMore || !_hasMoreJobs) return;

    const threshold = 200.0;
    final position = _scrollController.position;

    if (position.pixels >= position.maxScrollExtent - threshold) {
      _loadMoreJobs();
    }
  }

  /// Loads the next page from the database (no artificial delay).
  Future<void> _loadMoreJobs() async {
    if (!_hasMoreJobs || _isFetchingMore || _isLoading || _loadMoreFailed) return;

    final requestId = _requestId;
    setState(() => _isFetchingMore = true);

    try {
      final page = await _controller.fetchJobsPage(
        filters: _activeFilters,
        offset: _nextOffset,
        pageSize: _pageSize,
      );
      if (!mounted || requestId != _requestId) return;
      // A job posted while scrolling shifts the pages by one: skip repeats.
      final shown = _jobs.map((j) => j.jobID).toSet();
      setState(() {
        _jobs = [..._jobs, ...page.jobs.where((j) => !shown.contains(j.jobID))];
        _nextOffset = page.nextOffset;
        _hasMoreJobs = page.hasMore;
        _isFetchingMore = false;
      });
    } on DataLoadException {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _isFetchingMore = false;
        _loadMoreFailed = true; // footer shows "Tap to retry"
      });
    }
  }

  /// "Tap to retry" after loading more jobs failed.
  void _retryLoadMore() {
    setState(() => _loadMoreFailed = false);
    _loadMoreJobs();
  }

  /// Starts a new list (first page) for [filters].
  Future<void> _startNewList(JobSearchFilters filters) async {
    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _loadError = null;
      _loadMoreFailed = false;
      _isFetchingMore = false;
      _activeFilters = filters;
    });

    try {
      final page = await _controller.fetchJobsPage(filters: filters, pageSize: _pageSize);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _jobs = page.jobs;
        _nextOffset = page.nextOffset;
        _hasMoreJobs = page.hasMore;
        _isLoading = false;
      });
    } on DataLoadException catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _jobs = [];
        _hasMoreJobs = false;
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  /// All jobs, no filters (first page).
  Future<void> _loadJobs() => _startNewList(const JobSearchFilters());

  /// Searches with the keyword, location and filters (first page).
  Future<void> _performSearch() async {
    FocusScope.of(context).unfocus();
    await _startNewList(JobSearchFilters(
      query: _keywordController.text.trim(),
      location: _locationController.text.trim(),
      jobType: _selectedJobType,
      datePosted: _selectedDatePosted,
      salary: _selectedSalary,
    ));
  }

  /// Pull to refresh: reloads with the current search.
  Future<void> _refreshJobs() async {
    if (_hasActiveFilters) {
      await _performSearch();
    } else {
      await _loadJobs();
    }
  }

  /// Clears the search and every filter, then reloads.
  Future<void> _resetFilters() async {
    setState(() {
      _selectedJobType = JobFilterOptions.anyJobType;
      _selectedDatePosted = JobFilterOptions.anyDate;
      _selectedSalary = JobFilterOptions.anySalary;
      _keywordController.clear();
      _locationController.clear();
    });

    await _loadJobs();
  }

  /// Opens the location screen; searches with what it returns.
  Future<void> _openLocationSearch() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSearchScreen(
          initialKeyword: _keywordController.text,
          initialLocation: _locationController.text,
        ),
      ),
    );

    if (!mounted) return;
    if (result != null && result is Map<String, String>) {
      setState(() {
        _keywordController.text = result['keyword'] ?? '';
        _locationController.text = result['location'] ?? '';
      });
      _performSearch();
    }
  }

  /// The current value of one filter chip.
  String _currentFilterValue(String filterType) {
    switch (filterType) {
      case JobFilterOptions.datePosted:
        return _selectedDatePosted;
      case JobFilterOptions.jobType:
        return _selectedJobType;
      default:
        return _selectedSalary;
    }
  }

  /// Opens one filter's sheet and searches with the new value.
  Future<void> _showFilterOptions(String filterType) async {
    final value = await showJobFilterSheet(
      context,
      filterType: filterType,
      currentValue: _currentFilterValue(filterType),
    );
    if (value == null || !mounted) return;

    setState(() {
      switch (filterType) {
        case JobFilterOptions.datePosted:
          _selectedDatePosted = value;
        case JobFilterOptions.jobType:
          _selectedJobType = value;
        default:
          _selectedSalary = value;
      }
    });
    _performSearch();
  }

  /// Home tab: header, search panel and the job list.
  Widget _buildHomeTab() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshJobs,
        color: AppColors.primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    _buildHeroHeader(),
                    const SizedBox(height: 24),
                    JobSearchPanel(
                      keywordController: _keywordController,
                      locationController: _locationController,
                      selectedDatePosted: _selectedDatePosted,
                      selectedJobType: _selectedJobType,
                      selectedSalary: _selectedSalary,
                      onSearch: _performSearch,
                      onReset: _resetFilters,
                      onOpenLocation: _openLocationSearch,
                      onClearLocation: () {
                        _locationController.clear();
                        _performSearch();
                      },
                      onFilterTap: _showFilterOptions,
                    ),
                    const SizedBox(height: 24),
                    _buildResultsHeader(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_loadError != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: LoadErrorView(message: _loadError!, onRetry: _refreshJobs),
              )
            else if (_jobs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 72,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No jobs match your search yet.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try a broader keyword, a different location, or clear a filter to see more roles.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      // Last slot: "load more" error, spinner or end-of-list text
                      if (index == _visibleJobs.length) {
                        if (_loadMoreFailed) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: TextButton.icon(
                                onPressed: _retryLoadMore,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text("Couldn't load more jobs. Tap to retry"),
                              ),
                            ),
                          );
                        }
                        if (_hasMoreJobs) {
                          // The footer is visible, so fetch the next page
                          // (also covers short lists that can't be scrolled)
                          WidgetsBinding.instance.addPostFrameCallback((_) => _loadMoreJobs());
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        } else {
                          // No more jobs
                          return Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 40),
                            child: Center(
                              child: Text(
                                "You've reached the end of the list!",
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }
                      }

                      // Otherwise, build the standard job card
                      final job = _visibleJobs[index];

                      return JobCard(
                        job: job,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => JobDetailsScreen(job: job),
                            ),
                          );
                        },
                      );
                    },
                    // + 1 for the slot at the bottom
                    childCount: _visibleJobs.length + 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Gradient header with the greeting and the Scan QR button.
  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.travel_explore, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Job Seeker Workspace',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              NotificationBellButton(
                onReturned: () => AppliedJobsController.notifyChanged(),
              ),
              const SizedBox(width: 10),
              _buildHeaderIconButton(
                icon: Icons.qr_code_scanner,
                tooltip: 'Scan QR',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QRScannerScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome back, $_firstName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Search roles, filter faster, and keep your applications moving.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// "Recommended Jobs" title, the Nearby Jobs button and the result count.
  Widget _buildResultsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recommended Jobs',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const JobMapScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.map, size: 18),
              label: const Text('Nearby Jobs'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                side: const BorderSide(color: AppColors.borderActive),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _hasActiveFilters
              ? 'Showing filtered roles based on your current search.'
              : 'Fresh opportunities selected from active postings.',
          style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.work_outline_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isLoading
                      ? 'Searching opportunities for you...'
                      : '${_jobs.length}${_hasMoreJobs ? '+' : ''} jobs available',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Messages tab (the chat list).
  Widget _buildMessagesTab() {
    if (_currentUserId == null) {
      return const Center(child: Text('Not logged in'));
    }

    return const ChatInboxScreen();
  }

  /// See-through round button in the header.
  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          const MyJobsScreen(),
          _buildMessagesTab(),
          _buildCommunityTab(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primarySoft,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'My Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Community',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  /// Community tab.
  Widget _buildCommunityTab() {
    if (_currentUserId == null) {
      return const Center(child: Text('Not logged in'));
    }
    return CommunityHubScreen(currentUserID: _currentUserId!);
  }
}
