/// The non-empty strings in a JSON list ([] if [v] isn't a list).
List<String> _strings(dynamic v) =>
    v is List ? v.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList() : const [];

/// The objects in a JSON list ([] if [v] isn't a list).
List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : const [];

/// Which resume was reviewed.
enum ResumeReviewSource {
  uploaded('Uploaded resume'),
  builder('Resume built in app');

  final String label;
  const ResumeReviewSource(this.label);

  /// Reads the stored source name ('uploaded' when missing or unknown).
  static ResumeReviewSource fromName(String? name) =>
      name == 'builder' ? ResumeReviewSource.builder : ResumeReviewSource.uploaded;
}

/// Score for one area, e.g. "Impact & Achievements".
class ReviewCategoryScore {
  final String key; // content | impact | keywords | structure | writing
  final String label;
  final int score;
  final String comment;

  ReviewCategoryScore({
    required this.key,
    required this.label,
    required this.score,
    required this.comment,
  });

  factory ReviewCategoryScore.fromJson(Map<String, dynamic> json) => ReviewCategoryScore(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        score: (json['score'] as num?)?.round() ?? 0,
        comment: json['comment'] as String? ?? '',
      );
}

/// One suggested change, optionally with a before/after rewrite.
class ResumeImprovement {
  final String priority; // high | medium | low
  final String section;
  final String issue;
  final String suggestion;
  final String before;
  final String after;

  ResumeImprovement({
    required this.priority,
    required this.section,
    required this.issue,
    required this.suggestion,
    required this.before,
    required this.after,
  });

  bool get hasRewrite => before.trim().isNotEmpty && after.trim().isNotEmpty;

  factory ResumeImprovement.fromJson(Map<String, dynamic> json) => ResumeImprovement(
        priority: json['priority'] as String? ?? 'medium',
        section: json['section'] as String? ?? 'Overall',
        issue: json['issue'] as String? ?? '',
        suggestion: json['suggestion'] as String? ?? '',
        before: json['before'] as String? ?? '',
        after: json['after'] as String? ?? '',
      );
}

/// Row of ResumeReviewRecord.
class ResumeReviewModel {
  final String reviewID;
  final String seekerID;
  final ResumeReviewSource source;
  final String resumeName;
  final String? targetJobRole;
  final int overallScore;
  final DateTime createdAt;

  final String scoreLabel;
  final String verdict;
  final String summary;
  final String detectedRole;
  final List<ReviewCategoryScore> categories;
  final List<String> strengths;
  final List<ResumeImprovement> improvements;
  final List<String> missingSections;
  final List<String> keywordSuggestions;
  final List<String> formattingNotes;
  final int jobSampleSize;

  ResumeReviewModel({
    required this.reviewID,
    required this.seekerID,
    required this.source,
    required this.resumeName,
    required this.targetJobRole,
    required this.overallScore,
    required this.createdAt,
    required this.scoreLabel,
    required this.verdict,
    required this.summary,
    required this.detectedRole,
    required this.categories,
    required this.strengths,
    required this.improvements,
    required this.missingSections,
    required this.keywordSuggestions,
    required this.formattingNotes,
    required this.jobSampleSize,
  });

  /// "Junior Data Analyst" if the user gave one, otherwise what the AI detected.
  String get roleLabel {
    final role = targetJobRole?.trim() ?? '';
    if (role.isNotEmpty) return role;
    return detectedRole.trim().isNotEmpty ? detectedRole : 'General review';
  }

  int get highPriorityCount => improvements.where((i) => i.priority == 'high').length;

  factory ResumeReviewModel.fromJson(Map<String, dynamic> json) {
    final f = (json['feedback'] as Map?)?.cast<String, dynamic>() ?? const {};
    final score = (json['overallScore'] as num?)?.round() ?? 0;
    final role = (json['targetJobRole'] as String?)?.trim();

    return ResumeReviewModel(
      reviewID: json['reviewID'] as String,
      seekerID: json['seekerID'] as String,
      source: ResumeReviewSource.fromName(json['source'] as String?),
      resumeName: json['resumeName'] as String? ?? '',
      targetJobRole: role == null || role.isEmpty ? null : role,
      overallScore: score,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      scoreLabel: f['scoreLabel'] as String? ?? labelFor(score),
      verdict: f['verdict'] as String? ?? '',
      summary: f['summary'] as String? ?? '',
      detectedRole: f['detectedRole'] as String? ?? '',
      categories: _maps(f['categories']).map(ReviewCategoryScore.fromJson).toList(),
      strengths: _strings(f['strengths']),
      improvements: _maps(f['improvements']).map(ResumeImprovement.fromJson).toList(),
      missingSections: _strings(f['missingSections']),
      keywordSuggestions: _strings(f['keywordSuggestions']),
      formattingNotes: _strings(f['formattingNotes']),
      jobSampleSize: (f['jobSampleSize'] as num?)?.round() ?? 0,
    );
  }

  /// Same bands as the Edge Function.
  static String labelFor(int score) {
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Fair';
    return 'Needs work';
  }
}

/// The resumes the user can choose from (shown before reviewing).
class ResumeReviewSources {
  final String? uploadedURL;
  final bool hasBuiltResume;
  final DateTime? builtResumeUpdatedAt;

  ResumeReviewSources({
    this.uploadedURL,
    required this.hasBuiltResume,
    this.builtResumeUpdatedAt,
  });

  bool get hasUploaded => uploadedURL != null && uploadedURL!.trim().isNotEmpty;

  String get uploadedFileName {
    if (!hasUploaded) return '';
    final last = Uri.decodeComponent(uploadedURL!.split('?').first.split('/').last);
    // Uploaded files are named "<timestamp>_<original name>"
    final i = last.indexOf('_');
    return i > 0 && int.tryParse(last.substring(0, i)) != null ? last.substring(i + 1) : last;
  }

  bool get uploadedReadable {
    final name = uploadedFileName.toLowerCase();
    return name.endsWith('.pdf') || name.endsWith('.docx');
  }

  /// True if [source] can be reviewed now (an uploaded file must also be readable).
  bool isAvailable(ResumeReviewSource source) => switch (source) {
        ResumeReviewSource.uploaded => hasUploaded && uploadedReadable,
        ResumeReviewSource.builder => hasBuiltResume,
      };
}
