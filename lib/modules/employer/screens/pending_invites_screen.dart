import 'package:flutter/material.dart';
import '../../../models/company_model.dart';
import '../../../services/employer_service.dart';
import 'company_detail_screen.dart';

class PendingInvitationsScreen extends StatefulWidget {
  const PendingInvitationsScreen({super.key});

  @override
  State<PendingInvitationsScreen> createState() =>
      _PendingInvitationsScreenState();
}

class _PendingInvitationsScreenState extends State<PendingInvitationsScreen> {
  final _employerService = EmployerService();
  List<Map<String, dynamic>> _invitations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    setState(() => _isLoading = true);

    final invites = await _employerService.getMyPendingInvitations();

    if (mounted) {
      setState(() {
        _invitations = invites;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleResponse(String companyId, bool accept) async {
    final success = await _employerService.respondToInvitation(
      companyId,
      accept,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'You have joined the company!' : 'Invitation declined.',
          ),
          backgroundColor: accept ? Colors.green : Colors.grey,
        ),
      );
      _loadInvitations(); // Refresh the list automatically
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  CompanyModel? _extractCompanyModel(Map<String, dynamic> invite) {
    final rawCompany = invite['Company'];
    if (rawCompany is Map<String, dynamic>) {
      try {
        return CompanyModel.fromJson(rawCompany);
      } catch (_) {}
    } else if (rawCompany is Map) {
      try {
        return CompanyModel.fromJson(Map<String, dynamic>.from(rawCompany));
      } catch (_) {}
    }
    return null;
  }

  Future<void> _openCompanyProfile({
    required String companyId,
    CompanyModel? companyModel,
  }) async {
    CompanyModel? targetCompany = companyModel;

    if (targetCompany == null || targetCompany.companyID == null) {
      targetCompany = await _employerService.getCompanyById(companyId);
    }

    if (!mounted) return;

    if (targetCompany == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load company profile details.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyDetailScreen(company: targetCompany!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 16),
                  _buildHeroCard(),
                  const SizedBox(height: 24),
                  if (_invitations.isEmpty)
                    _buildEmptyState()
                  else ...[
                    _buildSectionHeader(),
                    const SizedBox(height: 16),
                    ..._invitations.map((invite) {
                      final companyModel = _extractCompanyModel(invite);
                      final companyName = companyModel?.name ??
                          invite['Company']?['name'] ??
                          'Unknown Company';
                      final companyId = invite['companyID']?.toString() ?? '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildInviteCard(
                          companyName: companyName,
                          companyId: companyId,
                          company: companyModel,
                        ),
                      );
                    }),
                  ],
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
            'Pending Invites',
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
            onTap: _loadInvitations,
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

  Widget _buildHeroCard() {
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
                Icon(Icons.mail_outline_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Team Invitations',
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
            _invitations.isEmpty
                ? 'No pending company invites'
                : '${_invitations.length} invitation${_invitations.length > 1 ? 's' : ''} waiting for your response',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Inspect each company profile carefully before joining a company workspace.',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invitation List',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B2433),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'View the company profile to learn more, then accept or decline the invitation.',
          style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF687588)),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
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
              Icons.mark_email_read_rounded,
              size: 36,
              color: Color(0xFF163B65),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'You have no pending invitations',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'When another employer invites you to help manage a company, it will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF687588),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCard({
    required String companyName,
    required String companyId,
    CompanyModel? company,
  }) {
    final bool hasLogo = company?.companyLogoURL != null &&
        company!.companyLogoURL!.trim().isNotEmpty;
    final bool isVerified = company != null &&
        (company.isVerified ||
            company.verificationStatus.toLowerCase() == 'verified' ||
            company.verificationStatus.toLowerCase() == 'approved');
    final String? address =
        (company?.companyAddress != null &&
                company!.companyAddress!.trim().isNotEmpty)
            ? company.companyAddress!.trim()
            : null;
    final String? description =
        (company != null && company.description.trim().isNotEmpty)
            ? company.description.trim()
            : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D10243E),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _openCompanyProfile(
              companyId: companyId,
              companyModel: company,
            ),
            borderRadius: BorderRadius.circular(18),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEBFB),
                    borderRadius: BorderRadius.circular(16),
                    image: hasLogo
                        ? DecorationImage(
                            image: NetworkImage(company!.companyLogoURL!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: !hasLogo
                      ? Center(
                          child: Text(
                            companyName.isNotEmpty
                                ? companyName.substring(0, 1).toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF163B65),
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Invitation to join',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF687588),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              companyName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B2433),
                              ),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              size: 18,
                              color: Color(0xFF2D8A5D),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF687588),
                ),
              ],
            ),
          ),
          if (address != null) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Color(0xFF687588),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4F5C6C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            description ??
                'Joining this company will give you access to its employer workspace and hiring tools.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF687588),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _openCompanyProfile(
                companyId: companyId,
                companyModel: company,
              ),
              icon: const Icon(Icons.business_rounded, size: 18),
              label: const Text(
                'View Company Profile',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5FA),
                foregroundColor: const Color(0xFF163B65),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleResponse(companyId, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC24E4E),
                    side: const BorderSide(color: Color(0xFFF1C5C5)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleResponse(companyId, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF163B65),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Accept & Join',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
