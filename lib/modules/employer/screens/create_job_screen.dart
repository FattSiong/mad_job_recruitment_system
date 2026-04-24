import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/job_model.dart';
import '../../../models/company_model.dart';
import '../../../services/employer_service.dart';

class CreateJobScreen extends StatefulWidget {
  final CompanyModel? preselectedCompany;

  const CreateJobScreen({super.key, this.preselectedCompany});

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

  double? _selectedLat;
  double? _selectedLng;

  @override
  void initState() {
    super.initState();
    _loadVerifiedCompanies();
  }

  // 👉 PRE-SCREENING QUESTION VARIABLES
  bool _requirePreScreening = false;
  final List<TextEditingController> _questionControllers = [];
  final List<String> _questionTypes = []; // 👉 NEW: Tracks 'Text' or 'File' for each question

  // 👉 NEW: AI Tracking Arrays
  final List<bool> _isGeneratingQuestion = [];
  final List<bool> _isAIGeneratedList = [];

  // Pre-Screening Helper: Add a question
  void _addQuestion() {
    if (_questionControllers.length < 5) {
      setState(() {
        _questionControllers.add(TextEditingController());
        _questionTypes.add('Text');
        _isGeneratingQuestion.add(false); // 👉 NEW
        _isAIGeneratedList.add(false);    // 👉 NEW
      });
    }
  }

  // Pre-Screening Helper: Remove a question
  void _removeQuestion(int index) {
    setState(() {
      _questionControllers[index].dispose();
      _questionControllers.removeAt(index);
      _questionTypes.removeAt(index);
      _isGeneratingQuestion.removeAt(index); // 👉 NEW
      _isAIGeneratedList.removeAt(index);    // 👉 NEW

      if (_questionControllers.isEmpty) {
        _requirePreScreening = false;
      }
    });
  }

  Future<void> _loadVerifiedCompanies() async {
    if (widget.preselectedCompany != null) {
      setState(() {
        _myCompanies = [widget.preselectedCompany!];
        _selectedCompanyID = widget.preselectedCompany!.companyID;
        _isLoadingCompanies = false;
      });
      return;
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final allCompanies = await _employerService.getCompanies(currentUser.id, 'employer');

    if (mounted) {
      setState(() {
        _myCompanies = allCompanies.where((c) => c.isVerified).toList();
        if (_myCompanies.length == 1) {
          _selectedCompanyID = _myCompanies.first.companyID;
        }
        _isLoadingCompanies = false;
      });
    }
  }

  Future<void> _suggestSalary() async {
    if (!_hasActiveSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⭐️ Premium Feature! Please upgrade your company plan to use AI suggestions.'),
          backgroundColor: Colors.amber.shade900,
          action: SnackBarAction(label: 'UPGRADE', textColor: Colors.white, onPressed: () {}),
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
      _descriptionController.text.trim(),
      parsedExperience,
      _selectedJobType,
    );

    setState(() {
      _minSalaryController.text = suggestionMap['min'] ?? '';
      _maxSalaryController.text = suggestionMap['max'] ?? '';
      _isFetchingAi = false;
    });
  }

  void _openLocationPicker() {
    setState(() {
      _selectedLat = 3.2162;
      _selectedLng = 101.7289;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test location automatically inserted!'), backgroundColor: Colors.blue),
    );
  }

  bool get _hasActiveSubscription {
    if (_selectedCompanyID == null) return false;
    final company = _myCompanies.firstWhere((c) => c.companyID == _selectedCompanyID);
    if (company.currentPlanType.toUpperCase() == 'FREE') return false;
    return true;
  }

  Future<void> _generateQuestionWithAi(int index) async {
    // 1. Premium Check (Optional: You can remove this if you want it free)
    if (!_hasActiveSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⭐️ Upgrade to Premium to use AI Generation!'), backgroundColor: Colors.amber),
      );
      return;
    }

    // 2. Validate Job Title exists
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Job Title first so the AI knows what to ask.')),
      );
      return;
    }

    // 3. Start Loading
    setState(() => _isGeneratingQuestion[index] = true);

    // 4. Fetch from AI
    final type = _questionTypes[index];
    final desc = _descriptionController.text.trim();

    final aiQuestion = await _employerService.generateAiQuestion(title, desc, type);

