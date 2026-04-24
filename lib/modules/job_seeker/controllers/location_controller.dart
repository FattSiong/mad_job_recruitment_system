import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/job_model.dart';
import 'dart:math' show cos, sqrt, asin;

class LocationController {
  final _supabase = Supabase.instance.client;

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p)/2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  /// Fetches jobs filtered by an optional keyword, THEN filters them by radius
  Future<List<JobModel>> getNearbyJobs(double centerLat, double centerLng, double radiusInMeters, {String query = ''}) async {
    try {
      // 1. Build the base query
      var queryBuilder = _supabase
          .from('Job')
          .select('*, Company(name)')
          .eq('status', 'active');

      // 2. If the user typed a keyword, add the text search filter
      if (query.isNotEmpty) {
        queryBuilder = queryBuilder.or('title.ilike.%$query%,description.ilike.%$query%');
      }

      // 3. Execute the query
      final response = await queryBuilder;

      final List<JobModel> allJobs = (response as List<dynamic>).map((item) {
        return JobModel.fromJson(item as Map<String, dynamic>);
      }).toList();

      // 4. Filter the remaining jobs to see if they fall within the circle
      final List<JobModel> nearbyJobs = allJobs.where((job) {
        if (job.latitude == null || job.longitude == null) return false;
        final distance = _calculateDistance(centerLat, centerLng, job.latitude!, job.longitude!);
        return distance <= radiusInMeters;
      }).toList();

      return nearbyJobs;
    } catch (e) {
      print('❌ Error fetching nearby jobs: $e');
      return [];
    }
  }
}