import 'package:flutter/material.dart';
import '../../../models/company_model.dart';
import '../../../services/employer_service.dart';
import 'company_jobs_screen.dart'; // We will create this next

class ManageJobsCompanyListScreen extends StatefulWidget {
  const ManageJobsCompanyListScreen({super.key});

  @override
  State<ManageJobsCompanyListScreen> createState() => _ManageJobsCompanyListScreenState();
}

class _ManageJobsCompanyListScreenState extends State<ManageJobsCompanyListScreen> {
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
    final companies = await _employerService.getMyAcceptedCompanies();
    if (mounted) {
      setState(() {
        _companies = companies;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Company')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _companies.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _companies.length,
        itemBuilder: (context, index) {
          final company = _companies[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: const Icon(Icons.business, color: Colors.blue),
              ),
              title: Text(company.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text('SSM: ${company.registrationNumber}'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // 👉 Navigate to the specific jobs list for THIS company
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CompanyJobsScreen(company: company),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_center_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No Companies Found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'You must register a company or accept an invitation before you can manage jobs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}