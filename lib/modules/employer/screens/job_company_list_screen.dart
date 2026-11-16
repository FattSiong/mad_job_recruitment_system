import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/company_model.dart';
import '../../../models/job_model.dart';
import '../../../services/employer_service.dart';
import 'create_job_screen.dart';
import 'job_detail_screen.dart';

class ManageJobsCompanyListScreen extends StatefulWidget {
  const ManageJobsCompanyListScreen({super.key});

  @override
  State<ManageJobsCompanyListScreen> createState() =>
      _ManageJobsCompanyListScreenState();
}

class _ManageJobsCompanyListScreenState
    extends State<ManageJobsCompanyListScreen> {
  final EmployerService _employerService = EmployerService();
  final TextEditingController _searchController = TextEditingController();

  List<CompanyModel> _companies = [];
  List<JobModel> _jobs = [];
  Map<String, Map<String, int>> _applicantCountsByJobId = {};
  bool _isLoading = true;
  String _selectedCompanyId = 'all';
  _JobsTab _selectedTab = _JobsTab.all;

  // Search, Filter & Sort state
  String _searchQuery = '';
  _JobSortOption _sortOption = _JobSortOption.newest;
  _JobStatusFilter _statusFilter = _JobStatusFilter.all;
  _JobExpiryFilter _expiryFilter = _JobExpiryFilter.all;
  _ApplicantFilter _applicantFilter = _ApplicantFilter.all;
  String _jobTypeFilter = 'all';
  String _workplaceFilter = 'all';

  String? get _currentEmployerId =>
      Supabase.instance.client.auth.currentUser?.id;

  CompanyModel? get _selectedCompany {
    if (_selectedCompanyId == 'all') return null;
    for (final company in _companies) {
      if (company.companyID == _selectedCompanyId) return company;
    }
    return null;
  }

  List<CompanyModel> get _verifiedCompanies =>
      _companies.where((company) => company.isApprovedForJobPosting).toList();

  int get _activeFilterCount {
    int count = 0;
    if (_sortOption != _JobSortOption.newest) count++;
    if (_statusFilter != _JobStatusFilter.all) count++;
    if (_expiryFilter != _JobExpiryFilter.all) count++;
    if (_applicantFilter != _ApplicantFilter.all) count++;
    if (_jobTypeFilter != 'all') count++;
    if (_workplaceFilter != 'all') count++;
    return count;
  }

  bool get _hasActiveSearchOrFilter =>
      _searchQuery.trim().isNotEmpty || _activeFilterCount > 0;

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearAllSearchAndFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _sortOption = _JobSortOption.newest;
      _statusFilter = _JobStatusFilter.all;
      _expiryFilter = _JobExpiryFilter.all;
      _applicantFilter = _ApplicantFilter.all;
      _jobTypeFilter = 'all';
      _workplaceFilter = 'all';
    });
  }

  Future<void> _loadWorkspace() async {
    setState(() => _isLoading = true);

    final companies = await _employerService.getMyAcceptedCompanies();
    final jobs = <JobModel>[];

    for (final company in companies) {
      final companyId = company.companyID;
      if (companyId == null) continue;

      final companyJobs = await _employerService.getJobsByCompanyId(
        companyId,
        includeDeleted: true,
      );
      for (final job in companyJobs) {
        jobs.add(
          JobModel(
            jobID: job.jobID,
            companyID: job.companyID,
            employerID: job.employerID,
            title: job.title,
            description: job.description,
            latitude: job.latitude,
            longitude: job.longitude,
            salaryRange: job.salaryRange,
            status: job.status,
            createdAt: job.createdAt,
            minExperienceYears: job.minExperienceYears,
            jobType: job.jobType,
            locationName: job.locationName,
            companyName: job.companyName ?? company.name,
            expiresAt: job.expiresAt,
            workplaceType: job.workplaceType,
            workingPeriod: job.workingPeriod,
            qualification: job.qualification,
            vacancies: job.vacancies,
          ),
        );
      }
    }

    final jobIds = jobs
        .map((job) => job.jobID)
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toList();
    final applicantCounts =
        await _employerService.getApplicantCountsForJobs(jobIds);

    if (!mounted) return;

    setState(() {
      _companies = companies;
      _jobs = jobs;
      _applicantCountsByJobId = applicantCounts;
      _isLoading = false;
      if (_selectedCompanyId != 'all' &&
          !_companies.any(
            (company) => company.companyID == _selectedCompanyId,
          )) {
        _selectedCompanyId = 'all';
      }
    });
  }

  /// Jobs scoped only by Company Filter + Ownership Tab (before search/filters).
  List<JobModel> _baseJobsForTab(_JobsTab tab) {
    final currentEmployerId = _currentEmployerId;

    return _jobs.where((job) {
      final matchesCompany = _selectedCompanyId == 'all'
          ? true
          : job.companyID == _selectedCompanyId;

      if (!matchesCompany) return false;

      switch (tab) {
        case _JobsTab.all:
          return true;
        case _JobsTab.mine:
          return currentEmployerId != null &&
              job.employerID == currentEmployerId;
        case _JobsTab.team:
          return currentEmployerId != null &&
              job.employerID != currentEmployerId;
      }
    }).toList();
  }

  bool _isJobExpiringSoon(JobModel job) {
    if (job.status.toLowerCase() == 'deleted') return false;
    if (job.expiresAt == null || job.isExpired) return false;
    final remaining = job.expiresAt!.toLocal().difference(DateTime.now());
    return remaining.inSeconds > 0 && remaining.inHours <= 24 * 7;
  }

  List<JobModel> _applyFiltersAndSort(
    List<JobModel> source, {
    required String query,
    required _JobSortOption sortOption,
    required _JobStatusFilter statusFilter,
    required _JobExpiryFilter expiryFilter,
    required _ApplicantFilter applicantFilter,
    required String jobTypeFilter,
    required String workplaceFilter,
  }) {
    final normalizedQuery = query.trim().toLowerCase();

    final filtered = source.where((job) {
      // 1. Keyword Search
      if (normalizedQuery.isNotEmpty) {
        final companyName = _resolveCompanyName(job).toLowerCase();
        final title = job.title.toLowerCase();
        final location = (job.locationName ?? '').toLowerCase();
        final description = job.description.toLowerCase();
        final jobType = job.jobType.toLowerCase();
        final workplace = job.workplaceType.toLowerCase();

        final matchesSearch = title.contains(normalizedQuery) ||
            companyName.contains(normalizedQuery) ||
            location.contains(normalizedQuery) ||
            description.contains(normalizedQuery) ||
            jobType.contains(normalizedQuery) ||
            workplace.contains(normalizedQuery);
        if (!matchesSearch) return false;
      }

      // 2. Job Status Filter
      final status = job.status.trim().toLowerCase();
      switch (statusFilter) {
        case _JobStatusFilter.all:
          break;
        case _JobStatusFilter.active:
          if (status != 'active') return false;
          break;
        case _JobStatusFilter.inactive:
          if (status != 'inactive') return false;
          break;
        case _JobStatusFilter.deleted:
          if (status != 'deleted') return false;
          break;
      }

      // 3. Expiry Status Filter
      switch (expiryFilter) {
        case _JobExpiryFilter.all:
          break;
        case _JobExpiryFilter.notExpired:
          if (job.isExpired) return false;
          break;
        case _JobExpiryFilter.expiringSoon:
          if (!_isJobExpiringSoon(job)) return false;
          break;
        case _JobExpiryFilter.expired:
          if (!job.isExpired) return false;
          break;
      }

      // 4. Application Activity Filter
      final counts = _applicantCountsByJobId[job.jobID ?? ''];
      final totalApplied = counts?['total'] ?? 0;
      final pendingCount = counts?['pending'] ?? 0;
      switch (applicantFilter) {
        case _ApplicantFilter.all:
          break;
        case _ApplicantFilter.needsReview:
          if (pendingCount <= 0) return false;
          break;
        case _ApplicantFilter.hasApplicants:
          if (totalApplied <= 0) return false;
          break;
        case _ApplicantFilter.noApplicants:
          if (totalApplied != 0) return false;
          break;
      }

      // 5. Job Type Filter
      if (jobTypeFilter != 'all' &&
          job.jobType.toLowerCase() != jobTypeFilter.toLowerCase()) {
        return false;
      }

      // 6. Work Arrangement Filter
      if (workplaceFilter != 'all' &&
          job.workplaceType.toLowerCase() != workplaceFilter.toLowerCase()) {
        return false;
      }

      return true;
    }).toList();

    // 7. Sort Order
    filtered.sort((a, b) {
      final countsA = _applicantCountsByJobId[a.jobID ?? ''];
      final countsB = _applicantCountsByJobId[b.jobID ?? ''];
      final totalA = countsA?['total'] ?? 0;
      final totalB = countsB?['total'] ?? 0;
      final pendingA = countsA?['pending'] ?? 0;
      final pendingB = countsB?['pending'] ?? 0;

      int compareCreatedAtDesc() {
        final dateA = a.createdAt;
        final dateB = b.createdAt;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      }

      switch (sortOption) {
        case _JobSortOption.newest:
          return compareCreatedAtDesc();
        case _JobSortOption.oldest:
          final dateA = a.createdAt;
          final dateB = b.createdAt;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateA.compareTo(dateB);
        case _JobSortOption.expiringSoonest:
          int bucket(JobModel job) {
            if (job.expiresAt != null && !job.isExpired) return 0;
            if (job.expiresAt == null) return 1;
            return 2; // already expired
          }

          final bucketCmp = bucket(a).compareTo(bucket(b));
          if (bucketCmp != 0) return bucketCmp;

          if (a.expiresAt != null && b.expiresAt != null) {
            if (!a.isExpired && !b.isExpired) {
              return a.expiresAt!.compareTo(b.expiresAt!);
            }
            return b.expiresAt!.compareTo(a.expiresAt!);
          }
          return compareCreatedAtDesc();
        case _JobSortOption.mostApplied:
          final totalCmp = totalB.compareTo(totalA);
          if (totalCmp != 0) return totalCmp;
          final pendingCmp = pendingB.compareTo(pendingA);
          if (pendingCmp != 0) return pendingCmp;
          return compareCreatedAtDesc();
        case _JobSortOption.mostPending:
          final pendingCmp = pendingB.compareTo(pendingA);
          if (pendingCmp != 0) return pendingCmp;
          final totalCmp = totalB.compareTo(totalA);
          if (totalCmp != 0) return totalCmp;
          return compareCreatedAtDesc();
      }
    });

    return filtered;
  }

  List<JobModel> _filteredJobsForTab(_JobsTab tab) {
    return _applyFiltersAndSort(
      _baseJobsForTab(tab),
      query: _searchQuery,
      sortOption: _sortOption,
      statusFilter: _statusFilter,
      expiryFilter: _expiryFilter,
      applicantFilter: _applicantFilter,
      jobTypeFilter: _jobTypeFilter,
      workplaceFilter: _workplaceFilter,
    );
  }

  Future<void> _openJob(JobModel job) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => JobDetailScreen(job: job)),
    );

    if (!mounted) return;
    await _loadWorkspace();
  }

  Future<void> _openCreateJob() async {
    CompanyModel? company = _selectedCompany;

    // If a specific company filter is active, ensure that company is verified.
    if (company != null && !company.isApprovedForJobPosting) {
      if (!mounted) return;
      final statusLabel = company.verificationStatus.trim().isEmpty
          ? 'unverified'
          : company.verificationStatus.trim().toLowerCase();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${company.name}" is $statusLabel. Only verified companies can post jobs.',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final verifiedList = _verifiedCompanies;
    if (verifiedList.isEmpty) {
      // Opening CreateJobScreen with no verified companies shows the "No Verified Companies" empty state.
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CreateJobScreen()),
      );
      if (!mounted) return;
      await _loadWorkspace();
      return;
    }

    if (company == null && verifiedList.length == 1) {
      company = verifiedList.first;
    }

    company ??= await _showCompanyPickerSheet(verifiedList);

    if (company == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateJobScreen(preselectedCompany: company),
      ),
    );

    if (!mounted) return;
    await _loadWorkspace();
  }

  Future<CompanyModel?> _showCompanyPickerSheet(
    List<CompanyModel> verifiedCompanies,
  ) async {
    return showModalBottomSheet<CompanyModel>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                        color: const Color(0xFFD6DEE8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Choose a Verified Company',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2433),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pick the verified company you want to post a new job for.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Color(0xFF687588),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...verifiedCompanies.map(
                    (company) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () => Navigator.pop(context, company),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFFDCEBFB),
                                  child: Text(
                                    company.name.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF163B65),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        company.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1B2433),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'SSM: ${company.registrationNumber}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF687588),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: Color(0xFF163B65),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFilterBottomSheet() async {
    _JobSortOption tempSort = _sortOption;
    _JobStatusFilter tempStatus = _statusFilter;
    _JobExpiryFilter tempExpiry = _expiryFilter;
    _ApplicantFilter tempApplicants = _applicantFilter;
    String tempJobType = _jobTypeFilter;
    String tempWorkplace = _workplaceFilter;

    final baseTabJobs = _baseJobsForTab(_selectedTab);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final matchingCount = _applyFiltersAndSort(
              baseTabJobs,
              query: _searchQuery,
              sortOption: tempSort,
              statusFilter: tempStatus,
              expiryFilter: tempExpiry,
              applicantFilter: tempApplicants,
              jobTypeFilter: tempJobType,
              workplaceFilter: tempWorkplace,
            ).length;

            final bool hasModalFilters = tempSort != _JobSortOption.newest ||
                tempStatus != _JobStatusFilter.all ||
                tempExpiry != _JobExpiryFilter.all ||
                tempApplicants != _ApplicantFilter.all ||
                tempJobType != 'all' ||
                tempWorkplace != 'all';

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.84,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                      child: Column(
                        children: [
                          Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD6DEE8),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Filter & Sort Jobs',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1B2433),
                                  ),
                                ),
                              ),
                              if (hasModalFilters)
                                TextButton(
                                  onPressed: () {
                                    setModalState(() {
                                      tempSort = _JobSortOption.newest;
                                      tempStatus = _JobStatusFilter.all;
                                      tempExpiry = _JobExpiryFilter.all;
                                      tempApplicants = _ApplicantFilter.all;
                                      tempJobType = 'all';
                                      tempWorkplace = 'all';
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFC24E4E),
                                  ),
                                  child: const Text(
                                    'Reset',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              IconButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Color(0xFF687588),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE8EEF5)),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFilterSheetSection(
                              title: 'Sort By',
                              children: _JobSortOption.values.map((option) {
                                return _buildModalChoiceChip(
                                  label: _sortOptionLabel(option),
                                  isSelected: tempSort == option,
                                  onTap: () =>
                                      setModalState(() => tempSort = option),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            _buildFilterSheetSection(
                              title: 'Job Status',
                              children: _JobStatusFilter.values.map((filter) {
                                return _buildModalChoiceChip(
                                  label: _statusFilterLabel(filter),
                                  isSelected: tempStatus == filter,
                                  onTap: () =>
                                      setModalState(() => tempStatus = filter),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            _buildFilterSheetSection(
                              title: 'Expiry Status',
                              children: _JobExpiryFilter.values.map((filter) {
                                return _buildModalChoiceChip(
                                  label: _expiryFilterLabel(filter),
                                  isSelected: tempExpiry == filter,
                                  onTap: () =>
                                      setModalState(() => tempExpiry = filter),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            _buildFilterSheetSection(
                              title: 'Application Activity',
                              children: _ApplicantFilter.values.map((filter) {
                                return _buildModalChoiceChip(
                                  label: _applicantFilterLabel(filter),
                                  isSelected: tempApplicants == filter,
                                  onTap: () => setModalState(
                                    () => tempApplicants = filter,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            _buildFilterSheetSection(
                              title: 'Job Type',
                              children: [
                                ('all', 'All Types'),
                                ('Full-time', 'Full-time'),
                                ('Part-time', 'Part-time'),
                              ].map((entry) {
                                return _buildModalChoiceChip(
                                  label: entry.$2,
                                  isSelected: tempJobType == entry.$1,
                                  onTap: () => setModalState(
                                    () => tempJobType = entry.$1,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            _buildFilterSheetSection(
                              title: 'Work Arrangement',
                              children: [
                                ('all', 'All Arrangements'),
                                ('On-site', 'On-site'),
                                ('Remote', 'Remote'),
                                ('Hybrid', 'Hybrid'),
                              ].map((entry) {
                                return _buildModalChoiceChip(
                                  label: entry.$2,
                                  isSelected: tempWorkplace == entry.$1,
                                  onTap: () => setModalState(
                                    () => tempWorkplace = entry.$1,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE8EEF5)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _sortOption = _JobSortOption.newest;
                                  _statusFilter = _JobStatusFilter.all;
                                  _expiryFilter = _JobExpiryFilter.all;
                                  _applicantFilter = _ApplicantFilter.all;
                                  _jobTypeFilter = 'all';
                                  _workplaceFilter = 'all';
                                });
                                Navigator.pop(sheetContext);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF163B65),
                                side: const BorderSide(
                                  color: Color(0xFFD6DEE8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Reset All',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _sortOption = tempSort;
                                  _statusFilter = tempStatus;
                                  _expiryFilter = tempExpiry;
                                  _applicantFilter = tempApplicants;
                                  _jobTypeFilter = tempJobType;
                                  _workplaceFilter = tempWorkplace;
                                });
                                Navigator.pop(sheetContext);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF163B65),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Show $matchingCount Job${matchingCount == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSheetSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B2433),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children,
        ),
      ],
    );
  }

  Widget _buildModalChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? const Color(0xFF163B65) : const Color(0xFFF4F7FB),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : const Color(0xFF4F5C6C),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mineCount = _baseJobsForTab(_JobsTab.mine).length;
    final teamCount = _baseJobsForTab(_JobsTab.team).length;
    final baseTabJobs = _baseJobsForTab(_selectedTab);
    final filteredTabJobs = _filteredJobsForTab(_selectedTab);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _companies.isEmpty ? null : _openCreateJob,
        backgroundColor: const Color(0xFF163B65),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Job'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadWorkspace,
                child: CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: _buildTopBar(context),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: _buildHeroCard(mineCount, teamCount),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: _buildCompanyFilter(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: _buildTabSectionHeader(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildTabButton(
                                  label: 'All Jobs',
                                  tab: _JobsTab.all,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTabButton(
                                  label: 'Posted by Me',
                                  tab: _JobsTab.mine,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTabButton(
                                  label: 'Team Jobs',
                                  tab: _JobsTab.team,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!_isLoading && _companies.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                          child: _buildSearchAndFilterBar(),
                        ),
                      ),
                      if (_hasActiveSearchOrFilter)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                            child: _buildActiveFiltersStrip(
                              shownCount: filteredTabJobs.length,
                              baseCount: baseTabJobs.length,
                            ),
                          ),
                        ),
                    ],
                    if (_isLoading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_companies.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                          child: _buildEmptyCompaniesState(),
                        ),
                      )
                    else
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          child: _buildJobsList(
                            tab: _selectedTab,
                            baseJobs: baseTabJobs,
                            filteredJobs: filteredTabJobs,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    final activeCount = _activeFilterCount;
    final bool hasFilters = activeCount > 0;

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B2433),
              ),
              decoration: InputDecoration(
                hintText: 'Search title, location, or keyword...',
                hintStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8A96A8),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF163B65),
                  size: 21,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF687588),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: hasFilters ? const Color(0xFF163B65) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: _showFilterBottomSheet,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: hasFilters ? Colors.white : const Color(0xFF163B65),
                  ),
                  if (hasFilters) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$activeCount',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFiltersStrip({
    required int shownCount,
    required int baseCount,
  }) {
    final chips = <Widget>[];

    if (_searchQuery.trim().isNotEmpty) {
      chips.add(
        _buildRemovableFilterChip(
          label: '"${_searchQuery.trim()}"',
          onRemove: () {
            setState(() {
              _searchController.clear();
              _searchQuery = '';
            });
          },
        ),
      );
    }

    if (_sortOption != _JobSortOption.newest) {
      chips.add(
        _buildRemovableFilterChip(
          label: 'Sort: ${_sortOptionLabel(_sortOption)}',
          onRemove: () => setState(() => _sortOption = _JobSortOption.newest),
        ),
      );
    }

    if (_statusFilter != _JobStatusFilter.all) {
      chips.add(
        _buildRemovableFilterChip(
          label: 'Status: ${_statusFilterLabel(_statusFilter)}',
          onRemove: () =>
              setState(() => _statusFilter = _JobStatusFilter.all),
        ),
      );
    }

    if (_expiryFilter != _JobExpiryFilter.all) {
      chips.add(
        _buildRemovableFilterChip(
          label: _expiryFilterLabel(_expiryFilter),
          onRemove: () =>
              setState(() => _expiryFilter = _JobExpiryFilter.all),
        ),
      );
    }

    if (_applicantFilter != _ApplicantFilter.all) {
      chips.add(
        _buildRemovableFilterChip(
          label: _applicantFilterLabel(_applicantFilter),
          onRemove: () =>
              setState(() => _applicantFilter = _ApplicantFilter.all),
        ),
      );
    }

    if (_jobTypeFilter != 'all') {
      chips.add(
        _buildRemovableFilterChip(
          label: _jobTypeFilter,
          onRemove: () => setState(() => _jobTypeFilter = 'all'),
        ),
      );
    }

    if (_workplaceFilter != 'all') {
      chips.add(
        _buildRemovableFilterChip(
          label: _workplaceFilter,
          onRemove: () => setState(() => _workplaceFilter = 'all'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Showing $shownCount of $baseCount job${baseCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF687588),
                ),
              ),
            ),
            GestureDetector(
              onTap: _clearAllSearchAndFilters,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Text(
                  'Clear all',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF163B65),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
      ],
    );
  }

  Widget _buildRemovableFilterChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    return Material(
      color: const Color(0xFFDCEBFB),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF163B65),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.close_rounded,
                size: 15,
                color: Color(0xFF163B65),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.arrow_back_rounded, color: Color(0xFF163B65)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Jobs Workspace',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
        ),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: _loadWorkspace,
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.refresh_rounded, color: Color(0xFF163B65)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(int mineCount, int teamCount) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF163B65), Color(0xFF335D8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Icon(Icons.work_history_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Employer Jobs',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _companies.isEmpty
                ? 'No companies ready for job management'
                : '${_jobs.length} jobs across ${_companies.length} compan${_companies.length == 1 ? 'y' : 'ies'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Use one screen to browse shared company jobs, focus on your own postings, and jump straight into job details.',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroChip(
                Icons.dashboard_customize_rounded,
                '${_jobs.length} total',
              ),
              _buildHeroChip(Icons.person_rounded, '$mineCount mine'),
              _buildHeroChip(Icons.groups_rounded, '$teamCount team'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Company Filter',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B2433),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Switch between all companies or focus on one workspace.',
          style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF687588)),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCompanyChip(
                label: 'All Companies',
                isSelected: _selectedCompanyId == 'all',
                onTap: () => setState(() => _selectedCompanyId = 'all'),
              ),
              ..._companies.map(
                (company) => Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: _buildCompanyChip(
                    label: company.name,
                    isSelected: _selectedCompanyId == company.companyID,
                    onTap: () => setState(
                      () => _selectedCompanyId = company.companyID ?? 'all',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? const Color(0xFF163B65) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF163B65),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabSectionHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Job Lists',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B2433),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Browse every shared job, just your own postings, or the jobs created by teammates.',
          style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF687588)),
        ),
      ],
    );
  }

  Widget _buildTabButton({required String label, required _JobsTab tab}) {
    final bool isSelected = _selectedTab == tab;

    return Material(
      color: isSelected ? const Color(0xFFDCEBFB) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = tab;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF163B65)
                  : const Color(0xFF687588),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCompaniesState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFDCEBFB),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.business_center_outlined,
                size: 36,
                color: Color(0xFF163B65),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No companies found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B2433),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Register a company or accept an invitation before managing jobs here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Color(0xFF687588),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobsList({
    required _JobsTab tab,
    required List<JobModel> baseJobs,
    required List<JobModel> filteredJobs,
  }) {
    if (baseJobs.isEmpty) {
      return _buildEmptyJobsState(tab);
    }

    if (filteredJobs.isEmpty) {
      return _buildNoMatchingFilterState();
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredJobs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final job = filteredJobs[index];
        return _buildJobCard(job);
      },
    );
  }

  Widget _buildNoMatchingFilterState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3F8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 30,
              color: Color(0xFF687588),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No matching jobs found',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search keywords or active filters to see more job postings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF687588),
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _clearAllSearchAndFilters,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF163B65),
              side: const BorderSide(color: Color(0xFFD6DEE8)),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
            label: const Text(
              'Clear Search & Filters',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyJobsState(_JobsTab tab) {
    String title;
    String description;

    switch (tab) {
      case _JobsTab.all:
        title = 'No jobs found';
        description = 'There are no jobs in the selected company scope yet.';
        break;
      case _JobsTab.mine:
        title = 'No jobs posted by you yet';
        description =
            'Create a new role to start building your own job portfolio.';
        break;
      case _JobsTab.team:
        title = 'No teammate jobs found';
        description = 'Jobs created by other company members will appear here.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Icon(Icons.work_off_rounded, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF687588),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(JobModel job) {
    final normalizedStatus = job.status.toLowerCase();
    final isActive = normalizedStatus == 'active';
    final isDeleted = normalizedStatus == 'deleted';
    final companyName = _resolveCompanyName(job);

    final jobId = job.jobID ?? '';
    final applicantCounts = _applicantCountsByJobId[jobId];
    final totalApplied = applicantCounts?['total'] ?? 0;
    final pendingCount = applicantCounts?['pending'] ?? 0;
    final acceptedCount = applicantCounts?['accepted'] ?? 0;

    final Color statusBg;
    final Color statusText;

    if (isActive) {
      statusBg = const Color(0xFFE5F6ED);
      statusText = const Color(0xFF2D8A5D);
    } else if (isDeleted) {
      statusBg = const Color(0xFFFCE9E9);
      statusText = const Color(0xFFC24E4E);
    } else {
      statusBg = const Color(0xFFEFF3F8);
      statusText = const Color(0xFF687588);
    }

    final expiryBadge = _buildExpiryBadge(job);

    return Material(
      color: isDeleted ? const Color(0xFFFFF7F7) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => _openJob(job),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDeleted
                          ? const Color(0xFFFDE1E1)
                          : const Color(0xFFDCEBFB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isDeleted
                          ? Icons.delete_outline_rounded
                          : Icons.work_outline_rounded,
                      color: isDeleted
                          ? const Color(0xFFC24E4E)
                          : const Color(0xFF163B65),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B2433),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          companyName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF687588),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: isDeleted
                        ? const Color(0xFFB98D8D)
                        : const Color(0xFF9AA5B5),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPill(
                    label: job.jobType,
                    backgroundColor: const Color(0xFFEFF3F8),
                    textColor: const Color(0xFF687588),
                  ),
                  _buildPill(
                    label: job.workplaceType,
                    backgroundColor: const Color(0xFFEFF3F8),
                    textColor: const Color(0xFF687588),
                  ),
                  _buildPill(
                    label: job.status.toUpperCase(),
                    backgroundColor: statusBg,
                    textColor: statusText,
                  ),
                  if (expiryBadge != null) expiryBadge,
                  _buildHiringProgressBadge(acceptedCount, job.vacancies),
                  _buildApplicantCountBadge(totalApplied),
                  if (pendingCount > 0) _buildPendingReviewBadge(pendingCount),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                job.description.trim().isEmpty
                    ? 'No job description provided.'
                    : job.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDeleted
                      ? const Color(0xFF8C5A5A)
                      : const Color(0xFF4F5C6C),
                ),
              ),
              if (isDeleted) ...[
                const SizedBox(height: 12),
                const Text(
                  'Deleted by admin. This job is now available for history only.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC24E4E),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildExpiryBadge(JobModel job) {
    if (job.status.toLowerCase() == 'deleted' || job.expiresAt == null) {
      return null;
    }

    final localExpiry = job.expiresAt!.toLocal();
    if (job.isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFCE9E9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 13,
              color: Color(0xFFC24E4E),
            ),
            SizedBox(width: 5),
            Text(
              'Expired',
              style: TextStyle(
                color: Color(0xFFC24E4E),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (_isJobExpiringSoon(job)) {
      final remaining = localExpiry.difference(DateTime.now());
      final daysLeft = remaining.inDays;
      final label = daysLeft <= 0
          ? 'Expires today'
          : 'Expires in ${daysLeft}d';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.hourglass_bottom_rounded,
              size: 13,
              color: Color(0xFFC05621),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFC05621),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_available_rounded,
            size: 13,
            color: Color(0xFF687588),
          ),
          const SizedBox(width: 5),
          Text(
            'Exp ${DateFormat('d MMM').format(localExpiry)}',
            style: const TextStyle(
              color: Color(0xFF687588),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _resolveCompanyName(JobModel job) {
    if (job.companyName != null && job.companyName!.trim().isNotEmpty) {
      return job.companyName!;
    }

    for (final company in _companies) {
      if (company.companyID == job.companyID) {
        return company.name;
      }
    }

    return 'Unknown Company';
  }

  String _sortOptionLabel(_JobSortOption option) {
    switch (option) {
      case _JobSortOption.newest:
        return 'Newest First';
      case _JobSortOption.oldest:
        return 'Oldest First';
      case _JobSortOption.expiringSoonest:
        return 'Expiring Soonest';
      case _JobSortOption.mostApplied:
        return 'Most Applied';
      case _JobSortOption.mostPending:
        return 'Most Pending Review';
    }
  }

  String _statusFilterLabel(_JobStatusFilter filter) {
    switch (filter) {
      case _JobStatusFilter.all:
        return 'All Statuses';
      case _JobStatusFilter.active:
        return 'Active';
      case _JobStatusFilter.inactive:
        return 'Inactive';
      case _JobStatusFilter.deleted:
        return 'Deleted';
    }
  }

  String _expiryFilterLabel(_JobExpiryFilter filter) {
    switch (filter) {
      case _JobExpiryFilter.all:
        return 'All Expiry';
      case _JobExpiryFilter.notExpired:
        return 'Not Expired';
      case _JobExpiryFilter.expiringSoon:
        return 'Expiring Soon (≤ 7d)';
      case _JobExpiryFilter.expired:
        return 'Expired';
    }
  }

  String _applicantFilterLabel(_ApplicantFilter filter) {
    switch (filter) {
      case _ApplicantFilter.all:
        return 'All Applications';
      case _ApplicantFilter.needsReview:
        return 'Needs Review (Pending)';
      case _ApplicantFilter.hasApplicants:
        return 'Has Applicants';
      case _ApplicantFilter.noApplicants:
        return 'No Applicants (0)';
    }
  }

  Widget _buildPill({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildHiringProgressBadge(int acceptedCount, int vacancies) {
    final safeVacancies = vacancies < 1 ? 1 : vacancies;
    final isFilled = acceptedCount >= safeVacancies;
    final hasHires = acceptedCount > 0;

    final Color bgColor = hasHires
        ? const Color(0xFFE5F6ED)
        : const Color(0xFFEFF3F8);
    final Color fgColor = hasHires
        ? const Color(0xFF2D8A5D)
        : const Color(0xFF687588);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFilled ? Icons.verified_rounded : Icons.how_to_reg_rounded,
            size: 13,
            color: fgColor,
          ),
          const SizedBox(width: 5),
          Text(
            isFilled
                ? 'Filled $acceptedCount/$safeVacancies'
                : 'Hired $acceptedCount/$safeVacancies',
            style: TextStyle(
              color: fgColor,
              fontSize: 11,
              fontWeight: isFilled ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantCountBadge(int totalApplied) {
    final bool hasApplicants = totalApplied > 0;
    final Color bgColor =
        hasApplicants ? const Color(0xFFDCEBFB) : const Color(0xFFEFF3F8);
    final Color fgColor =
        hasApplicants ? const Color(0xFF163B65) : const Color(0xFF687588);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasApplicants
                ? Icons.people_alt_rounded
                : Icons.people_outline_rounded,
            size: 13,
            color: fgColor,
          ),
          const SizedBox(width: 5),
          Text(
            '$totalApplied Applied',
            style: TextStyle(
              color: fgColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingReviewBadge(int pendingCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3DC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF5D491)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFFD9820B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$pendingCount Pending',
            style: const TextStyle(
              color: Color(0xFF9A640C),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

enum _JobsTab { all, mine, team }

enum _JobSortOption {
  newest,
  oldest,
  expiringSoonest,
  mostApplied,
  mostPending,
}

enum _JobStatusFilter { all, active, inactive, deleted }

enum _JobExpiryFilter { all, notExpired, expiringSoon, expired }

enum _ApplicantFilter { all, needsReview, hasApplicants, noApplicants }
