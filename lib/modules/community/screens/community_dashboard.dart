import 'package:flutter/material.dart';

class CommunityDashboard extends StatelessWidget {
  const CommunityDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      body: const Center(child: Text('Community Workspace')),
    );
  }
}