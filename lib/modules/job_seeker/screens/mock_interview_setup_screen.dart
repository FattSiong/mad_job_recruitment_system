import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../controllers/mock_interview_controller.dart';
import 'mock_interview_session_screen.dart';
import '../../../shared_widgets/surface_card.dart';
import '../../../shared_widgets/gradient_page_header.dart';
import '../widgets/career_tools/career_tool_widgets.dart';
import '../../../shared_widgets/confirm_dialog.dart';

/// Step 1 of Use Case 4.59: choose a role / topic and give AI consent.
class MockInterviewSetupScreen extends StatefulWidget {
  const MockInterviewSetupScreen({super.key});

  @override
  State<MockInterviewSetupScreen> createState() => _MockInterviewSetupScreenState();
}

class _MockInterviewSetupScreenState extends State<MockInterviewSetupScreen> {
  static const List<String> _suggestedRoles = [
    'Software Developer',
    'Data Analyst',
    'Marketing Executive',
    'Accountant',
    'Customer Service',
    'Graphic Designer',
    'Business Analyst',
    'HR Executive',
  ];

  static const List<String> _levels = [
    'Internship',
    'Fresh Graduate',
    'Junior (1-3 years)',
    'Mid-level (3-5 years)',
    'Senior (5+ years)',
  ];

  static const List<int> _questionCounts = [3, 5, 7];

  final MockInterviewController _controller = MockInterviewController();
  final TextEditingController _roleController = TextEditingController();

  String _level = 'Fresh Graduate';
  int _questionCount = 5;
  bool _consentGiven = false;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _roleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _roleController.dispose();
    super.dispose();
  }

  bool get _canStart =>
      _roleController.text.trim().isNotEmpty && _consentGiven && !_isStarting;

  /// Use case A1: microphone permission is required before the session starts.
  Future<bool> _ensureMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if (!mounted) return false;
    final openSettings = await showConfirmDialog(
      context,
      title: 'Microphone access needed',
      message: 'Microphone access is required to record and analyse your spoken answers. '
          'Please allow it in your device settings to start the mock interview.',
      confirmLabel: 'Open Settings',
      destructive: false,
    );
    if (openSettings) await openAppSettings();
    return false;
  }

  /// Asks for the microphone, creates the session and opens the interview.
  Future<void> _start() async {
    if (!_canStart) return;
    FocusScope.of(context).unfocus();

    if (!await _ensureMicrophonePermission()) return;
    if (!mounted) return; // left the screen during the permission prompt

    setState(() => _isStarting = true);
    try {
      final result = await _controller.startInterview(
        targetJobRole: _roleController.text.trim(),
        experienceLevel: _level,
        questionCount: _questionCount,
        consent: _consentGiven,
      );
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MockInterviewSessionScreen(
            sessionID: result.sessionID,
            targetJobRole: _roleController.text.trim(),
            questionCount: _questionCount,
            initialQuestions: result.questions,
          ),
        ),
      );
    } on MockInterviewException catch (e) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      SnackBarHelper.showError(context, e.message, duration: const Duration(seconds: 3));
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildRoleCard(),
              const SizedBox(height: 20),
              _buildOptionsCard(),
              const SizedBox(height: 20),
              _buildHowItWorksCard(),
              const SizedBox(height: 20),
              _buildConsentCard(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  /// Gradient header with the title and back button.
  Widget _buildHeader() => const GradientPageHeader(
        icon: Icons.record_voice_over_outlined,
        title: 'Mock Interview',
        subtitle: 'Practise speaking and get AI feedback on content and delivery.',
      );

  /// Job role or topic box with suggested roles.
  Widget _buildRoleCard() => TargetRoleField(
        title: 'Job Role or Topic',
        subtitle: 'Questions will be tailored to this role.',
        hint: 'e.g. Junior Flutter Developer',
        controller: _roleController,
        enabled: !_isStarting,
        suggestions: _suggestedRoles,
        onSuggestionTap: (role) {
          _roleController.text = role;
          _roleController.selection = TextSelection.collapsed(offset: role.length);
        },
      );

  /// Experience level and number of questions.
  Widget _buildOptionsCard() {
    return SurfaceCard(
      children: [
        SectionTitle('Interview Settings', subtitle: 'Choose your level and interview length.'),
        const Text(
          'Experience level',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _level,
              isExpanded: true,
              borderRadius: BorderRadius.circular(18),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
              items: _levels
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: _isStarting ? null : (v) => setState(() => _level = v ?? _level),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Number of questions',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 10),
        Row(
          children: _questionCounts.map((count) {
            final selected = _questionCount == count;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: count == _questionCounts.last ? 0 : 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _isStarting ? null : () => setState(() => _questionCount = count),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : AppColors.textDark,
                          ),
                        ),
                        Text(
                          '~${count * 2 + 2} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? Colors.white70 : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// The three steps of the interview.
  Widget _buildHowItWorksCard() {
    return SurfaceCard(
      children: [
        SectionTitle('How It Works', subtitle: 'Find a quiet place before you begin.'),
        _stepTile(1, 'Introduce yourself', 'Start with a short self-introduction.'),
        _stepTile(2, 'Answer the questions',
            'Questions are tailored to your role and introduction. Tap the mic to answer each one.'),
        _stepTile(3, 'End and get feedback',
            'Get a scorecard on your answers, speaking pace, filler words and hesitations.'),
      ],
    );
  }

  /// One numbered step.
  Widget _stepTile(int number, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$number',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.textMuted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// What the AI does with the recordings, and the consent checkbox.
  Widget _buildConsentCard() {
    return SurfaceCard(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'AI Processing Consent',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _consentPoint(Icons.mic_none_rounded,
            'Your spoken answers are recorded and sent to Deepgram to be converted into text.'),
        _consentPoint(Icons.smart_toy_outlined,
            'The text, your questions and speech statistics are sent to Google Gemini to generate feedback.'),
        _consentPoint(Icons.delete_outline_rounded,
            'Audio recordings are not stored. Only transcripts, scores and feedback are saved to your account.'),
        _consentPoint(Icons.videocam_outlined,
            'The camera is optional. When it is on, your phone estimates eye contact and smiling while you '
            'answer (Google ML Kit, on the device). Video is never recorded or uploaded: only these '
            'percentages are saved, as feedback that does not change your score.'),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isStarting ? null : () => setState(() => _consentGiven = !_consentGiven),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 10, 12, 10),
            decoration: BoxDecoration(
              color: _consentGiven ? AppColors.primarySoft : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _consentGiven ? AppColors.primary : AppColors.border),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _consentGiven,
                  activeColor: AppColors.primary,
                  onChanged: _isStarting
                      ? null
                      : (v) => setState(() => _consentGiven = v ?? false),
                ),
                const Expanded(
                  child: Text(
                    'I understand and agree to AI processing of my interview answers.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// One point in the consent card.
  Widget _consentPoint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
          ),
        ],
      ),
    );
  }

  /// Start Interview button (enabled after the role and consent are given).
  Widget _buildBottomButton() => CareerToolRunBar(
        busy: _isStarting,
        enabled: _canStart,
        onPressed: _start,
        icon: Icons.play_arrow_rounded,
        label: 'Start Mock Interview',
        busyLabel: 'Starting…',
      );
}
