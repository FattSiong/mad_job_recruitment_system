import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../controllers/resume_builder_controller.dart';
import '../widgets/load_error_view.dart';
import '../widgets/resume/resume_record_steps.dart';
import '../widgets/resume/resume_sections_step.dart';
import '../widgets/resume/resume_skills_step.dart';
import 'resume_preview_screen.dart';
import '../../../shared_widgets/gradient_page_header.dart';
import '../../../shared_widgets/bottom_action_bar.dart';
import '../../../core/theme/app_button_styles.dart';
import '../../../core/theme/app_input_decoration.dart';
import '../../../shared_widgets/button_spinner.dart';

/// In-app resume builder:
/// name -> phone -> address -> education -> work experience -> skills -> more sections,
/// then a PDF preview. The resume is saved as its own copy after every step.
class BuildResumeScreen extends StatefulWidget {
  const BuildResumeScreen({super.key});

  @override
  State<BuildResumeScreen> createState() => _BuildResumeScreenState();
}

/// Title, subtitle and icon of one builder step.
class _ResumeStep {
  final String title;
  final String subtitle;
  final IconData icon;

  const _ResumeStep(this.title, this.subtitle, this.icon);
}

class _BuildResumeScreenState extends State<BuildResumeScreen> {
  static const List<_ResumeStep> _steps = [
    _ResumeStep('Your Name', 'How your name should appear at the top of your resume.', Icons.person_outline_rounded),
    _ResumeStep('Phone Number', 'Employers will call you on this number.', Icons.phone_outlined),
    _ResumeStep('Address', 'Your city and state are usually enough.', Icons.location_on_outlined),
    _ResumeStep('Education', 'Your schools and qualifications, newest first.', Icons.school_outlined),
    _ResumeStep('Work Experience', 'Jobs, internships and part-time work.', Icons.work_outline_rounded),
    _ResumeStep('Skills', 'What you are good at. Add a level if you like.', Icons.psychology_outlined),
    _ResumeStep('More Sections', 'Add a summary, projects, awards, languages and more.', Icons.dashboard_customize_outlined),
  ];

  final ResumeBuilderController _controller = ResumeBuilderController();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();

  int _step = 0;
  bool _fieldsFilled = false;

