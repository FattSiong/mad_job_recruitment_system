import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../models/job_model.dart';
import '../../community/screens/chat_list_screen.dart';
import '../../community/screens/community_dashboard.dart';
import '../controllers/applied_jobs_controller.dart';
import '../controllers/job_discovery_controller.dart';
import '../controllers/profile_controller.dart';
import '../widgets/job_card.dart';
import '../widgets/load_error_view.dart';
import 'job_details_screen.dart';
import 'job_map_screen.dart';
import 'location_search_screen.dart';
import 'my_jobs_screen.dart';
import 'profile_screen.dart';
import 'qr_scanner_screen.dart';

class SeekerDashboard extends StatefulWidget {
  const SeekerDashboard({super.key});

  @override
  State<SeekerDashboard> createState() => _SeekerDashboardState();
}

class _SeekerDashboardState extends State<SeekerDashboard> {
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _salaryInputController = TextEditingController();
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

  String _selectedJobType = 'All';
  String _selectedDatePosted = 'All time';
  String _selectedSalary = 'Any';

  User? get _currentUser => Supabase.instance.client.auth.currentUser;

  bool get _hasActiveFilters =>
      _keywordController.text.isNotEmpty ||
          _locationController.text.isNotEmpty ||
          _selectedJobType != 'All' ||
          _selectedDatePosted != 'All time' ||
          _selectedSalary != 'Any';

  List<JobModel> get _visibleJobs => _jobs;

  String get _firstName {
    final name = _fullName?.trim() ?? '';
    if (name.isNotEmpty) return name.split(RegExp(r'\s+')).first;

    final email = _currentUser?.email ?? '';
    if (email.isEmpty) return 'there';
    return email.split('@').first;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadJobs();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await ProfileController().fetchFullName();
    if (mounted && name != null) setState(() => _fullName = name);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _keywordController.dispose();
    _locationController.dispose();
    _salaryInputController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    // My Jobs tab: reload Applied + Interviews so statuses are up to date
    if (index == 1) AppliedJobsController.notifyChanged();
  }

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
      setState(() {
        _jobs = [..._jobs, ...page.jobs];
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

  Future<void> _loadJobs() => _startNewList(const JobSearchFilters());

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

  Future<void> _refreshJobs() async {
    if (_hasActiveFilters) {
      await _performSearch();
    } else {
      await _loadJobs();
    }
  }

  Future<void> _resetFilters() async {
    setState(() {
      _selectedJobType = 'All';
      _selectedDatePosted = 'All time';
      _selectedSalary = 'Any';
      _keywordController.clear();
      _locationController.clear();
    });

    await _loadJobs();
  }

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

    if (result != null && result is Map<String, String>) {
      setState(() {
        _keywordController.text = result['keyword'] ?? '';
        _locationController.text = result['location'] ?? '';
      });
      _performSearch();
    }
  }

  void _showFilterOptions(String filterType) {
    List<String> options = [];
    String currentValue = '';

    if (filterType == 'Date posted') {
      options = [
        'All time',
        'Last 24 hours',
        'Last 3 days',
        'Last 7 days',
        'Last 14 days',
      ];
      currentValue = _selectedDatePosted;
    } else if (filterType == 'Job type') {
      options = ['All', 'Full-time', 'Part-time'];
      currentValue = _selectedJobType;
    } else if (filterType == 'Salary') {
      options = ['Any', 'RM1000', 'RM2000', 'RM3000', 'RM4000', 'RM5000'];
      currentValue = _selectedSalary;
      _salaryInputController.text =
          _selectedSalary.replaceAll(RegExp(r'[^0-9]'), '');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Filter by $filterType',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                if (filterType == 'Salary') ...[
                  const Text(
                    'Enter custom minimum salary',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _salaryInputController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'e.g. 3500',
                      prefixIcon: const Padding(
                        padding: EdgeInsetsDirectional.only(start: 16, end: 8),
                        child: Align(
                          widthFactor: 1,
                          heightFactor: 1,
                          child: Text(
                            'RM',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _salaryInputController.clear();
                            setState(() => _selectedSalary = 'Any');
                            Navigator.pop(context);
                            _performSearch();
                          },
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final typed = _salaryInputController.text.trim();
                            if (typed.isNotEmpty) {
                              final salary = int.tryParse(typed);
                              if (salary == null || salary <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid salary amount.')),
                                );
                                return;
                              }
                            }
                            setState(() {
                              _selectedSalary = typed.isNotEmpty ? 'RM $typed' : 'Any';
                            });
                            Navigator.pop(context);
                            _performSearch();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Or select a suggested range',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioGroup<String>(
                    groupValue: currentValue,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedSalary = value);
                      Navigator.pop(context);
                      _performSearch();
                    },
                    child: Column(
                      children: options
                          .map(
                            (option) => RadioListTile<String>(
                          value: option,
                          title: Text(option),
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                          .toList(),
                    ),
                  ),
                ] else ...[
                  RadioGroup<String>(
                    groupValue: currentValue,
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        if (filterType == 'Date posted') {
                          _selectedDatePosted = value;
                        } else if (filterType == 'Job type') {
                          _selectedJobType = value;
                        }
                      });

                      Navigator.pop(context);
                      _performSearch();
                    },
                    child: Column(
                      children: options
                          .map(
                            (option) => RadioListTile<String>(
                          value: option,
                          title: Text(option),
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value, String defaultValue) {
    final isActive = value != defaultValue;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(isActive ? value : label),
        selected: isActive,
        onSelected: (_) => _showFilterOptions(label),
        selectedColor: AppColors.primarySoft,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: isActive ? AppColors.primary : AppColors.textDark,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isActive
                ? const Color(0xFFB8D1EE)
                : AppColors.border,
          ),
        ),
      ),
    );
  }

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
                    _buildSearchPanel(),
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
                      // 👉 Check if we are at the very bottom slot
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
                          // 👉 Show "End of list" text if there are no more jobs
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
                    // 👉 Changed to ALWAYS add 1 extra slot for either the loader or the text
                    childCount: _visibleJobs.length + 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildSearchPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search smarter',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Refine by role, location, job type, posted date, and salary.',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _keywordController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _performSearch(),
            decoration: _searchInputDecoration(
              hint: 'Job title, keywords, or company',
              icon: Icons.search,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            readOnly: true,
            onTap: _openLocationSearch,
            decoration: _searchInputDecoration(
              hint: 'City, state, or postcode',
              icon: Icons.location_on_outlined,
              suffix: _locationController.text.isNotEmpty
                  ? IconButton(
                onPressed: () {
                  _locationController.clear();
                  _performSearch();
                },
                icon: const Icon(Icons.close, size: 18),
              )
                  : IconButton(
                onPressed: _openLocationSearch,
                icon: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _performSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Search Jobs'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: const BorderSide(color: Color(0xFFB8D1EE)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'Date posted',
                  _selectedDatePosted,
                  'All time',
                ),
                _buildFilterChip('Job type', _selectedJobType, 'All'),
                _buildFilterChip('Salary', _selectedSalary, 'Any'),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
                side: const BorderSide(color: Color(0xFFB8D1EE)),
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

  Widget _buildMessagesTab() {
    if (_currentUser == null) {
      return const Center(child: Text('Not logged in'));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: ChatListScreen(currentUserID: _currentUser!.id),
    );
  }

  InputDecoration _searchInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

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

  Widget _buildCommunityTab() {
    if (_currentUser == null) {
      return const Center(child: Text('Not logged in'));
    }
    return CommunityDashboard(currentUserID: _currentUser!.id);
  }
}
