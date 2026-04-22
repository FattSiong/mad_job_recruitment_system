import 'package:flutter/material.dart';

class ChatMainScreen extends StatelessWidget {
  const ChatMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // 两个部分：Chats 和 Interviews
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: const Text("Messages",
              style: TextStyle(color: Color(0xFF4A4A4A), fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            labelColor: Color(0xFF6D8299),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF6D8299),
            tabs: [
              Tab(text: "Chats"),
              Tab(text: "Interviews"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ChatListSection(),      // 聊天列表
            InterviewListSection(), // 面试邀请列表
          ],
        ),
      ),
    );
  }
}

// --- 1. Chats 列表部分 ---
class ChatListSection extends StatelessWidget {
  const ChatListSection({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> chats = [
      {'name': 'Google HR', 'msg': 'Are you available for a call?', 'time': '10:30 AM'},
      {'name': 'Intel Corp', 'msg': 'Your resume looks great!', 'time': 'Yesterday'},
    ];

    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) => ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFA7BED3).withValues(alpha: 0.2),
          child: Text(chats[index]['name']![0], style: const TextStyle(color: Color(0xFF6D8299))),
        ),
        title: Text(chats[index]['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(chats[index]['msg']!),
        trailing: Text(chats[index]['time']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ),
    );
  }
}

// --- 2. Interviews 列表部分  ---
class InterviewListSection extends StatelessWidget {
  const InterviewListSection({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> interviews = [
      {'company': 'Microsoft', 'date': '25 April 2026', 'status': 'Confirmed'},
      {'company': 'Grab Malaysia', 'date': '28 April 2026', 'status': 'Pending'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: interviews.length,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.videocam_outlined, color: Color(0xFFD3AB9E)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(interviews[index]['company']!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("Date: ${interviews[index]['date']}",
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2ECE9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(interviews[index]['status']!,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6D8299))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}