import '../../../models/face_metrics.dart';

/// Turns the ML Kit samples of one answer into [FaceMetrics].
///
/// Pure Dart (no camera / ML Kit), so it can be unit tested.
///
/// "Eye contact" is estimated from the head direction: ML Kit gives the head
/// angles, not where the eyes look. The phone is rarely exactly in front of
/// the face, so the first [calibrationWindow] of the answer is taken as
/// "looking at the phone" and later frames are compared with it.
class FaceMetricsTracker {
  /// Fewer frames than this (camera on for only a moment) -> no result.
  static const int minSamples = 5;

  /// Fewer frames with a face than this -> eye contact / smile are null.
  static const int minFaceSamples = 5;

  /// Frames from the start of the answer used to find the head's resting angle.
  static const Duration calibrationWindow = Duration(milliseconds: 1500);

  /// Head turned more than this left / right from the resting angle = looking away.
  static const double maxYawDegrees = 15;

  /// Head tilted more than this up / down from the resting angle = looking away.
  /// Larger than [maxYawDegrees]: reading the question on screen moves the head a little.
  static const double maxPitchDegrees = 20;

  /// A resting angle further than this is not trusted (e.g. the user looked
  /// away right at the start), so it is limited to this.
  static const double maxBaselineDegrees = 25;

  /// Smiling when ML Kit's smilingProbability is above this.
  static const double smileThreshold = 0.5;

  /// Away (or out of frame) for at least this long = one look-away.
  static const Duration lookAwayMin = Duration(seconds: 1);

  final List<FaceSample> _samples = [];

  int get sampleCount => _samples.length;

  /// Starts a new answer.
  void reset() => _samples.clear();

  void add(FaceSample sample) => _samples.add(sample);

  /// Metrics for the frames added since [reset]; null if there are too few.
  FaceMetrics? result() => summarize(_samples);

  static FaceMetrics? summarize(List<FaceSample> samples) {
    if (samples.length < minSamples) return null;

    final sorted = List.of(samples)..sort((a, b) => a.at.compareTo(b.at));
    final withFace = sorted.where((s) => s.hasFace).toList();
    final angled = withFace.where((s) => s.yaw != null && s.pitch != null).toList();

    // Resting head angle: median of the first 1.5 s (or of the first 3 frames with a face)
    final early = angled.where((s) => s.at <= calibrationWindow).toList();
    final calibration = early.length >= 2 ? early : angled.take(3).toList();
    final baseYaw = _baseline(calibration.map((s) => s.yaw!).toList());
    final basePitch = _baseline(calibration.map((s) => s.pitch!).toList());

    bool facing(FaceSample s) =>
        s.hasFace &&
        s.yaw != null &&
        s.pitch != null &&
        (s.yaw! - baseYaw).abs() <= maxYawDegrees &&
        (s.pitch! - basePitch).abs() <= maxPitchDegrees;

    // Look-aways: runs of "not facing / no face" lasting >= lookAwayMin
    var lookAways = 0;
    Duration? awayStart;
    for (final s in sorted) {
      if (facing(s)) {
        if (awayStart != null && s.at - awayStart >= lookAwayMin) lookAways++;
        awayStart = null;
      } else {
        awayStart ??= s.at;
      }
    }
    if (awayStart != null && sorted.last.at - awayStart >= lookAwayMin) lookAways++;

    final enoughFace = withFace.length >= minFaceSamples;
    final smiles = withFace.where((s) => s.smilingProbability != null).toList();

    return FaceMetrics(
      sampleCount: sorted.length,
      facePresentPercent: _percent(withFace.length, sorted.length),
      eyeContactPercent: enoughFace ? _percent(withFace.where(facing).length, withFace.length) : null,
      smilePercent: smiles.length >= minFaceSamples
          ? _percent(smiles.where((s) => s.smilingProbability! > smileThreshold).length, smiles.length)
          : null,
      lookAwayCount: lookAways,
    );
  }

  static double _baseline(List<double> values) {
    if (values.isEmpty) return 0;
    final v = List.of(values)..sort();
    final mid = v.length ~/ 2;
    final median = v.length.isOdd ? v[mid] : (v[mid - 1] + v[mid]) / 2;
    return median.clamp(-maxBaselineDegrees, maxBaselineDegrees).toDouble();
  }

  static int _percent(int part, int total) => total == 0 ? 0 : (part * 100 / total).round();
}
