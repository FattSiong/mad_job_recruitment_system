import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
// Note: Update these imports to point to your actual screens
import '../../../core/screens/temp_main_screen.dart';
import 'create_job_screen.dart';
import 'company_list_screen.dart';
import 'job_company_list_screen.dart';
import 'manage_job_screen.dart';
import 'pending_invites_screen.dart';

class EmployerDashboard extends StatefulWidget {
  const EmployerDashboard({super.key});

  @override
  State<EmployerDashboard> createState() => _EmployerDashboardState();
}

class _EmployerDashboardState extends State<EmployerDashboard> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    if (index == 0) {
      setState(() => _currentIndex = index); // Home
    } else if (index == 1) {
      print('Navigate to Chats');
    } else if (index == 2) {
      print('Navigate to Community');
    } else if (index == 3) {
      print('Navigate to Profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7), // Morandi background
      body: Column(
        children: [
          // 1. Custom Deep Blue Header
          _buildHeader(context),

          // 2. Main Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 👉 Removed "Workspace Tools" text and adjusted padding
                  const SizedBox(height: 32),

                  // 3. Grid View (One row, 4 items)
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4, // 👉 Changed to 4 columns
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 20,
                    childAspectRatio: 0.8, // 👉 Adjusted so text has room to wrap
                    children: [
                      _buildDashboardIcon(
                        context,
                        title: 'Companies',
                        icon: Icons.business_outlined,
                        color: const Color(0xFFA7BED3),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CompanyListScreen(userRole: 'employer'),
                            ),
                          );
                        },
                      ),
                      _buildDashboardIcon(
                        context,
                        title: 'Jobs',
                        icon: Icons.work_outline,
                        color: const Color(0xFFC6DEF1),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ManageJobsCompanyListScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDashboardIcon(
                        context,
                        title: 'ATS Module',
                        icon: Icons.people_alt_outlined,
                        color: const Color(0xFFDBCDF0),
                        onTap: () {
                          print('Navigate to ATS');
                        },
                      ),
                      _buildDashboardIcon(
                        context,
                        title: 'Invites',
                        icon: Icons.mail_outline,
                        color: const Color(0xFFE2ECE9),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PendingInvitationsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 80), // Padding so FAB doesn't block icons
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF6D8299),
        unselectedItemColor: Colors.grey,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_outlined), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateJobScreen()),
          );
        },
        backgroundColor: const Color(0xFF1A2A4D),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: const Text('Post Job', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: const BoxDecoration(
        color: Color(0xFF1A2A4D),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30)
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text("Welcome back", style: TextStyle(color: Colors.white70, fontSize: 12)),
              SizedBox(height: 4),
              Text(
                  "Employer Workspace",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white, size: 20),
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
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDashboardIcon(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14), // 👉 Slightly reduced padding to fit 4 columns
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 5
                )
              ],
            ),
            child: Icon(icon, color: color, size: 28), // 👉 Slightly smaller icon
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, // 👉 Slightly smaller text to prevent clipping
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A4A4A)
            ),
          ),
        ],
      ),
    );
  }
}