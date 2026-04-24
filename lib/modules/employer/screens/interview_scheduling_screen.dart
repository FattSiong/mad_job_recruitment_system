import 'package:flutter/material.dart';
import '../../../services/employer_service.dart';

class InterviewSchedulingScreen extends StatefulWidget {
  final String applicantId;
  final String applicantName;

  const InterviewSchedulingScreen({super.key, required this.applicantId, required this.applicantName});

  @override
  State<InterviewSchedulingScreen> createState() => _InterviewSchedulingScreenState();
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
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time != null) {
      setState(() {
        if (isStart) _startTime = time;
        else _endTime = time;
      });
    }
  }

  Future<void> _saveSchedule() async {
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
      return;
    }

    if (_meetingMethod != 'internal' && _linkController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a meeting link or location.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await _employerService.scheduleInterview(
      applicantId: widget.applicantId,
      date: _selectedDate!,
      startTime: _startTime!,
      endTime: _endTime!,
      meetingMethod: _meetingMethod,
      meetingLink: _meetingMethod == 'internal' ? null : _linkController.text.trim(),
    );

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Interview Scheduled successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // 👉 Return 'true' so the detail screen knows to refresh!
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to schedule interview.'), backgroundColor: Colors.red),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule Interview')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Scheduling interview for:', style: TextStyle(color: Colors.grey.shade600)),
          Text(widget.applicantName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),

          // --- DATE & TIME PICKERS ---
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
            leading: const Icon(Icons.calendar_today, color: Colors.blue),
            title: Text(_selectedDate == null ? 'Select Date' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
            onTap: _pickDate,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                  leading: const Icon(Icons.access_time, color: Colors.blue),
                  title: Text(_startTime == null ? 'Start Time' : _startTime!.format(context)),
                  onTap: () => _pickTime(isStart: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                  leading: const Icon(Icons.access_time_filled, color: Colors.blue),
                  title: Text(_endTime == null ? 'End Time' : _endTime!.format(context)),
                  onTap: () => _pickTime(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // --- MEETING METHOD ---
          const Text('Meeting Method', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _meetingMethod,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'online', child: Text('Online (Google Meet, Zoom, etc.)')),
              DropdownMenuItem(value: 'offline', child: Text('Offline (In-Person/Office)')),
              DropdownMenuItem(value: 'internal', child: Text('App Internal Interview')),
            ],
            onChanged: (val) => setState(() => _meetingMethod = val!),
          ),
          const SizedBox(height: 16),

          if (_meetingMethod != 'internal')
            TextField(
              controller: _linkController,
              decoration: InputDecoration(
                labelText: _meetingMethod == 'online' ? 'Meeting Link (URL)' : 'Office Location/Address',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(_meetingMethod == 'online' ? Icons.link : Icons.location_on),
              ),
            ),
          const SizedBox(height: 48),

          _isSaving
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
            onPressed: _saveSchedule,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('Confirm Schedule', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}