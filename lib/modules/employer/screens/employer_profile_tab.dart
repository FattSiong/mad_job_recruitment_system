import 'package:flutter/material.dart';

class EmployerProfileTab extends StatelessWidget {
  final String email;
  final String displayName;
  final String? profilePictureUrl;
  final bool isPremium;
  final Future<void> Function() onEditProfile;
  final Future<void> Function() onOpenSubscription;
  final VoidCallback onOpenTransactionHistory;
  final VoidCallback onOpenPostInterviewAiReportDraft;
  final VoidCallback onOpenRegisterCompany;
  final VoidCallback onOpenManageCompanies;
  final VoidCallback onOpenManageJobs;
  final VoidCallback onOpenScheduledInterviews;
  final VoidCallback onOpenPendingInvites;
  final VoidCallback onLogout;

  const EmployerProfileTab({
    super.key,
    required this.email,
    required this.displayName,
    required this.profilePictureUrl,
    required this.isPremium,
    required this.onEditProfile,
    required this.onOpenSubscription,
    required this.onOpenTransactionHistory,
    required this.onOpenPostInterviewAiReportDraft,
    required this.onOpenRegisterCompany,
    required this.onOpenManageCompanies,
    required this.onOpenManageJobs,
    required this.onOpenScheduledInterviews,
    required this.onOpenPendingInvites,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedEmail = email.isNotEmpty ? email : 'employer@email.com';

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
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Material(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () async => onEditProfile(),
                        borderRadius: BorderRadius.circular(14),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 18,
                            color: Color(0xFF163B65),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      _buildProfileAvatar(),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B2433),
                            ),
                          ),
                          if (isPremium) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.verified,
                              color: Colors.purple,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        resolvedEmail,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF687588),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (!isPremium)
              _buildProfileTile(
                icon: Icons.workspace_premium_outlined,
                title: 'Upgrade to Premium',
                subtitle: 'Unlock all AI features',
                color: Colors.purple,
                onTap: () async => onOpenSubscription(),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.purple.withOpacity(0.2),
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      color: Colors.purple,
                      size: 36,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Premium Active',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    Text(
                      'Full access to all AI features.',
                      style: TextStyle(
                        color: Colors.purple,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _buildProfileTile(
              icon: Icons.receipt_long_outlined,
              title: 'Transaction History',
              subtitle: 'View your Premium payment records',
              color: const Color(0xFF1E8F8B),
              onTap: onOpenTransactionHistory,
            ),
            const SizedBox(height: 12),
            _buildProfileTile(
              icon: Icons.auto_awesome_outlined,
              title: 'AI Interview Report (Draft)',
              subtitle: 'Temporary FYP documentation preview',
              color: const Color(0xFF6B4FD3),
              onTap: onOpenPostInterviewAiReportDraft,
            ),
            const SizedBox(height: 12),
            _buildProfileTile(
              icon: Icons.app_registration,
              title: 'Register Company',
              subtitle: 'Create a new profile',
              color: const Color(0xFF335D8A),
              onTap: onOpenRegisterCompany,
            ),
            const SizedBox(height: 12),
            _buildProfileTile(
              icon: Icons.business_rounded,
              title: 'Manage Companies',
              subtitle: 'Open your company list',
              color: const Color(0xFF163B65),
              onTap: onOpenManageCompanies,
            ),
            const SizedBox(height: 12),
            _buildProfileTile(
              icon: Icons.work_outline_rounded,
              title: 'Manage Jobs',
              subtitle: 'Review all job postings',
              color: const Color(0xFF1E8F8B),
              onTap: onOpenManageJobs,
            ),
            const SizedBox(height: 12),
            _buildProfileTile(
              icon: Icons.calendar_month_rounded,
              title: 'Scheduled Interviews',
              subtitle: 'Check interview plans',
              color: const Color(0xFFE4A73B),
              onTap: onOpenScheduledInterviews,
            ),
            const SizedBox(height: 12),
            _buildProfileTile(
              icon: Icons.mail_outline_rounded,
              title: 'Pending Invites',
              subtitle: 'View team invitations',
              color: const Color(0xFFE27D60),
              onTap: onOpenPendingInvites,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onLogout,
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

  Widget _buildProfileAvatar() {
    final firstLetter = displayName.trim().isNotEmpty
        ? displayName.trim().substring(0, 1).toUpperCase()
        : 'E';
    final hasProfilePicture =
        profilePictureUrl != null && profilePictureUrl!.isNotEmpty;

    return CircleAvatar(
      radius: 34,
      backgroundColor:
          isPremium ? Colors.purple.shade100 : const Color(0xFFDCEBFB),
      backgroundImage:
          hasProfilePicture ? NetworkImage(profilePictureUrl!) : null,
      child: !hasProfilePicture
          ? Text(
              firstLetter,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isPremium
                    ? Colors.purple.shade700
                    : const Color(0xFF163B65),
              ),
            )
          : null,
    );
  }
}
