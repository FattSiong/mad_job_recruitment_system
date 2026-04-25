import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/interview_service.dart';

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

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    // 1. Request camera and mic permissions
    await [Permission.microphone, Permission.camera].request();

    // 2. Initialize the Agora Engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: "5258f95e9daa4744b8538323423c8077", // 👈 REMEMBER TO PUT YOUR APP ID HERE
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // 3. Set up listeners to know when people join or leave
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

    // 4. Turn on the video and join the room!
    await _engine.enableVideo();
    await _engine.startPreview();

    await _engine.joinChannel(
      token: '', // Leave empty if your project is in Testing Mode
      channelId: widget.roomCode,
      uid: 0, // 0 tells Agora to assign you a random ID
      options: const ChannelMediaOptions(),
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  // Handle what happens when they click the red hang-up button
  void _onCallEnded() async {
    if (widget.isEmployer) {
      await InterviewService().endInterview(widget.interviewID);
    }
    if (mounted) {
      Navigator.pop(context); // Send them back to the dashboard
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

          // THE HANG-UP BUTTON
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: FloatingActionButton(
                onPressed: _onCallEnded,
                backgroundColor: Colors.red,
                elevation: 0,
                child: const Icon(Icons.call_end, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}