  bool get _isLast => _step == _steps.length - 1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_fillFieldsOnce);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_fillFieldsOnce);
    if (_controller.hasUnsavedChanges) _controller.save(); // keep the draft when leaving
    _controller.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  /// Puts the loaded resume into the text boxes (only once).
  void _fillFieldsOnce() {
    if (_fieldsFilled || _controller.isLoading || _controller.error != null) return;
    final r = _controller.resume;
    _name.text = r.fullName;
    _email.text = r.email;
    _phone.text = r.phone;
    _address.text = r.address;
    _fieldsFilled = true;
  }

  // ---------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------

  /// Saves, then goes to the next step (the last step opens the PDF preview).
  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_step <= 2 && !(_formKey.currentState?.validate() ?? true)) return;

    final saved = await _controller.save();
    if (!mounted) return;
    if (!saved) {
      SnackBarHelper.showStyled(
        context,
        message: 'Could not save your progress. Check your connection; your changes are kept for now.',
        icon: Icons.cloud_off_rounded,
        accentColor: AppColors.warning,
      );
    }

    if (!_isLast) {
      setState(() => _step++);
      return;
    }

    final problem = _controller.validateForPdf();
    if (problem != null) {
      SnackBarHelper.showStyled(
        context,
        message: problem,
        icon: Icons.info_outline_rounded,
        accentColor: AppColors.errorRed,
      );
      setState(() => _step = _controller.resume.fullName.isEmpty ? 0 : 1);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResumePreviewScreen(controller: _controller)),
    );
  }

  /// Previous step, or leaves the builder from the first step.
  void _back() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: _controller.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _controller.error != null
                    ? LoadErrorView(message: _controller.error!, onRetry: _controller.load)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 18),
                            _buildProgress(),
                            if (_controller.prefilledFromProfile && _step == 0) ...[
                              const SizedBox(height: 14),
                              _buildPrefillNote(),
                            ],
                            const SizedBox(height: 18),
                            _buildStepCard(),
                          ],
                        ),
                      ),
          ),
          bottomNavigationBar:
              (_controller.isLoading || _controller.error != null) ? null : _buildBottomButtons(),
        );
      },
    );
  }

  /// Gradient header with the title and back button.
  Widget _buildHeader() => GradientPageHeader(
        title: 'Build Resume',
        subtitle: 'Create a professional PDF resume step by step.',
        trailing: _controller.isSaving
            ? const ButtonSpinner()
            : null,
      );

  /// "Step 3 of 7" with a progress bar.
  Widget _buildProgress() {
    final step = _steps[_step];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(step.icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Step ${_step + 1} of ${_steps.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ),
              Text(
                _isLast ? 'Last step' : 'Next: ${_steps[_step + 1].title}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (_step + 1) / _steps.length,
              minHeight: 6,
              color: AppColors.primary,
              backgroundColor: AppColors.primarySoft,
            ),
          ),
        ],
      ),
    );
  }

  /// Note that the resume starts from the profile, and edits stay in the resume.
  Widget _buildPrefillNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_outlined, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'We filled this in from your profile. Changes here only affect your resume.',
              style: TextStyle(color: AppColors.primary, height: 1.35, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// White card with the current step's title and fields.
  Widget _buildStepCard() {
    final step = _steps[_step];
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            step.title,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          Text(step.subtitle, style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
          const SizedBox(height: 20),
          _buildStepBody(),
        ],
      ),
    );
  }

  /// The fields of the current step.
  Widget _buildStepBody() {
    switch (_step) {
      case 0:
        return Form(
          key: _formKey,
          child: Column(
            children: [
              _field(
                controller: _name,
                label: 'Full name*',
                icon: Icons.person_outline_rounded,
                capitalization: TextCapitalization.words,
                onChanged: _controller.setName,
                validator: (v) => (v == null || v.trim().length < 2) ? 'Please enter your full name' : null,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _email,
                label: 'Email (optional)',
                icon: Icons.email_outlined,
                keyboard: TextInputType.emailAddress,
                onChanged: _controller.setEmail,
                validator: (v) {
                  final text = v?.trim() ?? '';
                  if (text.isEmpty) return null;
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
                      ? null
                      : 'Enter a valid email address';
                },
              ),
            ],
          ),
        );
      case 1:
        return Form(
          key: _formKey,
          child: _field(
            controller: _phone,
            label: 'Phone number*',
            icon: Icons.phone_outlined,
            keyboard: TextInputType.phone,
            hint: 'e.g. 012-345 6789',
            onChanged: _controller.setPhone,
            validator: (v) {
              final text = v?.trim() ?? '';
              if (text.isEmpty) return 'Please enter your phone number';
              return RegExp(r'^[0-9+\-\s()]{8,20}$').hasMatch(text) ? null : 'Enter a valid phone number';
            },
          ),
        );
      case 2:
        return Form(
          key: _formKey,
          child: _field(
            controller: _address,
            label: 'Address*',
            icon: Icons.location_on_outlined,
            hint: 'e.g. Petaling Jaya, Selangor',
            maxLines: 3,
            capitalization: TextCapitalization.words,
            onChanged: _controller.setAddress,
            validator: (v) => (v == null || v.trim().length < 3) ? 'Please enter your address' : null,
          ),
        );
      case 3:
        return ResumeEducationStep(controller: _controller);
      case 4:
        return ResumeExperienceStep(controller: _controller);
      case 5:
        return ResumeSkillsStep(controller: _controller);
      default:
        return ResumeSectionsStep(controller: _controller);
    }
  }

  /// One labelled text box with an icon.
  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ValueChanged<String> onChanged,
    String? Function(String?)? validator,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      decoration: filledInputDecoration(label: label, hint: hint, icon: icon),
    );
  }

  /// Back and Next / Finish buttons.
  Widget _buildBottomButtons() {
    return BottomActionBar(
             padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
             child: Row(
               children: [
                 Expanded(
                   child: OutlinedButton(
                     onPressed: _back,
                     style: AppButtonStyles.neutral(),
                     child: Text(_step == 0 ? 'Cancel' : 'Back'),
                   ),
                 ),
                 const SizedBox(width: 12),
                 Expanded(
                   flex: 2,
                   child: ElevatedButton.icon(
                     onPressed: _controller.isSaving ? null : _next,
                     icon: Icon(_isLast ? Icons.picture_as_pdf_outlined : Icons.arrow_forward_rounded),
                     label: Text(_isLast ? 'Preview PDF' : 'Next'),
                     style: AppButtonStyles.filled(),
                   ),
                 ),
               ],
             ),
           );
  }
}
