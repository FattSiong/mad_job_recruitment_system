import 'chat_room_model.dart';

/// Order of an admin moderation list (community posts / comments, jobs).
enum ModerationSort {
  /// Reported: newest report first. All: newest first.
  newest('Newest first'),

  /// Reported: waiting longest first. All: oldest first.
  oldest('Oldest first'),

  /// Reported only: reported by the most people first.
  mostReported('Most reported');

  const ModerationSort(this.label);
  final String label;
}

/// One user's report ("ReportedPost", "ReportedComment" or "ReportedJob").
class ContentReport {
  final String reportID;
  final String reporterID;
  final String category;
  final String? details;
  final DateTime reportedAt;

  /// Filled in from UserDirectory.
  final ChatParticipant? reporter;

  const ContentReport({
    required this.reportID,
    required this.reporterID,
    required this.category,
    this.details,
    required this.reportedAt,
    this.reporter,
  });

  /// [idColumn]: 'reportPostID', 'reportCommentID' or 'reportID' (job reports).
  factory ContentReport.fromJson(
    Map<String, dynamic> json, {
    required String idColumn,
    ChatParticipant? reporter,
  }) {
    final details = json['additionalDetails']?.toString().trim();
    return ContentReport(
      reportID: json[idColumn]?.toString() ?? '',
      reporterID: json['reporterID']?.toString() ?? '',
      category: json['reportCategory']?.toString().trim().isNotEmpty == true
          ? json['reportCategory'].toString().trim()
          : 'Other',
      details: (details == null || details.isEmpty) ? null : details,
      reportedAt: DateTime.tryParse(json['reportedAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      reporter: reporter,
    );
  }
}

/// What an item with open reports can tell about them.
mixin ReportSummary {
  /// Open ("pending") reports, newest first.
  List<ContentReport> get reports;

  bool get isReported => reports.isNotEmpty;

  /// How many different people reported it.
  int get reporterCount => reports.map((r) => r.reporterID).toSet().length;

  /// Report reasons with how often each was given, most common first.
  List<MapEntry<String, int>> get categoryCounts {
    final counts = <String, int>{};
    for (final r in reports) {
      counts[r.category] = (counts[r.category] ?? 0) + 1;
    }
    return counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  DateTime? get latestReportAt => reports.isEmpty ? null : reports.first.reportedAt;

  /// When the oldest open report came in (how long it has been waiting).
  DateTime? get firstReportAt => reports.isEmpty ? null : reports.last.reportedAt;

  /// True if [query] (lower case) is in a report's reason, details or
  /// reporter name.
  bool reportsMatch(String query) {
    bool has(String? text) => text != null && text.toLowerCase().contains(query);
    return reports.any((r) => has(r.category) || has(r.details) || has(r.reporter?.displayName));
  }
}

/// Sorts a Reported list in place by [sort] and returns it: newest report,
/// waiting longest, or most people (then most reports, then newest).
List<T> sortByReports<T extends ReportSummary>(List<T> list, ModerationSort sort) {
  final never = DateTime.fromMillisecondsSinceEpoch(0);
  int newestFirst(T a, T b) => (b.latestReportAt ?? never).compareTo(a.latestReportAt ?? never);
  switch (sort) {
    case ModerationSort.newest:
      list.sort(newestFirst);
    case ModerationSort.oldest:
      list.sort((a, b) => (a.firstReportAt ?? never).compareTo(b.firstReportAt ?? never));
    case ModerationSort.mostReported:
      list.sort((a, b) {
        final people = b.reporterCount.compareTo(a.reporterCount);
        if (people != 0) return people;
        final count = b.reports.length.compareTo(a.reports.length);
        return count != 0 ? count : newestFirst(a, b);
      });
  }
  return list;
}
