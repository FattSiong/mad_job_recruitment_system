import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../../../services/call_service.dart';
import '../../../models/call_model.dart';
import '../../../services/community_service.dart';
import '../../../models/message_model.dart';

class StandardCallScreen extends StatefulWidget {
  final String callID;
  final String roomCode;
  final String otherUserName;
  final String? otherUserProfilePic;

  final String? chatRoomID;
  final String? currentUserID;
  final bool isCaller;

  const StandardCallScreen({
    super.key,
    required this.callID,
    required this.roomCode,
    required this.otherUserName,
    this.otherUserProfilePic,
    this.chatRoomID,
    this.currentUserID,
    this.isCaller = false,
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
  bool _isRemoteVideoEnabled = false;
  int? _remoteUid;

  Timer? _callTimer;
  Timer? _ringingTimeoutTimer;
  int _callDurationSeconds = 0;

  bool _isEndingCall = false;
  StreamSubscription? _callStatusSubscription;

  bool _isDeclined = false;
  bool _hasSentLog = false;

  @override
  void initState() {
    super.initState();
    initAgora();
    _listenToDatabaseStatus();

    _ringingTimeoutTimer = Timer(const Duration(minutes: 1), _handleRingingTimeout);
  }

  void _handleRingingTimeout() {
    if (!_isRemoteUserJoined && mounted) {
      if (widget.isCaller) {
        setState(() => _isDeclined = true);
        _sendCallLog("Voice call\nNo answer");
        _callService.updateCallStatus(widget.callID, 'ended');
        try { _engine.leaveChannel(); } catch(e) {}
      } else {
        _endCall(updateDatabase: false);
      }
    }
  }

  void _sendCallLog(String content) {
    if (!widget.isCaller || _hasSentLog || widget.chatRoomID == null || widget.currentUserID == null) return;

    _hasSentLog = true;
    final newMessage = MessageModel(
      messageID: '',
      roomID: widget.chatRoomID!,
      senderID: widget.currentUserID!,
      content: content,
      isRead: false,
      sentAt: DateTime.now(),
      mediaType: 'call_log',
    );
    CommunityService().sendMessage(newMessage);
  }

  void _listenToDatabaseStatus() {
    _callStatusSubscription = _callService.listenToCallStatus(widget.callID).listen((CallModel? call) {
      if (call == null) return;

      if (call.status == 'ended') {
        // ------------------------------------------------------------------
        // 👈 THE FIX: Do not auto-close if the caller is on the "No Answer" screen!
        // ------------------------------------------------------------------
        if (widget.isCaller && _isDeclined) return;

        _endCall(updateDatabase: false);
      }
      else if (call.status == 'declined') {
        if (widget.isCaller && !_isRemoteUserJoined) {
          setState(() => _isDeclined = true);
          _sendCallLog("Voice call\nNo answer");
          try { _engine.leaveChannel(); } catch(e) {}
        } else {
          _endCall(updateDatabase: false);
        }
      }
      else if (call.status == 'active' && !_isRemoteUserJoined) {
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
      appId: "5258f95e9daa4744b8538323423c8077",
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onError: (ErrorCodeType err, String msg) => debugPrint("🚨 AGORA ERROR: $err - $msg"),
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) => debugPrint("✅ Joined Channel"),
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          _ringingTimeoutTimer?.cancel();

          setState(() {
            _isRemoteUserJoined = true;
            _remoteUid = remoteUid;
          });
          _startTimer();
          _callService.updateCallStatus(widget.callID, 'active');
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          _endCall();
        },
        onRemoteVideoStateChanged: (RtcConnection connection, int remoteUid, RemoteVideoState state, RemoteVideoStateReason reason, int elapsed) {
          if (mounted) {
            setState(() {
              if (state == RemoteVideoState.remoteVideoStateDecoding || state == RemoteVideoState.remoteVideoStateStarting) {
                _isRemoteVideoEnabled = true;
              } else if (state == RemoteVideoState.remoteVideoStateStopped) {
                _isRemoteVideoEnabled = false;
              }
            });
          }
        },
      ),
    );

    await _engine.enableAudio();
    await _engine.enableVideo();
    await _engine.enableLocalVideo(false);

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

  void _endCall({bool updateDatabase = true, bool recall = false}) async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    _callTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _callStatusSubscription?.cancel();

    if (!_isDeclined) {
      if (_isRemoteUserJoined) {
        _sendCallLog("Voice call\n$_formattedDuration");
      } else {
        _sendCallLog("Voice call\nNo answer");
      }
    }

    if (updateDatabase) {
      // ------------------------------------------------------------------
      // 👈 THE FIX: Ensure the receiver triggers a 'decline' if they reject it!
      // ------------------------------------------------------------------
      if (!widget.isCaller && !_isRemoteUserJoined) {
        await _callService.updateCallStatus(widget.callID, 'declined');
      } else {
        await _callService.updateCallStatus(widget.callID, 'ended');
      }
    }

    try {
      await _engine.leaveChannel();
      await _engine.release();
    } catch (e) {
      debugPrint("Agora closed safely: $e");
    }

    if (mounted) {
      Navigator.pop(context, recall ? 'recall' : null);
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
      await _engine.enableLocalVideo(true);
      await _engine.startPreview();
      await _engine.updateChannelMediaOptions(const ChannelMediaOptions(publishCameraTrack: true));
    } else {
      await _engine.enableLocalVideo(false);
      await _engine.stopPreview();
      await _engine.updateChannelMediaOptions(const ChannelMediaOptions(publishCameraTrack: false));
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _callStatusSubscription?.cancel();

    if (!_isEndingCall) {
      if (!_isDeclined) {
        if (_isRemoteUserJoined) {
          _sendCallLog("Voice call\n$_formattedDuration");
        } else {
          _sendCallLog("Voice call\nNo answer");
        }
      }
      // Catch-all safety net for hitting the physical back button
      if (!widget.isCaller && !_isRemoteUserJoined) {
        _callService.updateCallStatus(widget.callID, 'declined');
      } else {
        _callService.updateCallStatus(widget.callID, 'ended');
      }
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
            if (_isRemoteVideoEnabled && _remoteUid != null)
              Center(
                child: AgoraVideoView(
                    controller: VideoViewController.remote(
                        rtcEngine: _engine,
                        canvas: VideoCanvas(uid: _remoteUid!),
                        connection: RtcConnection(channelId: widget.roomCode)
                    )
                ),
              ),

            Column(
              children: [
                const SizedBox(height: 40),
                Text(widget.otherUserName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),

                Text(
                  _isDeclined ? "No answer" : (_isRemoteUserJoined ? _formattedDuration : "Ringing..."),
                  style: TextStyle(
                      color: _isRemoteUserJoined && !_isDeclined ? Colors.greenAccent : Colors.white.withOpacity(0.7),
                      fontSize: _isRemoteUserJoined && !_isDeclined ? 18 : 16,
                      fontWeight: _isRemoteUserJoined && !_isDeclined ? FontWeight.bold : FontWeight.normal
                  ),
                ),
                const Spacer(),

                if (!_isRemoteVideoEnabled)
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

                if (_isDeclined)
                  Container(
                    padding: const EdgeInsets.only(bottom: 50, top: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap: () => _endCall(recall: false),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 30)),
                              const SizedBox(height: 8),
                              const Text("Cancel", style: TextStyle(color: Colors.white, fontSize: 14)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _endCall(recall: true),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 60, height: 60, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.call, color: Colors.white, size: 30)),
                              const SizedBox(height: 8),
                              const Text("Call again", style: TextStyle(color: Colors.white, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.only(bottom: 40, top: 20),
                    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildControlButton(icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off, color: _isVideoEnabled ? Colors.white : Colors.white38, onPressed: _toggleVideo),
                        _buildControlButton(icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off, color: _isSpeakerOn ? Colors.white : Colors.white38, onPressed: _toggleSpeaker),
                        _buildControlButton(icon: _isMuted ? Icons.mic_off : Icons.mic, color: _isMuted ? Colors.white38 : Colors.white, onPressed: _toggleMute),
                        FloatingActionButton(heroTag: 'standard_end_call', backgroundColor: Colors.red, elevation: 0, onPressed: () => _endCall(recall: false), child: const Icon(Icons.call_end, color: Colors.white, size: 30)),
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