import 'package:flutter/material.dart';
import '../../../services/interview_service.dart';
import 'interview_call_screen.dart'; // Add this

class InterviewLobbyScreen extends StatefulWidget {
  final String interviewID;
  final String roomCode; // A unique string for the video call room
  final bool isEmployer; // TRUE if employer, FALSE if job seeker

  const InterviewLobbyScreen({
    super.key,
    required this.interviewID,
    required this.roomCode,
    required this.isEmployer,
  });

  @override
  State<InterviewLobbyScreen> createState() => _InterviewLobbyScreenState();
}

class _InterviewLobbyScreenState extends State<InterviewLobbyScreen> {
  final InterviewService _interviewService = InterviewService();

  // This will be replaced with actual video call navigation later
  void _enterVideoCallRoom() {
    // We use pushReplacement so they can't hit "Back" and end up in the lobby again
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => InterviewCallScreen(
          roomCode: widget.roomCode,
          interviewID: widget.interviewID,
          isEmployer: widget.isEmployer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interview Lobby'),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _interviewService.listenToInterviewStatus(widget.interviewID),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Interview not found."));
          }

          // Get the current status from Supabase
          final interviewData = snapshot.data!.first;
          final status = interviewData['status'] ?? 'waiting';

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    status == 'active' ? Icons.videocam : Icons.hourglass_empty,
                    size: 80,
                    color: status == 'active' ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 24),

                  // --- EMPLOYER VIEW ---
                  if (widget.isEmployer) ...[
                    const Text(
                      "You are the Host",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "The job seeker is waiting in the lobby. Start the interview when you are ready.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: () async {
                        // 1. Update database to 'active'
                        await _interviewService.startInterview(widget.interviewID);
                        // 2. Jump into the call
                        _enterVideoCallRoom();
                      },
                      child: const Text("Start Interview", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ]

                  // --- JOB SEEKER VIEW ---
                  else ...[
                    const Text(
                      "Waiting for Employer...",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status == 'waiting'
                          ? "The employer has not started the room yet. The join button will appear automatically when they are ready."
                          : "The employer has started the interview!",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),

                    // The Join button ONLY becomes clickable if status == 'active'
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: status == 'active' ? Colors.green : Colors.grey[300],
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: status == 'active'
                          ? () => _enterVideoCallRoom()
                          : null, // Disabled when null
                      child: Text(
                        status == 'active' ? "Join Interview Now" : "Waiting to Start...",
                        style: TextStyle(
                          color: status == 'active' ? Colors.white : Colors.grey[600],
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}