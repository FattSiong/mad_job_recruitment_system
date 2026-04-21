import 'package:flutter/material.dart';

class SeekerDashboard extends StatelessWidget {
  const SeekerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job Seeker Module')),
      body: const Center(child: Text('Job Seeker Workspace')),
    );
  }
}