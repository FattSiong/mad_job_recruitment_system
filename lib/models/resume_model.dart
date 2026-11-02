import 'education_model.dart';
import 'work_experience_model.dart';

/// Optional resume sections the user can add after the main steps.
enum ResumeSectionType {
  summary('Professional Summary', 'A short introduction about you', isTextOnly: true),
  projects('Projects', 'Things you built or worked on'),
  awards('Awards & Achievements', 'Prizes, scholarships, recognition'),
  certifications('Certifications', 'Courses and professional certificates'),
  languages('Languages', 'Languages you speak and how well'),
  volunteer('Volunteer Experience', 'Community and volunteer work'),
  additional('Additional Information', 'Anything else worth mentioning', isTextOnly: true);

  final String label;
  final String hint;
  final bool isTextOnly; // one paragraph instead of a list of items

  const ResumeSectionType(this.label, this.hint, {this.isTextOnly = false});

  static ResumeSectionType? fromName(String? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

/// One line in an optional section, e.g. a project or an award.
/// Field meaning depends on the section (see ResumeSectionItemSheet).
class ResumeSectionItem {
  final String title;
  final String? subtitle; // issuer, role, proficiency...
  final String? period; // "2025", "Jan 2024 - Mar 2024"
  final String? description;

  const ResumeSectionItem({
    required this.title,
    this.subtitle,
    this.period,
    this.description,
  });

  factory ResumeSectionItem.fromJson(Map<String, dynamic> json) => ResumeSectionItem(
        title: (json['title'] ?? '').toString(),
        subtitle: json['subtitle'] as String?,
        period: json['period'] as String?,
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        if (subtitle != null && subtitle!.isNotEmpty) 'subtitle': subtitle,
        if (period != null && period!.isNotEmpty) 'period': period,
        if (description != null && description!.isNotEmpty) 'description': description,
      };
}

class ResumeSection {
  final ResumeSectionType type;
  final List<ResumeSectionItem> items;
  final String text; // for text-only sections (summary, additional information)

  const ResumeSection({required this.type, this.items = const [], this.text = ''});

  bool get isEmpty => type.isTextOnly ? text.trim().isEmpty : items.isEmpty;

  ResumeSection copyWith({List<ResumeSectionItem>? items, String? text}) =>
      ResumeSection(type: type, items: items ?? this.items, text: text ?? this.text);

  static ResumeSection? fromJson(Map<String, dynamic> json) {
    final type = ResumeSectionType.fromName(json['type'] as String?);
    if (type == null) return null;
    return ResumeSection(
      type: type,
      text: (json['text'] ?? '').toString(),
      items: ((json['items'] as List?) ?? const [])
          .map((e) => ResumeSectionItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (type.isTextOnly) 'text': text,
        if (!type.isTextOnly) 'items': items.map((e) => e.toJson()).toList(),
      };
}

class ResumeSkill {
  final String name;
  final String? level; // Beginner / Intermediate / Advanced

  const ResumeSkill(this.name, [this.level]);

  factory ResumeSkill.fromJson(Map<String, dynamic> json) =>
      ResumeSkill((json['name'] ?? '').toString(), json['level'] as String?);

  Map<String, dynamic> toJson() => {'name': name, if (level != null) 'level': level};
}

/// The whole resume. Stored as one JSON document ("Resume"."content"), so it is
/// a separate copy: editing it never changes the profile.
class ResumeModel {
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final List<EducationModel> education;
  final List<WorkExperienceModel> experience;
  final List<ResumeSkill> skills;
  final List<ResumeSection> sections;
  final DateTime? updatedAt;

  const ResumeModel({
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.education = const [],
    this.experience = const [],
    this.skills = const [],
    this.sections = const [],
    this.updatedAt,
  });

  ResumeModel copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? address,
    List<EducationModel>? education,
    List<WorkExperienceModel>? experience,
    List<ResumeSkill>? skills,
    List<ResumeSection>? sections,
  }) {
    return ResumeModel(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      education: education ?? this.education,
      experience: experience ?? this.experience,
      skills: skills ?? this.skills,
      sections: sections ?? this.sections,
      updatedAt: updatedAt,
    );
  }

  factory ResumeModel.fromJson(Map<String, dynamic> json, {DateTime? updatedAt}) {
    List<Map<String, dynamic>> list(String key) => ((json[key] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return ResumeModel(
      fullName: (json['fullName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      education: list('education').map(EducationModel.fromJson).toList(),
      experience: list('experience').map((e) {
        // The resume copy has no seekerID; the model requires one.
        return WorkExperienceModel.fromJson({'seekerID': '', ...e});
      }).toList(),
      skills: list('skills').map(ResumeSkill.fromJson).where((s) => s.name.isNotEmpty).toList(),
      sections: list('sections').map(ResumeSection.fromJson).whereType<ResumeSection>().toList(),
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> strip(Map<String, dynamic> m) =>
        Map.of(m)..remove('seekerID'); // not needed inside the resume copy

    return {
      'version': 1,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'address': address,
      'education': education.map((e) => strip(e.toJson())).toList(),
      'experience': experience.map((e) => strip(e.toJson())).toList(),
      'skills': skills.map((s) => s.toJson()).toList(),
      'sections': sections.map((s) => s.toJson()).toList(),
    };
  }
}
