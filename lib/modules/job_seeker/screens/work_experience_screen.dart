import 'package:flutter/material.dart';

import '../../../models/work_experience_model.dart';
import '../controllers/profile_controller.dart';
import '../widgets/profile/add_experience_sheet.dart';
import '../widgets/profile/profile_record_card.dart';
import '../widgets/profile/profile_records_page.dart';

/// Add, edit and remove the job seeker's work experience.
/// Changes are saved straight away; callers should reload when this screen closes.
class WorkExperienceScreen extends StatelessWidget {
  const WorkExperienceScreen({super.key});

  static final ProfileController _controller = ProfileController();

  @override
  Widget build(BuildContext context) {
    return ProfileRecordsPage<WorkExperienceModel>(
      icon: Icons.work_history_outlined,
      title: 'Work Experience',
      subtitle: 'Show employers where you have worked and what you did.',
      listTitle: 'Your Experience',
      addLabel: 'Add Experience',
      noun: 'work experience',
      emptyText: 'No work experience added yet. Tap "Add Experience" to add one.',
      load: _controller.fetchWorkExperiences,
      add: _controller.addWorkExperience,
      update: _controller.updateWorkExperience,
      delete: _controller.deleteWorkExperience,
      openSheet: (context, initial) => showAddExperienceSheet(context, initial: initial),
      idOf: (e) => e.experienceID,
      describe: (e) => '${e.jobTitle} at ${e.companyName}',
      cardBuilder: (e, onEdit, onDelete) => ProfileRecordCard.experience(e, onEdit: onEdit, onDelete: onDelete),
    );
  }
}
