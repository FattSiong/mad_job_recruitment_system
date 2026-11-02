import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/agora_constants.dart';
import '../../../models/post_interview_report_model.dart';
import '../../../services/employer_service.dart';
import '../../../services/interview_service.dart';
import '../../employer/screens/post_interview_ai_report_screen.dart';

class InterviewCallScreen extends StatefulWidget {
  final String roomCode;
  final String interviewID;
  final bool isEmployer;
  final bool aiAnalyticsEnabled;

  const InterviewCallScreen({
    super.key,
    required this.roomCode,
    required this.interviewID,
    required this.isEmployer,
    this.aiAnalyticsEnabled = false,
  });

  @override
  State<InterviewCallScreen> createState() => _InterviewCallScreenState();
}

class _InterviewCallScreenState extends State<InterviewCallScreen> {
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _engineReady = false;
  bool _engineReleased = false;
  bool _isExiting = false;
  bool _isMicrophoneMuted = false;
  bool _isCameraOff = false;
  String? _initializationError;
  late final RtcEngine _engine;

  late bool _aiAnalyticsEnabled;
  bool _isAiRecording = false;
  String? _recordingFilePath;
  DateTime? _recordingStartedAt;

  StreamSubscription? _roomSubscription;
  Timer? _roomPoller;

  @override
  void initState() {
    super.initState();
    _aiAnalyticsEnabled = widget.aiAnalyticsEnabled;
    initAgora();

    if (!widget.isEmployer) {
      _roomSubscription = InterviewService()
          .listenToInterviewStatus(widget.interviewID)
          .listen((data) {
        if (data.isNotEmpty && mounted && !_isExiting) {
          final row = data.first;
          final remoteAi = row['aiAnalyticsEnabled'] == true;
          if (remoteAi != _aiAnalyticsEnabled) {
            setState(() => _aiAnalyticsEnabled = remoteAi);
          }
          _evaluateRoomRowForHostEnd(row);
        }
      });

      // Fallback periodic check in case Supabase Realtime publication isn't enabled on InterviewRoom
      _roomPoller = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!_isExiting && mounted) {
          _checkIfRoomEndedByHost();
        }
      });
    }
  }

  bool _isRoomEndedRow(Map<String, dynamic> row) {
    final status = (row['status'] ?? '').toString().toLowerCase();
    final roomCode = row['roomCode']?.toString().trim();

    if (status == 'waiting' || status == 'pending' || status == 'completed') {
      return true;
    }
    if (roomCode == null || roomCode.isEmpty || roomCode != widget.roomCode) {
      return true;
    }
    return false;
  }

  void _evaluateRoomRowForHostEnd(Map<String, dynamic> row) {
    if (_isExiting || widget.isEmployer || !mounted) return;
    if (_isRoomEndedRow(row)) {
      final status = (row['status'] ?? '').toString().toLowerCase();
      _handleHostForceEndedCall(isCompleted: status == 'completed');
    }
  }

  Future<void> _checkIfRoomEndedByHost() async {
    if (_isExiting || widget.isEmployer || !mounted) return;
    final row = await InterviewService().getRoomById(widget.interviewID);
    if (row != null && mounted && !_isExiting) {
      final remoteAi = row['aiAnalyticsEnabled'] == true;
      if (remoteAi != _aiAnalyticsEnabled) {
        setState(() => _aiAnalyticsEnabled = remoteAi);
      }
      _evaluateRoomRowForHostEnd(row);
    }
  }

  Future<void> _startAiAudioRecordingIfEnabled() async {
    if (!widget.isEmployer ||
        !_aiAnalyticsEnabled ||
        _isAiRecording ||
        !_engineReady ||
        _engineReleased) {
      return;
    }
    try {
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/interview_${widget.interviewID}_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _engine.startAudioRecording(
        AudioRecordingConfiguration(
          filePath: path,
          encode: true,
          sampleRate: 32000,
          fileRecordingType: AudioFileRecordingType.audioFileRecordingMixed,
          quality: AudioRecordingQualityType.audioRecordingQualityMedium,
          recordingChannel: 1,
        ),
      );

      _recordingFilePath = path;
      _recordingStartedAt = DateTime.now();
      if (mounted) {
        setState(() => _isAiRecording = true);
      } else {
        _isAiRecording = true;
      }
      debugPrint('Started Agora mixed audio recording: $path');
    } catch (e) {
      debugPrint('Failed to start Agora audio recording: $e');
    }
  }

  Future<int> _stopAiAudioRecording() async {
    final started = _recordingStartedAt;
    final elapsed = started != null
        ? DateTime.now().difference(started).inSeconds
        : 0;
    if (_isAiRecording && _engineReady && !_engineReleased) {
      try {
        await _engine.stopAudioRecording();
      } catch (e) {
        debugPrint('Error stopping Agora audio recording: $e');
      }
    }
    _isAiRecording = false;
    return elapsed < 1 ? 1 : elapsed;
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
            _startAiAudioRecordingIfEnabled();
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
            if (!widget.isEmployer && !_isExiting) {
              // Immediately check if the employer permanently ended/reset the meeting
              _checkIfRoomEndedByHost();
              Future.delayed(const Duration(milliseconds: 600), () {
                if (mounted && !_isExiting) {
                  _checkIfRoomEndedByHost();
                }
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

  Future<void> _cleanupEngine() async {
    if (!_engineReady || _engineReleased) return;
    _engineReleased = true;
    if (_isAiRecording) {
      _isAiRecording = false;
      try {
        await _engine.stopAudioRecording();
      } catch (_) {}
    }
    try {
      await _engine.stopPreview();
    } catch (_) {}
    try {
      await _engine.leaveChannel();
    } catch (_) {}
    try {
      await _engine.release();
    } catch (_) {}
  }

  @override
  void dispose() {
    _roomPoller?.cancel();
    _roomSubscription?.cancel();
    if (_engineReady && !_engineReleased) {
      _engineReleased = true;
      if (_isAiRecording) {
        _isAiRecording = false;
        try {
          _engine.stopAudioRecording();
        } catch (_) {}
      }
      _engine.leaveChannel();
      _engine.release();
    }
    super.dispose();
  }

  Future<void> _handleHostForceEndedCall({bool isCompleted = false}) async {
    if (_isExiting || !mounted) return;
    _isExiting = true;

    _roomPoller?.cancel();
    _roomPoller = null;
    await _roomSubscription?.cancel();
    _roomSubscription = null;

    if (mounted) {
      setState(() {
        _remoteUid = null;
        _localUserJoined = false;
      });
    }

    // Force-disconnect audio/video immediately
    await _cleanupEngine();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.call_end_rounded,
                    color: Color(0xFFC24E4E),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  isCompleted
                      ? 'Interview Completed'
                      : 'Meeting Ended by Employer',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2433),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isCompleted
                      ? 'The employer has concluded this interview and closed the room. Your call has been disconnected.'
                      : 'The employer has ended the meeting and reset the interview room. Your call has been disconnected.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF687588),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF163B65),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Return to Lobby',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _exitCallAsSeeker() async {
    if (_isExiting) return;
    _isExiting = true;
    _roomPoller?.cancel();
    _roomPoller = null;
    await _roomSubscription?.cancel();
    _roomSubscription = null;
    await InterviewService().leaveInterview(widget.interviewID, false);
    await _cleanupEngine();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<String?> _showEmployerEndDialog() {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Leave or End Meeting?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2433),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _aiAnalyticsEnabled
                    ? 'Post-interview AI analytics is active. End the meeting and generate your AI evaluation report, or leave temporarily.'
                    : 'Do you want to temporarily leave the room, or permanently end the interview for everyone?',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF687588),
                ),
              ),
              const SizedBox(height: 20),
              if (_aiAnalyticsEnabled) ...[
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop('end_analyze'),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 19),
                  label: const Text(
                    'End & Generate AI Report',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B4FD3),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop('end'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC24E4E),
                    side: const BorderSide(color: Color(0xFFF3B8B8)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'End Without AI Report',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop('end'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5484D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'End Meeting & Reset Room',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop('leave'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF163B65),
                  side: const BorderSide(color: Color(0xFFD8E4F5)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Leave Temporarily',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('cancel'),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF687588),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onCallEnded() async {
    if (_isExiting) return;

    if (widget.isEmployer) {
      final action = await _showEmployerEndDialog();
      if (!mounted || action == null || action == 'cancel') return;

      _isExiting = true;
      await _roomSubscription?.cancel();
      _roomSubscription = null;

      // Flush and close audio recording BEFORE leaving channel / releasing engine
      final int recordedSeconds = await _stopAiAudioRecording();
      final String? recordedPath = _recordingFilePath;

      if (action == 'leave') {
        await InterviewService().leaveInterview(widget.interviewID, true);
        await _cleanupEngine();
        if (recordedPath != null) {
          try {
            final f = File(recordedPath);
            if (await f.exists()) await f.delete();
          } catch (_) {}
        }
        if (mounted) Navigator.of(context).pop();
        return;
      }

      // Both 'end' and 'end_analyze' reset/end the active room immediately so the candidate is notified right away
      await InterviewService().forceEndInterview(widget.interviewID);
      await _cleanupEngine();

      if (action == 'end') {
        if (recordedPath != null) {
          try {
            final f = File(recordedPath);
            if (await f.exists()) await f.delete();
          } catch (_) {}
        }
        if (mounted) Navigator.of(context).pop();
        return;
      }

      if (action == 'end_analyze') {
        await _generateAndOpenAiReport(
          recordedPath: recordedPath,
          durationSeconds: recordedSeconds,
        );
      }
    } else {
      await _exitCallAsSeeker();
    }
  }

  Future<void> _generateAndOpenAiReport({
    required String? recordedPath,
    required int durationSeconds,
  }) async {
    if (!mounted) return;
    if (recordedPath == null || recordedPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No audio recording was captured during this call.'),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    // Brief pause so native audio encoder finishes flushing the final frame
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    bool progressOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: const Padding(
            padding: EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF6B4FD3)),
                SizedBox(height: 20),
                Text(
                  'Generating AI Interview Report…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2433),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Transcribing dialogue, evaluating role fit & communication delivery. This usually takes 10–25 seconds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Color(0xFF687588),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final report = await EmployerService().generatePostInterviewAiReport(
        roomID: widget.interviewID,
        audioFile: File(recordedPath),
        durationSeconds: durationSeconds,
      );

      if (!mounted) return;
      if (progressOpen) {
        progressOpen = false;
        Navigator.of(context).pop(); // Close progress dialog
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PostInterviewAiReportScreen(initialReport: report),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (progressOpen) {
        progressOpen = false;
        Navigator.of(context).pop(); // Close progress dialog
      }

      final message = e is PostInterviewReportException
          ? e.message
          : 'Unable to generate the AI report right now. Please try again.';

      await showDialog<void>(
        context: context,
        builder: (errContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'AI Report Not Generated',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(errContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF163B65),
                foregroundColor: Colors.white,
              ),
              child: const Text('Return to Lobby'),
            ),
          ],
        ),
      );

      if (mounted) {
        Navigator.of(context).pop();
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _onCallEnded();
        }
      },
      child: Scaffold(
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
                    color: const Color(0xFFF5A524).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.videocam_off_rounded,
                    color: Color(0xFFF5A524),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Camera could not start',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _initializationError!,
                  style: const TextStyle(
                    color: Color(0xFFBAC4D1),
                    fontSize: 14,
                    height: 1.45,
                  ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
                decoration: const BoxDecoration(
                  color: Color(0xFF314158),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFFCFD7E3),
                  size: 50,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Waiting for the other participant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
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
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                ),
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
                  const Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: Color(0xFFA9C8FF),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      widget.isEmployer
                          ? 'Interview in progress'
                          : 'Live interview',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_aiAnalyticsEnabled) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xD96B4FD3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'AI REC',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(width: 10),
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFF41D88C),
              shape: BoxShape.circle,
            ),
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 6)),
        ],
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
                  ? const Icon(
                      Icons.videocam_off_rounded,
                      color: Color(0xFFCFD7E3),
                      size: 34,
                    )
                  : const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
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
                  Icon(
                    _isMicrophoneMuted
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'You',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

  Widget _buildControlDock() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xE61F2937),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
            icon: _isCameraOff
                ? Icons.videocam_off_rounded
                : Icons.videocam_rounded,
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
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: foregroundColor),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
