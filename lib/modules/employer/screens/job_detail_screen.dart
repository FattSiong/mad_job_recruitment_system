import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/job_model.dart';
import '../../../services/employer_service.dart';
import 'applicant_detail_screen.dart';
import 'edit_job_screen.dart';

enum _JobDetailTab { overview, applicants }

class JobDetailScreen extends StatefulWidget {
  final JobModel job;

  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final EmployerService _employerService = EmployerService();

  late JobModel _currentJob;
  _JobDetailTab _selectedTab = _JobDetailTab.overview;

  bool _isStatusUpdating = false;
  bool _isApplicantsLoading = true;
  bool _isRankingWithAi = false;
  int _rankingCompletedCount = 0;
  int _rankingTotalCount = 0;

  List<Map<String, dynamic>> _applicants = [];

  @override
  void initState() {
    super.initState();
    _currentJob = widget.job;
    _loadApplicants();
  }

  Future<void> _loadApplicants() async {
    if (_currentJob.jobID == null) {
      setState(() {
        _applicants = [];
        _isApplicantsLoading = false;
      });
      return;
    }

    setState(() => _isApplicantsLoading = true);

    final applicants = await _employerService.getJobApplicants(
      _currentJob.jobID!,
    );

    if (!mounted) return;

    setState(() {
      _applicants = applicants;
      _isApplicantsLoading = false;
    });
  }

