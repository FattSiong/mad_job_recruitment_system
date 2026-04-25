import 'package:flutter/material.dart';
import '../../../services/interview_service.dart';
import 'interview_call_screen.dart';

class InterviewLobbyScreen extends StatefulWidget {
  final String roomID; // 👉 Renamed to roomID to match your new table!
  final bool isEmployer;

  // 👉 REMOVED: roomCode is no longer passed in! It's generated dynamically.
  const InterviewLobbyScreen({
    super.key,
    required this.roomID,
    required this.isEmployer,
  });

  @override
  State<InterviewLobbyScreen> createState() => _InterviewLobbyScreenState();
}

class _InterviewLobbyScreenState extends State<InterviewLobbyScreen> {
  final InterviewService _interviewService = InterviewService();
  bool _isStarting = false;

  // 👉 UPDATED: Now requires the roomCode to be passed exactly when navigation happens
  void _enterVideoCallRoom(String generatedRoomCode) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => InterviewCallScreen(
          roomCode: generatedRoomCode,
          interviewID: widget.roomID,
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
        stream: _interviewService.listenToInterviewStatus(widget.roomID),
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

          // 👉 NEW: Extract the room code from the database stream!
          // (This will be null until the employer actually hits start)
          final streamRoomCode = interviewData['roomCode'];

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
                    Text(
                      status == 'active' ? "Room is Active" : "You are the Host",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status == 'active'
                          ? "The interview room is currently open. You can rejoin at any time."
                          : "The job seeker is waiting in the lobby. Start the interview when you are ready.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),

                    _isStarting
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: status == 'active' ? Colors.green : Colors.blueAccent,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: () async {
                        setState(() => _isStarting = true);

                        // 👉 NEW LOGIC: Check if we are starting fresh or rejoining
                        if (status == 'active' && streamRoomCode != null) {
                          // Just rejoin the existing room
                          _enterVideoCallRoom(streamRoomCode);
                        } else {
                          // Start fresh and generate code
                          final newCode = await _interviewService.startInterview(widget.roomID);
                          _enterVideoCallRoom(newCode);
                        }

                        if (mounted) setState(() => _isStarting = false);
                      },
                      child: Text(
                          status == 'active' ? "Rejoin Interview" : "Start Interview",
                          style: const TextStyle(color: Colors.white, fontSize: 18)
                      ),
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
                      status == 'waiting' || status == 'pending'
                          ? "The employer has not started the room yet. The join button will appear automatically when they are ready."
                          : "The employer has started the interview!",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),

                    // The Join button ONLY becomes clickable if status == 'active' AND roomCode exists
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (status == 'active' && streamRoomCode != null) ? Colors.green : Colors.grey[300],
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: (status == 'active' && streamRoomCode != null)
                          ? () => _enterVideoCallRoom(streamRoomCode) // 👉 Pass the stream code!
                          : null,
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