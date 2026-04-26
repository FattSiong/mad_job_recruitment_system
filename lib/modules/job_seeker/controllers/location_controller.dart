import 'dart:math' show asin, cos, sqrt;
import 'package:supabase_flutter/supabase_flutter.dart';
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

  List<int> _extractSalaryNumbers(String text) {
    final parts = text
        .split(RegExp(r'[^0-9]'))
        .where((s) => s.isNotEmpty)
        .toList();

    return parts.map((s) => int.tryParse(s) ?? 0).toList();
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

      if (query.isNotEmpty) {
        queryBuilder = queryBuilder.or(
          'title.ilike.%$query%,description.ilike.%$query%',
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

        final distance = _calculateDistance(
          centerLat,
          centerLng,
          job.latitude!,
          job.longitude!,
        );

        final isWithinDistance = distance <= radiusInMeters;

        bool isSalaryMatched = true;
        if (salary != null && salary != 'Any' && salary != 'All') {
          final inputNumbers = _extractSalaryNumbers(salary);

          if (inputNumbers.isNotEmpty) {
            final userInput = inputNumbers.first;
            final jobRange = _extractSalaryNumbers(job.salaryRange);

            if (jobRange.length >= 2) {
              final min = jobRange[0];
              final max = jobRange[1];
              isSalaryMatched = userInput >= min && userInput <= max;
            } else if (jobRange.length == 1) {
              isSalaryMatched = userInput >= jobRange[0];
            }
          }
        }

        return isWithinDistance && isSalaryMatched;
      }).toList();

      return filteredJobs;
    } catch (e) {
      print('Error fetching nearby jobs: $e');
      return [];
    }
  }
}
