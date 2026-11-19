import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mad_job_recruitment_system/modules/admin/screens/admin_community_screen.dart';
import 'package:mad_job_recruitment_system/modules/admin/screens/AdminSubscriptionListScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../services/auth_service.dart';
import '../../../shared_widgets/login_screen.dart';
import 'admin_job_moderation_screen.dart';
import 'company_verification_screen.dart';

// --- STYLING CONSTANTS ---
const Color _backgroundColor = Color(0xFFF4F7FB);
const Color _surfaceColor = Colors.white;
const Color _heroStart = Color(0xFF12343B); // Forest Green
const Color _heroEnd = Color(0xFF2A6B66);   // Teal Green
const Color _textPrimary = Color(0xFF1B2433);
const Color _textSecondary = Color(0xFF687588);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isLoadingOverview = true;
  Timer? _refreshTimer;

  String _adminName = 'Admin';
  String _adminEmail = '';
  int _pendingCompanies = 0, _verifiedCompanies = 0;
  int _liveJobs = 0, _flaggedJobs = 0;
  int _activePosts = 0, _activeComments = 0, _flaggedPosts = 0, _flaggedComments = 0;
  int _premiumSubscriptions = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOverviewData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (t) {
      if (mounted && _currentIndex == 0) _loadOverviewData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) _loadOverviewData();
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _loadOverviewData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final supabase = Supabase.instance.client;
    try {
      final profile = await supabase.from(TableConstants.user).select('username, email').eq('userID', user.id).maybeSingle();

      final pendingComps = await supabase.from(TableConstants.company).select('companyID').ilike('verificationStatus', '%pending%');
      final verifiedComps = await supabase.from(TableConstants.company).select('companyID').or('verificationStatus.ilike.%verified%,isVerified.eq.true');
      final reportedJobs = await supabase.from('ReportedJob').select('jobID').ilike('status', '%pending%');
      final reportedPosts = await supabase.from('ReportedPost').select('postID').ilike('status', '%pending%');
      final reportedComments = await supabase.from('ReportedComment').select('commentID').ilike('status', '%pending%');

      final allSubs = await supabase.from(TableConstants.paymentSubscription).select('paymentID, planType, status');

      int premiumCount = 0;
      for (var sub in allSubs) {
        final plan = sub['planType']?.toString().toLowerCase() ?? '';
        final status = sub['status']?.toString().toLowerCase() ?? '';
        if ((plan.contains('monthly') || plan.contains('annually')) &&
            (status.contains('active') || status.contains('paid') || status.contains('success'))) {
          premiumCount++;
        }
      }

      if (!mounted) return;
      setState(() {
        _adminName = _toTitleCase(profile?['username']?.toString() ?? user.email?.split('@').first ?? 'Admin');
        _adminEmail = profile?['email']?.toString() ?? user.email ?? '';
        _pendingCompanies = pendingComps.length;
        _verifiedCompanies = verifiedComps.length;
        _flaggedJobs = reportedJobs.map((r) => r['jobID'].toString()).toSet().length;
        _flaggedPosts = reportedPosts.map((r) => r['postID'].toString()).toSet().length;
        _flaggedComments = reportedComments.map((r) => r['commentID'].toString()).toSet().length;
        _premiumSubscriptions = premiumCount;
        _isLoadingOverview = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingOverview = false);
    }
  }

  String _toTitleCase(String value) {
    return value.split(RegExp(r'[._\s-]+')).where((w) => w.isNotEmpty).map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildSafeTab(const CompanyVerificationScreen()),
          _buildSafeTab(const AdminJobModerationScreen()),
          _buildSafeTab(const AdminCommunityScreen()),
          _buildSafeTab(const AdminSubscriptionListScreen()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD9ECE8),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.approval_outlined), selectedIcon: Icon(Icons.approval), label: 'Companies'),
          NavigationDestination(icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work), label: 'Jobs'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: 'Community'),
          NavigationDestination(icon: Icon(Icons.credit_card_outlined), selectedIcon: Icon(Icons.credit_card), label: 'Billing'),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadOverviewData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroSection(),
              const SizedBox(height: 28),
              _buildSectionHeader('Quick Actions', 'Jump into the admin areas that usually need attention first.'),
              _buildQuickActionsGrid(),
              const SizedBox(height: 28),
              _buildSectionHeader('Moderation Pulse', 'The live queues shaping today\'s admin workload.'),
              _buildModerationGrid(),
              const SizedBox(height: 28),
              _buildSectionHeader('Priority Queue', 'The fastest path into the tasks most likely to need action.'),
              _buildPriorityQueue(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafeTab(Widget child) {
    return SafeArea(
      bottom: false,
      child: child,
    );
  }

  Widget _buildHeroSection() {
    final activeItems = _pendingCompanies + _flaggedJobs + _flaggedPosts + _flaggedComments;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_heroStart, _heroEnd]), borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const HeroChip(icon: Icons.admin_panel_settings_rounded, text: 'Admin Control Center'),
              IconButton(onPressed: _logout, icon: const Icon(Icons.logout, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 24),
          Text('Welcome back, $_adminName', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('There are $activeItems active review items, $_premiumSubscriptions premium plans, and ${_flaggedPosts + _flaggedComments} community alerts.',
              style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
          const SizedBox(height: 20),
          Wrap(spacing: 10, runSpacing: 10, children: [
            HeroChip(icon: Icons.approval_rounded, text: '$_pendingCompanies pending companies'),
            HeroChip(icon: Icons.report_problem_rounded, text: '$_flaggedJobs flagged jobs'),
          ]),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(fontSize: 14, color: _textSecondary)),
      const SizedBox(height: 18),
    ]);
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.85,
      children: [
        QuickActionCard(title: 'Companies', subtitle: 'Review requests.', icon: Icons.approval_rounded, color: const Color(0xFF1D6F6A), count: '$_pendingCompanies pending', onTap: () => _onTabTapped(1)),
        QuickActionCard(title: 'Jobs', subtitle: 'Moderate listings.', icon: Icons.work_history_rounded, color: const Color(0xFFD97706), count: '$_flaggedJobs flagged', onTap: () => _onTabTapped(2)),
        QuickActionCard(title: 'Community', subtitle: 'Resolve reports.', icon: Icons.policy_rounded, color: const Color(0xFFE15A4F), count: '${_flaggedPosts + _flaggedComments} alerts', onTap: () => _onTabTapped(3)),
        QuickActionCard(title: 'Billing', subtitle: 'Track revenue.', icon: Icons.payments_outlined, color: const Color(0xFF355C9B), count: '$_premiumSubscriptions premium', onTap: () => _onTabTapped(4)),
      ],
    );
  }

  Widget _buildModerationGrid() {
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.95,
      children: [
        StatCard(title: 'Pending Companies', value: '$_pendingCompanies', subtitle: '$_verifiedCompanies verified', color: const Color(0xFF1D6F6A), icon: Icons.approval_rounded),
        StatCard(title: 'Flagged Jobs', value: '$_flaggedJobs', subtitle: 'Active listings', color: const Color(0xFFD97706), icon: Icons.report_problem_rounded),
        StatCard(title: 'Reported Posts', value: '$_flaggedPosts', subtitle: 'User reports', color: const Color(0xFFE15A4F), icon: Icons.forum_rounded),
        StatCard(title: 'Reported Comments', value: '$_flaggedComments', subtitle: 'User reports', color: const Color(0xFF355C9B), icon: Icons.comment_bank_rounded),
      ],
    );
  }

  Widget _buildPriorityQueue() {
    List<Widget> queue = [];
    if (_pendingCompanies > 0) queue.add(PriorityTile(title: 'Company approvals waiting', subtitle: '$_pendingCompanies companies need verification.', icon: Icons.approval_rounded, color: const Color(0xFF1D6F6A), onTap: () => _onTabTapped(1)));
    if (_flaggedJobs > 0) queue.add(PriorityTile(title: 'Flagged jobs need moderation', subtitle: '$_flaggedJobs job listings reported.', icon: Icons.report_problem_rounded, color: const Color(0xFFD97706), onTap: () => _onTabTapped(2)));
    if (_flaggedPosts + _flaggedComments > 0) queue.add(PriorityTile(title: 'Community queue active', subtitle: '${_flaggedPosts + _flaggedComments} reports waiting.', icon: Icons.campaign_rounded, color: const Color(0xFFE15A4F), onTap: () => _onTabTapped(3)));

    if (queue.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(22)),
        child: const Row(children: [Icon(Icons.check_circle_rounded, color: Color(0xFF1D6F6A)), SizedBox(width: 12), Expanded(child: Text('Everything looks stable right now.', style: TextStyle(fontWeight: FontWeight.w600)))]),
      );
    }
    return Column(children: queue.map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w)).toList());
  }
}

// --- SHARED COMPONENTS (Dashboard) ---

class HeroChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const HeroChip({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(30)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 16), const SizedBox(width: 8), Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))]),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title, value, subtitle;
  final Color color;
  final IconData icon;
  const StatCard({super.key, required this.title, required this.value, required this.subtitle, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textPrimary)),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: _textSecondary)),
      ]),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  final String title, subtitle, count;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const QuickActionCard({super.key, required this.title, required this.subtitle, required this.count, required this.color, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surfaceColor, borderRadius: BorderRadius.circular(24),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(24), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(20)), child: Text(count, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))),
        ]),
        const Spacer(),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
        Text(subtitle, maxLines: 2, style: const TextStyle(fontSize: 13, color: _textSecondary)),
        const SizedBox(height: 8),
        Row(children: [Text('Open', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)), const SizedBox(width: 6), Icon(Icons.arrow_forward_rounded, size: 18, color: color)]),
      ]))),
    );
  }
}

class PriorityTile extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const PriorityTile({super.key, required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surfaceColor, borderRadius: BorderRadius.circular(22),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)), Text(subtitle, style: const TextStyle(fontSize: 13, color: _textSecondary))])),
        Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
      ]))),
    );
  }
}
