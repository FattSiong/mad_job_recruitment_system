import 'package:flutter/material.dart';
import '../../../services/call_service.dart';
import 'standard_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callID;
  final String roomCode;
  final String callerName;
  final String? callerProfilePic;

  const IncomingCallScreen({
    super.key,
    required this.callID,
    required this.roomCode,
    required this.callerName,
    this.callerProfilePic,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final CallService _callService = CallService();

  // If they click Accept
  void _acceptCall() async {
    // 1. Tell the database we answered
    await _callService.updateCallStatus(widget.callID, 'active');

    // 2. Go to the actual call screen!
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StandardCallScreen(
            callID: widget.callID,
            roomCode: widget.roomCode,
            otherUserName: widget.callerName,
            otherUserProfilePic: widget.callerProfilePic,
          ),
        ),
      );
    }
  }

  // If they click Decline
  void _declineCall() async {
    await _callService.updateCallStatus(widget.callID, 'declined');
    if (mounted) {
      Navigator.pop(context); // Close the ringing screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark WhatsApp Style
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // Caller Profile Picture
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[800],
              backgroundImage: widget.callerProfilePic != null ? NetworkImage(widget.callerProfilePic!) : null,
              child: widget.callerProfilePic == null ? const Icon(Icons.person, size: 60, color: Colors.white54) : null,
            ),
            const SizedBox(height: 24),

            // Caller Name
            Text(
              widget.callerName,
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              "Incoming Voice Call...",
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 18),
            ),

            const Spacer(),

            // Accept / Decline Buttons
            Padding(
              padding: const EdgeInsets.only(bottom: 60, left: 40, right: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Decline Button
                  Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'decline_btn',
                        onPressed: _declineCall,
                        backgroundColor: Colors.red,
                        child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 8),
                      const Text("Decline", style: TextStyle(color: Colors.white)),
                    ],
                  ),

                  // Accept Button
                  Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'accept_btn',
                        onPressed: _acceptCall,
                        backgroundColor: Colors.green,
                        child: const Icon(Icons.call, color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 8),
                      const Text("Accept", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}