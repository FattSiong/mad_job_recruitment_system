import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/company_model.dart';
import '../../../models/job_model.dart';
import '../../../services/employer_service.dart';
import 'company_map_picker.dart';

class EditJobScreen extends StatefulWidget {
  final JobModel job;
  final int? initialApplicantCount;

  const EditJobScreen({
    super.key,
    required this.job,
    this.initialApplicantCount,
  });

  @override
  State<EditJobScreen> createState() => _EditJobScreenState();
}

class _EditJobScreenState extends State<EditJobScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _minSalaryController = TextEditingController();
  final _maxSalaryController = TextEditingController();
  final _experienceController = TextEditingController();
  final _vacanciesController = TextEditingController();
  final _workingPeriodController = TextEditingController();

  final _employerService = EmployerService();

  CompanyModel? _jobCompany;
  int _applicantCount = 0;
  int _acceptedCount = 0;
  bool _isLoadingContext = true;

  late String _selectedJobType;
  late String _selectedWorkplaceType;
  late String _selectedQualification;

  late String _originalJobType;
  late String _originalWorkplaceType;
  late String _originalQualification;
  int? _originalMinSalary;

  bool _updateExpiryDate = false;
  String _expiryUnit = 'Months'; // 'Weeks' or 'Months'
  int _expiryDuration = 1;

  double? _selectedLat;
  double? _selectedLng;
  String? _selectedLocationName;

  bool _isSubmitting = false;
  bool _isFetchingAi = false;

  String? _formError;
  String? _titleError;
  String? _descriptionError;
  String? _locationError;
  String? _salaryError;
  String? _minSalaryError;
  String? _maxSalaryError;
  String? _experienceError;
  String? _vacanciesError;
  String? _workingPeriodError;

  static const List<String> _workingPeriodPresets = [
    'Mon - Fri, 9:00 AM - 6:00 PM',
    'Mon - Sat, 9:00 AM - 5:00 PM',
    'Shift-based',
    'Flexible Hours',
  ];

  static const List<String> _qualificationOptions = [
    'No Minimum',
    'SPM / O-Level',
    'STPM / A-Level / Foundation',
    'Certificate / SKM',
    'Diploma',
    "Bachelor's Degree",
    "Master's Degree",
    'Doctorate (PhD)',
  ];

  bool get _isJobOwner {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return currentUserId != null && widget.job.employerID == currentUserId;
  }

  bool get _isDeleted => widget.job.status.toLowerCase() == 'deleted';

  bool get _isInactive => widget.job.status.toLowerCase() == 'inactive';

  bool get _hasApplicants => _applicantCount > 0;

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

  bool get _hasActiveSubscription {
    return _jobCompany?.hasActiveSubscription ?? false;
  }

  @override
  void initState() {
    super.initState();
    _applicantCount = widget.initialApplicantCount ?? 0;
    _initializeData();
    _loadContextDetails();
  }

  Future<void> _loadContextDetails() async {
    final companyFuture =
        _employerService.getCompanyById(widget.job.companyID);
    final applicantsFuture = widget.job.jobID != null
        ? _employerService.getJobApplicants(widget.job.jobID!)
        : Future.value(<Map<String, dynamic>>[]);

    final results = await Future.wait([companyFuture, applicantsFuture]);
    if (!mounted) return;

    setState(() {
      _jobCompany = results[0] as CompanyModel?;
      final applicants = results[1] as List<Map<String, dynamic>>;
      _applicantCount = applicants.length;
      _acceptedCount = applicants
          .where(
            (a) =>
                (a['applicationStatus'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase() ==
                'accepted',
          )
          .length;
      _isLoadingContext = false;
    });
  }

  void _initializeData() {
    final job = widget.job;

    _titleController.text = job.title;
    _descriptionController.text = job.description;
    _experienceController.text = job.minExperienceYears.toString();
    _vacanciesController.text = job.vacancies.toString();

    _workingPeriodController.text =
        (job.workingPeriod != null && job.workingPeriod!.trim().isNotEmpty)
            ? job.workingPeriod!.trim()
            : 'Mon - Fri, 9:00 AM - 6:00 PM';

    // Normalize Job Type
    _selectedJobType = job.jobType == 'Part Time'
        ? 'Part-time'
        : job.jobType == 'Full Time'
            ? 'Full-time'
            : (job.jobType == 'Part-time' || job.jobType == 'Full-time')
                ? job.jobType
                : 'Full-time';
    _originalJobType = _selectedJobType;

    // Normalize Workplace Type
    const validWorkplaces = ['On-site', 'Remote', 'Hybrid'];
    final rawWorkplace = job.workplaceType.trim();
    _selectedWorkplaceType = validWorkplaces.contains(rawWorkplace)
        ? rawWorkplace
        : 'On-site';
    _originalWorkplaceType = _selectedWorkplaceType;

    // Normalize Qualification
    final rawQual = job.qualification.trim();
    final matchedQual = _qualificationOptions.firstWhere(
      (q) => q.toLowerCase() == rawQual.toLowerCase(),
      orElse: () => 'No Minimum',
    );
    _selectedQualification = matchedQual;
    _originalQualification = _selectedQualification;

    // If the job had no expiry date set previously, enable setting one by default
    _updateExpiryDate = job.expiresAt == null;

    _selectedLat = job.latitude;
    _selectedLng = job.longitude;
    if (job.locationName != null && job.locationName!.trim().isNotEmpty) {
      _selectedLocationName = job.locationName!.trim();
    } else if (_selectedLat != null && _selectedLng != null) {
      _selectedLocationName =
          'Coordinates: ${_selectedLat!.toStringAsFixed(4)}, ${_selectedLng!.toStringAsFixed(4)}';
    }

    // Extract numbers from the formatted salary string
    if (job.salaryRange.isNotEmpty) {
      final rawSalary = job.salaryRange
          .replaceAll('RM ', '')
          .replaceAll(',', '');

      if (_selectedJobType == 'Part-time') {
        final cleanedMin = rawSalary.replaceAll(' / hr', '').trim();
        _minSalaryController.text = cleanedMin;
        _originalMinSalary = int.tryParse(cleanedMin);
      } else {
        if (rawSalary.contains('-')) {
          final parts = rawSalary.split('-');
          if (parts.length == 2) {
            final cleanedMin = parts[0].trim();
            _minSalaryController.text = cleanedMin;
            _maxSalaryController.text = parts[1].trim();
            _originalMinSalary = int.tryParse(cleanedMin);
          }
        } else {
          final cleanedMin = rawSalary.trim();
          _minSalaryController.text = cleanedMin;
          _originalMinSalary = int.tryParse(cleanedMin);
        }
      }
    }
  }

  void _clearJobDetailsErrors() {
    if (_titleError != null ||
        _descriptionError != null ||
        _experienceError != null ||
        _vacanciesError != null ||
        _workingPeriodError != null ||
        _formError != null) {
      setState(() {
        _titleError = null;
        _descriptionError = null;
        _experienceError = null;
        _vacanciesError = null;
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
      final suggestedMin = int.tryParse(suggestionMap['min'] ?? '');
      // Respect the salary floor if applicants have already applied
      if (_hasApplicants &&
          _originalMinSalary != null &&
          suggestedMin != null &&
          suggestedMin < _originalMinSalary!) {
        _minSalaryController.text = _originalMinSalary.toString();
      } else {
        _minSalaryController.text = suggestionMap['min'] ?? '';
      }
      _maxSalaryController.text = suggestionMap['max'] ?? '';
      _isFetchingAi = false;
    });
  }

  void _useCompanyLocation() {
    if (_jobCompany == null) {
      setState(() {
        _locationError = 'Company location details are still loading.';
        _formError = null;
      });
      return;
    }

    if (_jobCompany!.latitude == null || _jobCompany!.longitude == null) {
      setState(() {
        _locationError = 'This company does not have a saved HQ location yet.';
        _formError = null;
      });
      return;
    }

    setState(() {
      _selectedLat = _jobCompany!.latitude;
      _selectedLng = _jobCompany!.longitude;
      _selectedLocationName = _jobCompany!.companyAddress ??
          'Coordinates: ${_jobCompany!.latitude!.toStringAsFixed(4)}, ${_jobCompany!.longitude!.toStringAsFixed(4)}';
      _locationError = null;
      _formError = null;
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

  Future<void> _updateJob() async {
    if (_isDeleted) {
      setState(() {
        _formError = 'This job was deleted by an admin and cannot be modified.';
      });
      return;
    }

    if (!_isJobOwner) {
      setState(() {
        _formError =
            'Only the employer who created this job posting can modify it.';
      });
      return;
    }

    setState(() {
      _formError = null;
      _titleError = null;
      _descriptionError = null;
      _locationError = null;
      _salaryError = null;
      _minSalaryError = null;
      _maxSalaryError = null;
      _experienceError = null;
      _vacanciesError = null;
      _workingPeriodError = null;
    });

    final title = _hasApplicants
        ? widget.job.title.trim()
        : _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final experienceText = _hasApplicants
        ? widget.job.minExperienceYears.toString()
        : _experienceController.text.trim();
    final vacanciesText = _vacanciesController.text.trim();
    final workingPeriodText = _workingPeriodController.text.trim();
    final effectiveJobType =
        _hasApplicants ? _originalJobType : _selectedJobType;
    final effectiveWorkplaceType =
        _hasApplicants ? _originalWorkplaceType : _selectedWorkplaceType;
    final effectiveQualification =
        _hasApplicants ? _originalQualification : _selectedQualification;

    bool hasError = false;

    if (title.isEmpty) {
      _titleError = 'Please enter the job title.';
      hasError = true;
    }

    if (workingPeriodText.isEmpty) {
      _workingPeriodError = 'Please specify the working period / schedule.';
      hasError = true;
    }

    if (description.isEmpty) {
      _descriptionError = 'Please provide a job description.';
      hasError = true;
    }

    if (_selectedLat == null || _selectedLng == null) {
      _locationError = 'Please choose a work location.';
      hasError = true;
    }

    if (experienceText.isNotEmpty && int.tryParse(experienceText) == null) {
      _experienceError = 'Please enter a valid number of years.';
      hasError = true;
    }

    final int? parsedVacancies = int.tryParse(vacanciesText);
    if (vacanciesText.isEmpty || parsedVacancies == null || parsedVacancies < 1) {
      _vacanciesError = 'Please enter at least 1 candidate to hire.';
      hasError = true;
    } else if (parsedVacancies < _acceptedCount) {
      _vacanciesError =
          'Cannot set below $_acceptedCount ($_acceptedCount candidate${_acceptedCount == 1 ? ' is' : 's are'} already accepted).';
      hasError = true;
    } else if (parsedVacancies > 500) {
      _vacanciesError = 'Maximum allowed per job posting is 500.';
      hasError = true;
    }

    final minStr = _minSalaryController.text.trim();
    final maxStr = _maxSalaryController.text.trim();

    final int? minSalary = minStr.isEmpty ? null : int.tryParse(minStr);
    final int? maxSalary = maxStr.isEmpty ? null : int.tryParse(maxStr);

    if (minStr.isNotEmpty && minSalary == null) {
      _minSalaryError = 'Enter a valid amount.';
      hasError = true;
    }

    if (effectiveJobType == 'Full-time' &&
        maxStr.isNotEmpty &&
        maxSalary == null) {
      _maxSalaryError = 'Enter a valid amount.';
      hasError = true;
    }

    if (effectiveJobType == 'Full-time' &&
        minSalary != null &&
        maxSalary != null &&
        minSalary > maxSalary) {
      _salaryError = 'Minimum salary cannot be greater than maximum salary.';
      hasError = true;
    }

    // Applicant-based restriction: prevent lowering or removing minimum salary
    if (_hasApplicants && _originalMinSalary != null) {
      if (minSalary == null || minSalary < _originalMinSalary!) {
        _salaryError =
            'Cannot lower salary below RM $_originalMinSalary once candidates have applied.';
        hasError = true;
      }
    }

    if (hasError) {
      setState(() {
        _formError = 'Please fix the highlighted fields before saving.';
      });
      return;
    }

    setState(() => _isSubmitting = true);

    final int parsedExperience = int.tryParse(experienceText) ?? 0;

    String finalSalaryRange;
    if (effectiveJobType == 'Part-time') {
      if (minSalary != null) {
        finalSalaryRange = 'RM $minSalary / hr';
      } else {
        finalSalaryRange = '';
      }
    } else {
      if (minSalary != null && maxSalary != null) {
        finalSalaryRange = 'RM $minSalary - RM $maxSalary';
      } else if (minSalary != null) {
        finalSalaryRange = 'RM $minSalary';
      } else {
        finalSalaryRange = '';
      }
    }

    final DateTime? finalExpiresAt =
        _updateExpiryDate ? _calculatedExpiryDate : widget.job.expiresAt;

    final updatedJob = JobModel(
      jobID: widget.job.jobID,
      companyID: widget.job.companyID,
      employerID: widget.job.employerID,
      status: widget.job.status,
      title: title,
      description: description,
      salaryRange: finalSalaryRange,
      latitude: _selectedLat,
      longitude: _selectedLng,
      minExperienceYears: parsedExperience,
      jobType: effectiveJobType,
      locationName: _selectedLocationName,
      expiresAt: finalExpiresAt,
      workplaceType: effectiveWorkplaceType,
      workingPeriod: workingPeriodText,
      qualification: effectiveQualification,
      vacancies: parsedVacancies ?? widget.job.vacancies,
    );

    final success = await _employerService.updateJobPosting(updatedJob);

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job Updated Successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, updatedJob);
    } else {
      setState(() {
        _formError = 'Failed to update job. Please try again.';
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
    _vacanciesController.dispose();
    _workingPeriodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isBlocked = _isDeleted || !_isJobOwner;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: (_isSubmitting || _isLoadingContext)
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 16),
                  _buildHeroCard(),
                  const SizedBox(height: 20),
                  if (isBlocked)
                    _buildBlockedRestrictionCard()
                  else ...[
                    if (_isInactive) ...[
                      _buildInactiveNoticeBanner(),
                      const SizedBox(height: 16),
                    ],
                    if (_hasApplicants) ...[
                      _buildApplicantRestrictionBanner(),
                      const SizedBox(height: 16),
                    ],
                    _buildJobDetailsSection(),
                    const SizedBox(height: 18),
                    _buildJobExpirySection(),
                    const SizedBox(height: 18),
                    _buildSalarySection(),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      title: 'Work Location',
                      subtitle:
                          'Update the work address and map pin candidates will see for this role.',
                      child: _buildLocationPanel(),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      title: 'Job Description',
                      subtitle:
                          'Describe the responsibilities, requirements, and opportunities for this role.',
                      child: _buildStyledField(
                        controller: _descriptionController,
                        label: 'Full Job Description',
                        icon: Icons.description_rounded,
                        maxLines: 6,
                        errorText: _descriptionError,
                        onChanged: (_) => _clearJobDetailsErrors(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSavePanel(),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildBlockedRestrictionCard() {
    final String title = _isDeleted
        ? 'Job Posting Deleted'
        : 'Editing Restricted to Job Creator';
    final String message = _isDeleted
        ? 'This job posting has been deleted by an administrator and can no longer be edited.'
        : 'Only the employer who originally created this job posting is allowed to modify its details.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3B8B8)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.lock_person_rounded,
              color: Color(0xFFC24E4E),
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF687588),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveNoticeBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD3E3F8)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF163B65),
            size: 22,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editing an Inactive Job',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF163B65),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'You can update these details while the job is inactive, then activate it from the Job Details screen when ready.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF335D8A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantRestrictionBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF6E6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF5D491)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_clock_rounded,
            color: Color(0xFFB47814),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Core Requirements Locked ($_applicantCount ${_applicantCount == 1 ? 'Applicant' : 'Applicants'})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8C5B08),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Because candidates have already applied to this job, Job Title, Job Type, Work Arrangement, Minimum Qualification, and Experience are locked to keep applications fair.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF8C5B08),
                  ),
                ),
              ],
            ),
          ),
        ],
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
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Job Posting Update',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (_jobCompany != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _jobCompany!.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
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
            'Refresh this posting so candidates see the latest role details, work arrangement, compensation, and location.',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildJobDetailsSection() {
    final bool lockCoreFields = _hasApplicants;

    return _buildSectionCard(
      title: 'Job Details',
      subtitle: lockCoreFields
          ? 'Core requirements are locked because candidates have already applied. Working schedule remains editable.'
          : 'Keep the role title, work arrangement, schedule, and requirements up to date.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStyledField(
            controller: _titleController,
            label: 'Job Title',
            icon: Icons.title_rounded,
            enabled: !lockCoreFields,
            errorText: _titleError,
            onChanged: (_) => _clearJobDetailsErrors(),
          ),
          const SizedBox(height: 16),
          _buildStyledDropdown(
            value: _selectedJobType,
            label: 'Job Type',
            icon: Icons.schedule_rounded,
            enabled: !lockCoreFields,
            items: [
              _buildDropdownItem(
                value: 'Full-time',
                label: 'Full-time',
                isSelected: _selectedJobType == 'Full-time',
              ),
              _buildDropdownItem(
                value: 'Part-time',
                label: 'Part-time',
                isSelected: _selectedJobType == 'Part-time',
              ),
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
            enabled: !lockCoreFields,
            items: [
              _buildDropdownItem(
                value: 'On-site',
                label: 'On-site (Work at Company)',
                isSelected: _selectedWorkplaceType == 'On-site',
              ),
              _buildDropdownItem(
                value: 'Remote',
                label: 'Remote (Work from Home)',
                isSelected: _selectedWorkplaceType == 'Remote',
              ),
              _buildDropdownItem(
                value: 'Hybrid',
                label: 'Hybrid (Both Home & Company)',
                isSelected: _selectedWorkplaceType == 'Hybrid',
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
            label: 'Working Schedule / Period',
            icon: Icons.access_time_filled_rounded,
            errorText: _workingPeriodError,
            onChanged: (_) => _clearJobDetailsErrors(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _workingPeriodPresets.map((preset) {
              final isSelected =
                  _workingPeriodController.text.trim() == preset;
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
                      color:
                          isSelected ? Colors.white : const Color(0xFF4F5C6C),
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
            enabled: !lockCoreFields,
            items: [
              _buildDropdownItem(
                value: 'No Minimum',
                label: 'No Minimum Qualification',
                isSelected: _selectedQualification == 'No Minimum',
              ),
              _buildDropdownItem(
                value: 'SPM / O-Level',
                label: 'SPM / O-Level',
                isSelected: _selectedQualification == 'SPM / O-Level',
              ),
              _buildDropdownItem(
                value: 'STPM / A-Level / Foundation',
                label: 'STPM / A-Level / Foundation',
                isSelected:
                    _selectedQualification == 'STPM / A-Level / Foundation',
              ),
              _buildDropdownItem(
                value: 'Certificate / SKM',
                label: 'Certificate / SKM',
                isSelected: _selectedQualification == 'Certificate / SKM',
              ),
              _buildDropdownItem(
                value: 'Diploma',
                label: 'Diploma',
                isSelected: _selectedQualification == 'Diploma',
              ),
              _buildDropdownItem(
                value: "Bachelor's Degree",
                label: "Bachelor's Degree",
                isSelected: _selectedQualification == "Bachelor's Degree",
              ),
              _buildDropdownItem(
                value: "Master's Degree",
                label: "Master's Degree",
                isSelected: _selectedQualification == "Master's Degree",
              ),
              _buildDropdownItem(
                value: 'Doctorate (PhD)',
                label: 'Doctorate (PhD)',
                isSelected: _selectedQualification == 'Doctorate (PhD)',
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
            enabled: !lockCoreFields,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            errorText: _experienceError,
            onChanged: (_) => _clearJobDetailsErrors(),
          ),
          const SizedBox(height: 16),
          _buildVacanciesSelector(),
        ],
      ),
    );
  }

  Widget _buildVacanciesSelector() {
    final minAllowed = _acceptedCount > 1 ? _acceptedCount : 1;
    final currentVal = int.tryParse(_vacanciesController.text.trim());
    final canDecrement = currentVal != null && currentVal > minAllowed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _vacanciesError != null
                  ? const Color(0xFFC24E4E)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.groups_2_rounded,
                color: Color(0xFF163B65),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _vacanciesController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  onChanged: (_) {
                    _clearJobDetailsErrors();
                    setState(() {});
                  },
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B2433),
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Candidates to Hire (Vacancies)',
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF687588),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildStepperButton(
                icon: Icons.remove_rounded,
                enabled: canDecrement,
                onTap: () {
                  final next = ((currentVal ?? minAllowed) - 1)
                      .clamp(minAllowed, 500);
                  setState(() {
                    _vacanciesController.text = next.toString();
                    _vacanciesError = null;
                    _formError = null;
                  });
                },
              ),
              const SizedBox(width: 6),
              _buildStepperButton(
                icon: Icons.add_rounded,
                enabled: (currentVal ?? minAllowed) < 500,
                onTap: () {
                  final next = ((currentVal ?? (minAllowed - 1)) + 1)
                      .clamp(minAllowed, 500);
                  setState(() {
                    _vacanciesController.text = next.toString();
                    _vacanciesError = null;
                    _formError = null;
                  });
                },
              ),
            ],
          ),
        ),
        if (_vacanciesError != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _vacanciesError!,
              style: const TextStyle(
                color: Color(0xFFC24E4E),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (_acceptedCount > 0) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 15,
                  color: Color(0xFF2D8A5D),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$_acceptedCount candidate${_acceptedCount == 1 ? ' is' : 's are'} already accepted (minimum allowed: $minAllowed).',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D8A5D),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [1, 2, 3, 5, 10]
              .where((preset) => preset >= minAllowed)
              .map((preset) {
            final isSelected = currentVal == preset;
            return InkWell(
              onTap: () {
                setState(() {
                  _vacanciesController.text = preset.toString();
                  _vacanciesError = null;
                  _formError = null;
                });
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF163B65)
                      : const Color(0xFFF1F5FA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$preset ${preset == 1 ? 'Hire' : 'Hires'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF4F5C6C),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: enabled ? Colors.white : const Color(0xFFEDF1F7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? const Color(0xFF163B65) : const Color(0xFF9AA5B5),
          ),
        ),
      ),
    );
  }

  Widget _buildJobExpirySection() {
    final List<int> durationOptions = _expiryUnit == 'Weeks'
        ? const [1, 2, 3, 4]
        : const [1, 2, 3, 6, 12];
    final currentExpiryText = widget.job.expiresAt != null
        ? DateFormat('dd MMM yyyy').format(widget.job.expiresAt!.toLocal())
        : 'Not set';
    final formattedNewExpiry =
        DateFormat('dd MMM yyyy').format(_calculatedExpiryDate);

    return _buildSectionCard(
      title: 'Job Expiry Duration',
      subtitle:
          'Keep the current expiry date or extend how long this job stays active.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SwitchListTile(
              title: const Text(
                'Update Expiry Duration',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF1B2433),
                ),
              ),
              subtitle: Text(
                'Current expiry: $currentExpiryText',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF687588),
                ),
              ),
              value: _updateExpiryDate,
              activeColor: const Color(0xFF163B65),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              onChanged: (val) {
                setState(() {
                  _updateExpiryDate = val;
                });
              },
            ),
          ),
          if (_updateExpiryDate) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStyledDropdown(
                    value: _expiryDuration.toString(),
                    label: 'Duration',
                    icon: Icons.timelapse_rounded,
                    items: durationOptions
                        .map(
                          (d) => _buildDropdownItem(
                            value: d.toString(),
                            label: '$d',
                            isSelected: _expiryDuration == d,
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
                    items: [
                      _buildDropdownItem(
                        value: 'Weeks',
                        label: 'Week(s)',
                        isSelected: _expiryUnit == 'Weeks',
                      ),
                      _buildDropdownItem(
                        value: 'Months',
                        label: 'Month(s)',
                        isSelected: _expiryUnit == 'Months',
                      ),
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
                      'New expiry date: $formattedNewExpiry ($_expiryDuration ${_expiryUnit.toLowerCase()} from today).',
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
        ],
      ),
    );
  }

  Widget _buildSalarySection() {
    final isPartTime = _selectedJobType == 'Part-time';
    return _buildSectionCard(
      title: 'Compensation',
      subtitle: isPartTime
          ? 'Set the hourly rate for this part-time role or ask AI for market rates.'
          : 'Provide a monthly salary range or ask AI for market rates.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasApplicants && _originalMinSalary != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: Color(0xFF163B65),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Minimum rate cannot be lowered below RM $_originalMinSalary${isPartTime ? ' / hr' : ''} while applicants exist.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4F5C6C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: _buildStyledField(
                  controller: _minSalaryController,
                  label: isPartTime ? 'Hourly Rate' : 'Min Salary',
                  icon: Icons.payments_rounded,
                  keyboardType: TextInputType.number,
                  prefixText: 'RM ',
                  suffixText: isPartTime ? ' / hr' : null,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  errorText: _minSalaryError,
                  onChanged: (_) => _clearSalaryError(),
                ),
              ),
              if (!isPartTime) ...[
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
                      _hasActiveSubscription ? Icons.auto_awesome : Icons.lock,
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
    final bool hasLocation = _selectedLat != null && _selectedLng != null;
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
                hasLocation
                    ? 'Change Location on Map'
                    : 'Search or Pick on Map',
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x1210243E),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
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

  Widget _buildStyledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool enabled = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
    String? suffixText,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: TextStyle(
        color: enabled ? const Color(0xFF1B2433) : const Color(0xFF687588),
        fontWeight: enabled ? FontWeight.w500 : FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        prefixIcon: Icon(
          icon,
          color: enabled ? const Color(0xFF687588) : const Color(0xFF9AA5B5),
        ),
        suffixIcon: !enabled
            ? const Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: Color(0xFF9AA5B5),
              )
            : null,
        prefixText: prefixText,
        suffixText: suffixText,
        filled: true,
        fillColor:
            enabled ? const Color(0xFFF7F9FC) : const Color(0xFFEEF2F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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

  DropdownMenuItem<String> _buildDropdownItem({
    required String value,
    required String label,
    bool isSelected = false,
  }) {
    return DropdownMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF163B65)
                    : const Color(0xFF1B2433),
              ),
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_rounded,
              size: 18,
              color: Color(0xFF163B65),
            ),
        ],
      ),
    );
  }

  Widget _buildStyledDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    bool enabled = true,
    String? errorText,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      isExpanded: true,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 6,
      menuMaxHeight: 340,
      icon: Icon(
        enabled ? Icons.keyboard_arrow_down_rounded : Icons.lock_outline_rounded,
        color: enabled ? const Color(0xFF163B65) : const Color(0xFF9AA5B5),
        size: enabled ? 22 : 18,
      ),
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: enabled ? const Color(0xFF1B2433) : const Color(0xFF687588),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF687588),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: enabled ? const Color(0xFF163B65) : const Color(0xFF687588),
          fontWeight: FontWeight.w700,
        ),
        errorText: errorText,
        prefixIcon: Icon(
          icon,
          color: enabled ? const Color(0xFF163B65) : const Color(0xFF9AA5B5),
        ),
        filled: true,
        fillColor:
            enabled ? const Color(0xFFF7F9FC) : const Color(0xFFEEF2F7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFF163B65),
            width: 1.6,
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
            width: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildSavePanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1210243E),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_formError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3B8B8)),
              ),
              child: Text(
                _formError!,
                style: const TextStyle(
                  color: Color(0xFFC24E4E),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const Text(
            'Save your changes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'These updates will be reflected in the job posting after saving.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF687588),
            ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
