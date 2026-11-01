import 'dart:math' as math;

/// One salary-filter rule shared by the Home dashboard and the Job Map.
///
/// The filter is a MINIMUM salary the job seeker wants (e.g. "RM3000" or "RM 3500").
/// A job matches when the highest salary it offers is at least that amount:
///   "3,000 - 4,500" matches RM4000 (4,500 >= 4,000)
///   "15"            matches RM10   (hourly part-time)
/// Jobs without any number in their salary (e.g. "Negotiable") don't match a minimum.
class SalaryUtils {
  SalaryUtils._();

  /// All numbers in a salary text, ignoring thousands separators.
  static List<double> numbers(String text) {
    final clean = text.replaceAll(',', '');
    return RegExp(r'\d+(\.\d+)?')
        .allMatches(clean)
        .map((m) => double.tryParse(m.group(0)!) ?? 0)
        .toList();
  }

  /// The minimum amount from a filter value, or null for "Any"/"All"/empty.
  static double? minimumFromFilter(String? filter) {
    if (filter == null) return null;
    final value = filter.trim();
    if (value.isEmpty || value == 'Any' || value == 'All') return null;
    final nums = numbers(value);
    return nums.isEmpty ? null : nums.first;
  }

  /// True if the job's salary meets the minimum in [filter].
  static bool meetsMinimum(String jobSalaryRange, String? filter) {
    final minimum = minimumFromFilter(filter);
    if (minimum == null) return true; // no salary filter
    final nums = numbers(jobSalaryRange);
    if (nums.isEmpty) return false;
    return nums.reduce(math.max) >= minimum;
  }
}
