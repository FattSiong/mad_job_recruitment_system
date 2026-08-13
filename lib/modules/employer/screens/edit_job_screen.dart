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
    // Keep the stored value compatible with the choices shown in the form.
    _selectedJobType = job.jobType == 'Part Time'
        ? 'Part-time'
        : job.jobType == 'Full Time'
        ? 'Full-time'
        : job.jobType;
    _selectedLat = job.latitude;
    _selectedLng = job.longitude;

    // 🧠 The tricky part: Extracting the numbers back out of the formatted string
    if (job.salaryRange != null && job.salaryRange!.isNotEmpty) {
      // Remove the "RM " and commas
      String rawSalary = job.salaryRange!
          .replaceAll('RM ', '')
          .replaceAll(',', '');

      if (_selectedJobType == 'Part-time') {
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
    if (_selectedJobType == 'Full-time' &&
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
    if (_selectedJobType == 'Part-time') {
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
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: _isSubmitting
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 16),
                  _buildHeroCard(),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    title: 'Position Details',
                    subtitle: 'Keep the role title, employment type, and experience requirement up to date.',
                    child: Column(
                      children: [
                        _buildStyledField(
                          controller: _titleController,
                          label: 'Job Title',
                          icon: Icons.work_outline_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildJobTypeField(),
                        const SizedBox(height: 16),
                        _buildStyledField(
                          controller: _experienceController,
                          label: 'Minimum Working Experience (Years)',
                          icon: Icons.workspace_premium_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildSectionCard(
                    title: 'Compensation',
                    subtitle: _selectedJobType == 'Part-time'
                        ? 'Set the hourly rate for this part-time role.'
                        : 'Provide a monthly salary range for candidates.',
                    child: _buildSalaryFields(),
                  ),
                  const SizedBox(height: 18),
                  _buildSectionCard(
                    title: 'Job Location',
                    subtitle: 'Update the map location candidates will see for this role.',
                    child: _buildLocationEditor(),
                  ),
                  const SizedBox(height: 18),
                  _buildSectionCard(
                    title: 'Job Description',
                    subtitle: 'Describe the responsibilities, requirements, and opportunities for this role.',
                    child: _buildStyledField(
                      controller: _descriptionController,
                      label: 'Full Job Description',
                      icon: Icons.article_outlined,
                      maxLines: 8,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSavePanel(),
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
              child: Icon(Icons.arrow_back_rounded, color: Color(0xFF163B65)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Edit Job',
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

  Widget _buildHeroCard() {
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Job Posting Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.job.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Refresh this posting so candidates see the latest role details, compensation, and location.',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1B2433))),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF687588))),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildJobTypeField() {
    return DropdownButtonFormField<String>(
      value: _selectedJobType,
      decoration: _fieldDecoration('Job Type', Icons.schedule_rounded),
      items: const [
        DropdownMenuItem(value: 'Full-time', child: Text('Full-time')),
        DropdownMenuItem(value: 'Part-time', child: Text('Part-time')),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _selectedJobType = value;
          if (value == 'Part-time') _maxSalaryController.clear();
        });
      },
    );
  }

  Widget _buildSalaryFields() {
    final isPartTime = _selectedJobType == 'Part-time';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildStyledField(
            controller: _minSalaryController,
            label: isPartTime ? 'Hourly Rate' : 'Min Salary',
            icon: Icons.payments_outlined,
            prefixText: 'RM ',
            suffixText: isPartTime ? ' / hr' : null,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        if (!isPartTime) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _buildStyledField(
              controller: _maxSalaryController,
              label: 'Max Salary',
              icon: Icons.payments_outlined,
              prefixText: 'RM ',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationEditor() {
    final hasLocation = _selectedLat != null && _selectedLng != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Color(0xFF163B65)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasLocation
                      ? 'Coordinates: ${_selectedLat!.toStringAsFixed(4)}, ${_selectedLng!.toStringAsFixed(4)}'
                      : 'No location selected yet',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1B2433)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _openLocationPicker,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Update Location on Map'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF163B65),
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFF163B65)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
    String? suffixText,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: _fieldDecoration(label, icon, prefixText: prefixText, suffixText: suffixText),
    );
  }

  InputDecoration _fieldDecoration(
    String label,
    IconData icon, {
    String? prefixText,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      prefixText: prefixText,
      suffixText: suffixText,
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF163B65), width: 1.4),
      ),
    );
  }

  Widget _buildSavePanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Save your changes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1B2433))),
          const SizedBox(height: 8),
          const Text(
            'These updates will be reflected in the job posting after saving.',
            style: TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF687588)),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _updateJob,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF163B65),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
