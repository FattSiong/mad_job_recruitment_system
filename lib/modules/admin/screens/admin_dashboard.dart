import 'package:flutter/material.dart';
import 'package:mad_job_recruitment_system/modules/admin/screens/AdminCommunityScreen.dart';
import 'package:mad_job_recruitment_system/modules/admin/screens/AdminSubscriptionListScreen.dart';
import '../../../core/screens/temp_main_screen.dart';
import '../../../services/auth_service.dart';
import 'company_verification_screen.dart';
import 'admin_job_details.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text("Admin Dashboard",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        // 👇 Move the button into the 'actions' array
        actions: [
          IconButton(
            // 👇 Change the color to black so it's visible on the white app bar
            icon: const Icon(Icons.logout, color: Colors.black, size: 20),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const TempMainScreen(),
                  ),
                      (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      ),

      body: IndexedStack(
        index: _currentIndex,
        children: const [
          CompanyVerificationScreen(),
          AdminJobModerationScreen(),
          AdminCommunityScreen(),
          AdminSubscriptionListScreen(),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.business_outlined),
              activeIcon: Icon(Icons.business),
              label: 'Companies'
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.work_outline),
              activeIcon: Icon(Icons.work),
              label: 'Jobs'
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.shield),
              label: 'Community'
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.credit_card_outlined),
              activeIcon: Icon(Icons.credit_card),
              label: 'Billing'
          ),
        ],
      ),
    );
  }
}