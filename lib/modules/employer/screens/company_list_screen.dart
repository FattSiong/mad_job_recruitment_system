import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/company_model.dart';
import '../../../services/employer_service.dart';
import 'company_detail_screen.dart';
import 'register_company_screen.dart'; // Import your register screen

class CompanyListScreen extends StatefulWidget {
  final String userRole; // Pass 'admin' or 'employer' when navigating here

  const CompanyListScreen({super.key, required this.userRole});

  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  final _employerService = EmployerService();

  List<CompanyModel> _companies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoading = true);

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      final fetchedCompanies = await _employerService.getCompanies(
        currentUser.id,
        widget.userRole,
      );

      if (mounted) {
        setState(() {
          _companies = fetchedCompanies;
          _isLoading = false;
        });
      }
    }
  }

  // Helper widget to color-code the status
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
      default: // 'pending'
        badgeColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        border: Border.all(color: badgeColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.userRole == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Company Directory (Admin)' : 'My Companies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCompanies,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _companies.isEmpty
          ? Center(
        child: Text(
          isAdmin
              ? 'No companies registered in the system yet.'
              : 'You haven\'t registered or joined any companies.',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _companies.length,
        itemBuilder: (context, index) {
          final company = _companies[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                company.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('SSM: ${company.registrationNumber}'),
                  const SizedBox(height: 4),
                  Text(
                    company.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              // Only show the status badge if it's an admin, OR if the company is pending/rejected so the employer knows
              trailing: (isAdmin || !company.isVerified)
                  ? _buildStatusBadge(company.verificationStatus)
                  : const Icon(Icons.verified, color: Colors.blue, size: 32),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CompanyDetailScreen(
                      company: company, // We just pass the company now!
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      // Only employers should see the button to register a new company
      floatingActionButton: !isAdmin
          ? FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to register screen and wait for it to close
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegisterCompanyScreen()),
          );
          // Refresh the list when they come back
          _loadCompanies();
        },
        icon: const Icon(Icons.add_business),
        label: const Text('Register Company'),
      )
          : null,
    );
  }
}