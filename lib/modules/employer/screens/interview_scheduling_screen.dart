import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/employer_service.dart';

class InterviewSchedulingScreen extends StatefulWidget {
  final String applicantId;
  final String applicantName;
  final String seekerId;
  final String? initialPreferredTime;
  final String? rejectionReason;

  const InterviewSchedulingScreen({
    super.key,
    required this.applicantId,
    required this.applicantName,
    required this.seekerId,
    this.initialPreferredTime,
    this.rejectionReason,
  });

  @override
  State<InterviewSchedulingScreen> createState() =>
      _InterviewSchedulingScreenState();
}

class _InterviewSchedulingScreenState extends State<InterviewSchedulingScreen> {
  static const Color _navy = Color(0xFF163B65);
  static const Color _navyLight = Color(0xFF335D8A);
  static const Color _bgColor = Color(0xFFF4F7FB);
  static const Color _surfaceSoft = Color(0xFFF7F9FC);
  static const Color _textDark = Color(0xFF1B2433);
  static const Color _textMuted = Color(0xFF687588);
  static const Color _errorRed = Color(0xFFC24E4E);
  static const Color _successGreen = Color(0xFF2D8A5D);

  static const List<int> _durationPresets = [30, 45, 60, 90];

  static const List<TimeOfDay> _quickStartSlots = [
    TimeOfDay(hour: 9, minute: 0),
    TimeOfDay(hour: 10, minute: 0),
    TimeOfDay(hour: 11, minute: 0),
    TimeOfDay(hour: 14, minute: 0),
    TimeOfDay(hour: 15, minute: 0),
    TimeOfDay(hour: 16, minute: 0),
    TimeOfDay(hour: 17, minute: 0),
    TimeOfDay(hour: 20, minute: 0),
  ];

  final _employerService = EmployerService();
  final _linkController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int? _selectedDurationMinutes = 60;
  String _meetingMethod = 'online';

  bool _isSaving = false;

  String? _formError;
  String? _scheduleError;
  String? _meetingDetailsError;

