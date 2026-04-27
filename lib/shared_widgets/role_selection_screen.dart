import 'package:flutter/material.dart';

import 'signup_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  static const Color _pageBackground = Color(0xFFF4F7FB);
  static const Color _cardColor = Colors.white;
  static const Color _primary = Color(0xFF163B65);
  static const Color _primarySoft = Color(0xFF335D8A);
  static const Color _textPrimary = Color(0xFF1B2433);
  static const Color _textSecondary = Color(0xFF687588);

  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    _BackButtonChip(onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Choose account type',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RoleOptionCard(
                        title: 'Job Seeker',
                        subtitle:
                            'Find jobs, manage applications, and practice interviews with a guided candidate flow.',
                        icon: Icons.person_search_rounded,
                        accentColor: const Color(0xFF1E8F8B),
                        highlights: const [
                          'Track applications',
                          'Build your profile',
                          'Prepare for interviews',
                        ],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const SignUpScreen(role: 'job_seeker'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _RoleOptionCard(
                        title: 'Employer',
                        subtitle:
                            'Post jobs, manage company hiring, and coordinate interviews from one workspace.',
                        icon: Icons.business_center_rounded,
                        accentColor: const Color(0xFFD97706),
                        highlights: const [
                          'Manage job postings',
                          'Review candidates',
                          'Schedule interviews',
                        ],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const SignUpScreen(role: 'employer'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already have an account?',
                            style: TextStyle(color: _textSecondary),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: _primary,
                            ),
                            child: const Text(
                              'Log in',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<String> highlights;
  final VoidCallback onTap;

  const _RoleOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.highlights,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accentColor.withValues(alpha: 0.18)),
            gradient: LinearGradient(
              colors: [
                accentColor.withValues(alpha: 0.08),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: accentColor, size: 28),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: accentColor,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B2433),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF687588),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: highlights
                    .map(
                      (item) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Text(
                          item,
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButtonChip extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButtonChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE1E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF1B2433),
          ),
        ),
      ),
    );
  }
}
