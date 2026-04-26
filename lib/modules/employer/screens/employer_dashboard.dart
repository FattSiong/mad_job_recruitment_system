import 'dart:async';
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
import 'subscription_screen.dart';
import 'register_company_screen.dart';
import 'premium_employer_home.dart';
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
  bool _isPremium = false;

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
    _refreshData();
  }

  Future<void> _refreshData() async {
    await _checkPremiumStatus();
    await _loadDashboardStats();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) _refreshData();
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    _refreshData();
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const TempMainScreen()),
          (route) => false,
    );
  }

  // ✅ UPDATED: Logic to include 'monthly' and 'annually'
  Future<void> _checkPremiumStatus() async {
    try {
      final user = _currentUser;
      if (user == null) return;
      final subInfo = await Supabase.instance.client
          .from('PaymentSubscription')
          .select('planType, status')
          .eq('paidByEmployerID', user.id)
          .eq('status', 'active')
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (subInfo != null) {
            final plan = subInfo['planType']?.toString().toLowerCase() ?? '';
            // Allow 'monthly' or 'annually' to trigger premium colors
            _isPremium = plan.contains('premium') || plan.contains('monthly') || plan.contains('annually');
          } else {
            _isPremium = false;
          }
        });
        debugPrint("👑 PREMIUM MODE: $_isPremium");
      }
    } catch (e) {
      debugPrint("Error checking premium status: $e");
    }
  }

  Future<void> _loadDashboardStats() async {
    final user = _currentUser;
    if (user == null) return;
    setState(() => _isLoadingStats = true);

    try {
      final List<Future<dynamic>> dashboardFutures = [
        Supabase.instance.client.from(TableConstants.employer).select('fullName, email').eq('employerID', user.id).maybeSingle(),
        _employerService.getCompanies(user.id, 'employer'),
        _employerService.getEmployerJobs(user.id),
        _employerService.getMyPendingInvitations(),
        _employerService.getScheduledInterviews(),
      ];

      final results = await Future.wait(dashboardFutures);
      final profile = results[0] as Map<String, dynamic>?;
      final companies = results[1] as List<CompanyModel>;
      final jobs = results[2] as List<JobModel>;

      if (mounted) {
        setState(() {
          _fullName = profile?['fullName'] ?? 'Employer';
          _email = profile?['email'] ?? user.email ?? '';
          _companyCount = companies.length;
          _verifiedCompanyCount = companies.where((c) => c.isVerified || c.verificationStatus == 'verified').length;
          _totalJobs = jobs.length;
          _activeJobs = jobs.where((j) => j.status.toLowerCase() == 'active').length;
          _pendingInviteCount = (results[3] as List).length;
          _scheduledInterviewCount = (results[4] as List).where((i) => i['JobApplicant']?['applicationStatus'] == 'scheduled').length;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
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
          ChatListScreen(currentUserID: _currentUser?.id ?? ''),
          CommunityDashboard(currentUserID: _currentUser?.id ?? ''),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        backgroundColor: Colors.white,
        // ✅ NAVIGATION COLOR FIX
        indicatorColor: _isPremium ? Colors.pink.shade100 : const Color(0xFFDCEBFB),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Community'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
        onPressed: () => _openScreen(const CreateJobScreen()),
        // ✅ FAB COLOR FIX
        backgroundColor: _isPremium ? const Color(0xFFD81B60) : const Color(0xFF163B65),
        icon: Icon(_isPremium ? Icons.auto_awesome : Icons.add, color: Colors.white),
        label: Text(_isPremium ? 'Post AI Job' : 'Post Job', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      )
          : null,
    );
  }

  Widget _buildHomeTab() {
    if (_isPremium) {
      return PremiumEmployerHome(
        fullName: _fullName,
        activeJobs: _activeJobs,
        companyCount: _companyCount,
        interviewCount: _scheduledInterviewCount,
        inviteCount: _pendingInviteCount,
        onLogout: _logout,
        onRefresh: _refreshData,
        openScreen: _openScreen,
      );
    }

    // --- ORIGINAL DESIGN (ALL ITEMS RESTORED) ---
    final actions = [
      {'title': 'Companies', 'subtitle': 'Manage company profiles', 'icon': Icons.business_rounded, 'color': const Color(0xFF163B65), 'count': '$_companyCount', 'onTap': () => _openScreen(const CompanyListScreen(userRole: 'employer'))},
      {'title': 'Jobs', 'subtitle': 'Review your job postings', 'icon': Icons.work_outline_rounded, 'color': const Color(0xFF1E8F8B), 'count': '$_activeJobs', 'onTap': () => _openScreen(const ManageJobsCompanyListScreen())},
      {'title': 'Interviews', 'subtitle': 'Check scheduled sessions', 'icon': Icons.calendar_month_rounded, 'color': const Color(0xFFE4A73B), 'count': '$_scheduledInterviewCount', 'onTap': () => _openScreen(const ScheduledInterviewsScreen())},
      {'title': 'Invites', 'subtitle': 'View pending invitations', 'icon': Icons.mail_outline_rounded, 'color': const Color(0xFFE27D60), 'count': '$_pendingInviteCount', 'onTap': () => _openScreen(const PendingInvitationsScreen())},
    ];

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF163B65), Color(0xFF335D8A)]),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildHeroChip(Icons.apartment, 'Employer Workspace'),
                        const Spacer(),
                        IconButton(onPressed: _logout, icon: const Icon(Icons.logout, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Welcome back, ${_fullName.split(' ').first}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(
                      _isLoadingStats ? 'Loading your employer workspace...' : 'You have $_activeJobs active jobs, $_companyCount companies, and $_scheduledInterviewCount scheduled interviews.',
                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                    const SizedBox(height: 20),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      _buildHeroChip(Icons.business, '$_companyCount companies'),
                      _buildHeroChip(Icons.work_history, '$_activeJobs active jobs'),
                      _buildHeroChip(Icons.mail_outline, '$_pendingInviteCount invites'),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _buildSectionHeader('Quick Actions', 'Your most-used employer tools in one place.'),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.82),
                itemBuilder: (context, i) {
                  final a = actions[i];
                  return _buildQuickActionCard(
                    title: a['title'] as String,
                    subtitle: a['subtitle'] as String,
                    icon: a['icon'] as IconData,
                    color: a['color'] as Color,
                    count: a['count'] as String,
                    onTap: a['onTap'] as VoidCallback,
                  );
                },
              ),
              const SizedBox(height: 28),
              _buildSectionHeader('Live Overview', 'Real numbers from your employer workspace.'),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.95,
                children: [
                  _buildStatCard(title: 'Companies', value: '$_companyCount', subtitle: '$_verifiedCompanyCount verified', color: const Color(0xFF163B65), icon: Icons.business_rounded),
                  _buildStatCard(title: 'Jobs', value: '$_totalJobs', subtitle: '$_activeJobs active now', color: const Color(0xFF1E8F8B), icon: Icons.work_outline_rounded),
                  _buildStatCard(title: 'Invites', value: '$_pendingInviteCount', subtitle: 'Pending responses', color: const Color(0xFFE27D60), icon: Icons.mail_outline_rounded),
                  _buildStatCard(title: 'Interviews', value: '$_scheduledInterviewCount', subtitle: 'Scheduled sessions', color: const Color(0xFFE4A73B), icon: Icons.calendar_month_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String sub) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B2433))),
      Text(sub, style: const TextStyle(fontSize: 14, color: Color(0xFF687588))),
      const SizedBox(height: 18),
    ]);
  }

  Widget _buildHeroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(30)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 16), const SizedBox(width: 8), Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))]),
    );
  }

  Widget _buildQuickActionCard({required String title, required String subtitle, required IconData icon, required Color color, required String count, required VoidCallback onTap}) {
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(count, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Expanded(child: Text(subtitle, maxLines: 2, style: const TextStyle(fontSize: 13, color: Color(0xFF687588)))),
            const SizedBox(height: 10),
            Row(children: [Text('Open', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(width: 6), Icon(Icons.arrow_forward_rounded, size: 18, color: color)]),
          ]),
        ),
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required String subtitle, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF687588))),
      ]),
    );
  }

  Widget _buildProfileTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
              child: Column(children: [
                CircleAvatar(radius: 34, backgroundColor: _isPremium ? Colors.pink.shade100 : const Color(0xFFDCEBFB), child: Text(_fullName[0].toUpperCase(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _isPremium ? const Color(0xFFD81B60) : const Color(0xFF163B65)))),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  if (_isPremium) ...[const SizedBox(width: 8), const Icon(Icons.verified, color: Colors.pink, size: 20)],
                ]),
                Text(_email, style: const TextStyle(color: Color(0xFF687588))),
              ]),
            ),
            const SizedBox(height: 24),
            if (!_isPremium) _buildProfileTile(Icons.workspace_premium_outlined, 'Upgrade to Premium', 'Unlock all AI features', Colors.pink, () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
              _refreshData();
            })
            else Container(
              width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.pink.withOpacity(0.05), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.pink.withOpacity(0.2))),
              child: const Column(children: [Icon(Icons.workspace_premium, color: Colors.pink, size: 36), SizedBox(height: 8), Text("Premium Active", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)), Text("Full access enabled.", style: TextStyle(color: Colors.pink, fontSize: 12))]),
            ),
            const SizedBox(height: 12),
            _buildProfileTile(Icons.app_registration, 'Register Company', 'Create a new profile', const Color(0xFF335D8A), () => _openScreen(const RegisterCompanyScreen())),
            _buildProfileTile(Icons.business_rounded, 'Manage Companies', 'Open your company list', const Color(0xFF163B65), () => _openScreen(const CompanyListScreen(userRole: 'employer'))),
            _buildProfileTile(Icons.work_outline_rounded, 'Manage Jobs', 'Review all job postings', const Color(0xFF1E8F8B), () => _openScreen(const ManageJobsCompanyListScreen())),
            _buildProfileTile(Icons.calendar_month_rounded, 'Scheduled Interviews', 'Check interview plans', const Color(0xFFE4A73B), () => _openScreen(const ScheduledInterviewsScreen())),
            _buildProfileTile(Icons.mail_outline_rounded, 'Pending Invites', 'View team invitations', const Color(0xFFE27D60), () => _openScreen(const PendingInvitationsScreen())),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _logout, icon: const Icon(Icons.logout), label: const Text('Logout'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF163B65), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))))),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF687588)))])),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
          ]),
        ),
      ),
    );
  }
}