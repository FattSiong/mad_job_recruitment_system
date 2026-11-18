import 'dart:ui' show FontFeature;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/mock_interview_model.dart';
import '../../../services/face_cue_analyzer.dart';
import '../controllers/mock_interview_controller.dart';
import '../controllers/mock_interview_session_controller.dart';
import 'mock_interview_result_screen.dart';
import '../../../shared_widgets/confirm_dialog.dart';
import '../../../core/theme/app_button_styles.dart';

/// Steps 2-6 of Use Case 4.59: introduction, questions, answers, end.
class MockInterviewSessionScreen extends StatefulWidget {
  final String sessionID;
  final String targetJobRole;
  final int questionCount; // excluding the introduction
  final List<InterviewQuestion> initialQuestions;

  const MockInterviewSessionScreen({
    super.key,
    required this.sessionID,
    required this.targetJobRole,
    required this.questionCount,
    required this.initialQuestions,
  });

  @override
  State<MockInterviewSessionScreen> createState() => _MockInterviewSessionScreenState();
}

class _MockInterviewSessionScreenState extends State<MockInterviewSessionScreen>
    with WidgetsBindingObserver {

  static const Duration _maxAnswerLength = MockInterviewSessionController.maxAnswerLength;

  /// Interview state and recording live in the controller (MVC).
  late final MockInterviewSessionController _session = MockInterviewSessionController(
    sessionID: widget.sessionID,
    requestedQuestionCount: widget.questionCount,
    initialQuestions: widget.initialQuestions,
  );

  // Read-only views of the controller state used by the UI below.
  InterviewStage get _stage => _session.stage;
  int get _position => _session.position;
  Duration get _elapsed => _session.elapsed;
  double get _level => _session.level;
  int get _totalQuestions => _session.totalQuestions;
  InterviewQuestion get _current => _session.current;
  bool get _isLastQuestion => _session.isLastQuestion;
  bool get _isBusy => _session.isBusy;

  // Camera: preview, plus eye contact / smile estimated on the phone while
  // answering (never recorded or uploaded, nothing shown while answering)
  CameraController? _camera;
  bool _cameraOn = false;
  bool _cameraLoading = false;

  @override
  void initState() {
    super.initState();
    _session
      ..onError = _showError
      ..onSessionGone = _closeAfterSessionGone
      ..addListener(_onSessionChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session
      ..onError = null
      ..onSessionGone = null
      ..removeListener(_onSessionChanged)
      ..dispose(); // stops the recorder and deletes any unsent recording
    _camera?.dispose();
    super.dispose();
  }

  /// Rebuilds when the interview state changes.
  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  /// Closes the screen when the session no longer exists on the server.
  void _closeAfterSessionGone() {
    if (mounted) Navigator.pop(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only react to "paused" (app really in background). "inactive" also fires for
    // permission dialogs and the notification shade, which must not stop an answer.
    if (state == AppLifecycleState.paused) {
      // Leaving the app: stop the camera and throw away a half-finished answer
      _session.onAppPaused();
      final cam = _camera;
      _camera = null;
      _releaseCamera(cam);
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed &&
        _cameraOn &&
        _camera == null &&
        !_cameraLoading) {
      _initCamera();
    }
  }

  // ---------------------------------------------------------------------
  // Camera
  // ---------------------------------------------------------------------

  /// Turns the camera preview on or off.
  Future<void> _toggleCamera() async {
    if (_cameraOn) {
      final cam = _camera;
      setState(() {
        _cameraOn = false;
        _camera = null;
      });
      await _releaseCamera(cam);
    } else {
      setState(() => _cameraOn = true);
      await _initCamera();
    }
  }

  /// Opens the front camera for the preview and the face checks.
  Future<void> _initCamera() async {
    setState(() => _cameraLoading = true);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('no_camera', 'No camera found');
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      // enableAudio: false -> the microphone stays free for the answer recorder
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: FaceCueAnalyzer.imageFormatGroup, // frames ML Kit can read
      );
      await controller.initialize();
      if (!mounted || !_cameraOn) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
      await _session.setCamera(controller);
    } on CameraException catch (e) {
      debugPrint('Camera error: ${e.code} ${e.description}');
      if (!mounted) return;
      setState(() => _cameraOn = false);
      _showError(
        e.code.contains('Access')
            ? 'Camera permission was denied. You can continue without the camera.'
            : 'Unable to open the camera. You can continue without it.',
      );
    } finally {
      if (mounted) setState(() => _cameraLoading = false);
    }
  }

  /// Stops face checks on [cam] before closing it.
  Future<void> _releaseCamera(CameraController? cam) async {
    if (cam == null) return;
    await _session.setCamera(null);
    await cam.dispose();
  }

  // ---------------------------------------------------------------------
  // Answers and navigation (logic is in MockInterviewSessionController)
  // ---------------------------------------------------------------------

  /// Mic tapped: start recording the answer.
  Future<void> _startRecording() => _session.startRecording();

  /// Stop tapped: send the answer for feedback.
  Future<void> _stopAndEvaluate() => _session.stopAndEvaluate();

  /// Goes to the next question.
  void _nextQuestion() => _session.nextQuestion();

  /// Ends the interview and opens the scorecard.
  Future<void> _endInterview() async {
    try {
      final record = await _session.finish();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MockInterviewResultScreen(
            sessionID: record.sessionID,
            initialRecord: record,
          ),
        ),
      );
    } on MockInterviewException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    }
  }

  /// Use case A2: early exit discards the session.
  Future<void> _confirmExit() async {
    if (_stage == InterviewStage.finishing) return;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Exit interview?',
      message: 'Exiting now will discard your progress. No scorecard will be generated or saved.',
      confirmLabel: 'Exit',
      cancelLabel: 'Continue Interview',
    );
    if (!confirmed) return;

    await _session.discard();
    if (mounted) Navigator.pop(context);
  }

  /// Red snackbar (if the screen is still open).
  void _showError(String message) {
    if (!mounted) return;
    SnackBarHelper.showError(context, message, duration: const Duration(seconds: 3));
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildCameraCard(),
                      const SizedBox(height: 16),
                      _buildQuestionCard(),
                      const SizedBox(height: 16),
                      _buildAnswerArea(),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  /// Header with the question number, progress bar and exit button.
  Widget _buildHeader() {
    final progress = (_position + (_session.currentAnswered ? 1 : 0)) /
        _totalQuestions;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 16, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _stage == InterviewStage.finishing ? null : _confirmExit,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: 'Exit interview',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mock Interview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.targetJobRole,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_position + 1} / $_totalQuestions',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Camera preview with the recording badge and camera switch.
  Widget _buildCameraCard() {
    final cam = _camera;
    final ready = cam != null && cam.value.isInitialized;

    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        color: AppColors.cameraBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                // previewSize is landscape, so swap for portrait
                width: cam.value.previewSize?.height ?? 300,
                height: cam.value.previewSize?.width ?? 400,
                child: CameraPreview(cam),
              ),
            )
          else
            Center(
              child: _cameraLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.person_outline_rounded,
                              color: Colors.white, size: 34),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Turn on the camera to practise eye contact\nand body language.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, height: 1.4),
                        ),
                      ],
                    ),
            ),
          // Recording badge
          if (_stage == InterviewStage.recording)
            Positioned(
              left: 14,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(_elapsed),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          // Privacy note
          if (ready)
            Positioned(
              left: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Not recorded · analysed on your phone',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          // Camera toggle
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: IconButton(
                tooltip: _cameraOn ? 'Turn camera off' : 'Turn camera on',
                icon: Icon(
                  _cameraOn ? Icons.videocam_off_outlined : Icons.videocam_outlined,
                  color: AppColors.primary,
                ),
                onPressed: _cameraLoading ? null : _toggleCamera,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The current question.
  Widget _buildQuestionCard() {
    final q = _current;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              q.isIntroduction ? 'Introduction' : 'Question ${q.index} · ${q.typeLabel}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            q.question,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Mic button, recording panel, spinner or feedback, by stage.
  Widget _buildAnswerArea() {
    switch (_stage) {
      case InterviewStage.ready:
        return _buildMicPrompt();
      case InterviewStage.recording:
        return _buildRecordingPanel();
      case InterviewStage.evaluating:
        return _buildLoadingPanel(
          _current.isIntroduction
              ? 'Analysing your introduction and preparing your questions…'
              : 'Analysing your answer…',
        );
      case InterviewStage.finishing:
        return _buildLoadingPanel('Generating your interview scorecard…');
      case InterviewStage.reviewed:
        return _buildReviewPanel(_session.currentAnswer!);
    }
  }

  /// White rounded panel under the question.
  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }

  /// "Tap to answer" mic button.
  Widget _buildMicPrompt() {
    return _panel(
      child: Column(
        children: [
          GestureDetector(
            onTap: _startRecording,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 38),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Tap to start your answer',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Speak clearly. You can answer for up to 3 minutes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// Level meter, timer and stop button while recording.
  Widget _buildRecordingPanel() {
    return _panel(
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                // Simple level meter: middle bars are taller
                final weight = 1 - ((i - 3).abs() / 4);
                final h = 8 + 32 * _level * weight;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 6,
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_formatDuration(_elapsed)} / ${_formatDuration(_maxAnswerLength)}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _stopAndEvaluate,
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stop_rounded, color: AppColors.danger, size: 44),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Recording… tap to finish your answer',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// Spinner with a message (e.g. while the answer is evaluated).
  Widget _buildLoadingPanel(String message) {
    return _panel(
      child: Column(
        children: [
          const SizedBox(height: 8),
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          const Text(
            'This usually takes a few seconds.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// Feedback on the answer just given.
  Widget _buildReviewPanel(MockInterviewAnswerModel answer) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.successGreen),
              SizedBox(width: 8),
              Text(
                'Answer saved',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statChip(Icons.speed_rounded,
                  '${answer.wordsPerMinute?.round() ?? 0} wpm${answer.paceLabel.isEmpty ? '' : ' · ${answer.paceLabel}'}'),
              _statChip(Icons.chat_bubble_outline_rounded,
                  '${answer.fillerWordCount ?? 0} filler words'),
              _statChip(Icons.pause_circle_outline_rounded,
                  '${answer.hesitationCount ?? 0} hesitations'),
              if (answer.eyeContactPercent != null)
                _statChip(Icons.visibility_outlined, '${answer.eyeContactPercent}% eye contact'),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'What we heard',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 160),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              child: Text(
                answer.transcriptText,
                style: const TextStyle(color: AppColors.textMuted, height: 1.45),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Detailed feedback will be shown in your scorecard at the end.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// Small chip with an icon (e.g. words per minute).
  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Next Question or End Interview, shown once the answer is reviewed.
  Widget _buildBottomBar() {
    if (_stage != InterviewStage.reviewed) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _startRecording,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Re-record'),
                style: AppButtonStyles.outlined(radius: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isBusy
                    ? null
                    : (_isLastQuestion ? _endInterview : _nextQuestion),
                icon: Icon(_isLastQuestion ? Icons.flag_rounded : Icons.arrow_forward_rounded),
                label: Text(_isLastQuestion ? 'End Interview' : 'Next Question'),
                style: AppButtonStyles.filled(radius: 18, textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "1:05" (minutes:seconds).
  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
