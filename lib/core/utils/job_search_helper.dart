import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/table_constants.dart';

/// Search rules shared by the Home job list and the job map, so both
/// filter jobs in exactly the same way.
class JobSearchHelper {
  JobSearchHelper._();

  /// Keeps characters that are safe inside a PostgREST filter string
  /// (characters like , ( ) . : would break an "or" filter).
  static String sanitizeKeyword(String input) => input
      .replaceAll(RegExp(r'[^A-Za-z0-9\s+#&/-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Start of the "Date posted" window, in UTC (the database stores UTC;
  /// sending Malaysia time without a zone would shift the window by 8 hours).
  static DateTime? postedSinceUtc(String? datePosted) {
    final now = DateTime.now().toUtc();
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
        return null; // 'All time'
    }
  }

  /// True when [jobType] actually narrows the search.
  static bool isJobTypeFilter(String? jobType) =>
      jobType != null && jobType != 'All' && jobType != 'Any';

  /// IDs of companies whose name contains [keyword], so a keyword search can
  /// also match company names.
  static Future<List<String>> companyIdsMatching(SupabaseClient supabase, String keyword) async {
    if (keyword.isEmpty) return [];
    final rows = await supabase
        .from(TableConstants.company)
        .select('companyID')
        .ilike('name', '%$keyword%')
        .limit(50);
    return (rows as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['companyID'].toString())
        .toList();
  }

  /// One filter for `.or(...)`: not expired AND (keyword in title, description
  /// or company). One nested filter avoids sending two "or" parameters.
  static String notExpiredAndKeyword(String keyword, List<String> companyIds) {
    final expiry =
        'or(expiresAt.is.null,expiresAt.gt.${DateTime.now().toUtc().toIso8601String()})';
    if (keyword.isEmpty) return 'and($expiry)';

    final keywordParts = [
      'title.ilike.%$keyword%',
      'description.ilike.%$keyword%',
      if (companyIds.isNotEmpty) 'companyID.in.(${companyIds.join(',')})',
    ];
    return 'and($expiry,or(${keywordParts.join(',')}))';
  }
}
