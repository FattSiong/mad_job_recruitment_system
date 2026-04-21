import 'package:flutter/material.dart';
import 'temp_auth_screen.dart';

class TempMainScreen extends StatelessWidget {
  const TempMainScreen({super.key});

  void _goToAuth(BuildContext context, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TempAuthScreen(selectedRole: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dev Entry Point')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Select Module to Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => _goToAuth(context, 'Admin'),
              child: const Text('Go to Admin Auth'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _goToAuth(context, 'Employer'),
              child: const Text('Go to Employer Auth'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _goToAuth(context, 'Seeker'),
              child: const Text('Go to Seeker Auth'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _goToAuth(context, 'Community'),
              child: const Text('Go to Community Auth'),
            ),
          ],
        ),
      ),
    );
  }
}