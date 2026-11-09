/// One camera frame checked by ML Kit while the user answers.
/// Only these numbers are kept: the frame itself is thrown away.
class FaceSample {
  /// Time since the answer started.
  final Duration at;

  /// Faces found in the frame (0 = nobody in view).
  final int faceCount;

  /// Head turned left / right (ML Kit headEulerAngleY), degrees. Largest face.
  final double? yaw;

  /// Head tilted up / down (ML Kit headEulerAngleX), degrees. Largest face.
  final double? pitch;

  /// ML Kit smilingProbability, 0..1. Largest face.
  final double? smilingProbability;

  const FaceSample({
    required this.at,
    required this.faceCount,
    this.yaw,
    this.pitch,
    this.smilingProbability,
  });

  /// A frame with nobody in it.
  const FaceSample.noFace(this.at)
      : faceCount = 0,
        yaw = null,
        pitch = null,
        smilingProbability = null;

  bool get hasFace => faceCount > 0;
}

/// Body language cues for one answer, sent to the server with the audio.
/// Feedback only: they are not part of any score.
class FaceMetrics {
  /// Frames checked.
  final int sampleCount;

  /// Frames with a face in view, 0-100.
  final int facePresentPercent;

  /// Frames (face in view) where the head faced the camera, 0-100.
  /// Null when the face was in view too little to judge.
  final int? eyeContactPercent;

  /// Frames (face in view) with a smile, 0-100. Null when not enough data.
  final int? smilePercent;

  /// Times the user looked away or left the frame for 1 second or longer.
  final int lookAwayCount;

  const FaceMetrics({
    required this.sampleCount,
    required this.facePresentPercent,
    required this.eyeContactPercent,
    required this.smilePercent,
    required this.lookAwayCount,
  });

  Map<String, dynamic> toJson() => {
        'sampleCount': sampleCount,
        'facePresentPercent': facePresentPercent,
        'eyeContactPercent': eyeContactPercent,
        'smilePercent': smilePercent,
        'lookAwayCount': lookAwayCount,
      };

  @override
  String toString() => 'FaceMetrics(${toJson()})';
}
