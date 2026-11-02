class PostInterviewReportException implements Exception {
  final String code;
  final String message;

  const PostInterviewReportException(this.code, this.message);

  @override
  String toString() => message;
}

class InterviewQaExchange {
  final int questionIndex;
  final String questionAsked;
  final String candidateResponseSummary;
  final int score;
  final String evaluationNote;

  const InterviewQaExchange({
    required this.questionIndex,
    required this.questionAsked,
    required this.candidateResponseSummary,
    required this.score,
    required this.evaluationNote,
  });

  factory InterviewQaExchange.fromJson(Map<String, dynamic> json, [int fallbackIndex = 1]) {
    final rawScore = (json['score'] as num?)?.round() ?? 0;
    return InterviewQaExchange(
      questionIndex: (json['questionIndex'] as num?)?.toInt() ?? fallbackIndex,
      questionAsked: (json['questionAsked'] ?? '').toString().trim(),
      candidateResponseSummary:
          (json['candidateResponseSummary'] ?? '').toString().trim(),
      score: rawScore.clamp(0, 100),
      evaluationNote: (json['evaluationNote'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'questionIndex': questionIndex,
        'questionAsked': questionAsked,
        'candidateResponseSummary': candidateResponseSummary,
        'score': score,
        'evaluationNote': evaluationNote,
      };
}

class PostInterviewReportModel {
  final String reportID;
  final String scheduleID;
  final String applicantID;
  final String? roomID;
  final String employerID;
  final int durationSeconds;
  final int overallScore;
  final int contentScore;
  final int deliveryScore;
  final String recommendation;
  final String transcriptText;
  final Map<String, dynamic> aiReportData;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Enriched metadata (from joined tables or snapshot stored in aiReportData['metadata'])
  final String jobTitle;
  final String companyName;
  final String? companyLogoUrl;
  final String candidateName;
  final String candidateEmail;
  final String candidatePhone;
  final String? candidatePhotoUrl;
  final DateTime? interviewDate;
  final int? resumeAiMatchScore;

  const PostInterviewReportModel({
    required this.reportID,
    required this.scheduleID,
    required this.applicantID,
    this.roomID,
    required this.employerID,
    required this.durationSeconds,
    required this.overallScore,
    required this.contentScore,
    required this.deliveryScore,
    required this.recommendation,
    required this.transcriptText,
    required this.aiReportData,
    required this.createdAt,
    required this.updatedAt,
    required this.jobTitle,
    required this.companyName,
    this.companyLogoUrl,
    required this.candidateName,
    required this.candidateEmail,
    required this.candidatePhone,
    this.candidatePhotoUrl,
    this.interviewDate,
    this.resumeAiMatchScore,
  });

  String get shortReportCode {
    final cleaned = reportID.replaceAll('-', '').toUpperCase();
    return cleaned.length >= 8 ? 'RPT-${cleaned.substring(0, 8)}' : 'RPT-$cleaned';
  }

  String get formattedDuration {
    if (durationSeconds <= 0) return 'Under 1 min';
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    if (mins == 0) return '${secs}s';
    if (secs == 0) return '${mins}m';
    return '${mins}m ${secs}s';
  }

  String get summary => (aiReportData['summary'] ?? '').toString().trim();

  List<String> get strengths => _stringList(aiReportData['strengths']);

  List<String> get concerns => _stringList(aiReportData['concerns']);

  List<String> get followUpQuestions =>
      _stringList(aiReportData['followUpQuestions']);

  Map<String, dynamic> get communication =>
      (aiReportData['communication'] as Map<String, dynamic>?) ?? const {};

  int get estimatedWpm =>
      (communication['estimatedWpm'] as num?)?.round() ?? 0;

  String get paceLabel =>
      (communication['paceLabel'] ?? 'Not measured').toString().trim();

  String get fillerAssessment =>
      (communication['fillerAssessment'] ?? 'Minimal').toString().trim();

  String get clarityAssessment =>
      (communication['clarityAssessment'] ?? 'Clear').toString().trim();

  String get confidenceAssessment =>
      (communication['confidenceAssessment'] ?? 'Steady').toString().trim();

  String get deliveryNotes =>
      (communication['deliveryNotes'] ?? '').toString().trim();

  List<InterviewQaExchange> get qaBreakdown {
    final raw = aiReportData['qaBreakdown'];
    if (raw is! List) return const [];
    final items = <InterviewQaExchange>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is Map<String, dynamic>) {
        items.add(InterviewQaExchange.fromJson(item, i + 1));
      } else if (item is Map) {
        items.add(
          InterviewQaExchange.fromJson(Map<String, dynamic>.from(item), i + 1),
        );
      }
    }
    return items;
  }

  factory PostInterviewReportModel.fromJson(Map<String, dynamic> json) {
    final rawReportData = json['aiReportData'];
    final Map<String, dynamic> reportData = rawReportData is Map<String, dynamic>
        ? rawReportData
        : (rawReportData is Map
            ? Map<String, dynamic>.from(rawReportData)
            : <String, dynamic>{});

    final Map<String, dynamic> meta =
        (reportData['metadata'] is Map)
            ? Map<String, dynamic>.from(reportData['metadata'] as Map)
            : <String, dynamic>{};

    // Extract joined relations if included in SELECT
    final Map<String, dynamic> schedule =
        (json['InterviewSchedule'] is Map)
            ? Map<String, dynamic>.from(json['InterviewSchedule'] as Map)
            : <String, dynamic>{};

    final Map<String, dynamic> applicant =
        (json['JobApplicant'] is Map)
            ? Map<String, dynamic>.from(json['JobApplicant'] as Map)
            : ((schedule['JobApplicant'] is Map)
                ? Map<String, dynamic>.from(schedule['JobApplicant'] as Map)
                : <String, dynamic>{});

    final Map<String, dynamic> seeker =
        (applicant['JobSeeker'] is Map)
            ? Map<String, dynamic>.from(applicant['JobSeeker'] as Map)
            : <String, dynamic>{};

    final Map<String, dynamic> job =
        (applicant['Job'] is Map)
            ? Map<String, dynamic>.from(applicant['Job'] as Map)
            : <String, dynamic>{};

    final Map<String, dynamic> company =
        (job['Company'] is Map)
            ? Map<String, dynamic>.from(job['Company'] as Map)
            : <String, dynamic>{};

    String pickStr(List<dynamic> candidates, String fallback) {
      for (final c in candidates) {
        final s = (c ?? '').toString().trim();
        if (s.isNotEmpty) return s;
      }
      return fallback;
    }

    String? pickNullableStr(List<dynamic> candidates) {
      for (final c in candidates) {
        final s = (c ?? '').toString().trim();
        if (s.isNotEmpty) return s;
      }
      return null;
    }

    final rawDateStr = pickNullableStr([schedule['date'], meta['interviewDate']]);
    final DateTime? parsedInterviewDate =
        rawDateStr != null ? DateTime.tryParse(rawDateStr) : null;

    final num? rawMatchScore = (applicant['aiRankingScore'] as num?) ??
        (meta['resumeAiMatchScore'] as num?);

    return PostInterviewReportModel(
      reportID: (json['reportID'] ?? '').toString(),
      scheduleID: (json['scheduleID'] ?? '').toString(),
      applicantID: (json['applicantID'] ?? '').toString(),
      roomID: json['roomID']?.toString(),
      employerID: (json['employerID'] ?? '').toString(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      overallScore: ((json['overallScore'] as num?)?.round() ?? 0).clamp(0, 100),
      contentScore: ((json['contentScore'] as num?)?.round() ?? 0).clamp(0, 100),
      deliveryScore: ((json['deliveryScore'] as num?)?.round() ?? 0).clamp(0, 100),
      recommendation: pickStr([json['recommendation']], 'Consider'),
      transcriptText: (json['transcriptText'] ?? '').toString(),
      aiReportData: reportData,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
      jobTitle: pickStr([job['title'], meta['jobTitle']], 'Applied Position'),
      companyName: pickStr([company['name'], meta['companyName']], 'Employer'),
      companyLogoUrl:
          pickNullableStr([company['companyLogoURL'], meta['companyLogoUrl']]),
      candidateName:
          pickStr([seeker['fullName'], meta['candidateName']], 'Candidate'),
      candidateEmail: pickStr([seeker['email'], meta['candidateEmail']], ''),
      candidatePhone:
          pickStr([seeker['phoneNumber'], meta['candidatePhone']], ''),
      candidatePhotoUrl: pickNullableStr(
        [seeker['profilePictureURL'], meta['candidatePhotoUrl']],
      ),
      interviewDate: parsedInterviewDate,
      resumeAiMatchScore: rawMatchScore?.round(),
    );
  }
}

List<String> _stringList(dynamic value) =>
    value is List
        ? value
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : const [];
