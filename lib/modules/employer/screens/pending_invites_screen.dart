import 'package:flutter/material.dart';
import '../../../services/employer_service.dart';

class PendingInvitationsScreen extends StatefulWidget {
  const PendingInvitationsScreen({super.key});

  @override
  State<PendingInvitationsScreen> createState() => _PendingInvitationsScreenState();
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
    final success = await _employerService.respondToInvitation(companyId, accept);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'You have joined the company!' : 'Invitation declined.'),
          backgroundColor: accept ? Colors.green : Colors.grey,
        ),
      );
      _loadInvitations(); // Refresh the list automatically
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Invitations')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invitations.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_email_read, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('You have no pending invitations.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _invitations.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final invite = _invitations[index];
          final companyName = invite['Company']['name'] ?? 'Unknown Company';
          final companyId = invite['companyID'];

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invitation to join:',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    companyName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _handleResponse(companyId, false),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _handleResponse(companyId, true),
                        child: const Text('Accept & Join'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}