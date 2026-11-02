import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';

/// What is being reported.
enum ReportTarget { post, comment }

/// Sends a report on a community post or comment to the admins
/// ("ReportedPost" / "ReportedComment", reviewed in Admin > Community).
class ContentReportController {
  final _supabase = Supabase.instance.client;

  static const List<String> categories = [
    'Spam',
    'Inappropriate Content',
    'Harassment',
    'False Information',
    'Other',
  ];

  static const int maxDetailsLength = 500;

  /// Returns an error message, or null when the report was sent.
  Future<String?> submit({
    required ReportTarget target,
    required String targetID,
    required String reporterID,
    required String category,
    String? details,
  }) async {
    final table = target == ReportTarget.post
        ? TableConstants.reportedPost
        : TableConstants.reportedComment;
    final idColumn = target == ReportTarget.post ? 'postID' : 'commentID';
    final extra = details?.trim() ?? '';

    if (category == 'Other' && extra.isEmpty) {
      return 'Please describe the problem.';
    }

    // One open report per person per item.
    try {
      final existing = await _supabase
          .from(table)
          .select(idColumn)
          .eq(idColumn, targetID)
          .eq('reporterID', reporterID)
          .eq('status', 'pending')
          .limit(1);
      if ((existing as List).isNotEmpty) {
        return 'You have already reported this. Our team will review it soon.';
      }
    } catch (e) {
      debugPrint('Report duplicate check skipped: $e'); // e.g. no read access
    }

    try {
      await _supabase.from(table).insert({
        idColumn: targetID,
        'reporterID': reporterID,
        'reportCategory': category,
        'additionalDetails': extra.isEmpty ? null : extra,
        'status': 'pending',
      });
      return null;
    } catch (e) {
      debugPrint('Report failed: $e');
      return 'Unable to send your report. Please try again.';
    }
  }
}