  @override
  void initState() {
    super.initState();
    _prefillFromPreferredTime();
    if (_selectedDate == null) {
      final now = DateTime.now();
      // Default to tomorrow if it is already late evening (>= 9:30 PM), else today
      final base = (now.hour > 21 || (now.hour == 21 && now.minute >= 30))
          ? now.add(const Duration(days: 1))
          : now;
      _selectedDate = DateTime(base.year, base.month, base.day);
    } else {
      _scheduleError = _computeTimingValidationError();
    }
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isSelectedDateToday {
    if (_selectedDate == null) return false;
    return _isSameDay(_selectedDate!, DateTime.now());
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  TimeOfDay _fromMinutes(int totalMinutes) {
    final clamped = totalMinutes.clamp(0, 23 * 60 + 59);
    return TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60);
  }

  bool _isSlotPassedOnSelectedDate(TimeOfDay slot) {
    if (_selectedDate == null) return false;
    final now = DateTime.now();
    final today = _dateOnly(now);
    final chosenDay = _dateOnly(_selectedDate!);

    if (chosenDay.isBefore(today)) return true;
    if (_isSameDay(chosenDay, today)) {
      final slotDateTime = DateTime(
        chosenDay.year,
        chosenDay.month,
        chosenDay.day,
        slot.hour,
        slot.minute,
      );
      return !slotDateTime.isAfter(now);
    }
    return false;
  }

  TimeOfDay _suggestInitialStartTime() {
    if (_startTime != null && !_isSlotPassedOnSelectedDate(_startTime!)) {
      return _startTime!;
    }
    if (_isSelectedDateToday) {
      final now = DateTime.now();
      // Round up to the next 15-minute mark at least 5 minutes in the future
      final minFuture = now.add(const Duration(minutes: 5));
      final roundedMinutes =
          ((minFuture.hour * 60 + minFuture.minute + 14) ~/ 15) * 15;
      if (roundedMinutes <= 23 * 60 + 30) {
        return _fromMinutes(roundedMinutes);
      }
      return const TimeOfDay(hour: 23, minute: 45);
    }
    return const TimeOfDay(hour: 10, minute: 0);
  }

  TimeOfDay _calculateEndTimeForStart(TimeOfDay start, int durationMinutes) {
    final rawEnd = _toMinutes(start) + durationMinutes;
    // Prevent wrapping past midnight on a single-day schedule
    final cappedEnd = rawEnd > (23 * 60 + 59) ? (23 * 60 + 59) : rawEnd;
    return _fromMinutes(cappedEnd);
  }

  void _syncDurationPresetFromTimes() {
    if (_startTime == null || _endTime == null) return;
    final diff = _toMinutes(_endTime!) - _toMinutes(_startTime!);
    if (_durationPresets.contains(diff)) {
      _selectedDurationMinutes = diff;
    } else {
      _selectedDurationMinutes = null;
    }
  }

  String? _computeTimingValidationError() {
    if (_selectedDate == null) return null;

    final now = DateTime.now();
    final today = _dateOnly(now);
    final chosenDay = _dateOnly(_selectedDate!);

    if (chosenDay.isBefore(today)) {
      return 'The selected date has already passed. Please choose today or a future date.';
    }

    if (_startTime != null) {
      final startDateTime = DateTime(
        chosenDay.year,
        chosenDay.month,
        chosenDay.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      if (!startDateTime.isAfter(now)) {
        return 'Start time (${_formatTimeOfDay(_startTime!)}) has already passed for today. Please select a future time or choose another date.';
      }
    }

    if (_startTime != null && _endTime != null) {
      final startMins = _toMinutes(_startTime!);
      final endMins = _toMinutes(_endTime!);

      if (endMins <= startMins) {
        return 'End time must be later than start time.';
      }
      if (endMins - startMins < 15) {
        return 'Interview duration must be at least 15 minutes.';
      }
    }

    return null;
  }

  void _prefillFromPreferredTime() {
    final raw = widget.initialPreferredTime?.trim();
    if (raw == null || raw.isEmpty) return;

    try {
      // Expected format: "YYYY-MM-DD | HH:mm - HH:mm"
      final parts = raw.split('|');
      if (parts.isNotEmpty) {
        final parsedDate = DateTime.tryParse(parts[0].trim());
        if (parsedDate != null) {
          _selectedDate = _dateOnly(parsedDate);
        }
      }

      if (parts.length > 1) {
        final timeRange = parts[1].trim().split('-');
        TimeOfDay? parseTimeToken(String token) {
          final hm = token.trim().split(':');
          if (hm.length < 2) return null;
          final h = int.tryParse(hm[0]);
          final m = int.tryParse(hm[1]);
          if (h == null || m == null) return null;
          return TimeOfDay(hour: h, minute: m);
        }

        if (timeRange.isNotEmpty) {
          _startTime = parseTimeToken(timeRange[0]);
        }
        if (timeRange.length > 1) {
          _endTime = parseTimeToken(timeRange[1]);
        }
        _syncDurationPresetFromTimes();
      }
    } catch (_) {
      // Ignore parsing errors and let employer pick manually
    }
  }

  void _selectDate(DateTime date) {
    final normalized = _dateOnly(date);
    setState(() {
      _selectedDate = normalized;
      _formError = null;
      _scheduleError = _computeTimingValidationError();
    });
  }

  void _selectQuickStartSlot(TimeOfDay slot) {
    if (_isSlotPassedOnSelectedDate(slot)) return;
    final duration = _selectedDurationMinutes ?? 60;
    setState(() {
      _startTime = slot;
      _selectedDurationMinutes = duration;
      _endTime = _calculateEndTimeForStart(slot, duration);
      _formError = null;
      _scheduleError = _computeTimingValidationError();
    });
  }

  void _selectDurationPreset(int minutes) {
    setState(() {
      _selectedDurationMinutes = minutes;
      if (_startTime != null) {
        _endTime = _calculateEndTimeForStart(_startTime!, minutes);
      }
      _formError = null;
      _scheduleError = _computeTimingValidationError();
    });
  }

  Future<void> _pickCalendarDate() async {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final lastDate = today.add(const Duration(days: 365));
    DateTime initial = _selectedDate != null ? _dateOnly(_selectedDate!) : today;
    if (initial.isBefore(today)) initial = today;
    if (initial.isAfter(lastDate)) initial = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: lastDate,
      helpText: 'SELECT INTERVIEW DATE',
      confirmText: 'Confirm',
      cancelText: 'Cancel',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _navy,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _textDark,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: _navy,
              headerForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _selectDate(picked);
    }
  }

  Future<void> _pickCustomTime({required bool isStart}) async {
    final TimeOfDay initial = isStart
        ? _suggestInitialStartTime()
        : (_endTime ??
            (_startTime != null
                ? _calculateEndTimeForStart(
                    _startTime!,
                    _selectedDurationMinutes ?? 60,
                  )
                : const TimeOfDay(hour: 11, minute: 0)));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText:
          isStart ? 'SELECT INTERVIEW START TIME' : 'SELECT INTERVIEW END TIME',
      confirmText: 'Confirm',
      cancelText: 'Cancel',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _navy,
              onPrimary: Colors.white,
              primaryContainer: Color(0xFFDCEBFB),
              onPrimaryContainer: _navy,
              surface: Colors.white,
              onSurface: _textDark,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              dialBackgroundColor: _surfaceSoft,
              dialHandColor: _navy,
              hourMinuteColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? const Color(0xFFDCEBFB)
                    : _surfaceSoft,
              ),
              hourMinuteTextColor: WidgetStateColor.resolveWith(
                (states) =>
                    states.contains(WidgetState.selected) ? _navy : _textDark,
              ),
              dayPeriodColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? _navy
                    : _surfaceSoft,
              ),
              dayPeriodTextColor: WidgetStateColor.resolveWith(
                (states) =>
                    states.contains(WidgetState.selected)
                        ? Colors.white
                        : _textMuted,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startTime = picked;
        if (_selectedDurationMinutes != null) {
          _endTime =
              _calculateEndTimeForStart(picked, _selectedDurationMinutes!);
        } else if (_endTime != null &&
            _toMinutes(_endTime!) <= _toMinutes(picked)) {
          _endTime = _calculateEndTimeForStart(picked, 60);
          _syncDurationPresetFromTimes();
        }
      } else {
        _endTime = picked;
        _syncDurationPresetFromTimes();
      }
      _formError = null;
      _scheduleError = _computeTimingValidationError();
    });
  }

  Future<void> _saveSchedule() async {
    setState(() {
      _formError = null;
      _scheduleError = null;
      _meetingDetailsError = null;
    });

    final hasMissingSchedule =
        _selectedDate == null || _startTime == null || _endTime == null;
    final timingError =
        hasMissingSchedule ? null : _computeTimingValidationError();
    final hasMissingMeetingDetails =
        _meetingMethod != 'internal' && _linkController.text.trim().isEmpty;

    if (hasMissingSchedule || timingError != null || hasMissingMeetingDetails) {
      setState(() {
        if (hasMissingSchedule) {
          _scheduleError =
              'Please select an interview date, start time, and end time.';
        } else if (timingError != null) {
          _scheduleError = timingError;
        }

        if (hasMissingMeetingDetails) {
          _meetingDetailsError = _meetingMethod == 'online'
              ? 'Please provide the meeting link.'
              : 'Please provide the office location or address.';
        }

        _formError = timingError ??
            'Please complete all required fields before confirming the schedule.';
      });
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

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Interview scheduled successfully!'),
          backgroundColor: _successGreen,
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() {
        _formError = 'Failed to schedule interview. Please try again.';
      });
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
      backgroundColor: _bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _buildTopBar(context),
            const SizedBox(height: 16),
            _buildHeroCard(methodLabel),
            if ((widget.initialPreferredTime ?? '').trim().isNotEmpty ||
                (widget.rejectionReason ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              _buildCandidatePreferenceBanner(),
            ],
            const SizedBox(height: 20),
            _buildScheduleSetupCard(context),
            const SizedBox(height: 18),
            _buildSectionCard(
              title: 'Meeting Method',
              subtitle:
                  'Choose how the interview will happen and provide the related access details.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _meetingMethod,
                    isExpanded: true,
                    decoration: _buildInputDecoration(
                      label: 'Meeting Method',
                      icon: Icons.video_settings_rounded,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'online',
                        child: Text(
                          'Online (Google Meet, Zoom, etc.)',
                          overflow: TextOverflow.ellipsis,
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
                      setState(() {
                        _meetingMethod = val;
                        _formError = null;
                        if (val == 'internal' ||
                            _linkController.text.trim().isNotEmpty) {
                          _meetingDetailsError = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_meetingMethod == 'internal')
                    _buildInternalMeetingNotice()
                  else
                    TextField(
                      controller: _linkController,
                      onChanged: (_) {
                        if (_meetingDetailsError == null && _formError == null) {
                          return;
                        }
                        setState(() {
                          _meetingDetailsError = null;
                          _formError = null;
                        });
                      },
                      decoration: _buildInputDecoration(
                        label: _meetingMethod == 'online'
                            ? 'Meeting Link (URL)'
                            : 'Office Location / Address',
                        icon: _meetingMethod == 'online'
                            ? Icons.link_rounded
                            : Icons.location_on_rounded,
                        errorText: _meetingDetailsError,
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
                    value: _buildSessionSummary(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_formError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE9E9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: _errorRed,
                      size: 19,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _formError!,
                        style: const TextStyle(
                          color: _errorRed,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
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
                      backgroundColor: _navy,
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

  Widget _buildCandidatePreferenceBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBDD6F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.event_available_rounded,
                size: 18,
                color: _navy,
              ),
              SizedBox(width: 8),
              Text(
                'Candidate Reschedule Preference',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
            ],
          ),
          if ((widget.initialPreferredTime ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Preferred Slot: ${widget.initialPreferredTime!.trim()} (pre-filled below)',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
          ],
          if ((widget.rejectionReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Decline Reason: "${widget.rejectionReason!.trim()}"',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Color(0xFF4F5C6C),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleSetupCard(BuildContext context) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final List<DateTime> nextSevenDays =
        List.generate(7, (index) => today.add(Duration(days: index)));
    final bool isCustomBeyondWeek = _selectedDate != null &&
        !nextSevenDays.any((d) => _isSameDay(d, _selectedDate!));

    final bool allQuickSlotsPassedToday = _isSelectedDateToday &&
        _quickStartSlots.every(_isSlotPassedOnSelectedDate);

    final bool hasStartError = _scheduleError != null &&
        (_startTime == null ||
            (_startTime != null && _isSlotPassedOnSelectedDate(_startTime!)));
    final bool hasEndError = _scheduleError != null &&
        (_endTime == null ||
            (_startTime != null &&
                _endTime != null &&
                _toMinutes(_endTime!) - _toMinutes(_startTime!) < 15));

    return _buildSectionCard(
      title: 'Date & Time Slot',
      subtitle:
          'Choose an upcoming date, pick a quick time slot or custom clock time, and set the session duration.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Date Header + Full Calendar Button
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: _navy,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '1. Select Date',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _pickCalendarDate,
                icon: const Icon(Icons.edit_calendar_rounded, size: 17),
                label: const Text('Open Calendar'),
                style: TextButton.styleFrom(
                  foregroundColor: _navy,
                  backgroundColor: const Color(0xFFEAF2FC),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Horizontal 7-Day Strip (+ custom picked date card if > 7 days out)
          SizedBox(
            height: 86,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (isCustomBeyondWeek && _selectedDate != null) ...[
                  _buildDateDayCard(
                    date: _selectedDate!,
                    badgeLabel: _selectedDate!.isBefore(today)
                        ? 'Past'
                        : DateFormat('MMM').format(_selectedDate!),
                    isSelected: true,
                    isPast: _selectedDate!.isBefore(today),
                  ),
                  const SizedBox(width: 10),
                ],
                ...List.generate(nextSevenDays.length, (i) {
                  final d = nextSevenDays[i];
                  final isSelected =
                      _selectedDate != null && _isSameDay(d, _selectedDate!);
                  final String topLabel = i == 0
                      ? 'Today'
                      : (i == 1 ? 'Tmrw' : DateFormat('EEE').format(d));
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i == nextSevenDays.length - 1 ? 0 : 10,
                    ),
                    child: _buildDateDayCard(
                      date: d,
                      badgeLabel: topLabel,
                      isSelected: isSelected,
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // 3. Duration Preset Selector
          const Row(
            children: [
              Icon(Icons.timelapse_rounded, size: 18, color: _navy),
              SizedBox(width: 8),
              Text(
                '2. Session Duration',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._durationPresets.map((mins) {
                final bool selected = _selectedDurationMinutes == mins;
                final String label = mins == 60
                    ? '1 hr'
                    : (mins == 90 ? '1.5 hr' : '$mins min');
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: _navy,
                  backgroundColor: _surfaceSoft,
                  side: BorderSide(
                    color: selected ? _navy : const Color(0xFFDCE4EE),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : _textDark,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (_) => _selectDurationPreset(mins),
                );
              }),
              if (_selectedDurationMinutes == null &&
                  _startTime != null &&
                  _endTime != null &&
                  _toMinutes(_endTime!) > _toMinutes(_startTime!))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEBFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Custom (${_formatDuration(_toMinutes(_endTime!) - _toMinutes(_startTime!))})',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 22),

          // 4. Quick Start Time Slots + Custom Time Cards
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 18, color: _navy),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '3. Select Time',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
              ),
              if (_isSelectedDateToday)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3DC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Passed times disabled',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB7791F),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickStartSlots.map((slot) {
              final bool isPassed = _isSlotPassedOnSelectedDate(slot);
              final bool isSelected = !isPassed &&
                  _startTime != null &&
                  _startTime!.hour == slot.hour &&
                  _startTime!.minute == slot.minute;

              return Material(
                color: isPassed
                    ? const Color(0xFFF0F3F7)
                    : (isSelected ? _navy : _surfaceSoft),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: isPassed ? null : () => _selectQuickStartSlot(slot),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPassed
                            ? const Color(0xFFE2E8F0)
                            : (isSelected ? _navy : const Color(0xFFD8E2EE)),
                      ),
                    ),
                    child: Text(
                      _formatTimeOfDay(slot),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        decoration:
                            isPassed ? TextDecoration.lineThrough : null,
                        color: isPassed
                            ? const Color(0xFFA0AEC0)
                            : (isSelected ? Colors.white : _textDark),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (allQuickSlotsPassedToday) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3DC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 17,
                    color: Color(0xFFB7791F),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Standard quick slots for today have already passed. Tap Start Time below for a late custom slot or pick Tomorrow.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8C5A11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Custom Start Time & End Time Interactive Cards
          Row(
            children: [
              Expanded(
                child: _buildTimeCard(
                  label: 'START TIME',
                  value: _startTime == null
                      ? 'Tap to set'
                      : _formatTimeOfDay(_startTime!),
                  isSet: _startTime != null,
                  hasError: hasStartError,
                  icon: Icons.play_circle_outline_rounded,
                  onTap: () => _pickCustomTime(isStart: true),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: _textMuted,
                ),
              ),
              Expanded(
                child: _buildTimeCard(
                  label: 'END TIME',
                  value: _endTime == null
                      ? 'Tap to set'
                      : _formatTimeOfDay(_endTime!),
                  isSet: _endTime != null,
                  hasError: hasEndError,
                  icon: Icons.stop_circle_outlined,
                  onTap: () => _pickCustomTime(isStart: false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Live Validation Error OR Confirmed Summary Banner
          if (_scheduleError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE9E9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _errorRed.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: _errorRed,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _scheduleError!,
                      style: const TextStyle(
                        color: _errorRed,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (_selectedDate != null &&
                        _startTime != null &&
                        _endTime != null)
                    ? const Color(0xFFEAF6F0)
                    : _surfaceSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: (_selectedDate != null &&
                          _startTime != null &&
                          _endTime != null)
                      ? _successGreen.withValues(alpha: 0.3)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    (_selectedDate != null &&
                            _startTime != null &&
                            _endTime != null)
                        ? Icons.check_circle_rounded
                        : Icons.event_note_rounded,
                    color: (_selectedDate != null &&
                            _startTime != null &&
                            _endTime != null)
                        ? _successGreen
                        : _navy,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _buildSessionSummary(),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: (_selectedDate != null &&
                                _startTime != null &&
                                _endTime != null)
                            ? const Color(0xFF1F6343)
                            : const Color(0xFF4F5C6C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateDayCard({
    required DateTime date,
    required String badgeLabel,
    required bool isSelected,
    bool isPast = false,
  }) {
    final Color bg = isPast
        ? const Color(0xFFFCE9E9)
        : (isSelected ? _navy : _surfaceSoft);
    final Color borderCol = isPast
        ? _errorRed
        : (isSelected ? _navy : const Color(0xFFDCE4EE));

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _selectDate(date),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderCol, width: isSelected ? 1.5 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                badgeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isPast
                      ? _errorRed
                      : (isSelected ? Colors.white70 : _textMuted),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  color: isPast
                      ? _errorRed
                      : (isSelected ? Colors.white : _textDark),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                DateFormat('MMM').format(date),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isPast
                      ? _errorRed
                      : (isSelected ? Colors.white70 : _textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCard({
    required String label,
    required String value,
    required bool isSet,
    required bool hasError,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final Color borderColor = hasError
        ? _errorRed
        : (isSet ? _navy.withValues(alpha: 0.45) : const Color(0xFFDCE4EE));
    final Color bgColor = hasError
        ? const Color(0xFFFFF5F5)
        : (isSet ? const Color(0xFFF2F7FE) : _surfaceSoft);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: isSet ? 1.3 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: hasError ? _errorRed : _navy,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w800,
                        color: hasError ? _errorRed : _textMuted,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: hasError ? _errorRed : const Color(0xFF9AA5B5),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: hasError
                      ? _errorRed
                      : (isSet ? _textDark : _textMuted),
                ),
              ),
            ],
          ),
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
                color: _navy,
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
              color: _textDark,
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
          colors: [_navy, _navyLight],
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
            'Pick a verified future interview slot and meeting format for your candidate.',
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
                _selectedDate == null
                    ? 'Date not set'
                    : _formatDateWithWeekday(_selectedDate!),
              ),
              _buildHeroMetric(
                Icons.schedule_rounded,
                (_startTime == null || _endTime == null)
                    ? 'Time not set'
                    : '${_formatTimeOfDay(_startTime!)} - ${_formatTimeOfDay(_endTime!)}',
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
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
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
            color: _navy,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'A secure video room will be generated automatically. You can start the meeting later from your Scheduled Interviews workspace.',
              style: TextStyle(
                color: _navy,
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
          child: Icon(icon, color: _navy),
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
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: _textDark,
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
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
        mainAxisSize: MainAxisSize.min,
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
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      errorText: errorText,
      filled: true,
      fillColor: _surfaceSoft,
      prefixIcon: Icon(icon, color: _navy),
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
          color: _navy,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _errorRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _errorRed,
          width: 1.4,
        ),
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final dt = DateTime(2000, 1, 1, t.hour, t.minute);
    return DateFormat('h:mm a').format(dt);
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '0 min';
    final hrs = minutes ~/ 60;
    final rem = minutes % 60;
    if (hrs > 0 && rem > 0) {
      return '${hrs}h ${rem}m';
    }
    if (hrs > 0) {
      return hrs == 1 ? '1 hr' : '$hrs hrs';
    }
    return '$rem min';
  }

  String _buildSessionSummary() {
    final date = _selectedDate == null
        ? 'Date not selected'
        : _formatDateWithWeekday(_selectedDate!);
    if (_startTime == null || _endTime == null) {
      return '$date · Select start & end time';
    }
    final diff = _toMinutes(_endTime!) - _toMinutes(_startTime!);
    final durPart = diff > 0 ? ' (${_formatDuration(diff)})' : '';
    return '$date · ${_formatTimeOfDay(_startTime!)} – ${_formatTimeOfDay(_endTime!)}$durPart';
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

  String _formatDateWithWeekday(DateTime date) {
    return DateFormat('EEE, d MMM yyyy').format(date);
  }
}
