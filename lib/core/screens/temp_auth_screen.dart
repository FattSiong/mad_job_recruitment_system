import 'package:flutter/material.dart';
import '../../modules/employer/screens/employer_dashboard.dart';
import '../../modules/job_seeker/screens/seeker_dashboard.dart';
import '../../modules/admin/screens/admin_dashboard.dart';
import '../../modules/community/screens/community_dashboard.dart';
import '../../modules/job_seeker/screens/seeker_main_screen.dart';

class TempAuthScreen extends StatelessWidget {
  final String selectedRole;

  const TempAuthScreen({super.key, required this.selectedRole});

  void _navigateToDashboard(BuildContext context) {
    Widget destination;

    // Route based on the role passed from the main screen
    switch (selectedRole) {
      case 'Employer':
        destination = const EmployerDashboard();
        break;
      case 'Seeker':
        destination = const SeekerMainScreen();
        break;
      case 'Community':
        destination = const CommunityDashboard();
        break;
      case 'Admin':
      default:
        destination = const AdminDashboard();
        break;
    }

    // Use pushReplacement so the user can't hit the "back" button to go back to the auth screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Temporary Auth')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Mock Login for: $selectedRole',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => _navigateToDashboard(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
