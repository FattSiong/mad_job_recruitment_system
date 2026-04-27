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

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(widget.isEmployer ? 'Hosting Interview' : 'Live Interview'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.videocam_off_rounded,
                  color: Colors.orange,
                  size: 72,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Camera could not start',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _initializationError!,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Return to Lobby'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.isEmployer ? 'Hosting Interview' : 'Live Interview'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
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
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    heroTag: 'switch_camera_btn',
                    onPressed: _onSwitchCamera,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    elevation: 0,
                    child: const Icon(
                      Icons.flip_camera_ios,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 24),
                  FloatingActionButton(
                    heroTag: 'hang_up_btn',
                    onPressed: _onCallEnded,
                    backgroundColor: Colors.red,
                    elevation: 0,
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 28,
                    ),
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
