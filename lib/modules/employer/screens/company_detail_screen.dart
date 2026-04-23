import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/company_model.dart';

class CompanyDetailScreen extends StatefulWidget {
  final CompanyModel company;

  // Removed userRole parameter since this is now strictly an Employer screen
  const CompanyDetailScreen({
    super.key,
    required this.company,
  });

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  late CompanyModel _currentCompany;

  @override
  void initState() {
    super.initState();
    _currentCompany = widget.company;
  }

  // Helper to open the document URL
  Future<void> _launchDocumentURL() async {
    final urlString = _currentCompany.verificationDocumentURL;
    if (urlString == null || urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No document attached.')),
      );
      return;
    }

    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the document.')),
        );
      }
    }
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    switch (status.toLowerCase()) {
      case 'approved':
      case 'verified':
        badgeColor = Colors.green;
        break;
      case 'rejected':
        badgeColor = Colors.red;
        break;
      default:
        badgeColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        border: Border.all(color: badgeColor, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _currentCompany.name,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStatusBadge(_currentCompany.verificationStatus),
              ],
            ),
            const SizedBox(height: 24),

            // Details Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Registration (SSM) Number', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(_currentCompany.registrationNumber, style: const TextStyle(fontSize: 18)),
                    const Divider(height: 32),

                    const Text('Company Description', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                        _currentCompany.description.isEmpty ? 'No description provided.' : _currentCompany.description,
                        style: const TextStyle(fontSize: 16, height: 1.5)
                    ),
                    const Divider(height: 32),

                    const Text('Verification Document', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _launchDocumentURL,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('View Document'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade50,
                        foregroundColor: Colors.blueGrey.shade900,
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Action Buttons (Employer Only)
            // Only show the "Manage Jobs" button if the admin has verified the company
            if (_currentCompany.isVerified) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Navigate to job list specifically filtered for this company
                    print('View Jobs for ${_currentCompany.name}');
                  },
                  icon: const Icon(Icons.work),
                  label: const Text('Manage Jobs for this Company'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You can start posting and managing jobs once an admin verifies your company registration.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    )
                  ],
                ),
              )
            ],
          ],
        ),
      ),
    );
  }
}