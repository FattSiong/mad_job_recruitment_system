import 'package:flutter/material.dart';

import '../../../models/education_model.dart';
import '../controllers/profile_controller.dart';
import '../widgets/profile/add_education_sheet.dart';
import '../widgets/profile/profile_record_card.dart';
import '../widgets/profile/profile_records_page.dart';

/// Add, edit and remove the job seeker's education.
/// Changes are saved straight away; callers should reload when this screen closes.
class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});

  static final ProfileController _controller = ProfileController();

  @override
  Widget build(BuildContext context) {
    return ProfileRecordsPage<EducationModel>(
      icon: Icons.school_outlined,
      title: 'Education',
      subtitle: 'Add your schools, qualifications and achievements.',
      listTitle: 'Your Education',
      addLabel: 'Add Education',
      noun: 'education',
      emptyText: 'No education added yet. Tap "Add Education" to add one.',
      load: _controller.fetchEducation,
      add: _controller.addEducation,
      update: _controller.updateEducation,
      delete: _controller.deleteEducation,
      openSheet: (context, initial) => showAddEducationSheet(context, initial: initial),
      idOf: (e) => e.educationID,
      describe: (e) => '${e.degree} at ${e.institutionName}',
      cardBuilder: (e, onEdit, onDelete) => ProfileRecordCard.education(e, onEdit: onEdit, onDelete: onDelete),
    );
  }
}
