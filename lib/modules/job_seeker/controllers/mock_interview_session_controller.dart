import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../models/mock_interview_model.dart';
import '../../../services/face_cue_analyzer.dart';
import 'mock_interview_controller.dart';
import '../../../core/utils/safe_notifier.dart';

/// Where the session is for the question on screen.
enum InterviewStage { ready, recording, evaluating, reviewed, finishing }

/// State of a running mock interview (Use Case 4.59, steps 2-6): the
/// questions, the answers so far, and recording / evaluating each answer.
///
/// The camera preview stays in the screen. While an answer is recorded with
/// the camera on, [FaceCueAnalyzer] estimates eye contact and smiling on the
/// phone; only those numbers are sent with the answer (video never leaves the
/// phone, and the numbers are feedback only, not part of the score).
class MockInterviewSessionController extends ChangeNotifier with SafeNotifier {
  final String sessionID;

  /// Questions requested at setup (excluding the introduction).
  final int requestedQuestionCount;

  /// Shown when something goes wrong, e.g. an answer that was too short.
  /// Set by the screen.
  ValueChanged<String>? onError;

  /// The session no longer exists on the server; the screen should close.
  VoidCallback? onSessionGone;

  final MockInterviewController _api;
  final AudioRecorder _recorder = AudioRecorder();
  final FaceCueAnalyzer _faceCues;

  MockInterviewSessionController({
    required this.sessionID,
    required this.requestedQuestionCount,
    required List<InterviewQuestion> initialQuestions,
    MockInterviewController? api,
    FaceCueAnalyzer? faceCues,
  })  : _api = api ?? MockInterviewController(),
        _faceCues = faceCues ?? FaceCueAnalyzer(),
        _questions = List.of(initialQuestions);

  static const Duration maxAnswerLength = Duration(minutes: 3);
  static const Duration minAnswerLength = Duration(seconds: 3);
  static const int _amplitudeIntervalMs = 100;

  List<InterviewQuestion> _questions;
  final Map<int, MockInterviewAnswerModel> _answers = {};
  int _position = 0; // position in _questions
  InterviewStage _stage = InterviewStage.ready;

  // Recording
  String? _recordingPath;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudeSub;
  double _level = 0; // 0..1 microphone level
  final List<double> _amplitudeTrack = []; // dBFS, one sample per _amplitudeIntervalMs
  final Stopwatch _recordClock = Stopwatch();
  bool _starting = false; // the microphone is being started

  // ---------------------------------------------------------------------
  // Read-only state for the screen
  // ---------------------------------------------------------------------

  List<InterviewQuestion> get questions => List.unmodifiable(_questions);
  int get position => _position;
  InterviewStage get stage => _stage;
  Duration get elapsed => _elapsed;
  double get level => _level;

  /// Questions are generated after the introduction, so until then use the requested count.
  bool get questionsReady => _questions.length > 1;
  int get totalQuestions =>
      questionsReady ? _questions.length : requestedQuestionCount + 1; // + introduction
  InterviewQuestion get current => _questions[_position];
  bool get isLastQuestion => questionsReady && _position == _questions.length - 1;
  bool get isBusy => _stage == InterviewStage.evaluating || _stage == InterviewStage.finishing;
  bool get currentAnswered => _answers.containsKey(current.index);
  MockInterviewAnswerModel? get currentAnswer => _answers[current.index];

  // ---------------------------------------------------------------------
  // Camera (body language cues)
  // ---------------------------------------------------------------------

  /// The screen passes its preview camera here when it is ready, and null
  /// before turning it off. Frames are only checked while recording.
  Future<void> setCamera(CameraController? camera) => _faceCues.setCamera(camera);

  // ---------------------------------------------------------------------
  // Recording (mono AAC, 16 kHz)
  // ---------------------------------------------------------------------

