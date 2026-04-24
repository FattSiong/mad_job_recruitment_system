import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/job_model.dart';
import '../../../services/employer_service.dart';

class EditJobScreen extends StatefulWidget {
  final JobModel job;

  const EditJobScreen({super.key, required this.job});

  @override
  State<EditJobScreen> createState() => _EditJobScreenState();
}

class _EditJobScreenState extends State<EditJobScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _minSalaryController = TextEditingController();
  final _maxSalaryController = TextEditingController();
  final _experienceController = TextEditingController();

  final _employerService = EmployerService();

  late String _selectedJobType;
  double? _selectedLat;
  double? _selectedLng;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final job = widget.job;

    _titleController.text = job.title;
    _descriptionController.text = job.description;
    _experienceController.text = job.minExperienceYears.toString();
    _selectedJobType = job.jobType;
    _selectedLat = job.latitude;
    _selectedLng = job.longitude;

    // 🧠 The tricky part: Extracting the numbers back out of the formatted string
    if (job.salaryRange != null && job.salaryRange!.isNotEmpty) {
      // Remove the "RM " and commas
      String rawSalary = job.salaryRange!
          .replaceAll('RM ', '')
          .replaceAll(',', '');

      if (_selectedJobType == 'Part Time') {
        // Example: "15 / hr" -> "15"
        _minSalaryController.text = rawSalary.replaceAll(' / hr', '').trim();
      } else {
        if (rawSalary.contains('-')) {
          // Example: "4000 - 6000"
          final parts = rawSalary.split('-');
          if (parts.length == 2) {
            _minSalaryController.text = parts[0].trim();
            _maxSalaryController.text = parts[1].trim();
          }
        } else {
          // Fixed full-time salary: Example "4000"
          _minSalaryController.text = rawSalary.trim();
        }
      }
    }
  }

  void _openLocationPicker() {
    setState(() {
      _selectedLat = 3.2162;
      _selectedLng = 101.7289;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test location updated!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _updateJob() async {
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _selectedLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields and set a location.'),
        ),
      );
      return;
    }

    final minStr = _minSalaryController.text.trim();
    final maxStr = _maxSalaryController.text.trim();

    final int? minSalary = int.tryParse(minStr);
    final int? maxSalary = int.tryParse(maxStr);
    final int parsedExperience =
        int.tryParse(_experienceController.text.trim()) ?? 0;

    // Validation
    if (_selectedJobType == 'Full Time' &&
        minSalary != null &&
        maxSalary != null) {
      if (minSalary > maxSalary) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Minimum salary cannot be greater than maximum salary.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    // Rebuild the salary string
    String? finalSalaryRange;
    if (_selectedJobType == 'Part Time') {
      if (minSalary != null) {
        finalSalaryRange = 'RM $minSalary / hr';
      } else {
        finalSalaryRange = '';
      }
      ;
    } else {
      if (minSalary != null && maxSalary != null) {
        finalSalaryRange = 'RM $minSalary - RM $maxSalary';
      } else if (minSalary != null) {
        finalSalaryRange = 'RM $minSalary';
      } else {
        finalSalaryRange = '';
      }
    }

    // Create the updated model (preserving the unchangeable IDs)
    final updatedJob = JobModel(
      jobID: widget.job.jobID,
      // Ensure we pass the ID so the DB knows which row to update
      companyID: widget.job.companyID,
      employerID: widget.job.employerID,
      status: widget.job.status,
      // Keep current status
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      salaryRange: finalSalaryRange,
      latitude: _selectedLat,
      longitude: _selectedLng,
      minExperienceYears: parsedExperience,
      jobType: _selectedJobType,
    );

    final success = await _employerService.updateJobPosting(updatedJob);

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job Updated Successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      // Pass the updated job back to the detail screen so it refreshes immediately!
      Navigator.pop(context, updatedJob);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update job. Please try again.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _minSalaryController.dispose();
    _maxSalaryController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Job Posting')),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Notice we don't allow changing the Company here.
          // Once a job is posted for a company, it stays with that company.
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Job Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _selectedJobType,
            decoration: const InputDecoration(
              labelText: 'Job Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Full-time', child: Text('Full-time')),
              DropdownMenuItem(value: 'Part-time', child: Text('Part-time')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedJobType = value;
                  if (_selectedJobType == 'Part-time')
                    _maxSalaryController.clear();
                });
              }
            },
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _experienceController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Minimum Working Experience (Years)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _minSalaryController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: _selectedJobType == 'Part-time'
                        ? 'Hourly Rate'
                        : 'Min Salary',
                    prefixText: 'RM ',
                    suffixText: _selectedJobType == 'Part-time'
                        ? ' / hr'
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              if (_selectedJobType == 'Full-time') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxSalaryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Max Salary',
                      prefixText: 'RM ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Job Location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Coordinates: $_selectedLat, $_selectedLng'),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _openLocationPicker,
                  icon: const Icon(Icons.pin_drop),
                  label: const Text('Update Location on Map'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _descriptionController,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Full Job Description',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 32),

          _isSubmitting
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _updateJob,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
        ],
      ),
    );
  }
}
