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

  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);

    final members = await _employerService.getCompanyMembers(widget.company.companyID!);

    if (mounted) {
      setState(() {
        _members = members;

        if (_currentUser != null) {
          final myRecord = members.where((m) => m['employerID'] == _currentUser.id).toList();
          if (myRecord.isNotEmpty && myRecord.first['companyRole'] == 'owner') {
            _isOwner = true;
          }
        }

        _isLoading = false;
      });
    }
  }

  Future<void> _showInviteDialog() async {
    final emailController = TextEditingController();
    bool isSending = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Invite Team Member'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter the email address of the employer you want to invite to manage jobs for this company.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Employer Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                    if (emailController.text.trim().isEmpty) return;

                    setDialogState(() => isSending = true);

                    final resultMessage = await _employerService.sendInvitation(
                      widget.company.companyID!,
                      emailController.text,
                    );

                    setDialogState(() => isSending = false);

                    if (context.mounted) {
                      if (resultMessage == 'Success') {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invitation sent successfully!'), backgroundColor: Colors.green),
                        );
                        _loadMembers();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(resultMessage), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: isSending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Send Invite'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final company = widget.company;

    // 👉 State definitions
    final isRejected = company.verificationStatus.toLowerCase() == 'rejected';
    final isApproved = company.isVerified || company.verificationStatus.toLowerCase() == 'verified' || company.verificationStatus.toLowerCase() == 'approved';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Details'),
        actions: [
          // 👉 NEW: Only show Edit & Invite buttons if the company is completely verified
          if (_isOwner && !_isLoading && isApproved) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Company',
              onPressed: () async {
                final didUpdate = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditCompanyScreen(company: widget.company),
                  ),
                );

                if (didUpdate == true) {
                  _loadMembers();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'Invite Member',
              onPressed: _showInviteDialog,
            ),
          ]
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- COMPANY HEADER INFO ---
            Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.blue.shade50,
                  backgroundImage: company.companyLogoURL != null && company.companyLogoURL!.isNotEmpty
                      ? NetworkImage(company.companyLogoURL!)
                      : null,
                  child: company.companyLogoURL == null || company.companyLogoURL!.isEmpty
                      ? Text(
                    company.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
                  )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(company.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text('SSM: ${company.registrationNumber}', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Verification & Plan Status Badges
            Row(
              children: [
                _buildBadge(
                  company.isVerified ? 'VERIFIED' : company.verificationStatus.toUpperCase(),
                  isRejected ? Colors.red : (company.isVerified ? Colors.green : Colors.orange),
                ),
                const SizedBox(width: 8),
                _buildBadge(
                  company.currentPlanType.toUpperCase(),
                  company.currentPlanType == 'PREMIUM' ? Colors.purple : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 👉 NEW: Show the red rejection reason box if rejected
            if (isRejected && company.rejectionReason != null && company.rejectionReason!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Registration Rejected',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      company.rejectionReason!,
                      style: TextStyle(color: Colors.red.shade900, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            const Text('About Company', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(company.description, style: const TextStyle(fontSize: 16, height: 1.5)),

            // 👉 NEW: Only render the team members block if approved
            if (isApproved) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(),
              ),

              // --- TEAM MEMBERS SECTION ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Team Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (_isOwner)
                    TextButton.icon(
                      onPressed: _showInviteDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Invite'),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // List of Members
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final member = _members[index];
                  final profile = member['Employer'] ?? {};
                  final name = profile['fullName'] ?? 'Unknown User';
                  final email = profile['email'] ?? 'No email provided';

                  final isOwner = member['companyRole'] == 'owner';
                  final isPending = member['status'] == 'pending';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isOwner ? Colors.amber.shade100 : Colors.grey.shade200,
                        child: Icon(
                          isOwner ? Icons.star : Icons.person,
                          color: isOwner ? Colors.amber.shade700 : Colors.grey.shade600,
                        ),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(email),
                      trailing: isPending
                          ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Pending', style: TextStyle(color: Colors.orange, fontSize: 12)),
                      )
                          : Text(
                        member['companyRole'].toString().toUpperCase(),
                        style: TextStyle(
                          color: isOwner ? Colors.amber.shade800 : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper UI Widget
  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}