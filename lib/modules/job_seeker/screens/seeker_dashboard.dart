import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/screens/temp_main_screen.dart';
import '../../../services/auth_service.dart';
import '../../community/screens/community_dashboard.dart';

class SeekerDashboard extends StatelessWidget {
  const SeekerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job Seeker Module')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Select Function to Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
            onPressed: () {
              // Grab the currently logged-in user's UUID directly from Supabase
              final String currentUserId = Supabase.instance.client.auth.currentUser!.id;

              // Navigate to the Community Dashboard and pass the ID
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CommunityDashboard(currentUserID: currentUserId),
                ),
              );
            },
            child: const Text('Community'),
          ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                // 1. Tell Supabase to destroy the saved session
                await AuthService().signOut();

                // 2. Kick them back to the login screen and clear the route history
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    // MaterialPageRoute(builder: (context) => const LoginScreen()),
                    MaterialPageRoute(builder: (context) => const TempMainScreen()),
                        (Route<dynamic> route) => false,
                  );
                }
              },
            )
          ],

        ),
      ),

    );
  }
}