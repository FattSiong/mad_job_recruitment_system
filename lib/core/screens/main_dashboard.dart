import 'package:flutter/material.dart';

class MainDashboard extends StatelessWidget {
  const MainDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7), // 极简米白色背景
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 顶部欢迎语
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Hello, User",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A))),
                    const SizedBox(height: 8),
                    Text("Welcome to the SDG Job Platform",
                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              ),
            ),

            // 核心模块网格
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.9,
                ),
                delegate: SliverChildListDelegate([
                  _buildModuleCard(context, "Job Search", Icons.search_rounded, const Color(0xFFA7BED3), "Job Seeker"),
                  _buildModuleCard(context, "Recruitment", Icons.business_center_outlined, const Color(0xFFC6DEF1), "Employer"),
                  _buildModuleCard(context, "Moderation", Icons.security_outlined, const Color(0xFFF2C6DE), "Admin"),
                  _buildModuleCard(context, "AI Training", Icons.psychology_outlined, const Color(0xFFDBCDF0), "AI Module"),
                  _buildModuleCard(context, "Community", Icons.forum_outlined, const Color(0xFFF7D9C4), "Social"),
                  _buildModuleCard(context, "Subscription", Icons.stars_rounded, const Color(0xFFE2ECE9), "Payment"),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard(BuildContext context, String title, IconData icon, Color color, String role) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            // 这里之后会连接到各个具体的模块
            print("Navigating to $title");
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4A4A4A))),
              const SizedBox(height: 4),
              Text(role, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}