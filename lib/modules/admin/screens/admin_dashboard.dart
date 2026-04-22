import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      appBar: AppBar(title: const Text("Admin Moderation"), backgroundColor: Colors.white, elevation: 0.5),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildAdminTile(Icons.business, "Company Verification", "3 Pending", const Color(0xFFA7BED3)),
          _buildAdminTile(Icons.policy_rounded, "Job Moderation", "12 New", const Color(0xFFC6DEF1)),
          _buildAdminTile(Icons.forum_outlined, "Community Control", "5 Reported", const Color(0xFFDBCDF0)),
        ],
      ),
    );
  }

  Widget _buildAdminTile(IconData icon, String title, String count, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Text(count, style: TextStyle(color: color, fontWeight: FontWeight.bold))),
      ),
    );
  }
}