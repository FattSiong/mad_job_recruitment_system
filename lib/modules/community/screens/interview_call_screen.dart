import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/agora_constants.dart';
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
  bool _engineReady = false;
  bool _isMicrophoneMuted = false;
  bool _isCameraOff = false;
  String? _initializationError;
  late final RtcEngine _engine;

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

        if (status == 'waiting' && !widget.isEmployer) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The host ended the meeting. Returning to lobby.'),
              backgroundColor: Colors.orange,
            ),
          );
          _onCallEnded();
        }
      }
    });
  }

  Future<void> initAgora() async {
    try {
      final permissions = await [
        Permission.microphone,
        Permission.camera,
      ].request();

      final microphoneGranted =
          permissions[Permission.microphone]?.isGranted ?? false;
      final cameraGranted =
          permissions[Permission.camera]?.isGranted ?? false;

      if (!microphoneGranted || !cameraGranted) {
        throw Exception(
          'Camera and microphone permissions are required to join the interview.',
        );
      }

      _engine = createAgoraRtcEngine();
      await _engine.initialize(const RtcEngineContext(
        appId: AgoraConstants.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      _engineReady = true;

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onError: (ErrorCodeType err, String msg) {
            debugPrint('AGORA ERROR: $err - $msg');
            if (mounted) {
              setState(() {
                _initializationError =
                    'Unable to connect to the interview room. Please try again.';
              });
            }
          },
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('Local user joined');
            if (mounted) {
              setState(() {
                _localUserJoined = true;
                _initializationError = null;
              });
            }
          },
          onUserJoined: (
            RtcConnection connection,
            int remoteUid,
            int elapsed,
          ) {
            debugPrint('Remote user uid:$remoteUid joined the channel');
            if (mounted) {
              setState(() {
                _remoteUid = remoteUid;
              });
            }
          },
          onUserOffline: (
            RtcConnection connection,
            int remoteUid,
            UserOfflineReasonType reason,
          ) {
            debugPrint('Remote user uid:$remoteUid left the channel');
            if (mounted) {
              setState(() {
                _remoteUid = null;
              });
            }
          },
        ),
      );

      await _engine.enableAudio();
      await _engine.enableVideo();
      await _engine.enableLocalVideo(true);
      await _engine.startPreview();

      await InterviewService().markUserAsJoined(
        widget.interviewID,
        widget.isEmployer,
      );

      await _engine.joinChannel(
        token: '',
        channelId: widget.roomCode,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishMicrophoneTrack: true,
          publishCameraTrack: true,
        ),
      );
    } catch (e) {
      debugPrint('Failed to initialize interview call: $e');
      if (mounted) {
        setState(() {
          _initializationError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    if (_engineReady) {
      _engine.leaveChannel();
      _engine.release();
    }
    super.dispose();
  }

  void _onCallEnded() async {
    if (widget.isEmployer) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave or End Meeting?'),
          content: const Text(
            'Do you want to temporarily leave the room, or permanently end the interview for everyone?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await InterviewService().leaveInterview(widget.interviewID, true);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Leave Temporarily'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await InterviewService().forceEndInterview(widget.interviewID);
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'End Meeting & Reset Room',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } else {
      await InterviewService().leaveInterview(widget.interviewID, false);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _onSwitchCamera() async {
    if (!_engineReady) return;

    try {
      await _engine.switchCamera();
    } catch (e) {
      debugPrint('Error switching camera: $e');
    }
  }

  Future<void> _toggleMicrophone() async {
    if (!_engineReady) return;

    final nextValue = !_isMicrophoneMuted;
    try {
      await _engine.muteLocalAudioStream(nextValue);
      if (mounted) setState(() => _isMicrophoneMuted = nextValue);
    } catch (e) {
      debugPrint('Error updating microphone: $e');
    }
  }

  Future<void> _toggleCamera() async {
    if (!_engineReady) return;

    final nextValue = !_isCameraOff;
    try {
      await _engine.muteLocalVideoStream(nextValue);
      if (mounted) setState(() => _isCameraOff = nextValue);
    } catch (e) {
      debugPrint('Error updating camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF111827),
        body: SafeArea(child: _buildErrorState()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildRemoteStage()),
            _buildTopOverlay(),
            Positioned(
              top: 76,
              right: 16,
              child: _buildLocalPreview(),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildControlDock(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildTopOverlay(),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5A524).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.videocam_off_rounded, color: Color(0xFFF5A524), size: 38),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Camera could not start',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _initializationError!,
                  style: const TextStyle(color: Color(0xFFBAC4D1), fontSize: 14, height: 1.45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF111827),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Return to Lobby'),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildRemoteStage() {
    if (_remoteUid == null) {
      return Container(
        color: const Color(0xFF1A2332),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(color: Color(0xFF314158), shape: BoxShape.circle),
                child: const Icon(Icons.person_rounded, color: Color(0xFFCFD7E3), size: 50),
              ),
              const SizedBox(height: 18),
              const Text(
                'Waiting for the other participant',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'They will appear here when they join the interview room.',
                style: TextStyle(color: Color(0xFFBAC4D1), fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.roomCode),
        ),
      ),
    );
  }

  Widget _buildTopOverlay() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Material(
            color: const Color(0xB31F2937),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: _onCallEnded,
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xB31F2937),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFA9C8FF)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      widget.isEmployer ? 'Interview in progress' : 'Live interview',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(color: Color(0xFF41D88C), shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalPreview() {
    return Container(
      width: 118,
      height: 158,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF263448),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.65), width: 1.4),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_localUserJoined && !_isCameraOff)
            AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _engine,
                canvas: const VideoCanvas(uid: 0),
              ),
            )
          else
            Center(
              child: _localUserJoined
                  ? const Icon(Icons.videocam_off_rounded, color: Color(0xFFCFD7E3), size: 34)
                  : const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    ),
            ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              color: const Color(0xB3111824),
              child: Row(
                children: [
                  Icon(_isMicrophoneMuted ? Icons.mic_off_rounded : Icons.mic_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                  const Text('You', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlDock() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xE61F2937),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMeetingControl(
            icon: _isMicrophoneMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _isMicrophoneMuted ? 'Unmute' : 'Mute',
            isActive: _isMicrophoneMuted,
            onTap: _toggleMicrophone,
          ),
          _buildMeetingControl(
            icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            label: _isCameraOff ? 'Start video' : 'Stop video',
            isActive: _isCameraOff,
            onTap: _toggleCamera,
          ),
          _buildMeetingControl(
            icon: Icons.flip_camera_ios_rounded,
            label: 'Switch',
            onTap: _onSwitchCamera,
          ),
          _buildMeetingControl(
            icon: Icons.call_end_rounded,
            label: widget.isEmployer ? 'End' : 'Leave',
            isDestructive: true,
            onTap: _onCallEnded,
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingControl({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    bool isDestructive = false,
  }) {
    final backgroundColor = isDestructive
        ? const Color(0xFFE5484D)
        : isActive
        ? Colors.white
        : const Color(0xFF344154);
    final foregroundColor = isActive ? const Color(0xFF1F2937) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(18)),
                child: Icon(icon, color: foregroundColor),
              ),
              const SizedBox(height: 7),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
