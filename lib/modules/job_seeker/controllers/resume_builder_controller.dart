import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../core/utils/data_load_exception.dart';
import '../../../core/utils/resume_pdf_builder.dart';
import '../../../core/utils/session_helper.dart';
import '../../../models/education_model.dart';
import '../../../models/resume_model.dart';
import '../../../models/skill_model.dart';
import '../../../models/work_experience_model.dart';
import 'profile_controller.dart';
import 'skill_controller.dart';

/// Data for the in-app resume builder.
///
/// The resume is saved as a separate copy ("Resume" table): it is pre-filled
/// from the profile the first time, but edits here never change the profile.
class ResumeBuilderController extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final ProfileController _profileController = ProfileController();
  final SkillController _skillController = SkillController();

  ResumeModel _resume = const ResumeModel();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  bool _prefilledFromProfile = false;
  String? _error;
  bool _disposed = false;

  ResumeModel get resume => _resume;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get prefilledFromProfile => _prefilledFromProfile;
  String? get error => _error;

  // ---------------------------------------------------------------------
  // Load / save
  // ---------------------------------------------------------------------

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final userId = SessionHelper.requireUserId();
      final row = await _supabase
          .from(TableConstants.resume)
          .select('content, updatedAt')
          .eq('seekerID', userId)
          .maybeSingle();

      if (row != null) {
        _resume = ResumeModel.fromJson(
          Map<String, dynamic>.from(row['content'] as Map),
          updatedAt: DateTime.tryParse(row['updatedAt']?.toString() ?? ''),
        );
        _prefilledFromProfile = false;
      } else {
        _resume = await _fromProfile();
        _prefilledFromProfile = true;
        _hasUnsavedChanges = true;
      }
    } catch (e) {
      debugPrint('Error loading resume: $e');
      _error = e is DataLoadException
          ? e.message
          : 'Unable to load your resume. Please check your connection and try again.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// First-time resume: copy what the profile already has.
  Future<ResumeModel> _fromProfile() async {
    final profile = await _profileController.fetchProfile();
    var skills = <SkillModel>[];
    try {
      skills = await _skillController.fetchMySkills();
    } catch (_) {
      // Skills are optional here; the user can add them in the Skills step.
    }

    return ResumeModel(
      fullName: profile?.fullName ?? '',
      email: profile?.email ?? '',
      phone: profile?.phoneNumber ?? '',
      address: profile?.location ?? '',
      education: [...?profile?.education]..sort(_newestEducationFirst),
      experience: [...?profile?.workExperience]..sort(_newestExperienceFirst),
      skills: skills.map((s) => ResumeSkill(s.skillName, s.proficiency)).toList(),
    );
  }

  /// Saves the resume copy. Returns false (and keeps the changes) on failure.
  Future<bool> save() async {
    if (!_hasUnsavedChanges) return true;
    _isSaving = true;
    _notify();
    try {
      await _supabase.from(TableConstants.resume).upsert({
        'seekerID': SessionHelper.requireUserId(),
        'content': _resume.toJson(),
      });
      _hasUnsavedChanges = false;
      return true;
    } catch (e) {
      debugPrint('Error saving resume: $e');
      return false;
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  void _update(ResumeModel next) {
    _resume = next;
    _hasUnsavedChanges = true;
    _notify();
  }

  // ---------------------------------------------------------------------
  // Steps
  // ---------------------------------------------------------------------

  void setName(String value) => _update(_resume.copyWith(fullName: value.trim()));
  void setEmail(String value) => _update(_resume.copyWith(email: value.trim()));
  void setPhone(String value) => _update(_resume.copyWith(phone: value.trim()));
  void setAddress(String value) => _update(_resume.copyWith(address: value.trim()));

  void addEducation(EducationModel e) =>
      _update(_resume.copyWith(education: [..._resume.education, e]..sort(_newestEducationFirst)));

  void replaceEducation(int index, EducationModel e) {
    final list = [..._resume.education]..[index] = e;
    _update(_resume.copyWith(education: list..sort(_newestEducationFirst)));
  }

  void removeEducation(int index) =>
      _update(_resume.copyWith(education: [..._resume.education]..removeAt(index)));

  void addExperience(WorkExperienceModel e) =>
      _update(_resume.copyWith(experience: [..._resume.experience, e]..sort(_newestExperienceFirst)));

  void replaceExperience(int index, WorkExperienceModel e) {
    final list = [..._resume.experience]..[index] = e;
    _update(_resume.copyWith(experience: list..sort(_newestExperienceFirst)));
  }

  void removeExperience(int index) =>
      _update(_resume.copyWith(experience: [..._resume.experience]..removeAt(index)));

  /// Returns an error message, or null when added.
  String? addSkill(String name, String? level) {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return 'Please enter a skill.';
    if (clean.length > 50) return 'Skill names can be up to 50 characters.';
    if (_resume.skills.any((s) => s.name.toLowerCase() == clean.toLowerCase())) {
      return '"$clean" is already on your resume.';
    }
    _update(_resume.copyWith(skills: [..._resume.skills, ResumeSkill(clean, level)]));
    return null;
  }

  void setSkillLevel(int index, String? level) {
    final list = [..._resume.skills];
    list[index] = ResumeSkill(list[index].name, level);
    _update(_resume.copyWith(skills: list));
  }

  void removeSkill(int index) =>
      _update(_resume.copyWith(skills: [..._resume.skills]..removeAt(index)));

  // Optional sections -----------------------------------------------------

  List<ResumeSectionType> get availableSectionTypes => ResumeSectionType.values
      .where((t) => !_resume.sections.any((s) => s.type == t))
      .toList();

  void addSection(ResumeSectionType type) {
    if (_resume.sections.any((s) => s.type == type)) return;
    final sections = [..._resume.sections, ResumeSection(type: type)]
      ..sort((a, b) => a.type.index.compareTo(b.type.index));
    _update(_resume.copyWith(sections: sections));
  }

  void removeSection(ResumeSectionType type) =>
      _update(_resume.copyWith(sections: _resume.sections.where((s) => s.type != type).toList()));

  void setSectionText(ResumeSectionType type, String text) =>
      _replaceSection(type, (s) => s.copyWith(text: text));

  void addSectionItem(ResumeSectionType type, ResumeSectionItem item) =>
      _replaceSection(type, (s) => s.copyWith(items: [...s.items, item]));

  void replaceSectionItem(ResumeSectionType type, int index, ResumeSectionItem item) =>
      _replaceSection(type, (s) => s.copyWith(items: [...s.items]..[index] = item));

  void removeSectionItem(ResumeSectionType type, int index) =>
      _replaceSection(type, (s) => s.copyWith(items: [...s.items]..removeAt(index)));

  void _replaceSection(ResumeSectionType type, ResumeSection Function(ResumeSection) change) {
    _update(_resume.copyWith(
      sections: _resume.sections.map((s) => s.type == type ? change(s) : s).toList(),
    ));
  }

  static int _newestEducationFirst(EducationModel a, EducationModel b) {
    if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
    return b.startDate.compareTo(a.startDate);
  }

  static int _newestExperienceFirst(WorkExperienceModel a, WorkExperienceModel b) {
    if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
    return b.startDate.compareTo(a.startDate);
  }

  // ---------------------------------------------------------------------
  // Output
  // ---------------------------------------------------------------------

  /// Checks the required parts before making the PDF; null when ready.
  String? validateForPdf() {
    if (_resume.fullName.trim().isEmpty) return 'Please add your name.';
    if (_resume.phone.trim().isEmpty) return 'Please add your phone number.';
    return null;
  }

  Future<Uint8List> buildPdf() => ResumePdfBuilder.build(_resume);

  String get pdfFileName {
    final safe = _resume.fullName.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return '${safe.isEmpty ? 'My' : safe}_Resume.pdf';
  }

  /// Uploads the PDF and makes it the profile resume used for job applications.
  Future<bool> setAsProfileResume(Uint8List bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$pdfFileName');
      await file.writeAsBytes(bytes, flush: true);
      final url = await _profileController.uploadResume(file);
      return url != null;
    } catch (e) {
      debugPrint('Error setting profile resume: $e');
      return false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
