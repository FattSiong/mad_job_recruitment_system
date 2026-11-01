import 'dart:math' show asin, cos, sqrt, pi;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/salary_utils.dart';
import '../../../models/job_model.dart';

class LocationController {
  final _supabase = Supabase.instance.client;

  double _calculateDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const p = 0.017453292519943295;
    final c = cos;
    final a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;

    return 12742 * asin(sqrt(a)) * 1000;
  }

  /// Smallest latitude/longitude box that contains the search circle, so the
  /// database only returns jobs near the map centre (exact distance is still
  /// checked afterwards with [_calculateDistance]).
  ({double minLat, double maxLat, double minLng, double maxLng}) _boundingBox(
    double lat,
    double lng,
    double radiusInMeters,
  ) {
    // Same Earth radius as _calculateDistance (6371 km), plus a 1% safety margin
    const metersPerDegreeLat = 6371000 * pi / 180;
    final paddedRadius = radiusInMeters * 1.01;
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

  DateTime? _getFilterDate(String? datePosted) {
    if (datePosted == null || datePosted == 'All time') {
      return null;
    }

    final now = DateTime.now();

    switch (datePosted) {
      case 'Last 24 hours':
        return now.subtract(const Duration(hours: 24));
      case 'Last 3 days':
        return now.subtract(const Duration(days: 3));
      case 'Last 7 days':
        return now.subtract(const Duration(days: 7));
      case 'Last 14 days':
        return now.subtract(const Duration(days: 14));
      default:
        return null;
    }
  }

  Future<List<JobModel>> getNearbyJobs(
      double centerLat,
      double centerLng,
      double radiusInMeters, {
        String query = '',
        String? jobType,
        String? salary,
        String? datePosted,
      }) async {
    try {
      var queryBuilder = _supabase
          .from('Job')
          .select('*, Company(name)')
          .eq('status', 'active')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      // Only fetch jobs inside the search area (was: every job in the database)
      final box = _boundingBox(centerLat, centerLng, radiusInMeters);
      queryBuilder = queryBuilder
          .gte('latitude', box.minLat)
          .lte('latitude', box.maxLat)
          .gte('longitude', box.minLng)
          .lte('longitude', box.maxLng);

      // Characters like , ( ) . : would break the PostgREST "or" filter, so keep
      // only letters, numbers, spaces and a few safe symbols (fix #5).
      final safeQuery = query
          .replaceAll(RegExp(r'[^A-Za-z0-9\s+#&/-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (safeQuery.isNotEmpty) {
        queryBuilder = queryBuilder.or(
          'title.ilike.%$safeQuery%,description.ilike.%$safeQuery%',
        );
      }

      if (jobType != null && jobType != 'All' && jobType != 'Any') {
        queryBuilder = queryBuilder.eq('jobType', jobType);
      }

      final filterDate = _getFilterDate(datePosted);
      if (filterDate != null) {
        queryBuilder = queryBuilder.gte(
          'createdAt',
          filterDate.toIso8601String(),
        );
      }

      final response = await queryBuilder.order('createdAt', ascending: false);

      final allJobs = (response as List<dynamic>)
          .map((item) => JobModel.fromJson(item as Map<String, dynamic>))
          .toList();

      final filteredJobs = allJobs.where((job) {
        if (job.latitude == null || job.longitude == null) {
          return false;
        }

        // Hide jobs past their expiry date (fix #6)
        if (job.isExpired) {
          return false;
        }

        final distance = _calculateDistance(
          centerLat,
          centerLng,
          job.latitude!,
          job.longitude!,
        );

        final isWithinDistance = distance <= radiusInMeters;

        // Same minimum-salary rule as the Home dashboard (see SalaryUtils)
        final isSalaryMatched = SalaryUtils.meetsMinimum(job.salaryRange, salary);

        return isWithinDistance && isSalaryMatched;
      }).toList();

      return filteredJobs;
    } catch (e) {
      debugPrint('Error fetching nearby jobs: $e');
      throw DataLoadException(
        'Unable to load nearby jobs. Please check your connection and try again.',
      );
    }
  }
}
