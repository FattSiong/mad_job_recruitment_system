import 'dart:async';

import 'package:flutter/material.dart';
import '../../../models/call_model.dart';
import '../../../services/call_service.dart';
import '../../../services/push_service.dart';
import 'standard_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callID;
  final String roomCode;
  final String callerName;
  final String? callerProfilePic;
  /// Accept straight away ("Answer" tapped on the ringing notification).
  final bool autoAccept;

  const IncomingCallScreen({
    super.key,
    required this.callID,
    required this.roomCode,
    required this.callerName,
    this.callerProfilePic,
    this.autoAccept = false,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final CallService _callService = CallService();
  StreamSubscription<CallModel?>? _statusSubscription;
  bool _handled = false; // accepted, declined or closed

  @override
  void initState() {
    super.initState();
    // Close the ringing screen if the caller hangs up first.
    _statusSubscription = _callService.listenToCallStatus(widget.callID).listen((call) {
      if (_handled || call == null || call.status == 'ringing') return;
      _handled = true;
      CallNotifications.cancel(widget.callID);
      if (mounted) Navigator.pop(context);
    });
    if (widget.autoAccept) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _acceptCall());
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    CallNotifications.cancel(widget.callID); // stop the ringing notification
    super.dispose();
  }

  // If they click Accept
  void _acceptCall() async {
    if (_handled) return;
    _handled = true;
    CallNotifications.cancel(widget.callID);
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
    if (_handled) return;
    _handled = true;
    CallNotifications.cancel(widget.callID);
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