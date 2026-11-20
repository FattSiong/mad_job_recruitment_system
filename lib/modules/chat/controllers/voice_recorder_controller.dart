import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../core/utils/safe_notifier.dart';

/// A finished voice note.
class VoiceRecording {
  final File file;
  final int seconds;

  const VoiceRecording(this.file, this.seconds);
}

/// Hold-to-record voice notes for the chat composer.
class VoiceRecorderController extends ChangeNotifier with SafeNotifier {
  static const Duration minLength = Duration(milliseconds: 800);

  final AudioRecorder _recorder = AudioRecorder();
  DateTime? _startedAt;
  Timer? _ticker;
  bool _busy = false;
  bool _releasedWhileStarting = false;

  bool get isRecording => _startedAt != null;

  Duration get elapsed =>
      _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);

  /// Starts recording a voice note (the mic button is pressed).
  /// Returns false if the microphone permission was refused.
  Future<bool> start() async {
    if (_busy || isRecording) return true;
    _busy = true;
    _releasedWhileStarting = false;
    try {
      if (!await _recorder.hasPermission()) return false;

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
        path: path,
      );

      _startedAt = DateTime.now();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => notifySafely());
      notifySafely();
      if (_releasedWhileStarting) {
        // The button was released before the microphone was ready: too short.
        _busy = false;
        await cancel();
      }
      return true;
    } catch (e) {
      debugPrint('Voice recorder start failed: $e');
      return false;
    } finally {
      _busy = false;
    }
  }

  /// Stops and returns the recording, or null if it was too short.
  Future<VoiceRecording?> stop() async {
    if (_busy) {
      _releasedWhileStarting = true;
      return null;
    }
    if (!isRecording) return null;
    final length = elapsed;
    _reset();

    try {
      final path = await _recorder.stop();
      if (path == null) return null;
      final file = File(path);
      if (length < minLength) {
        _deleteQuietly(file);
        return null;
      }
      final seconds = (length.inMilliseconds / 1000).round().clamp(1, 3600);
      return VoiceRecording(file, seconds);
    } catch (e) {
      debugPrint('Voice recorder stop failed: $e');
      return null;
    }
  }

  /// Stops recording and throws the recording away (slid to cancel).
  Future<void> cancel() async {
    if (_busy) {
      _releasedWhileStarting = true;
      return;
    }
    if (!isRecording) return;
    _reset();
    try {
      final path = await _recorder.stop();
      if (path != null) _deleteQuietly(File(path));
    } catch (_) {}
  }

  /// Back to "not recording" (stops the timer).
  void _reset() {
    _startedAt = null;
    _ticker?.cancel();
    _ticker = null;
    notifySafely();
  }

  /// Deletes [file]; a failure is ignored (it is only a temporary file).
  void _deleteQuietly(File file) {
    file.delete().catchError((_) => file);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
