import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
// Note: Update this import to point to your actual LoginScreen when ready
import '../../../core/screens/temp_main_screen.dart';
import 'create_job_screen.dart';
import 'company_list_screen.dart'; // 👉 Make sure to import the new screen
import 'manage_job_screen.dart';

class EmployerDashboard extends StatelessWidget {
  const EmployerDashboard({super.key});

  // Helper method to build menu cards
  Widget _buildDashboardCard(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employer Workspace'),
        actions: [
          // Moved the logout button up to the AppBar
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const TempMainScreen()),
                      (Route<dynamic> route) => false,
                );
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Access',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  // 👉 Routes to the Company List passing the 'employer' role
                  _buildDashboardCard(
                    context,
                    title: 'My Companies',
                    icon: Icons.business,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CompanyListScreen(userRole: 'employer'),
                        ),
                      );
                    },
                  ),

                  // Placeholder for managing existing jobs
                  _buildDashboardCard(
                    context,
                    title: 'Manage Jobs',
                    icon: Icons.work,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageJobsScreen(),
                        ),
                      );
                    },
                  ),

                  // Placeholder for the Applicant Tracking System
                  _buildDashboardCard(
                    context,
                    title: 'Applicant ATS',
                    icon: Icons.people_alt,
                    onTap: () {
                      // TODO: Navigate to ATS Dashboard
                      print('Navigate to ATS');
                    },
                  ),

                  // Placeholder for Subscription/Premium features
                  _buildDashboardCard(
                    context,
                    title: 'Billing & Plans',
                    icon: Icons.payment,
                    onTap: () {
                      // TODO: Navigate to Payment Screen
                      print('Navigate to Billing');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Kept your Floating Action Button for quick job posting
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateJobScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Post Job'),
      ),
    );
  }
}