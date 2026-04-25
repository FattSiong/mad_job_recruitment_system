import 'package:flutter/material.dart';
import '../../../services/employer_service.dart';

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
                      final companyName =
                          invite['Company']?['name'] ?? 'Unknown Company';
                      final companyId = invite['companyID'];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildInviteCard(
                          companyName: companyName,
                          companyId: companyId,
                        ),
                      );
                    }).toList(),
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
            'Review each invitation carefully before joining a company workspace.',
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
          'Accept an invite to join a company, or decline if it is not relevant.',
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
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCEBFB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    companyName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF163B65),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invitation to join',
                      style: TextStyle(fontSize: 13, color: Color(0xFF687588)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      companyName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B2433),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Joining this company will give you access to its employer workspace and hiring tools.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF687588),
            ),
          ),
          const SizedBox(height: 20),
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
