import 'package:flutter/material.dart';
// 导入对应的页面路径，请根据你实际的项目文件夹名称调整

import '../../modules/community/screens/community_dashboard.dart';
import '../core/screens/login_page.dart';

class TempMainScreen extends StatefulWidget {
  const TempMainScreen({super.key});

  @override
  State<TempMainScreen> createState() => _TempMainScreenState();
}

class _TempMainScreenState extends State<TempMainScreen> {
  int _currentIndex = 0;

  // 处理底部导航栏跳转逻辑
  void _onTabTapped(int index) {
    if (index == 0) {
      setState(() => _currentIndex = index);
    } else if (index == 1) {
      // For you -> Community Dashboard
      //Navigator.push(context, MaterialPageRoute(builder: (context) => const CommunityDashboard()));
    } else if (index == 2) {
      // Chats -> Chat & Interview Main Screen
      //Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatMainScreen()));
    } else if (index == 3) {
      // My Jobs -> Seeker Dashboard
      //Navigator.push(context, MaterialPageRoute(builder: (context) => const SeekerDashboard()));
    } else if (index == 4) {
      // Profile -> Login/Sign Up Page
      Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7), // 莫兰迪底色
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. 顶部 Header (深蓝色背景 + 搜索框)
            _buildHeader(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // 2. 功能金刚区 (Grid) - 纯求职功能，无 Admin 按钮
                  _buildCategoryGrid(),

                  const SizedBox(height: 24),

                  // 3. 广告横幅 (Banner)
                  _buildPromoBanner(),

                  const SizedBox(height: 24),

                  // 4. 地点分类 (Browse by Location)
                  const Text("Browse by location",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A))),
                  const SizedBox(height: 16),
                  _buildLocationRow(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
      // 5. 底部导航栏
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF6D8299),
        unselectedItemColor: Colors.grey,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.rocket_launch_outlined), label: 'For you'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_outlined), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: 'My Jobs'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  // --- UI 构建组件 ---

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: const BoxDecoration(
        color: Color(0xFF1A2A4D), // 对应照片的深蓝色
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Preferred work location", style: TextStyle(color: Colors.white70, fontSize: 12)),
          Row(
            children: const [
              Text("Select location", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Icon(Icons.keyboard_arrow_down, color: Colors.white),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: InputDecoration(
              hintText: "Search Jobs...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              fillColor: Colors.white,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final List<Map<String, dynamic>> categories = [
      {'title': 'Latest jobs', 'icon': Icons.campaign_outlined, 'color': Color(0xFFA7BED3)},
      {'title': 'Part-time', 'icon': Icons.calendar_today_outlined, 'color': Color(0xFFC6DEF1)},
      {'title': 'Full-time', 'icon': Icons.access_time_outlined, 'color': Color(0xFFDBCDF0)},
      {'title': 'Near me', 'icon': Icons.location_on_outlined, 'color': Color(0xFFF7D9C4)},
      {'title': 'Internship', 'icon': Icons.school_outlined, 'color': Color(0xFFE2ECE9)},
      {'title': 'Gigs', 'icon': Icons.bolt_outlined, 'color': Color(0xFFF2C6DE)},
      {'title': 'No exp', 'icon': Icons.face_retouching_natural, 'color': Color(0xFFA7BED3)},
      {'title': 'Agency', 'icon': Icons.business_outlined, 'color': Color(0xFFC6DEF1)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 15,
        childAspectRatio: 0.85,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5)],
            ),
            child: Icon(categories[index]['icon'], color: categories[index]['color'], size: 26),
          ),
          const SizedBox(height: 6),
          Text(categories[index]['title'],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF4A4A4A))),
        ],
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF6D8299), Color(0xFFA7BED3)]),
      ),
      child: const Center(
        child: Text("Jobs in Penang!\nApply Now",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLocationRow() {
    return Row(
      children: [
        _buildLocCard("Kuala Lumpur", const Color(0xFF6D8299)),
        const SizedBox(width: 12),
        _buildLocCard("Penang", const Color(0xFFD3AB9E)),
      ],
    );
  }

  Widget _buildLocCard(String name, Color color) {
    return Expanded(
      child: Container(
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}