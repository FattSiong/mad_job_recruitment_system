import 'job_model.dart';

/// A job found on the map, with its distance from the search centre.
class NearbyJob {
  final JobModel job;
  final double distanceKm;

  const NearbyJob({required this.job, required this.distanceKm});

  double get latitude => job.latitude!;
  double get longitude => job.longitude!;

  /// Jobs with the same key are at the same spot (about 1 m apart or less),
  /// e.g. several openings at one company office.
  String get spotKey => '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';

  /// "350 m" or "2.4 km".
  String get distanceLabel {
    if (distanceKm < 1) return '${(distanceKm * 1000).round()} m';
    if (distanceKm < 10) return '${distanceKm.toStringAsFixed(1)} km';
    return '${distanceKm.round()} km';
  }
}

/// Result of one map search.
class NearbyJobsResult {
  /// Nearest first.
  final List<NearbyJob> jobs;

  /// True when more jobs matched than could be shown.
  final bool capped;

  const NearbyJobsResult({required this.jobs, required this.capped});
}
