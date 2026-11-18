import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_picker_helper.dart';
import '../../../core/utils/file_preview_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/job_model.dart';
import '../../../models/pre_screening_question_model.dart';
import '../controllers/application_controller.dart';
import '../widgets/load_error_view.dart';
import '../../../shared_widgets/hero_icon_button.dart';
import '../../../shared_widgets/surface_card.dart';
import '../../../shared_widgets/hero_card.dart';
import '../../../shared_widgets/bottom_action_bar.dart';
import '../../../core/theme/app_button_styles.dart';
import '../../../core/theme/app_input_decoration.dart';
import '../../../shared_widgets/button_spinner.dart';

/// Applying for a job: answer the employer's questions, choose a resume,
/// then submit.
class JobApplicationScreen extends StatefulWidget {
  final JobModel job;

  const JobApplicationScreen({super.key, required this.job});

  @override
  State<JobApplicationScreen> createState() => _JobApplicationScreenState();
}

class _JobApplicationScreenState extends State<JobApplicationScreen> {
  final ApplicationController _appController = ApplicationController();
  final PageController _pageController = PageController();

  int _currentPage = 0; // which step of the form is showing (UI only)

  // Form state lives in the controller (MVC); these read it.
  bool get _isLoading => _appController.isLoading;
  bool get _isSubmitting => _appController.isSubmitting;
  List<PreScreeningQuestionModel> get _questions => _appController.questions;
  String? get _existingResumeUrl => _appController.existingResumeUrl;
  File? get _newResumeFile => _appController.newResumeFile;

  /// True if [choice] is the selected resume option.
  bool _isResume(ResumeChoice choice) => _appController.resumeChoice == choice;

  @override
  void initState() {
    super.initState();
    _appController.addListener(_onControllerChanged);
    _appController.load(widget.job.jobID!);
  }

