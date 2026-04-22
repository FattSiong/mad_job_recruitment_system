import 'package:flutter/material.dart';
import 'signup_screen.dart'; // We will build this next

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Account Type'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'How do you want to use the app?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Job Seeker Option
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SignUpScreen(role: 'job_seeker'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),                foregroundColor: Colors.blue,
                elevation: 0,
                side: const BorderSide(color: Colors.blue),
              ),
              child: const Column(
                children: [
                  Icon(Icons.person_search, size: 48),
                  SizedBox(height: 8),
                  Text('I am a Job Seeker', style: TextStyle(fontSize: 18)),
                  Text('I want to find jobs and practice interviews', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Employer Option
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SignUpScreen(role: 'employer'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Colors.orangeAccent.withValues(alpha: 0.1),
                foregroundColor: Colors.orange.shade800,
                elevation: 0,
                side: BorderSide(color: Colors.orange.shade800),
              ),
              child: const Column(
                children: [
                  Icon(Icons.business_center, size: 48),
                  SizedBox(height: 8),
                  Text('I am an Employer', style: TextStyle(fontSize: 18)),
                  Text('I want to post jobs and find candidates', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}