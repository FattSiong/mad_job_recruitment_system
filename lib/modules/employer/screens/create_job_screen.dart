import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/job_model.dart';
import '../../../models/company_model.dart';
import '../../../services/employer_service.dart';

class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({super.key});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _minSalaryController = TextEditingController();
  final _maxSalaryController = TextEditingController();
  final _experienceController = TextEditingController();

  String _selectedJobType = 'Full-time';

  final _employerService = EmployerService();

  List<CompanyModel> _myCompanies = [];
  String? _selectedCompanyID;

  bool _isLoadingCompanies = true;
  bool _isSubmitting = false;
  bool _isFetchingAi = false;

  // Job Location (Using the bypass logic)
  double? _selectedLat;
  double? _selectedLng;

  @override
  void initState() {
    super.initState();
    _loadVerifiedCompanies();
  }

  // 1. Fetch only the employer's VERIFIED companies for the dropdown
  Future<void> _loadVerifiedCompanies() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final allCompanies = await _employerService.getCompanies(currentUser.id, 'employer');

    if (mounted) {
      setState(() {
        // Only allow posting jobs for companies that admins have approved
        _myCompanies = allCompanies.where((c) => c.isVerified).toList();

        // Auto-select the first company if they only have one
        if (_myCompanies.length == 1) {
          _selectedCompanyID = _myCompanies.first.companyID;
        }

        _isLoadingCompanies = false;
      });
    }
  }

  // 2. AI Salary Feature
  Future<void> _suggestSalary() async {
    // 👉 NEW: Block access if they are not Premium
    if (!_hasActiveSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⭐️ Premium Feature! Please upgrade your company plan to use AI suggestions.'),
          backgroundColor: Colors.amber.shade900,
          action: SnackBarAction(
            label: 'UPGRADE',
            textColor: Colors.white,
            onPressed: () {
              // TODO: Route to your Payment/Subscription Screen
              print('Route to billing');
            },
          ),
        ),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Job Title first.')),
      );
      return;
    }

    setState(() => _isFetchingAi = true);

    final int parsedExperience = int.tryParse(_experienceController.text.trim()) ?? 0;

    final suggestionMap = await _employerService.getAiSalarySuggestion(
      _titleController.text.trim(),
      _descriptionController.text.trim(), // Passes the description
      parsedExperience,                   // Passes the years of experience
      _selectedJobType,
    );

    setState(() {
      _minSalaryController.text = suggestionMap['min'] ?? '';
      _maxSalaryController.text = suggestionMap['max'] ?? '';
      _isFetchingAi = false;
    });
  }

  // 3. Location Bypass (Same as Company Registration)
  void _openLocationPicker() {
    setState(() {
      _selectedLat = 3.2162;
      _selectedLng = 101.7289;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test location automatically inserted!'), backgroundColor: Colors.blue),
    );
  }

  // Helper to check if the currently selected company has an active premium plan
  bool get _hasActiveSubscription {
    if (_selectedCompanyID == null) return false;

    // Find the full company object from the dropdown list
    final company = _myCompanies.firstWhere((c) => c.companyID == _selectedCompanyID);

    // 1. Check if the plan is anything other than FREE
    if (company.currentPlanType.toUpperCase() == 'FREE') return false;

    // 2. Check if the subscription date has expired
    // if (company.subscriptionEndAt == null) return false;
    // if (company.subscriptionEndAt!.isBefore(DateTime.now())) return false;

    return true; // Passed all checks!
  }

  // 4. Submit Job to Database
  Future<void> _submitJob() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    // 1. Basic Empty Checks
    if (_selectedCompanyID == null ||
        _titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _selectedLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields and set a location.')),
      );
      return;
    }

    // 2. Extract and Parse Numbers safely
    final minStr = _minSalaryController.text.trim();
    final maxStr = _maxSalaryController.text.trim();

    final int? minSalary = int.tryParse(minStr);
    final int? maxSalary = int.tryParse(maxStr);
    final int parsedExperience = int.tryParse(_experienceController.text.trim()) ?? 0;

    // 3. Logical Salary Validation
    if (minSalary != null && maxSalary != null) {
      if (minSalary > maxSalary) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Minimum salary cannot be greater than maximum salary.'),
            backgroundColor: Colors.red,
          ),
        );
        return; // Stop the submission
      }
    }

    setState(() => _isSubmitting = true);

    // Build the final salary string
    String? finalSalaryRange;

    if (_selectedJobType == 'Part Time') {
      // 👉 NEW: Part Time Formatting
      if (minSalary != null) {
        finalSalaryRange = 'RM $minSalary / hr';
      } else {
        finalSalaryRange = '';
      }
    } else {
      // 👉 Original: Full Time Formatting
      if (minSalary != null && maxSalary != null) {
        finalSalaryRange = 'RM $minSalary - RM $maxSalary';
      } else if (minSalary != null) {
        finalSalaryRange = 'RM $minSalary';
      } else {
        finalSalaryRange = '';
      }
    }

    // 5. Create and save the model
    final newJob = JobModel(
      companyID: _selectedCompanyID!,
      employerID: currentUser!.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      salaryRange: finalSalaryRange,
      latitude: _selectedLat,
      longitude: _selectedLng,
      minExperienceYears: parsedExperience,
      jobType: _selectedJobType,
    );

    final createdJob = await _employerService.createJobPosting(newJob);

    setState(() => _isSubmitting = false);

    if (createdJob != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job Posted Successfully!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post job. Please try again.')),
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
      appBar: AppBar(title: const Text('Post New Job')),
      body: _isLoadingCompanies
          ? const Center(child: CircularProgressIndicator())
          : _myCompanies.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'You need an approved company before you can post a job. Please register a company and wait for admin verification.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Company Selection Dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedCompanyID,
            decoration: const InputDecoration(
              labelText: 'Select Company',
              border: OutlineInputBorder(),
            ),
            items: _myCompanies.map((company) {
              return DropdownMenuItem(
                value: company.companyID,
                child: Text(company.name),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedCompanyID = value),
          ),
          const SizedBox(height: 16),

          // Job Title
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Job Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            initialValue: _selectedJobType,
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
                setState(() => _selectedJobType = value);
              }
            },
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _experienceController,
            keyboardType: TextInputType.number, // Forces the number keypad
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Minimum Working Experience (Years)',
              hintText: 'e.g., 0 for fresh grad, 2 for intermediate',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // AI Salary Suggestion Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _minSalaryController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    // 👉 NEW: Dynamic label based on Job Type
                    labelText: _selectedJobType == 'Part-time' ? 'Hourly Rate' : 'Min Salary',
                    prefixText: 'RM ',
                    // 👉 NEW: Show the /hr suffix for Part Time
                    suffixText: _selectedJobType == 'Part-time' ? ' / hr' : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),

              // 👉 NEW: Only show the Max field if it's Full Time
              if (_selectedJobType == 'Full-time') ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _maxSalaryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Max (Optional)',
                      prefixText: 'RM ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],

              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isFetchingAi ? null : _suggestSalary,
                    icon: _isFetchingAi
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(
                        _hasActiveSubscription ? Icons.auto_awesome : Icons.lock,
                        color: Colors.amber
                    ),
                    label: const Text('AI Suggest'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.withValues(alpha: 0.1),
                      foregroundColor: Colors.amber.shade900,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Job Location Setup
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Job Location', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  _selectedLat == null ? 'Location required for Job Seekers to find this.' : 'Coordinates Set: $_selectedLat, $_selectedLng',
                  style: TextStyle(color: _selectedLat == null ? Colors.red : Colors.black),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _openLocationPicker,
                  icon: const Icon(Icons.pin_drop),
                  label: Text(_selectedLat == null ? 'Set Location on Map' : 'Change Location'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Job Description
          TextField(
            controller: _descriptionController,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Full Job Description & Requirements',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 32),

          // Submit Button
          _isSubmitting
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
            onPressed: _submitJob,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Publish Job Posting', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}