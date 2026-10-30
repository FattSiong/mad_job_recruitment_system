import 'package:flutter/material.dart';
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

  List<CompanyModel> _companies = [];
  List<JobModel> _jobs = [];
  bool _isLoading = true;
  String _selectedCompanyId = 'all';
  _JobsTab _selectedTab = _JobsTab.all;

  String? get _currentEmployerId =>
      Supabase.instance.client.auth.currentUser?.id;

  CompanyModel? get _selectedCompany {
    if (_selectedCompanyId == 'all') return null;
    for (final company in _companies) {
      if (company.companyID == _selectedCompanyId) return company;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
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
          ),
        );
      }
    }

    if (!mounted) return;

    setState(() {
      _companies = companies;
      _jobs = jobs;
      _isLoading = false;
      if (_selectedCompanyId != 'all' &&
          !_companies.any(
                (company) => company.companyID == _selectedCompanyId,
          )) {
        _selectedCompanyId = 'all';
      }
    });
  }

  List<JobModel> _jobsForTab(_JobsTab tab) {
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

    if (company == null && _companies.length == 1) {
      company = _companies.first;
    }

    if (company == null) {
      company = await _showCompanyPickerSheet();
    }

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

  Future<CompanyModel?> _showCompanyPickerSheet() async {
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
                    'Choose a Company',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B2433),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pick the company you want to post a new job for.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Color(0xFF687588),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ..._companies.map(
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

  @override
  Widget build(BuildContext context) {
    final mineCount = _jobsForTab(_JobsTab.mine).length;
    final teamCount = _jobsForTab(_JobsTab.team).length;

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
                          child: _buildJobsList(_selectedTab),
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
              color: Colors.white.withOpacity(0.14),
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
        color: Colors.white.withOpacity(0.14),
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

  Widget _buildJobsList(_JobsTab tab) {
    final jobs = _jobsForTab(tab);

    if (jobs.isEmpty) {
      return _buildEmptyJobsState(tab);
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: jobs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final job = jobs[index];
        return _buildJobCard(job);
      },
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
                    label: job.status.toUpperCase(),
                    backgroundColor: statusBg,
                    textColor: statusText,
                  ),
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
}

enum _JobsTab { all, mine, team }
