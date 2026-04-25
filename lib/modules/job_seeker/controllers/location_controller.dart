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

  /// Helper to extract numbers from a string (e.g., "RM 8,000 - 12,000" -> [8000, 12000])
  List<int> _extractSalaryNumbers(String text) {
    // Directly split the original text by any non-digit character
    final parts = text.split(RegExp(r'[^0-9]')).where((s) => s.isNotEmpty).toList();
    return parts.map((s) => int.tryParse(s) ?? 0).toList();
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
          .eq('status', 'active');

      if (query.isNotEmpty) {
        queryBuilder = queryBuilder.or('title.ilike.%$query%,description.ilike.%$query%');
      }

      if (jobType != null && jobType != 'All' && jobType != 'Any') {
        queryBuilder = queryBuilder.eq('jobType', jobType);
      }

      // We remove the queryBuilder.ilike for salary here because text matching
      // cannot handle "between" logic. We will filter it locally below.

      if (datePosted != null && datePosted != 'All time') {
        // ... (Keep existing date filtering logic)
      }

      final response = await queryBuilder;

      final List<JobModel> allJobs = (response as List<dynamic>).map((item) {
        return JobModel.fromJson(item as Map<String, dynamic>);
      }).toList();

      final List<JobModel> filteredJobs = allJobs.where((job) {
        // 1. Distance Filter
        bool isWithinDistance = true;
        if (job.latitude != null && job.longitude != null) {
          final double distance = _calculateDistance(centerLat, centerLng, job.latitude!, job.longitude!);
          isWithinDistance = distance <= radiusInMeters;
        }

        // 2. Mathematical Salary Range Filter
        bool isSalaryMatched = true;
        if (salary != null && salary != 'Any' && salary != 'All') {
          // Extract the number the user input (e.g., "RM 10000" -> 10000)
          final inputNumbers = _extractSalaryNumbers(salary);
          if (inputNumbers.isNotEmpty) {
            int userInput = inputNumbers.first;

            // Extract the range from the job (e.g., "8000 - 12000" -> [8000, 12000])
            final jobRange = _extractSalaryNumbers(job.salaryRange);

            if (jobRange.length >= 2) {
              int min = jobRange[0];
              int max = jobRange[1];
              // Check if input is between min and max
              isSalaryMatched = (userInput >= min && userInput <= max);
            } else if (jobRange.length == 1) {
              // If only one number exists, treat it as a minimum requirement
              isSalaryMatched = (userInput >= jobRange[0]);
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