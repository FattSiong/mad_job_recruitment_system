import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../../../core/screens/temp_main_screen.dart';
import '../../community/screens/chat_list_screen.dart';
import '../../community/screens/community_dashboard.dart';
import 'company_list_screen.dart';
import 'create_job_screen.dart';
import 'job_company_list_screen.dart';
import 'pending_invites_screen.dart';
import 'scheduled_interviews_screen.dart';
import '../../../core/constants/table_constants.dart';
import '../../../models/company_model.dart';
import '../../../models/job_model.dart';
import '../../../services/employer_service.dart';

class EmployerDashboard extends StatefulWidget {
  const EmployerDashboard({super.key});

  @override
  State<EmployerDashboard> createState() => _EmployerDashboardState();
}

class _EmployerDashboardState extends State<EmployerDashboard> {
  int _currentIndex = 0;

  final EmployerService _employerService = EmployerService();

  bool _isLoadingStats = true;

  String _fullName = 'Employer';
  String _email = '';

  int _companyCount = 0;
  int _verifiedCompanyCount = 0;
  int _totalJobs = 0;
  int _activeJobs = 0;
  int _pendingInviteCount = 0;
  int _scheduledInterviewCount = 0;

  User? get _currentUser => Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);

    if (index == 0) {
      _loadDashboardStats();
    }
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );

    if (!mounted) return;
    await _loadDashboardStats();
  }


  Future<void> _logout() async {
    await AuthService().signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const TempMainScreen()),
      (route) => false,
    );
  }

  Future<void> _loadDashboardStats() async {
    final currentUser = _currentUser;
    if (currentUser == null) return;

    setState(() => _isLoadingStats = true);

    try {
      final results = await Future.wait<dynamic>([
        Supabase.instance.client
            .from(TableConstants.employer)
            .select('fullName, email')
            .eq('employerID', currentUser.id)
            .maybeSingle(),
        _employerService.getCompanies(currentUser.id, 'employer'),
        _employerService.getEmployerJobs(currentUser.id),
        _employerService.getMyPendingInvitations(),
        _employerService.getScheduledInterviews(),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final companies = results[1] as List<CompanyModel>;
      final jobs = results[2] as List<JobModel>;
      final pendingInvites = results[3] as List<Map<String, dynamic>>;
      final interviews = results[4] as List<Map<String, dynamic>>;

      final activeJobs = jobs
          .where((job) => job.status.toLowerCase() == 'active')
          .length;

      final verifiedCompanies = companies
          .where(
            (company) =>
                company.isVerified ||
                company.verificationStatus.toLowerCase() == 'verified',
          )
          .length;

      setState(() {
        _fullName = (profile?['fullName'] as String?)?.trim().isNotEmpty == true
            ? (profile!['fullName'] as String).trim()
            : 'Employer';

        _email = (profile?['email'] as String?)?.trim().isNotEmpty == true
            ? (profile!['email'] as String).trim()
            : (currentUser.email ?? '');

        _companyCount = companies.length;
        _verifiedCompanyCount = verifiedCompanies;
        _totalJobs = jobs.length;
        _activeJobs = activeJobs;
        _pendingInviteCount = pendingInvites.length;

        final scheduledOnly = interviews.where((item) {
          final applicant = item['JobApplicant'] ?? {};
          return applicant['applicationStatus'] == 'scheduled';
        }).length;

        _scheduledInterviewCount = scheduledOnly;

        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() {
        _email = currentUser.email ?? '';
        _isLoadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildChatsTab(),
          _buildCommunityTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDCEBFB),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
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
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openScreen(const CreateJobScreen()),
              backgroundColor: const Color(0xFF163B65),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Post Job'),
            )
          : null,
    );
  }

  Widget _buildHomeTab() {
    final actions = [
      {
        'title': 'Companies',
        'subtitle': 'Manage company profiles',
        'icon': Icons.business_rounded,
        'color': const Color(0xFF163B65),
        'count': '$_companyCount',
        'onTap': () =>
            _openScreen(const CompanyListScreen(userRole: 'employer')),
      },
      {
        'title': 'Jobs',
        'subtitle': 'Review your job postings',
        'icon': Icons.work_outline_rounded,
        'color': const Color(0xFF1E8F8B),
        'count': '$_activeJobs',
        'onTap': () => _openScreen(const ManageJobsCompanyListScreen()),
      },
      {
        'title': 'Interviews',
        'subtitle': 'Check scheduled sessions',
        'icon': Icons.calendar_month_rounded,
        'color': const Color(0xFFE4A73B),
        'count': '$_scheduledInterviewCount',
        'onTap': () => _openScreen(const ScheduledInterviewsScreen()),
      },
      {
        'title': 'Invites',
        'subtitle': 'View pending invitations',
        'icon': Icons.mail_outline_rounded,
        'color': const Color(0xFFE27D60),
        'count': '$_pendingInviteCount',
        'onTap': () => _openScreen(const PendingInvitationsScreen()),
      },
    ];


    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadDashboardStats,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.apartment,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Employer Workspace',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout, color: Colors.white),
                          tooltip: 'Logout',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome back, ${_fullName.split(' ').first}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isLoadingStats
                          ? 'Loading your employer workspace...'
                          : 'You have $_activeJobs active jobs, $_companyCount companies, and $_scheduledInterviewCount scheduled interviews.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildHeroChip(
                          Icons.business,
                          '$_companyCount companies',
                        ),
                        _buildHeroChip(
                          Icons.work_history,
                          '$_activeJobs active jobs',
                        ),
                        _buildHeroChip(
                          Icons.mail_outline,
                          '$_pendingInviteCount invites',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B2433),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your most-used employer tools in one place.',
                style: TextStyle(fontSize: 14, color: Color(0xFF687588)),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final double width = constraints.maxWidth;
                  final int crossAxisCount = width >= 1000
                      ? 4
                      : width >= 700
                      ? 3
                      : 2;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: actions.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: width >= 700 ? 1.0 : 0.82,
                    ),
                    itemBuilder: (context, index) {
                      final action = actions[index];

                      return _buildQuickActionCard(
                        title: action['title'] as String,
                        subtitle: action['subtitle'] as String,
                        icon: action['icon'] as IconData,
                        color: action['color'] as Color,
                        count: action['count'] as String,
                        onTap: action['onTap'] as VoidCallback,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 28),
              const Text(
                'Live Overview',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B2433),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Real numbers from your employer workspace.',
                style: TextStyle(fontSize: 14, color: Color(0xFF687588)),
              ),
              const SizedBox(height: 18),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.95,
                children: [
                  _buildStatCard(
                    title: 'Companies',
                    value: '$_companyCount',
                    subtitle: '$_verifiedCompanyCount verified',
                    color: const Color(0xFF163B65),
                    icon: Icons.business_rounded,
                  ),
                  _buildStatCard(
                    title: 'Jobs',
                    value: '$_totalJobs',
                    subtitle: '$_activeJobs active now',
                    color: const Color(0xFF1E8F8B),
                    icon: Icons.work_outline_rounded,
                  ),
                  _buildStatCard(
                    title: 'Invites',
                    value: '$_pendingInviteCount',
                    subtitle: 'Pending responses',
                    color: const Color(0xFFE27D60),
                    icon: Icons.mail_outline_rounded,
                  ),
                  _buildStatCard(
                    title: 'Interviews',
                    value: '$_scheduledInterviewCount',
                    subtitle: 'Scheduled sessions',
                    color: const Color(0xFFE4A73B),
                    icon: Icons.calendar_month_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today in your workspace',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B2433),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'This design focuses on clarity first: a safe header, responsive cards, real community access, and better tap feedback.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF687588),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF687588)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String count,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      count,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B2433),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF687588),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Open',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: color,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatsTab() {
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

  Widget _buildCommunityTab() {
    if (_currentUser == null) {
      return const Center(child: Text('Not logged in'));
    }

    return CommunityDashboard(currentUserID: _currentUser!.id);
  }

  Widget _buildProfileTab() {
    final email = _email.isNotEmpty
        ? _email
        : (_currentUser?.email ?? 'employer@email.com');
    final displayName = _fullName;
    final firstLetter = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'E';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFFDCEBFB),
                    child: Text(
                      firstLetter,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF163B65),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B2433),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF687588),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildProfileTile(
              icon: Icons.business_rounded,
              title: 'Manage Companies',
              subtitle: 'Open your company list',
              color: const Color(0xFF163B65),
              onTap: () =>
                  _openScreen(const CompanyListScreen(userRole: 'employer')),
            ),
            const SizedBox(height: 12),
            _buildProfileTile(
              icon: Icons.work_outline_rounded,
              title: 'Manage Jobs',
              subtitle: 'Review all job postings',
              color: const Color(0xFF1E8F8B),
              onTap: () => _openScreen(const ManageJobsCompanyListScreen()),
            ),
            const SizedBox(height: 12),
            _buildProfileTile(
              icon: Icons.calendar_month_rounded,
              title: 'Scheduled Interviews',
              subtitle: 'Check interview plans',
              color: const Color(0xFFE4A73B),
              onTap: () => _openScreen(const ScheduledInterviewsScreen()),
            ),
            const SizedBox(height: 12),
            _buildProfileTile(
              icon: Icons.mail_outline_rounded,
              title: 'Pending Invites',
              subtitle: 'View team invitations',
              color: const Color(0xFFE27D60),
              onTap: () => _openScreen(const PendingInvitationsScreen()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF163B65),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
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

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B2433),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF687588),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
