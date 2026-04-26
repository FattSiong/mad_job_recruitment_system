import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_picker_helper.dart';
import '../../../core/utils/file_preview_helper.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../models/job_model.dart';
import '../../../models/pre_screening_question_model.dart';
import '../controllers/application_controller.dart';

class JobApplicationScreen extends StatefulWidget {
  final JobModel job;

  const JobApplicationScreen({super.key, required this.job});

  @override
  State<JobApplicationScreen> createState() => _JobApplicationScreenState();
}

class _JobApplicationScreenState extends State<JobApplicationScreen> {
  static const Color _primary = Color(0xFF163B65);
  static const Color _primarySoft = Color(0xFFDCEBFB);
  static const Color _textPrimary = Color(0xFF1B2433);
  static const Color _textMuted = Color(0xFF687588);
  static const Color _surfaceAlt = Color(0xFFF7F9FC);
  static const Color _border = Color(0xFFE1E8F0);

  final ApplicationController _appController = ApplicationController();
  final PageController _pageController = PageController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentPage = 0;

  List<PreScreeningQuestionModel> _questions = [];
  String? _existingResumeUrl;

  final Map<String, dynamic> _answers = {};
  String _resumeSelection = 'existing';
  File? _newResumeFile;

  @override
  void initState() {
    super.initState();
    _loadApplicationData();
  }

  Future<void> _loadApplicationData() async {
    final questions = await _appController.getQuestions(widget.job.jobID!);
    final resumeUrl = await _appController.getSeekerResume();

    if (mounted) {
      setState(() {
        _questions = questions;
        _existingResumeUrl = resumeUrl;

        if (resumeUrl == null) {
          _resumeSelection = 'new';
        }

        _isLoading = false;
      });
    }
  }

  bool _validateQuestions() {
    for (final q in _questions) {
      final answer = _answers[q.questionID!];
      if (answer == null) return false;
      if (answer is String && answer.trim().isEmpty) return false;
    }
    return true;
  }