  @override
  void dispose() {
    _appController.removeListener(_onControllerChanged);
    _appController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Rebuilds when the form state changes.
  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  /// Snackbar when a chosen file is too large.
  void _showFileTooLarge(String message) {
    if (!mounted) return;
    SnackBarHelper.showStyled(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      accentColor: AppColors.coral,
    );
  }

  /// Checks the resume step, submits, and closes the screen when it worked.
  Future<void> _submitApplication() async {
    final problem = _appController.validateResume();
    if (problem != null) {
      SnackBarHelper.showStyled(
        context,
        message: problem,
        icon: Icons.info_outline_rounded,
        accentColor: AppColors.coral,
      );
      return;
    }

    try {
      // Uploads files first, then saves the application + answers in one transaction
      await _appController.submit(widget.job.jobID!);

      if (!mounted) return;
      SnackBarHelper.showStyled(
        context,
        message: 'Application submitted successfully!',
        icon: Icons.check_circle_outline_rounded,
        accentColor: AppColors.teal,
      );
      Navigator.pop(context, true); // tells JobDetailsScreen the user has applied
    } on ApplicationException catch (e) {
      if (!mounted) return;
      SnackBarHelper.showStyled(
        context,
        message: e.message,
        icon: e.code == 'already_applied'
            ? Icons.info_outline_rounded
            : Icons.error_outline_rounded,
        accentColor: AppColors.coral,
        duration: const Duration(seconds: 3),
      );
      if (e.code == 'already_applied' || e.code == 'job_unavailable') {
        Navigator.pop(context, e.code == 'already_applied');
      }
    }
  }

  /// Style of the filled navy buttons (Next, Submit).
  ButtonStyle _primaryButtonStyle() {
    return AppButtonStyles.filled(radius: 18);
  }

  /// Style of the white outlined buttons (Back, file pickers).
  ButtonStyle _secondaryButtonStyle() {
    return AppButtonStyles.neutral();
  }

  /// One numbered step at the top (done, current or still to come).
  Widget _buildStepIndicator({
    required int stepNumber,
    required String title,
    required bool isActive,
    required bool isDone,
  }) {
    final Color color = isDone || isActive ? AppColors.primary : AppColors.iconDisabled;

    return Expanded(
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDone || isActive ? AppColors.primarySoft : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDone || isActive ? AppColors.borderActive : AppColors.border,
              ),
            ),
            child: Center(
              child: isDone
                  ? const Icon(
                Icons.check_rounded,
                size: 18,
                color: AppColors.primary,
              )
                  : Text(
                '$stepNumber',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isActive ? AppColors.textDark : AppColors.textMuted,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One question with a text box or a file picker, depending on its type.
  Widget _buildQuestionCard({
    required PreScreeningQuestionModel question,
  }) {
    final questionId = question.questionID!;
    final isText = question.questionType == 'Text';
    final currentAnswer = _appController.answerFor(questionId);
    final isFileSelected = currentAnswer != null && currentAnswer is File;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: SurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.questionText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),
            if (isText)
              TextField(
                onChanged: (val) => _appController.setTextAnswer(questionId, val),
                maxLines: 4,
                decoration: filledInputDecoration(hint: 'Enter your answer'),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final pickedFile = await FilePickerHelper.pickFile(
                          allowedExtensions: [
                            'pdf',
                            'jpg',
                            'jpeg',
                            'png',
                            'zip',
                            'rar',
                            'dart',
                            'py',
                            'js',
                            'java',
                            'cpp',
                            'html',
                            'css',
                            'txt',
                          ],
                          maxSizeMB: FileLimits.answerFileMB,
                          onTooLarge: _showFileTooLarge,
                        );

                        if (pickedFile != null) {
                          _appController.setFileAnswer(questionId, pickedFile);
                        }
                      },
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(isFileSelected ? 'Change File' : 'Upload File'),
                      style: _secondaryButtonStyle().copyWith(
                        foregroundColor: WidgetStateProperty.all(AppColors.primary),
                        side: WidgetStateProperty.all(
                          const BorderSide(color: AppColors.borderActive),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (isFileSelected) ...[
                    Expanded(
                      child: Text(
                        currentAnswer.path.split('/').last,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.visibility_outlined,
                        color: AppColors.primary,
                      ),
                      tooltip: 'Preview File',
                      onPressed: () =>
                          FilePreviewHelper.previewLocalFile(context, currentAnswer),
                    ),
                  ] else ...[
                    const Expanded(
                      child: Text(
                        'No file selected',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Step 1: the employer's questions.
  Widget _buildQuestionsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Answer pre-screening questions',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The employer requires answers to these questions before you continue.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                ..._questions.map(
                      (q) => _buildQuestionCard(question: q),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One selectable resume option (profile resume or a new file).
  Widget _buildResumeOptionCard({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.borderActive : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySoft : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: selected ? AppColors.primary : AppColors.textMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            Icon(
              selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  /// Step 2: choose the resume to send.
  Widget _buildResumePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add a resume for the employer',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose your existing resume or upload a fresh version for this application.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                if (_existingResumeUrl != null)
                  _buildResumeOptionCard(
                    selected: _isResume(ResumeChoice.existing),
                    icon: Icons.description_outlined,
                    title: 'Use your existing resume',
                    subtitle: 'Recommended for faster applications.',
                    onTap: () => _appController.chooseResume(ResumeChoice.existing),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.visibility_outlined,
                        color: AppColors.primary,
                      ),
                      tooltip: 'Preview',
                      onPressed: () => FilePreviewHelper.previewNetworkFile(
                        context,
                        _existingResumeUrl!,
                        title: 'My Resume',
                      ),
                    ),
                  ),
                _buildResumeOptionCard(
                  selected: _isResume(ResumeChoice.newFile),
                  icon: Icons.upload_file_rounded,
                  title: 'Upload a new resume',
                  subtitle: _newResumeFile != null
                      ? 'Selected: ${_newResumeFile!.path.split('/').last}'
                      : 'Accepted: ${FileLimits.resumeTypesLabel}, up to ${FileLimits.resumeMB} MB.',
                  onTap: () async {
                    _appController.chooseResume(ResumeChoice.newFile);

                    final pickedFile = await FilePickerHelper.pickFile(
                      allowedExtensions: FileLimits.resumeExtensions,
                      maxSizeMB: FileLimits.resumeMB,
                      onTooLarge: _showFileTooLarge,
                    );

                    if (pickedFile != null) _appController.setNewResumeFile(pickedFile);
                  },
                  trailing: _newResumeFile != null
                      ? IconButton(
                    icon: const Icon(
                      Icons.visibility_outlined,
                      color: AppColors.primary,
                    ),
                    tooltip: 'Preview',
                    onPressed: () => FilePreviewHelper.previewLocalFile(
                      context,
                      _newResumeFile!,
                    ),
                  )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final loadError = _appController.loadError;
    if (loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.primary),
        ),
        body: LoadErrorView(
          message: loadError,
          onRetry: () => _appController.load(widget.job.jobID!),
        ),
      );
    }

    final hasQuestions = _questions.isNotEmpty;
    final totalPages = hasQuestions ? 2 : 1;
    final progress = (_currentPage + 1) / totalPages;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 520;
            final headerPadding = isCompact ? 18.0 : 24.0;
            final heroGap = isCompact ? 12.0 : 18.0;
            final sectionGap = isCompact ? 12.0 : 16.0;
            final titleFontSize = isCompact ? 22.0 : 27.0;
            final companyFontSize = isCompact ? 14.0 : 15.0;

            return Column(
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        isCompact ? 12 : 16,
                        20,
                        sectionGap,
                      ),
                      child: Column(
                        children: [
                          HeroCard(padding: EdgeInsets.all(headerPadding), child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    HeroIconButton(
                                      icon: Icons.arrow_back_rounded,
                                      tooltip: 'Back',
                                      onTap: () {
                                        if (_currentPage > 0) {
                                          _pageController.previousPage(
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.ease,
                                          );
                                        } else {
                                          Navigator.pop(context);
                                        }
                                      },
                                    ),
                                    const Spacer(),
                                    HeroIconButton(
                                      icon: Icons.close_rounded,
                                      tooltip: 'Cancel',
                                      onTap: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: const HeroPill(icon: Icons.send_outlined, label: 'Job Application'),
                                ),
                                SizedBox(height: heroGap),
                                Text(
                                  widget.job.title,
                                  maxLines: isCompact ? 2 : 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: titleFontSize,
                                    fontWeight: FontWeight.bold,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.job.companyName ?? 'Company',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: companyFontSize,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: sectionGap),
                          SurfaceCard(
                            padding: EdgeInsets.all(isCompact ? 14 : 18),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _buildStepIndicator(
                                      stepNumber: 1,
                                      title: hasQuestions ? 'Questions' : 'Resume',
                                      isActive: _currentPage == 0,
                                      isDone: _currentPage > 0,
                                    ),
                                    if (hasQuestions) ...[
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Container(
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: FractionallySizedBox(
                                              widthFactor: progress,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary,
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      _buildStepIndicator(
                                        stepNumber: 2,
                                        title: 'Resume',
                                        isActive: _currentPage == 1,
                                        isDone: false,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    children: [
                      if (hasQuestions) _buildQuestionsPage(),
                      _buildResumePage(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: BottomActionBar(
                             child: Row(
                               children: [
                                 if (hasQuestions && _currentPage > 0) ...[
                                   Expanded(
                                     child: OutlinedButton(
                                       onPressed: _isSubmitting
                                           ? null
                                           : () {
                                               _pageController.previousPage(
                                                 duration: const Duration(milliseconds: 300),
                                                 curve: Curves.ease,
                                               );
                                             },
                                       style: _secondaryButtonStyle(),
                                       child: const Text(
                                         'Back',
                                         style: TextStyle(fontWeight: FontWeight.bold),
                                       ),
                                     ),
                                   ),
                                   const SizedBox(width: 12),
                                 ],
                                 Expanded(
                                   flex: hasQuestions && _currentPage > 0 ? 2 : 1,
                                   child: ElevatedButton(
                                     onPressed: _isSubmitting
                                         ? null
                                         : () {
                                             if (hasQuestions && _currentPage == 0) {
                                               if (!_appController.questionsAnswered) {
                                                 SnackBarHelper.showStyled(
                                                   context,
                                                   message:
                                                       'Please answer all pre-screening questions before continuing.',
                                                   icon: Icons.info_outline_rounded,
                                                   accentColor: AppColors.coral,
                                                 );
                                                 return;
                                               }
                                               _pageController.nextPage(
                                                 duration: const Duration(milliseconds: 300),
                                                 curve: Curves.ease,
                                               );
                                             } else {
                                               _submitApplication();
                                             }
                                           },
                                     style: _primaryButtonStyle(),
                                     child: _isSubmitting
                                         ? const ButtonSpinner(size: 20)
                                         : Text(
                                             (hasQuestions && _currentPage == 0)
                                                 ? 'Continue'
                                                 : 'Submit Application',
                                             style: const TextStyle(
                                               fontSize: 16,
                                               fontWeight: FontWeight.bold,
                                             ),
                                           ),
                                   ),
                                 ),
                               ],
                             ),
                           ),
    );
  }
}
