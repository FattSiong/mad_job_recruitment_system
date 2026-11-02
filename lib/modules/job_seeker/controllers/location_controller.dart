import 'dart:math' show asin, cos, sqrt, pi;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/job_search_helper.dart';
import '../../../core/utils/salary_utils.dart';
import '../../../models/job_model.dart';
import '../../../models/nearby_job_model.dart';

/// Area around a point, as a latitude/longitude box.
typedef GeoBox = ({double minLat, double maxLat, double minLng, double maxLng});

/// Finds active jobs around a point on the map.
class LocationController {
  final _supabase = Supabase.instance.client;

  /// Most pins the map shows at once (keeps the map smooth in busy areas).
  static const int maxResults = 200;

  /// Straight-line distance in metres (haversine, Earth radius 6371 km).
  static double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  /// Smallest latitude/longitude box that contains the search circle. Used to
  /// ask the database only for nearby jobs, and to zoom the map to the circle.
  static GeoBox boundingBox(double lat, double lng, double radiusInMeters) {
    const metersPerDegreeLat = 6371000 * pi / 180;
    final paddedRadius = radiusInMeters * 1.01; // 1% safety margin
    final latDelta = paddedRadius / metersPerDegreeLat;
    final cosLat = cos(lat * pi / 180).abs();
    // Near the poles cos() -> 0; fall back to the full longitude range
    final lngDelta = cosLat < 1e-6 ? 180.0 : paddedRadius / (metersPerDegreeLat * cosLat);
    return (
      minLat: lat - latDelta,
      maxLat: lat + latDelta,
      minLng: lng - lngDelta,
      maxLng: lng + lngDelta,
    );
  }

  /// Active, non-expired jobs within [radiusInMeters] of the centre, nearest
  /// first. Uses the same keyword / date / job type / salary rules as the Home
  /// search (see [JobSearchHelper]).
  Future<NearbyJobsResult> getNearbyJobs(
    double centerLat,
    double centerLng,
    double radiusInMeters, {
    String query = '',
    String? jobType,
    String? salary,
    String? datePosted,
  }) async {
    try {
      final keyword = JobSearchHelper.sanitizeKeyword(query);
      final companyIds = await JobSearchHelper.companyIdsMatching(_supabase, keyword);
      final box = boundingBox(centerLat, centerLng, radiusInMeters);

      var request = _supabase
          .from(TableConstants.job)
          .select('*, Company(name)')
          .eq('status', 'active')
          .or(JobSearchHelper.notExpiredAndKeyword(keyword, companyIds))
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .gte('latitude', box.minLat)
          .lte('latitude', box.maxLat)
          .gte('longitude', box.minLng)
          .lte('longitude', box.maxLng);

      if (JobSearchHelper.isJobTypeFilter(jobType)) {
        request = request.eq('jobType', jobType!);
      }
      final since = JobSearchHelper.postedSinceUtc(datePosted);
      if (since != null) {
        request = request.gte('createdAt', since.toIso8601String());
      }

      // The box's corners are outside the circle, so fetch a little extra.
      final rows = await request.order('createdAt', ascending: false).limit(maxResults * 2);

      final nearby = <NearbyJob>[];
      for (final row in rows as List<dynamic>) {
        final job = JobModel.fromJson(row as Map<String, dynamic>);
        if (job.jobID == null || job.latitude == null || job.longitude == null) continue;
        if (job.isExpired) continue;
        if (!SalaryUtils.meetsMinimum(job.salaryRange, salary)) continue;

        final meters = distanceMeters(centerLat, centerLng, job.latitude!, job.longitude!);
        if (meters <= radiusInMeters) {
          nearby.add(NearbyJob(job: job, distanceKm: meters / 1000));
        }
      }

      nearby.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      final capped = nearby.length > maxResults || rows.length == maxResults * 2;
      return NearbyJobsResult(
        jobs: nearby.length > maxResults ? nearby.sublist(0, maxResults) : nearby,
        capped: capped,
      );
    } catch (e) {
      debugPrint('Error fetching nearby jobs: $e');
      throw DataLoadException(
        'Unable to load nearby jobs. Please check your connection and try again.',
      );
    }
  }
}