  Future<void> _rankCandidatesWithAi({bool onlyUnranked = false}) async {
    if (_isRankingWithAi || _applicants.isEmpty) return;

    final targets = onlyUnranked
        ? _applicants.where((a) => a['aiRankingScore'] == null).toList()
        : _applicants;

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All applicants already have AI match scores.'),
        ),
      );
      return;
    }

    setState(() {
      _isRankingWithAi = true;
      _rankingCompletedCount = 0;
      _rankingTotalCount = targets.length;
    });

    final rankedCount = await _employerService.rankJobCandidatesWithAI(
      job: _currentJob,
      applicants: _applicants,
      onlyUnranked: onlyUnranked,
      onProgress: (completed, total) {
        if (!mounted) return;
        setState(() {
          _rankingCompletedCount = completed;
          _rankingTotalCount = total;
        });
      },
    );

    if (!mounted) return;

    await _loadApplicants();

    if (!mounted) return;

    setState(() {
      _isRankingWithAi = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          rankedCount > 0
              ? 'AI ranked $rankedCount/${targets.length} candidate(s) and sorted by best match!'
              : 'Could not generate AI rankings. Please check internet connection or resume access.',
        ),
        backgroundColor: rankedCount > 0 ? const Color(0xFF2D8A5D) : Colors.red,
      ),
    );
  }

  Future<void> _toggleJobStatus() async {
    if (_currentJob.status.toLowerCase() == 'deleted') return;

    if (_currentJob.jobID == null) return;

    setState(() => _isStatusUpdating = true);

    final currentStatus = _currentJob.status.toLowerCase();
    final isActivating = currentStatus != 'active';
    final newStatus = isActivating ? 'active' : 'inactive';

    DateTime? newExpiresAt;
    if (isActivating) {
      final now = DateTime.now();
      newExpiresAt = DateTime(now.year, now.month + 1, now.day, 23, 59, 59);
    }

    final success = await _employerService.updateJobStatus(
      _currentJob.jobID!,
      newStatus,
      expiresAt: newExpiresAt,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _currentJob = _currentJob.copyWith(
          status: newStatus,
          expiresAt: newExpiresAt,
        );
      });

      final message = isActivating
          ? 'Job activated! Expiry date set to ${DateFormat('dd MMM yyyy').format(newExpiresAt!)}.'
          : 'Job marked as INACTIVE.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    setState(() => _isStatusUpdating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _buildTopBar(context),
            const SizedBox(height: 16),
            _buildHeroCard(),
            const SizedBox(height: 20),
            _buildTabSwitcher(),
            const SizedBox(height: 20),
            if (_selectedTab == _JobDetailTab.overview)
              _buildOverviewSection()
            else
              _buildApplicantsSection(),
          ],
        ),
      ),
    );
  }

  bool get _isJobOwner {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return currentUserId != null && _currentJob.employerID == currentUserId;
  }

  Widget _buildTopBar(BuildContext context) {
    final isDeleted = _currentJob.status.toLowerCase() == 'deleted';
    final canEdit = !isDeleted && _isJobOwner;

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
            'Job Details',
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
            onTap: isDeleted
                ? null
                : !_isJobOwner
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Only the employer who created this job posting can edit it.',
                            ),
                          ),
                        );
                      }
                    : () async {
                        final updatedJob = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditJobScreen(
                              job: _currentJob,
                              initialApplicantCount: _applicants.length,
                            ),
                          ),
                        );

                        if (updatedJob != null && updatedJob is JobModel) {
                          setState(() {
                            _currentJob = updatedJob;
                          });
                          await _loadApplicants();
                        }
                      },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                canEdit ? Icons.edit_rounded : Icons.lock_outline_rounded,
                color: canEdit
                    ? const Color(0xFF163B65)
                    : const Color(0xFF9AA5B5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    final status = _currentJob.status.toLowerCase();
    final isActive = status == 'active';
    final isDeleted = status == 'deleted';

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
          Row(
            children: [
              _buildHeroChip(
                icon: Icons.work_outline_rounded,
                text: 'Job Workspace',
              ),
              const Spacer(),
              _buildHeroStatusBadge(_currentJob.status),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _currentJob.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isDeleted
                ? 'This role was removed by an admin and can no longer be managed.'
                : isActive
                ? 'This role is live and ready for applicant review.'
                : 'This role is currently inactive, but you can reopen it anytime.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroMetric(
                Icons.people_alt_rounded,
                '${_applicants.length} applicants',
              ),
              _buildHeroMetric(
                Icons.schedule_rounded,
                _currentJob.jobType,
              ),
              _buildHeroMetric(
                Icons.maps_home_work_rounded,
                _currentJob.workplaceType,
              ),
              _buildHeroMetric(
                Icons.work_history_rounded,
                _currentJob.minExperienceYears == 0
                    ? 'Entry level'
                    : '${_currentJob.minExperienceYears}+ years',
              ),
              _buildHeroMetric(
                Icons.monetization_on_rounded,
                _currentJob.salaryRange.isNotEmpty
                    ? _currentJob.salaryRange
                    : 'Salary not set',
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: _isStatusUpdating
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  )
                : isDeleted
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'This job was deleted by admin',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _toggleJobStatus,
                    icon: Icon(
                      isActive
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    label: Text(isActive ? 'Inactivate Job' : 'Activate Job'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF163B65),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: 'Overview',
              tab: _JobDetailTab.overview,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTabButton(
              label: 'Applicants',
              tab: _JobDetailTab.applicants,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({required String label, required _JobDetailTab tab}) {
    final isSelected = _selectedTab == tab;

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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF163B65)
                  : const Color(0xFF687588),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  String _formatWorkplaceLabel(String workplaceType) {
    switch (workplaceType.trim().toLowerCase()) {
      case 'remote':
        return 'Remote (Work from Home)';
      case 'hybrid':
        return 'Hybrid (Both Home & Company)';
      case 'on-site':
      default:
        return 'On-site (Work at Company)';
    }
  }

  String _formatExpiryLabel() {
    if (_currentJob.expiresAt == null) {
      return 'No expiry date set';
    }
    final formatted = DateFormat('dd MMM yyyy').format(
      _currentJob.expiresAt!.toLocal(),
    );
    if (_currentJob.isExpired) {
      return 'Expired on $formatted (Inactive)';
    }
    if (_currentJob.status.toLowerCase() != 'active') {
      return 'Inactive (Will reset to 1 month upon activation)';
    }
    return 'Active until $formatted';
  }

  Widget _buildOverviewSection() {
    final locationDisplay =
        (_currentJob.locationName != null &&
                _currentJob.locationName!.trim().isNotEmpty)
            ? _currentJob.locationName!.trim()
            : (_currentJob.latitude != null && _currentJob.longitude != null)
                ? 'Map coordinates set (${_currentJob.latitude!.toStringAsFixed(4)}, ${_currentJob.longitude!.toStringAsFixed(4)})'
                : 'No location provided';

    return Column(
      children: [
        _buildSectionCard(
          title: 'Job Requirements & Details',
          subtitle:
              'Core information, work arrangement, schedule, and qualifications.',
          child: Column(
            children: [
              _buildInfoRow(
                Icons.schedule_rounded,
                'Job Type',
                _currentJob.jobType,
              ),
              const SizedBox(height: 14),
              _buildInfoRow(
                Icons.maps_home_work_rounded,
                'Work Arrangement',
                _formatWorkplaceLabel(_currentJob.workplaceType),
              ),
              const SizedBox(height: 14),
              _buildInfoRow(
                Icons.access_time_filled_rounded,
                'Working Period / Schedule',
                (_currentJob.workingPeriod != null &&
                        _currentJob.workingPeriod!.trim().isNotEmpty)
                    ? _currentJob.workingPeriod!.trim()
                    : 'Not specified',
              ),
              const SizedBox(height: 14),
              _buildInfoRow(
                Icons.school_rounded,
                'Minimum Qualification',
                _currentJob.qualification == 'No Minimum'
                    ? 'No Minimum Qualification'
                    : _currentJob.qualification,
              ),
              const SizedBox(height: 14),
              _buildInfoRow(
                Icons.work_history_rounded,
                'Experience',
                _currentJob.minExperienceYears == 0
                    ? 'Entry Level (Fresh Graduates)'
                    : 'Minimum ${_currentJob.minExperienceYears} Years',
              ),
              const SizedBox(height: 14),
              _buildInfoRow(
                Icons.monetization_on_rounded,
                'Salary',
                _currentJob.salaryRange.isNotEmpty
                    ? _currentJob.salaryRange
                    : 'Not specified',
              ),
              const SizedBox(height: 14),
              _buildInfoRow(
                Icons.location_on_rounded,
                'Location',
                locationDisplay,
              ),
              const SizedBox(height: 14),
              _buildInfoRow(
                Icons.event_available_rounded,
                'Job Expiry Date',
                _formatExpiryLabel(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildSectionCard(
          title: 'Full Description',
          subtitle: 'The complete role description visible in the job post.',
          child: Text(
            _currentJob.description.trim().isEmpty
                ? 'No description provided.'
                : _currentJob.description,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Color(0xFF1B2433),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApplicantCard(Map<String, dynamic> data, {int? rankNumber}) {
    final seeker = data['JobSeeker'] ?? {};
    final name = seeker['fullName'] ?? 'Unknown Applicant';
    final status = data['applicationStatus'] ?? 'pending';
    final num? rawScore = data['aiRankingScore'] as num?;
    final int? aiScore = rawScore?.round();
    final String aiFeedback = (data['aiFeedback'] ?? '').toString().trim();

    final appliedAt = data['appliedAt'] != null
        ? DateTime.tryParse(data['appliedAt'].toString())
        : null;

    final appliedDate = appliedAt != null
        ? appliedAt.toLocal().toString().split(' ')[0]
        : 'Unknown Date';

    Color scoreFg = const Color(0xFFC28A22);
    Color scoreBg = const Color(0xFFFEF3DC);
    if (aiScore != null) {
      if (aiScore >= 75) {
        scoreFg = const Color(0xFF2D8A5D);
        scoreBg = const Color(0xFFE5F6ED);
      } else if (aiScore < 50) {
        scoreFg = const Color(0xFFC24E4E);
        scoreBg = const Color(0xFFFDECEC);
      }
    }

    return Material(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ApplicantDetailScreen(
                applicantData: data,
                jobTitle: _currentJob.title,
                jobStatus: _currentJob.status,
              ),
            ),
          );
          await _loadApplicants();
        },
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFDCEBFB),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF163B65),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (rankNumber != null && aiScore != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: rankNumber == 1
                                      ? const Color(0xFF163B65)
                                      : const Color(0xFFDCEBFB),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '#$rankNumber',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: rankNumber == 1
                                        ? Colors.white
                                        : const Color(0xFF163B65),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1B2433),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          seeker['email'] ?? 'No email provided',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF687588),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildApplicantStatusBadge(status),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildApplicantInfoPill(
                      icon: Icons.schedule_rounded,
                      text: 'Applied: $appliedDate',
                    ),
                  ),
                  if (aiScore != null) ...[
                    const SizedBox(width: 10),
                    _buildApplicantsMetaChip(
                      icon: Icons.auto_awesome_rounded,
                      text: 'AI match $aiScore%',
                      color: scoreFg,
                      backgroundColor: scoreBg,
                    ),
                  ] else ...[
                    const SizedBox(width: 10),
                    _buildApplicantsMetaChip(
                      icon: Icons.auto_awesome_outlined,
                      text: 'AI match pending',
                      color: const Color(0xFF687588),
                      backgroundColor: const Color(0xFFEFF3F8),
                    ),
                  ],
                ],
              ),
              if (aiFeedback.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.psychology_alt_rounded,
                        size: 16,
                        color: Color(0xFF163B65),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          aiFeedback,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Color(0xFF4F5D70),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Row(
                children: [
                  Spacer(),
                  Text(
                    'Open profile',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF163B65),
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Color(0xFF163B65),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF687588),
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF163B65)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF687588),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Color(0xFF1B2433),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApplicantsSection() {
    if (_currentJob.status.toLowerCase() == 'deleted') {
      return _buildSectionCard(
        title: 'Applicants Archived',
        subtitle: 'This job was deleted by admin.',
        child: const Text(
          'Applicant records still exist for history, but employer actions are disabled for deleted jobs.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xFF687588),
          ),
        ),
      );
    }

    if (_isApplicantsLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_applicants.isEmpty) {
      return Column(
        children: [
          _buildAiRankingPanel(),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEBFB),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.people_outline_rounded,
                    size: 36,
                    color: Color(0xFF163B65),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'No applicants yet',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2433),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'When candidates apply for this role, they will appear here for review.',
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
        ],
      );
    }

    final pendingCount = _applicants.where((item) {
      return (item['applicationStatus'] ?? '').toString().toLowerCase() == 'pending';
    }).length;

    final scheduledCount = _applicants.where((item) {
      return (item['applicationStatus'] ?? '').toString().toLowerCase() == 'scheduled';
    }).length;

    return Column(
      children: [
        _buildAiRankingPanel(),
        const SizedBox(height: 18),
        _buildSectionCard(
          title: 'Applicants',
          subtitle: 'Review candidate progress and open each application in detail.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildApplicantsMetaChip(
                    icon: Icons.groups_rounded,
                    text: '${_applicants.length} total',
                    color: const Color(0xFF163B65),
                    backgroundColor: const Color(0xFFDCEBFB),
                  ),
                  _buildApplicantsMetaChip(
                    icon: Icons.access_time_outlined,
                    text: '$pendingCount pending',
                    color: const Color(0xFFB28600),
                    backgroundColor: const Color(0xFFFFF8E1),
                  ),
                  _buildApplicantsMetaChip(
                    icon: Icons.event_available_rounded,
                    text: '$scheduledCount scheduled',
                    color: const Color(0xFF6B4FD3),
                    backgroundColor: const Color(0xFFF3ECFF),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _applicants.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final data = _applicants[index];
                  return _buildApplicantCard(
                    data,
                    rankNumber: data['aiRankingScore'] != null ? index + 1 : null,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiRankingPanel() {
    final totalCount = _applicants.length;
    final rankedCount =
        _applicants.where((a) => a['aiRankingScore'] != null).length;
    final unrankedCount = totalCount - rankedCount;
    final allRanked = totalCount > 0 && unrankedCount == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF4FF), Color(0xFFF8F5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8E4F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF163B65),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Candidate Ranking',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B2433),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Find the strongest matches faster',
                      style: TextStyle(fontSize: 13, color: Color(0xFF687588)),
                    ),
                  ],
                ),
              ),
              _buildApplicantsMetaChip(
                icon: allRanked
                    ? Icons.verified_rounded
                    : Icons.auto_awesome_rounded,
                text: totalCount == 0
                    ? 'No applicants'
                    : '$rankedCount/$totalCount ranked',
                color: allRanked
                    ? const Color(0xFF2D8A5D)
                    : const Color(0xFF163B65),
                backgroundColor: allRanked
                    ? const Color(0xFFE5F6ED)
                    : const Color(0xFFDCEBFB),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Compare each applicant’s uploaded resume, profile experience, education, and pre-screening answers against this job’s requirements using Gemini AI.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF4F5D70),
            ),
          ),
          const SizedBox(height: 18),
          if (_isRankingWithAi)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD8E4F5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFF163B65),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Analyzing candidate ${_rankingCompletedCount + 1 > _rankingTotalCount ? _rankingTotalCount : _rankingCompletedCount + 1} of $_rankingTotalCount with Gemini AI...',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF163B65),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (totalCount > 0 && unrankedCount > 0 && rankedCount > 0)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _rankCandidatesWithAi(onlyUnranked: true),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text('Rank New ($unrankedCount)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF163B65),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _rankCandidatesWithAi(onlyUnranked: false),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Re-rank All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF163B65),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF163B65)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: totalCount == 0
                    ? null
                    : () => _rankCandidatesWithAi(onlyUnranked: false),
                icon: Icon(
                  allRanked
                      ? Icons.refresh_rounded
                      : Icons.auto_awesome_rounded,
                ),
                label: Text(
                  allRanked
                      ? 'Re-rank All Candidates with AI'
                      : 'Rank Candidates with AI',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF163B65),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD8E2EE),
                  disabledForegroundColor: const Color(0xFF7B8798),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildHeroChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatusBadge(String status) {
    final normalized = status.toLowerCase();

    late final Color bgColor;
    late final Color textColor;

    switch (normalized) {
      case 'active':
        bgColor = const Color(0xFFE5F6ED);
        textColor = const Color(0xFF2D8A5D);
        break;
      case 'inactive':
        bgColor = const Color(0xFFEFF3F8);
        textColor = const Color(0xFF687588);
        break;
      case 'deleted':
        bgColor = const Color(0xFFFCE9E9);
        textColor = const Color(0xFFC24E4E);
        break;
      default:
        bgColor = const Color(0xFFEFF3F8);
        textColor = const Color(0xFF687588);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildApplicantsMetaChip({
    required IconData icon,
    required String text,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantInfoPill({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF687588)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF687588),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantStatusBadge(String status) {
    Color color;

    switch (status.toLowerCase()) {
      case 'pending':
        color = const Color(0xFFC28A22);
        break;
      case 'scheduled':
        color = const Color(0xFF6B4FD3);
        break;
      case 'accepted':
        color = const Color(0xFF2D8A5D);
        break;
      case 'rejected':
        color = const Color(0xFFC24E4E);
        break;
      case 'interviewed':
        color = const Color(0xFF1E8F8B);
        break;
      default:
        color = const Color(0xFF687588);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
