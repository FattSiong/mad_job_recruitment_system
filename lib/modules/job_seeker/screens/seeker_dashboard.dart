import 'package:flutter/material.dart';

import '../../../core/screens/temp_main_screen.dart';
import '../../../services/auth_service.dart';

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