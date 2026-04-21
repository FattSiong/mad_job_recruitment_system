import 'package:flutter/material.dart';
import 'create_job_screen.dart'; // Import the screen we just made
import 'register_company_screen.dart';

class EmployerDashboard extends StatelessWidget {
  const EmployerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employer Workspace')),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterCompanyScreen()),
                  );
                },
                child: const Text('Register Company'),
              ),
            ],
          ),
        ),
      // Add this button to navigate to the creation form!
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