List<String> _strings(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : const [];

/// A skill the applicant already has (from profile / resume / experience / education).
class DetectedSkill {
  final String skill;
  final String source;

  DetectedSkill({required this.skill, required this.source});

  factory DetectedSkill.fromJson(Map<String, dynamic> json) => DetectedSkill(
        skill: json['skill'] as String? ?? '',
        source: json['source'] as String? ?? '',
      );
}

/// A skill the market requires, compared with the applicant.
class RequiredSkillItem {
  final String skill;
  final String category;   // technical | tool | soft | domain | certification
  final String importance; // high | medium | low
  final String status;     // matched | partial | missing
  final String evidence;
  final String gap;

  RequiredSkillItem({
    required this.skill,
    required this.category,
    required this.importance,
    required this.status,
    required this.evidence,
    required this.gap,
  });

  factory RequiredSkillItem.fromJson(Map<String, dynamic> json) => RequiredSkillItem(
        skill: json['skill'] as String? ?? '',
        category: json['category'] as String? ?? '',
        importance: json['importance'] as String? ?? 'medium',
        status: json['status'] as String? ?? 'missing',
        evidence: json['evidence'] as String? ?? '',
        gap: json['gap'] as String? ?? '',
      );
}

/// One recommended action path.
class ActionPath {
  final String title;
  final String type; // course | certification | project | experience | networking | resume
  final String priority;
  final String timeframe;
  final List<String> skillsAddressed;
  final List<String> steps;
  final List<String> suggestedResources;

  ActionPath({
    required this.title,
    required this.type,
    required this.priority,
    required this.timeframe,
    required this.skillsAddressed,
    required this.steps,
    required this.suggestedResources,
  });

  factory ActionPath.fromJson(Map<String, dynamic> json) => ActionPath(
        title: json['title'] as String? ?? '',
        type: json['type'] as String? ?? '',
        priority: json['priority'] as String? ?? 'medium',
        timeframe: json['timeframe'] as String? ?? '',
        skillsAddressed: _strings(json['skillsAddressed']),
        steps: _strings(json['steps']),
        suggestedResources: _strings(json['suggestedResources']),
      );
}

class MarketInsights {
  final String demandLevel; // High | Medium | Low
  final String summary;
  final String typicalSalary;
  final List<String> commonRequirements;

  MarketInsights({
    required this.demandLevel,
    required this.summary,
    required this.typicalSalary,
    required this.commonRequirements,
  });

  factory MarketInsights.fromJson(Map<String, dynamic>? json) => MarketInsights(
        demandLevel: json?['demandLevel'] as String? ?? '',
        summary: json?['summary'] as String? ?? '',
        typicalSalary: json?['typicalSalary'] as String? ?? '',
        commonRequirements: _strings(json?['commonRequirements']),
      );
}

/// Row of SkillGapAnalysisRecord.
class SkillGapAnalysisModel {
  final String analysisID;
  final String seekerID;
  final String targetJobRole;
  final int matchScore;
  final int jobSampleSize;
  final DateTime createdAt;

  final List<DetectedSkill> userSkills;
  final List<RequiredSkillItem> requiredSkills;
  final List<RequiredSkillItem> matching;
  final List<RequiredSkillItem> partial;
  final List<RequiredSkillItem> missing;

  final String summary;
  final MarketInsights marketInsights;
  final List<ActionPath> actionPaths;
  final List<String> resumeTips;
  final bool resumeAnalysed;
  final String resumeNote;

  SkillGapAnalysisModel({
    required this.analysisID,
    required this.seekerID,
    required this.targetJobRole,
    required this.matchScore,
    required this.jobSampleSize,
    required this.createdAt,
    required this.userSkills,
    required this.requiredSkills,
    required this.matching,
    required this.partial,
    required this.missing,
    required this.summary,
    required this.marketInsights,
    required this.actionPaths,
    required this.resumeTips,
    required this.resumeAnalysed,
    required this.resumeNote,
  });

  factory SkillGapAnalysisModel.fromJson(Map<String, dynamic> json) {
    final gaps = (json['identifiedGaps'] as Map?)?.cast<String, dynamic>() ?? const {};
    final advice = (json['aiAdvice'] as Map?)?.cast<String, dynamic>() ?? const {};
    List<RequiredSkillItem> items(dynamic v) =>
        _maps(v).map(RequiredSkillItem.fromJson).toList();

    return SkillGapAnalysisModel(
      analysisID: json['analysisID'] as String,
      seekerID: json['seekerID'] as String,
      targetJobRole: json['targetJobRole'] as String? ?? '',
      matchScore: (json['matchScore'] as num?)?.round() ?? 0,
      jobSampleSize: (json['jobSampleSize'] as num?)?.round() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      userSkills: _maps(json['userSkills']).map(DetectedSkill.fromJson).toList(),
      requiredSkills: items(json['marketRequiredSkills']),
      matching: items(gaps['matching']),
      partial: items(gaps['partial']),
      missing: items(gaps['missing']),
      summary: advice['summary'] as String? ?? '',
      marketInsights: MarketInsights.fromJson(
        (advice['marketInsights'] as Map?)?.cast<String, dynamic>(),
      ),
      actionPaths: _maps(advice['actionPaths']).map(ActionPath.fromJson).toList(),
      resumeTips: _strings(advice['resumeTips']),
      resumeAnalysed: advice['resumeAnalysed'] as bool? ?? false,
      resumeNote: advice['resumeNote'] as String? ?? '',
    );
  }
}

/// What the analysis will be based on (shown before running it).
class SkillGapReadiness {
  final int skillCount;
  final int educationCount;
  final int experienceCount;
  final String? resumeURL;

  SkillGapReadiness({
    required this.skillCount,
    required this.educationCount,
    required this.experienceCount,
    this.resumeURL,
  });

  bool get hasResume => resumeURL != null && resumeURL!.trim().isNotEmpty;

  String get resumeFileName {
    if (!hasResume) return '';
    final last = Uri.decodeComponent(resumeURL!.split('?').first.split('/').last);
    // Uploaded files are named "<timestamp>_<original name>"
    final i = last.indexOf('_');
    return i > 0 && int.tryParse(last.substring(0, i)) != null ? last.substring(i + 1) : last;
  }

  bool get resumeReadable {
    final name = resumeFileName.toLowerCase();
    return name.endsWith('.pdf') || name.endsWith('.docx');
  }

  /// Use case A1: there must be something to analyse.
  bool get canAnalyse =>
      skillCount > 0 || educationCount > 0 || experienceCount > 0 || (hasResume && resumeReadable);
}
