import 'package:flutter/material.dart';
import 'package:mad_job_recruitment_system/modules/employer/screens/company_list_screen.dart';
import 'package:mad_job_recruitment_system/modules/employer/screens/job_company_list_screen.dart';
import 'package:mad_job_recruitment_system/modules/employer/screens/pending_invites_screen.dart';
import 'package:mad_job_recruitment_system/modules/employer/screens/scheduled_interviews_screen.dart';

class PremiumEmployerHome extends StatelessWidget {
  final String fullName;
  final int activeJobs, companyCount, interviewCount, inviteCount;
  final VoidCallback onLogout;
  final Future<void> Function() onRefresh;
  final Function(Widget) openScreen;

  const PremiumEmployerHome({
    super.key,
    required this.fullName,
    required this.activeJobs,
    required this.companyCount,
    required this.interviewCount,
    required this.inviteCount,
    required this.onLogout,
    required this.onRefresh,
    required this.openScreen,
  });

  static const Color _pinkDeep = Color(0xFFD81B60);
  static const Color _pinkLight = Color(0xFFF06292);
  static const Color _premiumGold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _pinkDeep,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPremiumHero(),
            const SizedBox(height: 32),
            _buildSectionHeader("AI Intelligence", "Premium tools to accelerate your hiring."),
            _buildActionGrid(),
            const SizedBox(height: 32),
            _buildSectionHeader("Live Performance", "Real-time metrics from your RM-optimized workspace."),
            _buildStatsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHero() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_pinkDeep, _pinkLight],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: _pinkDeep.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBadge(),
              IconButton(onPressed: onLogout, icon: const Icon(Icons.power_settings_new, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 24),
          Text(
              'Welcome back,\n${fullName.split(' ').first}',
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: 1.1)
          ),
          const SizedBox(height: 12),
          const Text('Premium Active • RM Tier Optimized', style: TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20), border: Border.all(color: _premiumGold.withOpacity(0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: _premiumGold, size: 14),
          SizedBox(width: 8),
          Text('PREMIUM PRO', style: TextStyle(color: _premiumGold, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.1)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1B2433))),
        Text(sub, style: const TextStyle(fontSize: 14, color: Color(0xFF687588))),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildActionGrid() {
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.85,
      children: [
        _ActionCard(title: "AI Jobs", sub: "Auto-generate posts", icon: Icons.psychology, color: _pinkDeep, count: "$activeJobs", onTap: () => openScreen(const ManageJobsCompanyListScreen())),
        _ActionCard(title: "Companies", sub: "Premium profiles", icon: Icons.verified, color: Colors.blueAccent, count: "$companyCount", onTap: () => openScreen(const CompanyListScreen(userRole: 'employer'))),
        _ActionCard(title: "Interviews", sub: "Auto-scheduling", icon: Icons.event_available, color: Colors.orange, count: "$interviewCount", onTap: () => openScreen(const ScheduledInterviewsScreen())),
        _ActionCard(title: "Invitations", sub: "Smart matching", icon: Icons.auto_graph, color: Colors.teal, count: "$inviteCount", onTap: () => openScreen(const PendingInvitationsScreen())),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.4,
      children: [
        _StatBox(label: "Active Jobs", val: "$activeJobs", icon: Icons.bolt, color: _pinkLight),
        _StatBox(label: "Total Companies", val: "$companyCount", icon: Icons.business, color: Colors.blue),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title, sub, count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.title, required this.sub, required this.icon, required this.color, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: color, size: 28),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text(count, style: TextStyle(color: color, fontWeight: FontWeight.bold))
                    ),
                  ]
              ),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, val;
  final IconData icon;
  final Color color;
  const _StatBox({required this.label, required this.val, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Icon(icon, color: color.withOpacity(0.5), size: 32),
          const SizedBox(width: 12),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
              ]
          ),
        ],
      ),
    );
  }
}