  Future<void> _submitApplication() async {
    if (_resumeSelection == 'new' && _newResumeFile == null) {
      SnackBarHelper.showStyled(
        context,
        message: 'Please select a resume file to upload.',
        icon: Icons.info_outline_rounded,
        accentColor: const Color(0xFFE27D60),
      );
      return;
    }

    if (_resumeSelection == 'existing' && _existingResumeUrl == null) {
      SnackBarHelper.showStyled(
        context,
        message: 'No existing resume found. Please upload a new one.',
        icon: Icons.info_outline_rounded,
        accentColor: const Color(0xFFE27D60),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await _appController.submitApplication(
      jobId: widget.job.jobID!,
      answers: _answers,
      existingResumeUrl:
      _resumeSelection == 'existing' ? _existingResumeUrl : null,
      newResumeFile: _newResumeFile,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (success) {
      SnackBarHelper.showStyled(
        context,
        message: 'Application submitted successfully!',
        icon: Icons.check_circle_outline_rounded,
        accentColor: const Color(0xFF1E8F8B),
      );
      Navigator.pop(context);
    } else {
      SnackBarHelper.showStyled(
        context,
        message: 'Failed to submit application.',
        icon: Icons.error_outline_rounded,
        accentColor: const Color(0xFFE27D60),
      );
    }
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  ButtonStyle _secondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _textPrimary,
      backgroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      side: const BorderSide(color: _border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildHeroActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildSurfaceCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(22),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }

  Widget _buildStepIndicator({
    required int stepNumber,
    required String title,
    required bool isActive,
    required bool isDone,
  }) {
    final Color color = isDone || isActive ? _primary : const Color(0xFFB0B9C5);

    return Expanded(
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDone || isActive ? _primarySoft : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDone || isActive ? const Color(0xFFB8D1EE) : _border,
              ),
            ),
            child: Center(
              child: isDone
                  ? const Icon(
                Icons.check_rounded,
                size: 18,
                color: _primary,
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
                color: isActive ? _textPrimary : _textMuted,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard({
    required PreScreeningQuestionModel question,
  }) {
    final questionId = question.questionID!;
    final isText = question.questionType == 'Text';
    final currentAnswer = _answers[questionId];
    final isFileSelected = currentAnswer != null && currentAnswer is File;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: _buildSurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.questionText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            if (isText)
              TextField(
                onChanged: (val) => _answers[questionId] = val,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter your answer',
                  filled: true,
                  fillColor: _surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _primary, width: 1.5),
                  ),
                ),
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
                        );

                        if (pickedFile != null) {
                          setState(() => _answers[questionId] = pickedFile);
                        }
                      },
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(isFileSelected ? 'Change File' : 'Upload File'),
                      style: _secondaryButtonStyle().copyWith(
                        foregroundColor: WidgetStateProperty.all(_primary),
                        side: WidgetStateProperty.all(
                          const BorderSide(color: Color(0xFFB8D1EE)),
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
                          color: Color(0xFF1E8F8B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.visibility_outlined,
                        color: _primary,
                      ),
                      tooltip: 'Preview File',
                      onPressed: () =>
                          FilePreviewHelper.previewLocalFile(context, currentAnswer),
                    ),
                  ] else ...[
                    const Expanded(
                      child: Text(
                        'No file selected',
                        style: TextStyle(color: _textMuted),
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

  Widget _buildQuestionsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Answer pre-screening questions',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The employer requires answers to these questions before you continue.',
                  style: TextStyle(
                    color: _textMuted,
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
            color: selected ? const Color(0xFFB8D1EE) : _border,
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
                color: selected ? _primarySoft : _surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: selected ? _primary : _textMuted),
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
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _textMuted,
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
              color: selected ? _primary : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add a resume for the employer',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose your existing resume or upload a fresh version for this application.',
                  style: TextStyle(
                    color: _textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                if (_existingResumeUrl != null)
                  _buildResumeOptionCard(
                    selected: _resumeSelection == 'existing',
                    icon: Icons.description_outlined,
                    title: 'Use your existing resume',
                    subtitle: 'Recommended for faster applications.',
                    onTap: () => setState(() => _resumeSelection = 'existing'),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.visibility_outlined,
                        color: _primary,
                      ),
                      tooltip: 'Preview',
                      onPressed: () => FilePreviewHelper.previewNetworkFile(
                        context,
                        _existingResumeUrl!,
                      ),
                    ),
                  ),
                _buildResumeOptionCard(
                  selected: _resumeSelection == 'new',
                  icon: Icons.upload_file_rounded,
                  title: 'Upload a new resume',
                  subtitle: _newResumeFile != null
                      ? 'Selected: ${_newResumeFile!.path.split('/').last}'
                      : 'Accepted file types are PDF, DOCX, RTF, or TXT.',
                  onTap: () async {
                    setState(() => _resumeSelection = 'new');

                    final pickedFile = await FilePickerHelper.pickFile(
                      allowedExtensions: ['pdf', 'doc', 'docx', 'rtf', 'txt'],
                    );

                    if (pickedFile != null) {
                      setState(() => _newResumeFile = pickedFile);
                    }
                  },
                  trailing: _newResumeFile != null
                      ? IconButton(
                    icon: const Icon(
                      Icons.visibility_outlined,
                      color: _primary,
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
        backgroundColor: Color(0xFFF4F7FB),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
      );
    }

    final hasQuestions = _questions.isNotEmpty;
    final totalPages = hasQuestions ? 2 : 1;
    final progress = (_currentPage + 1) / totalPages;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
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
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(headerPadding),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF163B65), Color(0xFF335D8A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _buildHeroActionButton(
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
                                    _buildHeroActionButton(
                                      icon: Icons.close_rounded,
                                      tooltip: 'Cancel',
                                      onTap: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.send_outlined,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Job Application',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
                          _buildSurfaceCard(
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
                                                  color: _primary,
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
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
                            if (!_validateQuestions()) {
                              SnackBarHelper.showStyled(
                                context,
                                message:
                                    'Please answer all pre-screening questions before continuing.',
                                icon: Icons.info_outline_rounded,
                                accentColor: const Color(0xFFE27D60),
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
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
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
      ),
    );
  }
}
