import 'dart:io';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../models/face_metrics.dart';
import '../modules/job_seeker/controllers/face_metrics_tracker.dart';

/// Body language cues for the mock interview, worked out on the phone with
/// Google ML Kit face detection while an answer is being recorded.
///
/// Frames are checked about 3 times a second and thrown away straight after:
/// nothing is recorded, saved or uploaded except the final [FaceMetrics].
/// Nothing is shown while the user answers.
class FaceCueAnalyzer {
  /// Time between checked frames (the camera gives ~30 a second).
  static const Duration frameInterval = Duration(milliseconds: 333);

  final FaceMetricsTracker _tracker = FaceMetricsTracker();
  final Stopwatch _clock = Stopwatch();
  FaceDetector? _detector; // created on first use

  CameraController? _camera;
  bool _answering = false;
  bool _streaming = false;
  bool _busy = false;
  bool _disposed = false;
  Future<void>? _starting;
  Future<void>? _stopping;
  Duration? _lastFrameAt;
  bool _loggedFormat = false;

  /// The camera format to ask for so frames can be passed to ML Kit.
  static ImageFormatGroup get imageFormatGroup =>
      Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21;

  /// The preview camera, or null when it is off. Can change mid-answer.
  Future<void> setCamera(CameraController? camera) async {
    if (identical(camera, _camera)) return;
    await _stopStream();
    _camera = camera;
    if (_answering) await _startStream();
  }

  /// An answer started recording.
  Future<void> beginAnswer() async {
    if (_disposed) return;
    _tracker.reset();
    _lastFrameAt = null;
    _clock
      ..reset()
      ..start();
    _answering = true;
    await _startStream();
  }

  /// The answer finished: the cues for it, or null if the camera was off
  /// (or on for too short a time).
  Future<FaceMetrics?> endAnswer() async {
    _answering = false;
    _clock.stop();
    await _stopStream();
    final result = _tracker.result();
    _tracker.reset();
    return result;
  }

  /// The answer was thrown away.
  Future<void> cancelAnswer() async {
    _answering = false;
    _clock.stop();
    await _stopStream();
    _tracker.reset();
  }

  Future<void> dispose() async {
    _disposed = true;
    _answering = false;
    await _stopStream();
    _camera = null;
    await _detector?.close();
    _detector = null;
  }

  // ---------------------------------------------------------------------
  // Camera frames -> ML Kit
  // ---------------------------------------------------------------------

  /// Starts sending camera frames to ML Kit (only while answering).
  Future<void> _startStream() async {
    final cam = _camera;
    if (_disposed || _streaming || cam == null || !cam.value.isInitialized) return;
    await _stopping; // let a previous stop finish first
    if (_streaming || !_answering || !identical(cam, _camera) || cam.value.isStreamingImages) return;
    _streaming = true;
    final starting = _starting = cam.startImageStream((image) => _onFrame(image, cam));
    try {
      await starting;
    } catch (e) {
      _streaming = false;
      debugPrint('Face cues: could not start the camera stream: $e');
    }
  }

  /// Stops the frame stream; waits for a stream that is still starting.
  Future<void> _stopStream() {
    if (!_streaming) return _stopping ?? Future.value();
    _streaming = false;
    final cam = _camera;
    final starting = _starting;
    return _stopping = () async {
      try {
        await starting; // a stream that is still starting can't be stopped yet
      } catch (_) {
        // already logged by _startStream
      }
      try {
        if (cam != null && cam.value.isStreamingImages) await cam.stopImageStream();
      } catch (e) {
        debugPrint('Face cues: could not stop the camera stream: $e');
      }
    }();
  }

  /// Checks one camera frame (about 3 a second) and keeps its result.
  Future<void> _onFrame(CameraImage image, CameraController cam) async {
    if (!_answering || _busy) return;
    final at = _clock.elapsed;
    final last = _lastFrameAt;
    if (last != null && at - last < frameInterval) return;
    _lastFrameAt = at;

    final input = _toInputImage(image, cam);
    if (input == null) return;

    _busy = true;
    try {
      final detector = _detector ??= FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true, // smilingProbability
          performanceMode: FaceDetectorMode.fast,
          minFaceSize: 0.15,
        ),
      );
      final faces = await detector.processImage(input);
      if (!_answering) return; // the answer ended while this frame was checked
      _tracker.add(_sampleFrom(faces, at));
    } catch (e) {
      debugPrint('Face cues: frame skipped: $e');
    } finally {
      _busy = false;
    }
  }

  /// Uses the largest face (the user, not someone in the background).
  static FaceSample _sampleFrom(List<Face> faces, Duration at) {
    if (faces.isEmpty) return FaceSample.noFace(at);
    final face = faces.reduce((a, b) {
      final areaA = a.boundingBox.width * a.boundingBox.height;
      final areaB = b.boundingBox.width * b.boundingBox.height;
      return areaB > areaA ? b : a;
    });
    return FaceSample(
      at: at,
      faceCount: faces.length,
      yaw: face.headEulerAngleY,
      pitch: face.headEulerAngleX,
      smilingProbability: face.smilingProbability,
    );
  }

  /// Camera frame -> ML Kit input (NV21 on Android, BGRA on iOS).
  InputImage? _toInputImage(CameraImage image, CameraController cam) {
    final sensorOrientation = cam.description.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else {
      // DeviceOrientation is portraitUp, landscapeLeft, portraitDown, landscapeRight
      // = 0, 90, 180, 270 degrees
      final deviceRotation = cam.value.deviceOrientation.index * 90;
      final degrees = cam.description.lensDirection == CameraLensDirection.front
          ? (sensorOrientation + deviceRotation) % 360
          : (sensorOrientation - deviceRotation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(degrees);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    final supported = Platform.isIOS
        ? format == InputImageFormat.bgra8888
        : format == InputImageFormat.nv21;
    if (format == null || !supported || image.planes.length != 1) {
      if (!_loggedFormat) {
        _loggedFormat = true;
        debugPrint('Face cues: unsupported camera format ${image.format.raw} '
            '(${image.planes.length} planes), skipping');
      }
      return null;
    }

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}