    // 5. Apply Result
    if (mounted) {
      setState(() {
        if (aiQuestion.isNotEmpty) {
          _questionControllers[index].text = aiQuestion;
          _isAIGeneratedList[index] = true; // Mark as AI generated for the database!
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate question. Try again.')),
          );
        }
        _isGeneratingQuestion[index] = false;
      });
    }
  }

  Future<void> _submitJob() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (_selectedCompanyID == null ||
        _titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _selectedLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields and set a location.')),
      );
      return;
    }

    // 👉 PRE-SCREENING VALIDATION
    List<Map<String, dynamic>> finalQuestions = [];
    if (_requirePreScreening) {
      for (int i = 0; i < _questionControllers.length; i++) {
        final text = _questionControllers[i].text.trim();
        if (text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill out all questions, or remove empty ones.'), backgroundColor: Colors.red),
          );
          return;
        }

        // Add both the text and the selected type to our list
        finalQuestions.add({
          'text': text,
          'type': _questionTypes[i],
          'isAIGenerated': _isAIGeneratedList[i],
        });
      }
    }

    final minStr = _minSalaryController.text.trim();
    final maxStr = _maxSalaryController.text.trim();
    final int? minSalary = int.tryParse(minStr);
    final int? maxSalary = int.tryParse(maxStr);
    final int parsedExperience = int.tryParse(_experienceController.text.trim()) ?? 0;

    if (minSalary != null && maxSalary != null && minSalary > maxSalary) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum salary cannot be greater than maximum salary.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    String? finalSalaryRange;
    if (_selectedJobType == 'Part-time') {
      finalSalaryRange = minSalary != null ? 'RM $minSalary / hr' : '';
    } else {
      if (minSalary != null && maxSalary != null) {
        finalSalaryRange = 'RM $minSalary - RM $maxSalary';
      } else if (minSalary != null) {
        finalSalaryRange = 'RM $minSalary';
      } else {
        finalSalaryRange = '';
      }
    }

    // 1. Build the base Job Model
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

    // 2. Step One: Save the Job to the database
    final createdJob = await _employerService.createJobPosting(newJob);

    // 3. Step Two: If job saved successfully AND we have questions, save questions
    if (createdJob != null && createdJob.jobID != null) {
      if (_requirePreScreening && finalQuestions.isNotEmpty) {
        await _employerService.addPreScreeningQuestions(createdJob.jobID!, finalQuestions);
      }

      setState(() => _isSubmitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job Posted Successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } else {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post job. Please try again.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _minSalaryController.dispose();
    _maxSalaryController.dispose();
    _experienceController.dispose();
    // 👉 PRE-SCREENING: Dispose dynamically generated controllers
    for (var controller in _questionControllers) {
      controller.dispose();
    }
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
          if (widget.preselectedCompany != null)
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Posting for Company',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              child: Text(widget.preselectedCompany!.name, style: const TextStyle(fontSize: 16)),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _selectedCompanyID,
              decoration: const InputDecoration(
                labelText: 'Select Company',
                border: OutlineInputBorder(),
              ),
              items: _myCompanies.map((company) {
                return DropdownMenuItem(value: company.companyID, child: Text(company.name));
              }).toList(),
              onChanged: (value) => setState(() => _selectedCompanyID = value),
            ),
          const SizedBox(height: 16),

          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Job Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            initialValue: _selectedJobType,
            decoration: const InputDecoration(labelText: 'Job Type', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'Full-time', child: Text('Full-time')),
              DropdownMenuItem(value: 'Part-time', child: Text('Part-time')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedJobType = value);
            },
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _experienceController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Minimum Working Experience (Years)',
              hintText: 'e.g., 0 for fresh grad, 2 for intermediate',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

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
                    labelText: _selectedJobType == 'Part-time' ? 'Hourly Rate' : 'Min Salary',
                    prefixText: 'RM ',
                    suffixText: _selectedJobType == 'Part-time' ? ' / hr' : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              if (_selectedJobType == 'Full-time') ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _maxSalaryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Max (Optional)', prefixText: 'RM ', border: OutlineInputBorder()),
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
                        : Icon(_hasActiveSubscription ? Icons.auto_awesome : Icons.lock, color: Colors.amber),
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

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
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

          TextField(
            controller: _descriptionController,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Full Job Description & Requirements',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),

          // 👉 PRE-SCREENING UI WIDGET
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('Add Pre-screening Questions', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Ask candidates up to 5 short questions before they can apply.'),
                  value: _requirePreScreening,
                  activeColor: Colors.blue,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (bool value) {
                    setState(() {
                      _requirePreScreening = value;
                      if (_requirePreScreening && _questionControllers.isEmpty) {
                        _addQuestion();
                      }
                    });
                  },
                ),

                if (_requirePreScreening) ...[
                  const Divider(),
                  const SizedBox(height: 8),

                  ...List.generate(_questionControllers.length, (index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                // 1. The Question Text Input
                                TextField(
                                  controller: _questionControllers[index],
                                  decoration: InputDecoration(
                                    labelText: 'Question ${index + 1}',
                                    hintText: 'e.g., Please upload your portfolio.',
                                    border: const OutlineInputBorder(),
                                    isDense: true,

                                    // 👉 THE MAGIC AI BUTTON
                                    suffixIcon: _isGeneratingQuestion[index]
                                        ? const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: SizedBox(
                                          width: 16, height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2)
                                      ),
                                    )
                                        : IconButton(
                                      icon: const Icon(Icons.auto_awesome, color: Colors.amber),
                                      tooltip: 'Generate with AI',
                                      onPressed: () => _generateQuestionWithAi(index),
                                    ),
                                  ),
                                  onChanged: (val) {
                                    // If the user manually edits the AI text, it's no longer purely AI generated!
                                    if (_isAIGeneratedList[index]) {
                                      setState(() => _isAIGeneratedList[index] = false);
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),

                                // 2. The Question Type Dropdown
                                DropdownButtonFormField<String>(
                                  initialValue: _questionTypes[index],

                                  isExpanded: true, // 👉 THE MAGIC FIX: Forces it to fit the screen!

                                  decoration: const InputDecoration(
                                    labelText: 'Required Answer Format',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    prefixIcon: Icon(Icons.rule),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Text',
                                      child: Text(
                                        'Text Answer (Typing)',
                                        overflow: TextOverflow.ellipsis, // 👉 Keeps text tidy
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'File',
                                      child: Text(
                                        'File Upload (PDF, Image, Code)',
                                        overflow: TextOverflow.ellipsis, // 👉 Keeps text tidy
                                      ),
                                    ),
                                  ],
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _questionTypes[index] = newValue;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 3. The Remove Button
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Remove Question',
                            onPressed: () => _removeQuestion(index),
                          ),
                        ],
                      ),
                    );
                  }),

                  if (_questionControllers.length < 5)
                    TextButton.icon(
                      onPressed: _addQuestion,
                      icon: const Icon(Icons.add),
                      label: Text('Add Another Question (${_questionControllers.length}/5)'),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          _isSubmitting
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
            onPressed: _submitJob,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('Publish Job Posting', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}