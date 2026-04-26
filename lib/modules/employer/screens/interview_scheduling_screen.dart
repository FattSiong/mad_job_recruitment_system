import 'package:flutter/material.dart';

import '../../../services/employer_service.dart';

class InterviewSchedulingScreen extends StatefulWidget {
  final String applicantId;
  final String applicantName;
  final String seekerId;

  const InterviewSchedulingScreen({
    super.key,
    required this.applicantId,
    required this.applicantName,
    required this.seekerId,
  });

  @override
  State<InterviewSchedulingScreen> createState() =>
      _InterviewSchedulingScreenState();
}

class _InterviewSchedulingScreenState extends State<InterviewSchedulingScreen> {
  final _employerService = EmployerService();
  final _linkController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _meetingMethod = 'online';

  bool _isSaving = false;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
    }
  }

  Future<void> _saveSchedule() async {
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a date and time.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_meetingMethod != 'internal' && _linkController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please provide a meeting link or location.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await _employerService.scheduleInterview(
      applicantId: widget.applicantId,
      seekerId: widget.seekerId,
      date: _selectedDate!,
      startTime: _startTime!,
      endTime: _endTime!,
      meetingMethod: _meetingMethod,
      meetingLink:
      _meetingMethod == 'internal' ? null : _linkController.text.trim(),
    );

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interview scheduled successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to schedule interview.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final methodLabel = _getMeetingMethodLabel(_meetingMethod);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _buildTopBar(context),
            const SizedBox(height: 16),
            _buildHeroCard(methodLabel),
            const SizedBox(height: 20),
            _buildSectionCard(
              title: 'Schedule Setup',
              subtitle:
              'Pick the interview date, define the time range, and keep everything in one compact block.',
              child: Column(
                children: [
                  _buildCompactPickerTile(
                    icon: Icons.calendar_today_rounded,
                    title: 'Interview Date',
                    value: _selectedDate == null
                        ? 'Select date'
                        : _formatDate(_selectedDate!),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactPickerTile(
                          icon: Icons.schedule_rounded,
                          title: 'Start Time',
                          value: _startTime == null
                              ? 'Select time'
                              : _startTime!.format(context),
                          onTap: () => _pickTime(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCompactPickerTile(
                          icon: Icons.timelapse_rounded,
                          title: 'End Time',
                          value: _endTime == null
                              ? 'Select time'
                              : _endTime!.format(context),
                          onTap: () => _pickTime(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.event_note_rounded,
                          color: Color(0xFF163B65),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _buildSessionSummary(context),
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: Color(0xFF4F5C6C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _buildSectionCard(
              title: 'Meeting Method',
              subtitle:
              'Choose how the interview will happen and provide the related access details.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _meetingMethod,
                    isExpanded: true, // 👈 FIX 1: Prevents the long text from overflowing the Dropdown!
                    decoration: _buildInputDecoration(
                      label: 'Meeting Method',
                      icon: Icons.video_settings_rounded,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'online',
                        child: Text(
                            'Online (Google Meet, Zoom, etc.)',
                            overflow: TextOverflow.ellipsis // 👈 Safe text truncation
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'offline',
                        child: Text('Offline (In-Person / Office)'),
                      ),
                      DropdownMenuItem(
                        value: 'internal',
                        child: Text('App Internal Interview'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _meetingMethod = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_meetingMethod == 'internal')
                    _buildInternalMeetingNotice()
                  else
                    TextField(
                      controller: _linkController,
                      decoration: _buildInputDecoration(
                        label: _meetingMethod == 'online'
                            ? 'Meeting Link (URL)'
                            : 'Office Location / Address',
                        icon: _meetingMethod == 'online'
                            ? Icons.link_rounded
                            : Icons.location_on_rounded,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _buildSectionCard(
              title: 'Candidate Review',
              subtitle:
              'Confirm who this interview is for and review the selected arrangement before saving.',
              child: Column(
                children: [
                  _buildReviewRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Candidate',
                    value: widget.applicantName,
                  ),
                  const SizedBox(height: 14),
                  _buildReviewRow(
                    icon: Icons.meeting_room_rounded,
                    label: 'Meeting Type',
                    value: methodLabel,
                  ),
                  const SizedBox(height: 14),
                  _buildReviewRow(
                    icon: Icons.schedule_send_rounded,
                    label: 'Prepared Session',
                    value: _buildSessionSummary(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _isSaving
                ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(child: CircularProgressIndicator()),
            )
                : ElevatedButton.icon(
              onPressed: _saveSchedule,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Confirm Schedule'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF163B65),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF163B65),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Schedule Interview',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(String methodLabel) {
    return Container(
      padding: const EdgeInsets.all(24),
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
          _buildHeroChip(
            icon: Icons.calendar_month_rounded,
            text: 'Interview Planner',
          ),
          const SizedBox(height: 20),
          Text(
            widget.applicantName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Create a polished interview schedule with a cleaner, tighter workflow that matches your employer workspace.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroMetric(
                Icons.event_available_rounded,
                _selectedDate == null ? 'Date not set' : _formatDate(_selectedDate!),
              ),
              _buildHeroMetric(
                Icons.schedule_rounded,
                (_startTime == null || _endTime == null)
                    ? 'Time not set'
                    : '${_startTime!.format(context)} - ${_endTime!.format(context)}',
              ),
              _buildHeroMetric(
                Icons.video_settings_rounded,
                methodLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF687588),
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildCompactPickerTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCEBFB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF163B65), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1, // 👈 FIX 2: Prevents wrapping bugs
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF687588),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1, // 👈 FIX 2: Prevents wrapping bugs
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B2433),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.expand_more_rounded,
                color: Color(0xFF9AA5B5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInternalMeetingNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDCEBFB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF163B65),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'A secure video room will be generated automatically. You can start the meeting later from your Scheduled Interviews workspace.',
              style: TextStyle(
                color: Color(0xFF163B65),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF163B65)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF687588),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Color(0xFF1B2433),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // 👈 FIX 3: Changed from max to min!
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // 👈 FIX 3: Changed from max to min!
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      prefixIcon: Icon(icon, color: const Color(0xFF163B65)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD6DEE8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD6DEE8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFF163B65),
          width: 1.4,
        ),
      ),
    );
  }

  String _buildSessionSummary(BuildContext context) {
    final date =
    _selectedDate == null ? 'Date not selected' : _formatDate(_selectedDate!);
    final time = (_startTime == null || _endTime == null)
        ? 'Time not selected'
        : '${_startTime!.format(context)} - ${_endTime!.format(context)}';

    return '$date, $time';
  }

  String _getMeetingMethodLabel(String method) {
    switch (method) {
      case 'offline':
        return 'Offline Meeting';
      case 'internal':
        return 'App Internal Interview';
      default:
        return 'Online Meeting';
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}