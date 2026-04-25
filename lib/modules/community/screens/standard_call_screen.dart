import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../../../services/call_service.dart';
import '../../../models/call_model.dart';

class StandardCallScreen extends StatefulWidget {
  final String callID;
  final String roomCode;
  final String otherUserName;
  final String? otherUserProfilePic;

  const StandardCallScreen({
    super.key,
    required this.callID,
    required this.roomCode,
    required this.otherUserName,
    this.otherUserProfilePic,
  });

  @override
  State<StandardCallScreen> createState() => _StandardCallScreenState();
}

class _StandardCallScreenState extends State<StandardCallScreen> {
  final CallService _callService = CallService();
  late RtcEngine _engine;

  bool _isMuted = false;
  bool _isVideoEnabled = false;
  bool _isSpeakerOn = false;

  bool _isRemoteUserJoined = false;
  int? _remoteUid;

  Timer? _callTimer;
  int _callDurationSeconds = 0;

  // 👈 NEW: The Safety Locks
  bool _isEndingCall = false;
  StreamSubscription? _callStatusSubscription;

  @override
  void initState() {
    super.initState();
    initAgora();
    _listenToDatabaseStatus();
  }

  void _listenToDatabaseStatus() {
    // 👈 We save the subscription so we can cancel it later!
    _callStatusSubscription = _callService.listenToCallStatus(widget.callID).listen((CallModel? call) {
      if (call == null) return;

      if (call.status == 'declined' || call.status == 'ended') {
        _endCall(updateDatabase: false);
      } else if (call.status == 'active' && !_isRemoteUserJoined) {
        setState(() => _isRemoteUserJoined = true);
        _startTimer();
      }
    });
  }

  String get _formattedDuration {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(_callDurationSeconds ~/ 60);
    String seconds = twoDigits(_callDurationSeconds % 60);
    return "$minutes:$seconds";
  }

  void _startTimer() {
    if (_callTimer != null && _callTimer!.isActive) return;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _callDurationSeconds++);
    });
  }

  Future<void> initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: "5258f95e9daa4744b8538323423c8077", // Your App ID
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onError: (ErrorCodeType err, String msg) => debugPrint("🚨 AGORA ERROR: $err - $msg"),
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) => debugPrint("✅ Joined Channel"),
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() {
            _isRemoteUserJoined = true;
            _remoteUid = remoteUid;
          });
          _startTimer();
          _callService.updateCallStatus(widget.callID, 'active');
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          // If they leave Agora unexpectedly (like losing WiFi), end the call
          _endCall();
        },
      ),
    );

    await _engine.enableAudio();
    await _engine.disableVideo();

    await _engine.joinChannel(
      token: '',
      channelId: widget.roomCode,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        publishMicrophoneTrack: true,
        publishCameraTrack: false,
      ),
    );
  }

  // 👈 CRITICAL FIX: The new bulletproof end call function
  void _endCall({bool updateDatabase = true}) async {
    // 1. If we are already closing the call, stop right here!
    if (_isEndingCall) return;
    _isEndingCall = true;

    // 2. Stop the timers and database listeners
    _callTimer?.cancel();
    _callStatusSubscription?.cancel();

    // 3. Update the database if we are the one who clicked the red button
    if (updateDatabase) {
      await _callService.updateCallStatus(widget.callID, 'ended');
    }

    // 4. Safely close Agora inside a try/catch block
    try {
      await _engine.leaveChannel();
      await _engine.release();
    } catch (e) {
      debugPrint("Agora closed safely: $e");
    }

    // 5. Finally, close the screen!
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _engine.muteLocalAudioStream(_isMuted);
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    _engine.setEnableSpeakerphone(_isSpeakerOn);
  }

  void _toggleVideo() async {
    setState(() => _isVideoEnabled = !_isVideoEnabled);
    if (_isVideoEnabled) {
      await _engine.enableVideo();
      await _engine.startPreview();
      await _engine.updateChannelMediaOptions(const ChannelMediaOptions(publishCameraTrack: true));
    } else {
      await _engine.disableVideo();
      await _engine.updateChannelMediaOptions(const ChannelMediaOptions(publishCameraTrack: false));
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _callStatusSubscription?.cancel();

    // Safety net: If the user hit the Android "Back" button to leave the screen
    if (!_isEndingCall) {
      _callService.updateCallStatus(widget.callID, 'ended');
      _engine.leaveChannel();
      _engine.release();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Stack(
          children: [
            if (_isVideoEnabled || _remoteUid != null)
              Center(
                child: _remoteUid != null
                    ? AgoraVideoView(controller: VideoViewController.remote(rtcEngine: _engine, canvas: VideoCanvas(uid: _remoteUid), connection: RtcConnection(channelId: widget.roomCode)))
                    : const SizedBox(),
              ),

            Column(
              children: [
                const SizedBox(height: 40),
                Text(widget.otherUserName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(
                  _isRemoteUserJoined ? _formattedDuration : "Ringing...",
                  style: TextStyle(
                      color: _isRemoteUserJoined ? Colors.greenAccent : Colors.white.withOpacity(0.7),
                      fontSize: _isRemoteUserJoined ? 18 : 16,
                      fontWeight: _isRemoteUserJoined ? FontWeight.bold : FontWeight.normal
                  ),
                ),
                const Spacer(),

                if (!_isVideoEnabled && _remoteUid == null)
                  CircleAvatar(
                    radius: 80,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: widget.otherUserProfilePic != null ? NetworkImage(widget.otherUserProfilePic!) : null,
                    child: widget.otherUserProfilePic == null ? const Icon(Icons.person, size: 80, color: Colors.white54) : null,
                  ),

                const Spacer(),

                if (_isVideoEnabled)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20, bottom: 20),
                      child: SizedBox(
                        width: 100, height: 130,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AgoraVideoView(controller: VideoViewController(rtcEngine: _engine, canvas: const VideoCanvas(uid: 0))),
                        ),
                      ),
                    ),
                  ),

                Container(
                  padding: const EdgeInsets.only(bottom: 40, top: 20),
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off, color: _isVideoEnabled ? Colors.white : Colors.white38, onPressed: _toggleVideo),
                      _buildControlButton(icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off, color: _isSpeakerOn ? Colors.white : Colors.white38, onPressed: _toggleSpeaker),
                      _buildControlButton(icon: _isMuted ? Icons.mic_off : Icons.mic, color: _isMuted ? Colors.white38 : Colors.white, onPressed: _toggleMute),
                      FloatingActionButton(heroTag: 'standard_end_call', backgroundColor: Colors.red, elevation: 0, onPressed: _endCall, child: const Icon(Icons.call_end, color: Colors.white, size: 30)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)),
    );
  }
}