  /// Starts recording the answer to the current question (asks for the
  /// microphone first). Problems go to [onError].
  Future<void> startRecording() async {
    // A second tap while the microphone is still starting is ignored
    // (it would start a second recorder and timer).
    if (_starting || (_stage != InterviewStage.ready && _stage != InterviewStage.reviewed)) return;
    _starting = true;
    String? path;
    try {
      if (!await _recorder.hasPermission()) {
        onError?.call('Microphone access is required to answer. Please allow it in Settings.');
        return;
      }
      if (isDisposed) return;

      final dir = await getTemporaryDirectory();
      final file = '${dir.path}/mock_${sessionID}_${current.index}_'
          '${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1, // mono
          sampleRate: 16000,
          bitRate: 32000,
        ),
        path: file,
      );
      path = file;
    } catch (e) {
      // e.g. the microphone is in use by another app
      debugPrint('Mock interview: could not start recording: $e');
      onError?.call('Unable to start recording. Please try again.');
      return;
    } finally {
      _starting = false;
    }
    if (isDisposed) return;

    _recordingPath = path;
    _amplitudeTrack.clear();
    _recordClock
      ..reset()
      ..start();
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: _amplitudeIntervalMs))
        .listen((amp) {
      // Keep the track aligned to real time: fill any missed slots with the latest value
      final slot = _recordClock.elapsedMilliseconds ~/ _amplitudeIntervalMs;
      final value = amp.current.isFinite ? amp.current : -100.0;
      while (_amplitudeTrack.length <= slot) {
        _amplitudeTrack.add(value);
      }
      // dBFS (-60 .. 0) -> 0 .. 1
      _level = ((amp.current + 50) / 50).clamp(0.0, 1.0);
      notifySafely();
    });

    _stage = InterviewStage.recording;
    _elapsed = Duration.zero;
    notifySafely();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isDisposed) return;
      _elapsed += const Duration(seconds: 1);
      notifySafely();
      if (_elapsed >= maxAnswerLength) stopAndEvaluate(); // auto stop
    });

    await _faceCues.beginAnswer(); // does nothing if the camera is off
  }

  /// Stops the recorder, timer and level meter without sending anything.
  Future<void> _stopRecorderOnly() async {
    _recordClock.stop();
    _ticker?.cancel();
    _ticker = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _level = 0;
  }

  /// Throws away the answer being recorded.
  Future<void> cancelRecording() async {
    await _stopRecorderOnly();
    await _faceCues.cancelAnswer();
    await _recorder.cancel(); // also deletes the file
    _recordingPath = null;
    _stage = currentAnswered ? InterviewStage.reviewed : InterviewStage.ready;
    notifySafely();
  }

  /// Stops recording and sends the answer for transcription + feedback.
  /// Problems go to [onError]; a session that no longer exists also calls
  /// [onSessionGone]. Never throws (it also runs from the auto-stop timer).
  Future<void> stopAndEvaluate() async {
    if (_stage != InterviewStage.recording) return;
    // Leave "recording" straight away: the stop button and the 3-minute
    // auto-stop can both fire, and the answer must be sent only once.
    _stage = InterviewStage.evaluating;
    notifySafely();
    await _stopRecorderOnly();
    var path = _recordingPath;
    try {
      path = await _recorder.stop() ?? path;
    } catch (e) {
      debugPrint('Mock interview: could not stop the recorder: $e');
    }
    final faceMetrics = await _faceCues.endAnswer(); // null if the camera was off

    if (isDisposed) {
      await _deleteRecordingFile();
      return;
    }

    if (path == null || _elapsed < minAnswerLength) {
      await _deleteRecordingFile();
      _stage = currentAnswered ? InterviewStage.reviewed : InterviewStage.ready;
      notifySafely();
      onError?.call('That answer was too short. Tap the mic and try again.');
      return;
    }

    final questionIndex = current.index;

    try {
      final result = await _api.evaluateAnswer(
        sessionID: sessionID,
        questionIndex: questionIndex,
        audioFile: File(path),
        amplitudeDb: List.of(_amplitudeTrack),
        amplitudeIntervalMs: _amplitudeIntervalMs,
        faceMetrics: faceMetrics,
      );
      _answers[questionIndex] = result.answer;
      if (result.questions != null && result.questions!.isNotEmpty) {
        _questions = result.questions!;
      }
      _stage = InterviewStage.reviewed;
    } on MockInterviewException catch (e) {
      _stage = _answers.containsKey(questionIndex) ? InterviewStage.reviewed : InterviewStage.ready;
      onError?.call(e.message);
      if (e.code == 'session_not_found') onSessionGone?.call();
    } catch (e) {
      // Anything else: never leave the screen stuck on "evaluating"
      debugPrint('Mock interview: evaluating the answer failed: $e');
      _stage = _answers.containsKey(questionIndex) ? InterviewStage.reviewed : InterviewStage.ready;
      onError?.call(MockInterviewController.unavailableMessage);
    } finally {
      await _deleteRecordingFile();
      notifySafely();
    }
  }

  /// Deletes the recorded audio file, if any (errors are ignored).
  Future<void> _deleteRecordingFile() async {
    final path = _recordingPath;
    _recordingPath = null;
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------

  /// Moves to the next question (no-op on the last one).
  void nextQuestion() {
    if (_position + 1 >= _questions.length) return;
    _position++;
    _stage = currentAnswered ? InterviewStage.reviewed : InterviewStage.ready;
    notifySafely();
  }

  /// Ends the interview and returns the scorecard.
  /// Throws [MockInterviewException] (the session stays open to try again).
  Future<MockInterviewSessionModel> finish() async {
    _stage = InterviewStage.finishing;
    notifySafely();
    try {
      return await _api.finishInterview(sessionID);
    } on MockInterviewException {
      _stage = InterviewStage.reviewed;
      notifySafely();
      rethrow;
    } catch (e) {
      // Never leave the screen stuck on "finishing" (Exit is blocked then)
      debugPrint('Mock interview: finishing failed: $e');
      _stage = InterviewStage.reviewed;
      notifySafely();
      throw MockInterviewException('ai_unavailable', MockInterviewController.unavailableMessage);
    }
  }

  /// Use case A2: early exit discards the session.
  Future<void> discard() async {
    if (_stage == InterviewStage.recording) await cancelRecording();
    await _api.discardInterview(sessionID);
  }

  /// The app went to the background: throw away a half-finished answer.
  void onAppPaused() {
    if (_stage == InterviewStage.recording) cancelRecording();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _amplitudeSub?.cancel();
    _recorder.dispose();
    _faceCues.dispose();
    _deleteRecordingFile();
    super.dispose();
  }
}
