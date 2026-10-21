import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/job_model.dart';
import '../../../models/company_model.dart';
import '../../../services/employer_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'company_map_picker.dart';

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
  final _workingPeriodController = TextEditingController(
    text: 'Mon - Fri, 9:00 AM - 6:00 PM',
  );

  String _selectedJobType = 'Full-time';
  String _selectedWorkplaceType = 'On-site';
  String _selectedQualification = 'No Minimum';
  String _expiryUnit = 'Months'; // 'Weeks' or 'Months'
  int _expiryDuration = 1;

  static const List<String> _workingPeriodPresets = [
    'Mon - Fri, 9:00 AM - 6:00 PM',
    'Mon - Sat, 9:00 AM - 5:00 PM',
    'Shift-based',
    'Flexible Hours',
  ];

  DateTime get _calculatedExpiryDate {
    final now = DateTime.now();
    if (_expiryUnit == 'Weeks') {
      return now.add(Duration(days: _expiryDuration * 7));
    } else {
      return DateTime(
        now.year,
        now.month + _expiryDuration,
        now.day,
        23,
        59,
        59,
      );
    }
  }

  final _employerService = EmployerService();

  List<CompanyModel> _myCompanies = [];
  String? _selectedCompanyID;

  bool _isLoadingCompanies = true;
  bool _isSubmitting = false;
  bool _isFetchingAi = false;

  double? _selectedLat;
  double? _selectedLng;
  String? _selectedLocationName;

  String? _formError;
  String? _companyError;
  String? _titleError;
  String? _descriptionError;
  String? _locationError;
  String? _salaryError;
  String? _minSalaryError;
  String? _maxSalaryError;
  String? _preScreeningError;
  String? _experienceError;
  String? _workingPeriodError;

  @override
  void initState() {
    super.initState();
    _loadVerifiedCompanies();
  }

  bool _requirePreScreening = false;
  final List<TextEditingController> _questionControllers = [];
  final List<String> _questionTypes = [];
  final List<bool> _isGeneratingQuestion = [];
  final List<bool> _isAIGeneratedList = [];

  void _clearFormError() {
    if (_formError != null) {
      setState(() => _formError = null);
    }
  }

  void _clearJobDetailsErrors() {
    if (_titleError != null ||
        _descriptionError != null ||
        _experienceError != null ||
        _workingPeriodError != null ||
        _formError != null) {
      setState(() {
        _titleError = null;
        _descriptionError = null;
        _experienceError = null;
        _workingPeriodError = null;
        _formError = null;
      });
    }
  }

  void _clearSalaryError() {
    if (_salaryError != null ||
        _minSalaryError != null ||
        _maxSalaryError != null ||
        _formError != null) {
      setState(() {
        _salaryError = null;
        _minSalaryError = null;
        _maxSalaryError = null;
        _formError = null;
      });
    }
  }

  void _clearPreScreeningError() {
    if (_preScreeningError != null || _formError != null) {
      setState(() {
        _preScreeningError = null;
        _formError = null;
      });
    }
  }

  void _addQuestion() {
    if (_questionControllers.length < 5) {
      setState(() {
        _questionControllers.add(TextEditingController());
        _questionTypes.add('Text');
        _isGeneratingQuestion.add(false);
        _isAIGeneratedList.add(false);
        _preScreeningError = null;
        _formError = null;
      });
    }
  }

  void _removeQuestion(int index) {
    setState(() {
      _questionControllers[index].dispose();
      _questionControllers.removeAt(index);
      _questionTypes.removeAt(index);
      _isGeneratingQuestion.removeAt(index);
      _isAIGeneratedList.removeAt(index);
      _preScreeningError = null;
      _formError = null;

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

    final allCompanies =
    await _employerService.getCompanies(currentUser.id, 'employer');

    if (mounted) {
      setState(() {
        _myCompanies = allCompanies.where((company) {
          final status = company.verificationStatus.toLowerCase();
          return company.isVerified ||
              status == 'verified' ||
              status == 'approved';
        }).toList();
        if (_myCompanies.length == 1) {
          _selectedCompanyID = _myCompanies.first.companyID;
        }
        _isLoadingCompanies = false;
      });
    }
  }

  Future<void> _suggestSalary() async {
    setState(() {
      _salaryError = null;
      _titleError = null;
      _formError = null;
    });

    if (!_hasActiveSubscription) {
      setState(() {
        _salaryError =
        'Premium feature: upgrade your company plan to use AI salary suggestions.';
      });
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      setState(() {
        _titleError = 'Please enter a job title first.';
        _salaryError =
        'Enter the job title first so AI can suggest a salary range.';
      });
      return;
    }

    setState(() => _isFetchingAi = true);

    final int parsedExperience =
        int.tryParse(_experienceController.text.trim()) ?? 0;

    final suggestionMap = await _employerService.getAiSalarySuggestion(
      _titleController.text.trim(),
      _descriptionController.text.trim(),
      parsedExperience,
      _selectedJobType,
      workplaceType: _selectedWorkplaceType,
      workingPeriod: _workingPeriodController.text.trim(),
      qualification: _selectedQualification,
      locationName: _selectedLocationName,
    );

    if (!mounted) return;

    setState(() {
      _minSalaryController.text = suggestionMap['min'] ?? '';
      _maxSalaryController.text = suggestionMap['max'] ?? '';
      _isFetchingAi = false;
    });
  }

  Future<void> _openLocationPicker() async {
    final LatLng? pickedLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyMapPickerScreen(
          initialLat: _selectedLat,
          initialLng: _selectedLng,
        ),
      ),
    );

    if (pickedLocation != null) {
      setState(() {
        _selectedLat = pickedLocation.latitude;
        _selectedLng = pickedLocation.longitude;
        _selectedLocationName = 'Translating map coordinates...';
        _locationError = null;
        _formError = null;
      });

      try {
        final placemarks = await placemarkFromCoordinates(
          pickedLocation.latitude,
          pickedLocation.longitude,
        );

        String readableAddress = 'Unknown Location';
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          readableAddress =
              '${place.street}, ${place.subLocality ?? place.locality}, ${place.administrativeArea}';
          readableAddress = readableAddress
              .replaceAll(RegExp(r'^, |, $'), '')
              .replaceAll(', ,', ',');
        }

        if (!mounted) return;

        setState(() {
          _selectedLat = pickedLocation.latitude;
          _selectedLng = pickedLocation.longitude;
          _selectedLocationName = readableAddress;
        });
      } catch (_) {
        if (!mounted) return;

        setState(() {
          _selectedLat = pickedLocation.latitude;
          _selectedLng = pickedLocation.longitude;
          _selectedLocationName =
              'Coordinates: ${pickedLocation.latitude.toStringAsFixed(4)}, ${pickedLocation.longitude.toStringAsFixed(4)}';
        });
      }
    }
  }

  bool get _hasActiveSubscription {
    if (_selectedCompanyID == null) return false;
    final company =
    _myCompanies.firstWhere((c) => c.companyID == _selectedCompanyID);
    if (company.currentPlanType.toUpperCase() == 'FREE') return false;
    return true;
  }

  Future<void> _generateQuestionWithAi(int index) async {
    setState(() {
      _preScreeningError = null;
      _titleError = null;
      _formError = null;
    });

    if (!_hasActiveSubscription) {
      setState(() {
        _preScreeningError =
        'Premium feature: upgrade your company plan to use AI question generation.';
      });
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _titleError = 'Please enter a job title first.';
        _preScreeningError =
        'Enter the job title first so AI knows what kind of question to generate.';
      });
      return;
    }

    setState(() => _isGeneratingQuestion[index] = true);

    final type = _questionTypes[index];
    final desc = _descriptionController.text.trim();
    final int parsedExperience =
        int.tryParse(_experienceController.text.trim()) ?? 0;
    final List<String> otherQuestions = [];
    for (int i = 0; i < _questionControllers.length; i++) {
      if (i != index) {
        final qText = _questionControllers[i].text.trim();
        if (qText.isNotEmpty) {
          otherQuestions.add(qText);
        }
      }
    }

    final aiQuestion = await _employerService.generateAiQuestion(
      title,
      desc,
      type,
      jobType: _selectedJobType,
      workplaceType: _selectedWorkplaceType,
      workingPeriod: _workingPeriodController.text.trim(),
      qualification: _selectedQualification,
      minExperience: parsedExperience,
      existingQuestions: otherQuestions,
    );

    if (!mounted) return;

    setState(() {
      if (aiQuestion.isNotEmpty) {
        _questionControllers[index].text = aiQuestion;
        _isAIGeneratedList[index] = true;
      } else {
        _preScreeningError = 'Failed to generate a question. Please try again.';
      }
      _isGeneratingQuestion[index] = false;
    });
  }

  Future<void> _submitJob() async {
    setState(() {
      _formError = null;
      _companyError = null;
      _titleError = null;
      _descriptionError = null;
      _locationError = null;
      _salaryError = null;
      _minSalaryError = null;
      _maxSalaryError = null;
      _preScreeningError = null;
      _experienceError = null;
      _workingPeriodError = null;
    });

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final experienceText = _experienceController.text.trim();
    final workingPeriodText = _workingPeriodController.text.trim();

    bool hasError = false;

    if (_selectedCompanyID == null) {
      _companyError = 'Please select a company.';
      hasError = true;
    }

    if (title.isEmpty) {
      _titleError = 'Please enter the job title.';
      hasError = true;
    }

    if (workingPeriodText.isEmpty) {
      _workingPeriodError = 'Please specify the working period / schedule.';
      hasError = true;
    }

    if (_selectedLat == null) {
      _locationError = 'Please choose a work location.';
      hasError = true;
    }

    if (experienceText.isNotEmpty && int.tryParse(experienceText) == null) {
      _experienceError = 'Please enter a valid number of years.';
      hasError = true;
    }

    List<Map<String, dynamic>> finalQuestions = [];
    if (_requirePreScreening) {
      for (int i = 0; i < _questionControllers.length; i++) {
        final text = _questionControllers[i].text.trim();
        if (text.isEmpty) {
          _preScreeningError =
          'Please fill out all pre-screening questions, or remove empty ones.';
          hasError = true;
          break;
        }

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
    final int parsedExperience = int.tryParse(experienceText) ?? 0;

    if (minStr.isEmpty) {
      _minSalaryError = _selectedJobType == 'Part-time'
          ? 'Please enter the hourly rate.'
          : 'Please enter the minimum salary.';
      hasError = true;
    } else if (minSalary == null) {
      _minSalaryError = 'Please enter a valid minimum salary.';
      hasError = true;
    }

    if (_selectedJobType == 'Full-time' && maxStr.isNotEmpty && maxSalary == null) {
      _maxSalaryError = 'Please enter a valid maximum salary.';
      hasError = true;
    }

    if (_selectedJobType == 'Full-time' &&
        minSalary != null &&
        maxSalary != null &&
        minSalary > maxSalary) {
      _maxSalaryError =
      'Maximum salary must be greater than minimum salary.';
      hasError = true;
    }

    if (hasError) {
      setState(() {
        _formError =
        'Please complete all required fields before publishing the job.';
      });
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

    final newJob = JobModel(
      companyID: _selectedCompanyID!,
      employerID: currentUser.id,
      title: title,
      description: description,
      salaryRange: finalSalaryRange,
      latitude: _selectedLat,
      longitude: _selectedLng,
      minExperienceYears: parsedExperience,
      jobType: _selectedJobType,
      locationName: _selectedLocationName,
      expiresAt: _calculatedExpiryDate,
      workplaceType: _selectedWorkplaceType,
      workingPeriod: workingPeriodText,
      qualification: _selectedQualification,
    );

    final createdJob = await _employerService.createJobPosting(newJob);

    if (createdJob != null && createdJob.jobID != null) {
      if (_requirePreScreening && finalQuestions.isNotEmpty) {
        await _employerService.addPreScreeningQuestions(
          createdJob.jobID!,
          finalQuestions,
        );
      }

      setState(() => _isSubmitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job Posted Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      setState(() {
        _isSubmitting = false;
        _formError = 'Failed to post job. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _minSalaryController.dispose();
    _maxSalaryController.dispose();
    _experienceController.dispose();
    _workingPeriodController.dispose();
    for (var controller in _questionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: _isLoadingCompanies
            ? const Center(child: CircularProgressIndicator())
            : _myCompanies.isEmpty
            ? _buildEmptyState()
            : ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _buildTopBar(context),
            const SizedBox(height: 16),
            _buildHeroCard(),
            const SizedBox(height: 24),
            _buildCompanySelection(),
            const SizedBox(height: 18),
            _buildJobDetailsSection(),
            const SizedBox(height: 18),
            _buildJobExpirySection(),
            const SizedBox(height: 18),
            _buildSalarySection(),
            const SizedBox(height: 18),
            _buildSectionCard(
              title: 'Work Location',
              subtitle:
              'Pinpoint where the employee will be working.',
              child: _buildLocationPanel(),
            ),
            const SizedBox(height: 18),
            _buildSectionCard(
              title: 'Job Description',
              subtitle:
              'Detail the responsibilities and requirements.',
              child: _buildStyledField(
                controller: _descriptionController,
                label: 'Full Description (Optional)',
                icon: Icons.notes_rounded,
                maxLines: 6,
                errorText: _descriptionError,
                onChanged: (_) => _clearJobDetailsErrors(),
              ),
            ),
            const SizedBox(height: 18),
            _buildSectionCard(
              title: 'Pre-Screening (Optional)',
              subtitle: 'Filter candidates before they apply.',
              child: _buildPreScreeningPanel(),
            ),
            const SizedBox(height: 24),
            _buildSubmitPanel(),
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
            'Post New Job',
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
                Icon(Icons.work_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Recruitment Setup',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Find the perfect candidate',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Create an attractive job posting with AI salary suggestions and custom pre-screening questions.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.4,
            ),
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
              color: Color(0xFF687588),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildCompanySelection() {
    return _buildSectionCard(
      title: 'Hiring Company',
      subtitle: 'Select which verified company this job belongs to.',
      child: widget.preselectedCompany != null
          ? Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.business_rounded,
              color: Color(0xFF163B65),
            ),
            const SizedBox(width: 12),
            Text(
              widget.preselectedCompany!.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      )
          : _buildStyledDropdown(
        value: _selectedCompanyID,
        label: 'Select Company',
        icon: Icons.business_rounded,
        items: _myCompanies
            .map(
              (c) => DropdownMenuItem(
            value: c.companyID,
            child: Text(c.name),
          ),
        )
            .toList(),
        errorText: _companyError,
        onChanged: (val) {
          setState(() {
            _selectedCompanyID = val;
            _companyError = null;
            _formError = null;
          });
        },
      ),
    );
  }

  Widget _buildJobDetailsSection() {
    return _buildSectionCard(
      title: 'Job Details',
      subtitle: 'The core information, work arrangement, and requirements for your posting.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStyledField(
            controller: _titleController,
            label: 'Job Title',
            icon: Icons.title_rounded,
            errorText: _titleError,
            onChanged: (_) => _clearJobDetailsErrors(),
          ),
          const SizedBox(height: 16),
          _buildStyledDropdown(
            value: _selectedJobType,
            label: 'Job Type',
            icon: Icons.schedule_rounded,
            items: const [
              DropdownMenuItem(value: 'Full-time', child: Text('Full-time')),
              DropdownMenuItem(value: 'Part-time', child: Text('Part-time')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedJobType = val;
                  _salaryError = null;
                  _formError = null;
                  if (val == 'Part-time') {
                    _maxSalaryController.clear();
                  }
                });
              }
            },
          ),
          const SizedBox(height: 16),
          _buildStyledDropdown(
            value: _selectedWorkplaceType,
            label: 'Work Arrangement',
            icon: Icons.maps_home_work_rounded,
            items: const [
              DropdownMenuItem(
                value: 'On-site',
                child: Text('On-site (Work at Company)'),
              ),
              DropdownMenuItem(
                value: 'Remote',
                child: Text('Remote (Work from Home)'),
              ),
              DropdownMenuItem(
                value: 'Hybrid',
                child: Text('Hybrid (Both Home & Company)'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedWorkplaceType = val;
                  _formError = null;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          _buildStyledField(
            controller: _workingPeriodController,
            label: 'Working Period / Schedule',
            icon: Icons.access_time_filled_rounded,
            errorText: _workingPeriodError,
            onChanged: (_) => _clearJobDetailsErrors(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _workingPeriodPresets.map((preset) {
              final isSelected = _workingPeriodController.text.trim() == preset;
              return InkWell(
                onTap: () {
                  setState(() {
                    _workingPeriodController.text = preset;
                    _workingPeriodError = null;
                    _formError = null;
                  });
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF163B65)
                        : const Color(0xFFF1F5FA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    preset,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF4F5C6C),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _buildStyledDropdown(
            value: _selectedQualification,
            label: 'Minimum Qualification',
            icon: Icons.school_rounded,
            items: const [
              DropdownMenuItem(
                value: 'No Minimum',
                child: Text('No Minimum Qualification'),
              ),
              DropdownMenuItem(
                value: 'SPM / O-Level',
                child: Text('SPM / O-Level'),
              ),
              DropdownMenuItem(
                value: 'STPM / A-Level / Foundation',
                child: Text('STPM / A-Level / Foundation'),
              ),
              DropdownMenuItem(
                value: 'Certificate / SKM',
                child: Text('Certificate / SKM'),
              ),
              DropdownMenuItem(
                value: 'Diploma',
                child: Text('Diploma'),
              ),
              DropdownMenuItem(
                value: "Bachelor's Degree",
                child: Text("Bachelor's Degree"),
              ),
              DropdownMenuItem(
                value: "Master's Degree",
                child: Text("Master's Degree"),
              ),
              DropdownMenuItem(
                value: 'Doctorate (PhD)',
                child: Text('Doctorate (PhD)'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedQualification = val;
                  _formError = null;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          _buildStyledField(
            controller: _experienceController,
            label: 'Minimum Experience (Years)',
            icon: Icons.history_edu_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            errorText: _experienceError,
            onChanged: (_) => _clearJobDetailsErrors(),
          ),
        ],
      ),
    );
  }

  Widget _buildJobExpirySection() {
    final List<int> durationOptions = _expiryUnit == 'Weeks'
        ? const [1, 2, 3, 4]
        : const [1, 2, 3, 6, 12];
    final formattedExpiry =
        DateFormat('dd MMM yyyy').format(_calculatedExpiryDate);

    return _buildSectionCard(
      title: 'Job Expiry Duration',
      subtitle:
          'Set how long this job stays active. Once expired, it will automatically become inactive.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStyledDropdown(
                  value: _expiryDuration.toString(),
                  label: 'Duration',
                  icon: Icons.timelapse_rounded,
                  items: durationOptions
                      .map(
                        (d) => DropdownMenuItem(
                          value: d.toString(),
                          child: Text('$d'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _expiryDuration = int.parse(val);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStyledDropdown(
                  value: _expiryUnit,
                  label: 'Unit',
                  icon: Icons.calendar_month_rounded,
                  items: const [
                    DropdownMenuItem(value: 'Weeks', child: Text('Week(s)')),
                    DropdownMenuItem(value: 'Months', child: Text('Month(s)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _expiryUnit = val;
                        final validOptions = val == 'Weeks'
                            ? const [1, 2, 3, 4]
                            : const [1, 2, 3, 6, 12];
                        if (!validOptions.contains(_expiryDuration)) {
                          _expiryDuration = 1;
                        }
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF5FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD3E3F8)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_available_rounded,
                  color: Color(0xFF163B65),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Expires on $formattedExpiry ($_expiryDuration ${_expiryUnit.toLowerCase()}). Status will switch to Inactive automatically after this date.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF163B65),
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

  Widget _buildSalarySection() {
    return _buildSectionCard(
      title: 'Compensation',
      subtitle: 'Set a salary range or ask AI for market rates.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStyledField(
                  controller: _minSalaryController,
                  label:
                  _selectedJobType == 'Part-time' ? 'Hourly Rate' : 'Min Salary',
                  icon: Icons.payments_rounded,
                  keyboardType: TextInputType.number,
                  prefixText: 'RM ',
                  suffixText: _selectedJobType == 'Part-time' ? ' / hr' : null,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  errorText: _minSalaryError,
                  onChanged: (_) => _clearSalaryError(),
                ),
              ),
              if (_selectedJobType == 'Full-time') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStyledField(
                    controller: _maxSalaryController,
                    label: 'Max Salary',
                    icon: Icons.trending_up_rounded,
                    keyboardType: TextInputType.number,
                    prefixText: 'RM ',
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    errorText: _maxSalaryError,
                    onChanged: (_) => _clearSalaryError(),
                  ),
                ),
              ],
            ],
          ),
          if (_salaryError != null) ...[
            const SizedBox(height: 8),
            Text(
              _salaryError!,
              style: const TextStyle(
                color: Color(0xFFC24E4E),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isFetchingAi ? null : _suggestSalary,
              icon: _isFetchingAi
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Icon(
                _hasActiveSubscription
                    ? Icons.auto_awesome
                    : Icons.lock,
                color: Colors.amber.shade700,
              ),
              label: Text(
                _hasActiveSubscription
                    ? 'Suggest Market Salary via AI'
                    : 'AI Salary Suggestion (Premium)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade50,
                foregroundColor: Colors.amber.shade900,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPanel() {
    final bool hasLocation = _selectedLat != null;
    final String locationLabel =
        _selectedLocationName ?? 'No location selected yet.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCEBFB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF163B65),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Work Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B2433),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            locationLabel,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: hasLocation
                  ? const Color(0xFF1B2433)
                  : const Color(0xFF687588),
            ),
          ),
          if (hasLocation) ...[
            const SizedBox(height: 8),
            Text(
              'Latitude: ${_selectedLat!.toStringAsFixed(4)}\nLongitude: ${_selectedLng!.toStringAsFixed(4)}',
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF687588),
              ),
            ),
          ],
          if (_locationError != null) ...[
            const SizedBox(height: 8),
            Text(
              _locationError!,
              style: const TextStyle(
                color: Color(0xFFC24E4E),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _useCompanyLocation,
              icon: const Icon(Icons.business_rounded),
              label: const Text('Use Company HQ Address'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF163B65),
                side: const BorderSide(color: Color(0xFF163B65)),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openLocationPicker,
              icon: const Icon(Icons.map_rounded),
              label: Text(
                hasLocation ? 'Change Location on Map' : 'Search or Pick on Map',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF163B65),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPreScreeningPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text(
              'Enable Pre-screening',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            subtitle: const Text(
              'Ask up to 5 questions.',
              style: TextStyle(fontSize: 12),
            ),
            value: _requirePreScreening,
            activeColor: const Color(0xFF163B65),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onChanged: (bool value) {
              setState(() {
                _requirePreScreening = value;
                _preScreeningError = null;
                _formError = null;
                if (_requirePreScreening && _questionControllers.isEmpty) {
                  _addQuestion();
                }
              });
            },
          ),
          if (_requirePreScreening) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_preScreeningError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE9E9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _preScreeningError!,
                        style: const TextStyle(
                          color: Color(0xFFC24E4E),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ...List.generate(_questionControllers.length, (index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Question ${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF163B65),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFC24E4E),
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _removeQuestion(index),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildStyledField(
                            controller: _questionControllers[index],
                            label: 'Question Text',
                            icon: Icons.help_outline_rounded,
                            onChanged: (val) {
                              if (_isAIGeneratedList[index] ||
                                  _preScreeningError != null ||
                                  _formError != null) {
                                setState(() {
                                  if (_isAIGeneratedList[index]) {
                                    _isAIGeneratedList[index] = false;
                                  }
                                  _preScreeningError = null;
                                  _formError = null;
                                });
                              }
                            },
                            suffixIcon: _isGeneratingQuestion[index]
                                ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                                : IconButton(
                              icon: const Icon(
                                Icons.auto_awesome,
                                color: Colors.amber,
                              ),
                              tooltip: 'Generate with AI',
                              onPressed: () =>
                                  _generateQuestionWithAi(index),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildStyledDropdown(
                            value: _questionTypes[index],
                            label: 'Format',
                            icon: Icons.rule_rounded,
                            items: const [
                              DropdownMenuItem(
                                value: 'Text',
                                child: Text('Text Answer'),
                              ),
                              DropdownMenuItem(
                                value: 'File',
                                child: Text('File Upload'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _questionTypes[index] = val;
                                  _preScreeningError = null;
                                  _formError = null;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_questionControllers.length < 5)
                    OutlinedButton.icon(
                      onPressed: _addQuestion,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(
                        'Add Question (${_questionControllers.length}/5)',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF163B65),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready to publish?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your job will be instantly visible to job seekers matching the criteria.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF687588),
            ),
          ),
          const SizedBox(height: 18),
          if (_formError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE9E9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _formError!,
                style: const TextStyle(
                  color: Color(0xFFC24E4E),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: _isSubmitting
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _submitJob,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF163B65),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Publish Job Posting',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.domain_disabled_rounded,
                size: 64,
                color: Color(0xFF163B65),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Approved Companies',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B2433),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You need an approved company before you can post a job. Please register a company and wait for admin verification.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF687588),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF163B65),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    String? prefixText,
    String? suffixText,
    Widget? suffixIcon,
    String? errorText,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        prefixIcon: Icon(icon, color: const Color(0xFF687588)),
        prefixText: prefixText,
        suffixText: suffixText,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFF163B65),
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFC24E4E)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFC24E4E),
            width: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildStyledDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    String? errorText,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: Color(0xFF687588),
      ),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        prefixIcon: Icon(icon, color: const Color(0xFF687588)),
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFF163B65),
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFC24E4E)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFC24E4E),
            width: 1.4,
          ),
        ),
      ),
    );
  }

  CompanyModel? _getSelectedCompany() {
    if (_selectedCompanyID == null) return null;

    try {
      return _myCompanies.firstWhere(
            (company) => company.companyID == _selectedCompanyID,
      );
    } catch (_) {
      return null;
    }
  }

  void _useCompanyLocation() {
    final company = _getSelectedCompany();

    if (company == null) {
      setState(() {
        _locationError = 'Please select a company first.';
        _formError = null;
      });
      return;
    }

    if (company.latitude == null || company.longitude == null) {
      setState(() {
        _locationError = 'This company does not have a saved HQ location yet.';
        _formError = null;
      });
      return;
    }

    setState(() {
      _selectedLat = company.latitude;
      _selectedLng = company.longitude;
      _selectedLocationName = company.companyAddress ??
          'Coordinates: ${company.latitude!.toStringAsFixed(4)}, ${company.longitude!.toStringAsFixed(4)}';
      _locationError = null;
      _formError = null;
    });
  }
}
