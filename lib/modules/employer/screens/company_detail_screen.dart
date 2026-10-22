import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/company_model.dart';
import '../../../services/employer_service.dart';
import 'edit_company_screen.dart';

class CompanyDetailScreen extends StatefulWidget {
  final CompanyModel company;

  const CompanyDetailScreen({super.key, required this.company});

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  final _employerService = EmployerService();
  final _currentUser = Supabase.instance.client.auth.currentUser;
  late CompanyModel _company;

  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isOwner = false;
  bool _isActiveMember = false;

  @override
  void initState() {
    super.initState();
    _company = widget.company;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);

    final members = await _employerService.getCompanyMembers(widget.company.companyID!);

    if (mounted) {
      setState(() {
        _members = members;
        _isOwner = false;
        _isActiveMember = false;

        if (_currentUser != null) {
          final myRecord = members.where((m) => m['employerID'] == _currentUser.id).toList();
          if (myRecord.isNotEmpty) {
            final status = (myRecord.first['status'] ?? '').toString().toLowerCase();
            final role = (myRecord.first['companyRole'] ?? '').toString().toLowerCase();
            _isActiveMember = status == 'active';
            if (role == 'owner' && _isActiveMember) {
              _isOwner = true;
            }
          }
        }

        _isLoading = false;
      });
    }
  }

  Future<void> _showInviteDialog() async {
    final emailController = TextEditingController();
    bool isSending = false;
    String? emailError;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCEBFB),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Color(0xFF163B65),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Invite Team Member',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1B2433),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Invite another employer to help manage jobs and hiring for this company.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Color(0xFF687588),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) {
                        if (emailError != null) {
                          setDialogState(() => emailError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Employer Email',
                        errorText: emailError,
                        prefixIcon: const Icon(Icons.email_outlined),
                        filled: true,
                        fillColor: const Color(0xFFF7F9FC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFF163B65),
                            width: 1.4,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0xFFC24E4E)),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFFC24E4E),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSending
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF687588),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isSending
                                ? null
                                : () async {
                              final email = emailController.text.trim();

                              if (email.isEmpty) {
                                setDialogState(() {
                                  emailError = 'Please enter an employer email.';
                                });
                                return;
                              }

                              setDialogState(() => isSending = true);

                              final resultMessage =
                              await _employerService.sendInvitation(
                                widget.company.companyID!,
                                email,
                              );

                              setDialogState(() => isSending = false);

                              if (context.mounted) {
                                if (resultMessage == 'Success') {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invitation sent successfully!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  _loadMembers();
                                } else {
                                  setDialogState(() {
                                    emailError = resultMessage;
                                  });
                                }
                              }
                            },
                            icon: isSending
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(Icons.send_rounded, size: 18),
                            label: Text(isSending ? 'Sending...' : 'Send Invite'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF163B65),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
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


  @override
  Widget build(BuildContext context) {
    final company = _company;

    final isRejected = company.verificationStatus.toLowerCase() == 'rejected';
    final isApproved =
        company.isVerified ||
            company.verificationStatus.toLowerCase() == 'verified' ||
            company.verificationStatus.toLowerCase() == 'approved';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      floatingActionButton: (_isOwner && !_isLoading && isApproved)
          ? FloatingActionButton.extended(
        onPressed: _showInviteDialog,
        backgroundColor: const Color(0xFF163B65),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Invite Member'),
      )
          : null,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _buildTopBar(context, isApproved),
            const SizedBox(height: 16),
            _buildHeroCard(company, isApproved, isRejected),
            const SizedBox(height: 18),
            if (isRejected &&
                company.rejectionReason != null &&
                company.rejectionReason!.isNotEmpty) ...[
              _buildRejectionCard(company.rejectionReason!),
              const SizedBox(height: 18),
            ],
            _buildSectionCard(
              title: 'About Company',
              subtitle: 'A quick look at the company profile and registration details.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    icon: Icons.badge_rounded,
                    label: 'Registration No. (SSM)',
                    value: company.registrationNumber,
                  ),
                  const SizedBox(height: 14),
                  if (company.companyAddress != null &&
                      company.companyAddress!.trim().isNotEmpty) ...[
                    _buildInfoRow(
                      icon: Icons.location_on_rounded,
                      label: 'Company Address',
                      value: company.companyAddress!,
                    ),
                    const SizedBox(height: 14),
                  ],
                  _buildInfoRow(
                    icon: Icons.description_rounded,
                    label: 'Description',
                    value: company.description.trim().isEmpty
                        ? 'No company description added yet.'
                        : company.description,
                  ),
                ],
              ),
            ),
            if (isApproved && _isActiveMember) ...[
              const SizedBox(height: 18),
              _buildSectionCard(
                title: 'Team Members',
                subtitle: 'People who currently help manage this company.',
                child: _members.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No members found for this company yet.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF687588),
                    ),
                  ),
                )
                    : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final rawProfile = member['Employer'];
                    final profile = rawProfile is List
                        ? (rawProfile.isNotEmpty
                            ? Map<String, dynamic>.from(rawProfile.first)
                            : <String, dynamic>{})
                        : rawProfile is Map
                            ? Map<String, dynamic>.from(rawProfile)
                            : <String, dynamic>{};
                    final name = profile['fullName'] ?? 'Unknown User';
                    final email = profile['email'] ?? 'No email provided';
                    final profilePictureUrl =
                        profile['profilePictureURL'] ??
                        profile['profilepictureurl'];
                    final isOwner = member['companyRole'] == 'owner';
                    final isPending = member['status'] == 'pending';

                    return _buildMemberCard(
                      name: name,
                      email: email,
                      profilePictureUrl: profilePictureUrl?.toString(),
                      role: member['companyRole'].toString(),
                      isOwner: isOwner,
                      isPending: isPending,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isApproved) {
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
              child: Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF163B65),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Company Details',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
        ),
        if (_isOwner && isApproved)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () async {
                final didUpdate = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditCompanyScreen(company: _company),
                  ),
                );

                if (didUpdate == true) {
                  await _reloadCompanyDetails();
                  await _loadMembers();
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.edit_rounded,
                  color: Color(0xFF163B65),
                ),
              ),
            ),
          ),
      ],
    );
  }


  Widget _buildHeroCard(
      CompanyModel company,
      bool isApproved,
      bool isRejected,
      ) {
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
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.14),
                backgroundImage: company.companyLogoURL != null &&
                    company.companyLogoURL!.isNotEmpty
                    ? NetworkImage(company.companyLogoURL!)
                    : null,
                child: company.companyLogoURL == null ||
                    company.companyLogoURL!.isEmpty
                    ? Text(
                  company.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroBadge(
                label: isApproved
                    ? 'Verified'
                    : isRejected
                    ? 'Rejected'
                    : 'Pending Verification',
                icon: isApproved
                    ? Icons.verified_rounded
                    : isRejected
                    ? Icons.cancel_outlined
                    : Icons.schedule_rounded,
                bg: isApproved
                    ? const Color(0xFFE5F6ED)
                    : isRejected
                    ? const Color(0xFFFCE9E9)
                    : const Color(0xFFFEF3DC),
                fg: isApproved
                    ? const Color(0xFF2D8A5D)
                    : isRejected
                    ? const Color(0xFFC24E4E)
                    : const Color(0xFFC28A22),
              ),
              _buildHeroBadge(
                label: company.currentPlanType.toUpperCase() == 'ANNUALLY'
                    ? 'PREMIUM ANNUAL'
                    : company.currentPlanType.toUpperCase() == 'MONTHLY'
                    ? 'PREMIUM MONTHLY'
                    : 'STANDARD PLAN',
                icon: (company.currentPlanType.toUpperCase() == 'ANNUALLY' ||
                        company.currentPlanType.toUpperCase() == 'MONTHLY')
                    ? Icons.workspace_premium_rounded
                    : Icons.layers_outlined,
                bg: company.currentPlanType.toUpperCase() == 'ANNUALLY'
                    ? const Color(0xFFEEE8FF)
                    : company.currentPlanType.toUpperCase() == 'MONTHLY'
                    ? const Color(0xFFE2F6F5)
                    : const Color(0xFFEFF3F8),
                fg: company.currentPlanType.toUpperCase() == 'ANNUALLY'
                    ? const Color(0xFF6B4FD3)
                    : company.currentPlanType.toUpperCase() == 'MONTHLY'
                    ? const Color(0xFF1E8F8B)
                    : const Color(0xFF687588),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionCard(String reason) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE9E9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFC24E4E),
              ),
              SizedBox(width: 10),
              Text(
                'Registration Rejected',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFC24E4E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            reason,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF7A2C2C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
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
                label,
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

  Widget _buildMemberCard({
    required String name,
    required String email,
    required String? profilePictureUrl,
    required String role,
    required bool isOwner,
    required bool isPending,
  }) {
    final Color accentColor = isOwner
        ? const Color(0xFFE4A73B)
        : isPending
        ? const Color(0xFFC28A22)
        : const Color(0xFF163B65);
    final hasProfilePicture =
        profilePictureUrl != null && profilePictureUrl.trim().isNotEmpty;
    final firstLetter = name.trim().isNotEmpty
        ? name.trim().substring(0, 1).toUpperCase()
        : 'U';
    final normalizedProfilePictureUrl =
        hasProfilePicture ? profilePictureUrl.trim() : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: accentColor.withOpacity(0.12),
            backgroundImage: normalizedProfilePictureUrl != null
                ? NetworkImage(normalizedProfilePictureUrl)
                : null,
            child: !hasProfilePicture
                ? Text(
                    firstLetter,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B2433),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF687588),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildRoleChip(
            isPending
                ? 'Pending Invite'
                : (isOwner ? 'Owner' : 'Member'),
            accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBadge({
    required String label,
    required IconData icon,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Future<void> _reloadCompanyDetails() async {
    final companyId = _company.companyID;
    if (companyId == null) return;

    final refreshedCompany = await _employerService.getCompanyById(companyId);

    if (!mounted || refreshedCompany == null) return;

    setState(() {
      _company = refreshedCompany;
    });
  }
}
