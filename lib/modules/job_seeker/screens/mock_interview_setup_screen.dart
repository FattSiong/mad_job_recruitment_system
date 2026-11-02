import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../controllers/mock_interview_controller.dart';
import 'mock_interview_session_screen.dart';

/// Step 1 of Use Case 4.59: choose a role / topic and give AI consent.
class MockInterviewSetupScreen extends StatefulWidget {
  const MockInterviewSetupScreen({super.key});

  @override
  State<MockInterviewSetupScreen> createState() => _MockInterviewSetupScreenState();
}

class _MockInterviewSetupScreenState extends State<MockInterviewSetupScreen> {
  static const Color _primary = AppColors.primary;
  static const Color _background = AppColors.background;
  static const Color _textPrimary = AppColors.textDark;
  static const Color _textMuted = AppColors.textMuted;
  static const Color _surfaceAlt = AppColors.surfaceAlt;
  static const Color _border = AppColors.border;

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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Microphone access needed'),
        content: const Text(
          'Microphone access is required to record and analyse your spoken answers. '
          'Please allow it in your device settings to start the mock interview.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    return false;
  }

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
      SnackBarHelper.showStyled(
        context,
        message: e.message,
        icon: Icons.error_outline_rounded,
        accentColor: AppColors.errorRed,
        duration: const Duration(seconds: 3),
      );
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.record_voice_over_outlined, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mock Interview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Practise speaking and get AI feedback on content and delivery.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _surfaceCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: _textMuted, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildRoleCard() {
    return _surfaceCard(
      children: [
        _sectionTitle('Job Role or Topic', 'Questions will be tailored to this role.'),
        TextField(
          controller: _roleController,
          enabled: !_isStarting,
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'e.g. Junior Flutter Developer',
            counterText: '',
            prefixIcon: const Icon(Icons.work_outline, color: _primary),
            filled: true,
            fillColor: _surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: _primary, width: 1.2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestedRoles.map((role) {
            final selected = _roleController.text.trim() == role;
            return ChoiceChip(
              label: Text(role),
              selected: selected,
              onSelected: _isStarting
                  ? null
                  : (_) {
                      _roleController.text = role;
                      _roleController.selection =
                          TextSelection.collapsed(offset: role.length);
                    },
              selectedColor: AppColors.primarySoft,
              backgroundColor: _surfaceAlt,
              side: BorderSide(color: selected ? _primary : _border),
              labelStyle: TextStyle(
                color: selected ? _primary : _textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              showCheckmark: false,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOptionsCard() {
    return _surfaceCard(
      children: [
        _sectionTitle('Interview Settings', 'Choose your level and interview length.'),
        const Text(
          'Experience level',
          style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _surfaceAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _level,
              isExpanded: true,
              borderRadius: BorderRadius.circular(18),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _primary),
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
          style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary),
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
                      color: selected ? _primary : _surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selected ? _primary : _border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : _textPrimary,
                          ),
                        ),
                        Text(
                          '~${count * 2 + 2} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? Colors.white70 : _textMuted,
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

  Widget _buildHowItWorksCard() {
    return _surfaceCard(
      children: [
        _sectionTitle('How It Works', 'Find a quiet place before you begin.'),
        _stepTile(1, 'Introduce yourself', 'Start with a short self-introduction.'),
        _stepTile(2, 'Answer the questions',
            'Questions are tailored to your role and introduction. Tap the mic to answer each one.'),
        _stepTile(3, 'End and get feedback',
            'Get a scorecard on your answers, speaking pace, filler words and hesitations.'),
      ],
    );
  }

  Widget _stepTile(int number, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$number',
              style: const TextStyle(color: _primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: _textMuted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCard() {
    return _surfaceCard(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.privacy_tip_outlined, color: _primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'AI Processing Consent',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
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
        _consentPoint(Icons.videocam_off_outlined,
            'The camera is optional and only shows a preview to you. Video is never recorded or uploaded.'),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isStarting ? null : () => setState(() => _consentGiven = !_consentGiven),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 10, 12, 10),
            decoration: BoxDecoration(
              color: _consentGiven ? AppColors.primarySoft : _surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _consentGiven ? _primary : _border),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _consentGiven,
                  activeColor: _primary,
                  onChanged: _isStarting
                      ? null
                      : (v) => setState(() => _consentGiven = v ?? false),
                ),
                const Expanded(
                  child: Text(
                    'I understand and agree to AI processing of my interview answers.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
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

  Widget _consentPoint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: _textMuted, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _canStart ? _start : null,
            icon: _isStarting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_isStarting ? 'Starting…' : 'Start Mock Interview'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFD7E3F3),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
      ),
    );
  }
}
