import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/interview_service.dart'; // Make sure this path is correct for your project!
import 'dart:async'; // 👉 NEW: Required for the StreamSubscription
import 'package:supabase_flutter/supabase_flutter.dart'; // 👉 NEW: Required to listen to the DB

class InterviewCallScreen extends StatefulWidget {
  final String roomCode;
  final String interviewID;
  final bool isEmployer;

  const InterviewCallScreen({
    super.key,
    required this.roomCode,
    required this.interviewID,
    required this.isEmployer,
  });

  @override
  State<InterviewCallScreen> createState() => _InterviewCallScreenState();
}

class _InterviewCallScreenState extends State<InterviewCallScreen> {
  int? _remoteUid;
  bool _localUserJoined = false;
  late RtcEngine _engine;

  StreamSubscription? _roomSubscription;

  @override
  void initState() {
    super.initState();
    initAgora();

    _roomSubscription = Supabase.instance.client
        .from('InterviewRoom')
        .stream(primaryKey: ['roomID'])
        .eq('roomID', widget.interviewID)
        .listen((data) {
      if (data.isNotEmpty && mounted) {
        final status = data.first['status'];

        // If the employer resets the room to waiting, kick the seeker!
        if (status == 'waiting' && !widget.isEmployer) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The Host has ended the meeting. Returning to lobby.'),
              backgroundColor: Colors.orange,
            ),
          );
          _onCallEnded(); // Forces the seeker to leave Agora and pop the screen
        }
      }
    });
  }

  Future<void> initAgora() async {
    await InterviewService().markUserAsJoined(widget.interviewID, widget.isEmployer);
    // 1. Request permissions
    await [Permission.microphone, Permission.camera].request();

    // 2. Initialize the Agora Engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: "16f92d86-ad69-4841-8a4f-b6c0cbb8f9f6", // 👈 REMEMBER TO PUT YOUR APP ID HERE
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // 3. Set up listeners
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("Local user joined");
          setState(() { _localUserJoined = true; });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("Remote user uid:$remoteUid joined the channel");
          setState(() { _remoteUid = remoteUid; });
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("Remote user uid:$remoteUid left the channel");
          setState(() { _remoteUid = null; });
        },
      ),
    );

    // 4. Turn on video and join!
    await _engine.enableVideo();
    await _engine.startPreview();

    await _engine.joinChannel(
      token: '', // Leave empty if your project is in Testing Mode
      channelId: widget.roomCode,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  void _onCallEnded() async {
    if (widget.isEmployer) {
      // --- EMPLOYER LOGIC: Show a choice dialog ---
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave or End Meeting?'),
          content: const Text('Do you want to temporarily leave the room, or permanently end the interview for everyone?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Cancel and go back to call
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                // Option A: Just leave temporarily (Room stays open)
                Navigator.pop(context); // Close dialog
                await InterviewService().leaveInterview(widget.interviewID, true);
                if (mounted) Navigator.pop(context); // Leave the call screen
              },
              child: const Text('Leave Temporarily'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Option B: Reset the room completely
                Navigator.pop(context); // Close dialog
                await InterviewService().forceEndInterview(widget.interviewID);
                if (mounted) Navigator.pop(context); // Leave the call screen
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              // 👉 UPDATED TEXT
              child: const Text('End Meeting & Reset Room', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      // --- SEEKER LOGIC: They can only leave temporarily ---
      await InterviewService().leaveInterview(widget.interviewID, false);
      if (mounted) {
        Navigator.pop(context); // Leave the call screen
      }
    }
  }

  // 👈 NEW: The Switch Camera Function
  void _onSwitchCamera() async {
    try {
      await _engine.switchCamera();
    } catch (e) {
      debugPrint("Error switching camera: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.isEmployer ? 'Hosting Interview' : 'Live Interview'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // BOTTOM LAYER: The Other Person's Video (Fullscreen)
          Center(
            child: _remoteUid != null
                ? AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine,
                canvas: VideoCanvas(uid: _remoteUid),
                connection: RtcConnection(channelId: widget.roomCode),
              ),
            )
                : const Text(
              'Waiting for other user to join...',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),

          // TOP LAYER: Your Video (Small Box)
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 110,
                height: 150,
                child: _localUserJoined
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
                )
                    : const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          ),

          // 👈 THE NEW UPDATED BOTTOM BUTTONS
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. Switch Camera Button
                  FloatingActionButton(
                    heroTag: "switch_camera_btn", // Required when you have multiple FloatingActionButtons
                    onPressed: _onSwitchCamera,
                    backgroundColor: Colors.white.withValues(alpha: 0.2), // Cool semi-transparent look
                    elevation: 0,
                    child: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
                  ),

                  const SizedBox(width: 24), // Spacing between buttons

                  // 2. Hang Up Button
                  FloatingActionButton(
                    heroTag: "hang_up_btn",
                    onPressed: _onCallEnded,
                    backgroundColor: Colors.red,
                    elevation: 0,
                    child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}