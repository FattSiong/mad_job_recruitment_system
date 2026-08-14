import 'package:flutter/material.dart';

class BuildResumeScreen extends StatefulWidget {
  const BuildResumeScreen({super.key});

  @override
  State<BuildResumeScreen> createState() => _BuildResumeScreenState();
}

class _BuildResumeScreenState extends State<BuildResumeScreen> {
  int _currentStep = 0;

  static const Color _primary = Color(0xFF163B65);
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _textPrimary = Color(0xFF1B2433);
  static const Color _textMuted = Color(0xFF687588);
  static const Color _surfaceAlt = Color(0xFFF7F9FC);
  static const Color _border = Color(0xFFE1E8F0);

  final List<String> _stepTitles = [
    'Personal Details',
    'Education',
    'Work Experience',
    'Skills',
  ];

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resume mockup completed.')),
      );
    }
  }

  void _backStep() {
    if (_currentStep == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildStepIndicator(),
              const SizedBox(height: 20),
              _buildFormCard(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF163B65), Color(0xFF335D8A)],
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Build Resume',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Create your digital resume step by step.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Personal', 'Education', 'Experience', 'Skills'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isDone = index < _currentStep;

          return Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isActive || isDone ? _primary : _surfaceAlt,
                  child: Icon(
                    isDone ? Icons.check_rounded : Icons.circle,
                    size: isDone ? 18 : 8,
                    color: isActive || isDone ? Colors.white : _textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  steps[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    color: isActive ? _primary : _textMuted,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _stepTitles[_currentStep],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getSubtitle(),
            style: const TextStyle(
              color: _textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          ..._getFields(),
        ],
      ),
    );
  }

  String _getSubtitle() {
    switch (_currentStep) {
      case 0:
        return 'Enter the information shown at the top of your resume.';
      case 1:
        return 'Add your academic background.';
      case 2:
        return 'Add your current or previous work experience.';
      default:
        return 'Add your skills, certifications, and licences.';
    }
  }

  List<Widget> _getFields() {
    switch (_currentStep) {
      case 0:
        return const [
          _MockInput(label: 'Full Name', icon: Icons.person_outline_rounded),
          _MockInput(label: 'Email', icon: Icons.email_outlined),
          _MockInput(label: 'Phone Number', icon: Icons.phone_outlined),
          _MockInput(label: 'Location', icon: Icons.location_on_outlined),
          _MockInput(label: 'Professional Summary', icon: Icons.notes_rounded, maxLines: 4),
        ];
      case 1:
        return const [
          _MockInput(label: 'Institution Name', icon: Icons.school_outlined),
          _MockInput(label: 'Degree / Qualification', icon: Icons.workspace_premium_outlined),
          _MockInput(label: 'Field of Study', icon: Icons.menu_book_outlined),
          _MockInput(label: 'Start Date', icon: Icons.calendar_today_outlined),
          _MockInput(label: 'End Date', icon: Icons.event_outlined),
        ];
      case 2:
        return const [
          _MockInput(label: 'Job Title', icon: Icons.work_outline_rounded),
          _MockInput(label: 'Company Name', icon: Icons.business_outlined),
          _MockInput(label: 'Start Date', icon: Icons.calendar_today_outlined),
          _MockInput(label: 'End Date', icon: Icons.event_outlined),
          _MockInput(label: 'Job Description', icon: Icons.description_outlined, maxLines: 4),
        ];
      default:
        return const [
          _MockInput(label: 'Skills', icon: Icons.psychology_outlined, maxLines: 3),
          _MockInput(label: 'Certifications', icon: Icons.verified_outlined, maxLines: 3),
          _MockInput(label: 'Licences', icon: Icons.badge_outlined, maxLines: 3),
        ];
    }
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _backStep,
              style: OutlinedButton.styleFrom(
                foregroundColor: _textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(_currentStep == 3 ? 'Finish' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockInput extends StatelessWidget {
  final String label;
  final IconData icon;
  final int maxLines;

  const _MockInput({
    required this.label,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: Color(0xFF687588), size: 20),
          ),
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFF163B65), width: 1.6),
          ),
        ),
      ),
    );
  }
}