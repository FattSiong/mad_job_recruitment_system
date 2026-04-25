import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../core/utils/file_preview_helper.dart';
import '../../../models/job_seeker_model.dart';
import '../../../models/work_experience_model.dart';
import '../../../models/education_model.dart';
import '../controllers/profile_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileController _controller = ProfileController();
  JobSeekerModel? _profile;
  bool _isLoading = true;
  bool _isUploading = false;

  bool _isEditing = false;

  // 👉 Added Email Controller
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _linkedinController = TextEditingController();
  final TextEditingController _githubController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    _linkedinController.dispose();
    _githubController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final profile = await _controller.fetchProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
      _populateControllers();
    }
  }

  void _populateControllers() {
    if (_profile != null) {
      _nameController.text = _profile!.fullName;
      _emailController.text = _profile!.email ?? '';
      _phoneController.text = _profile!.phoneNumber ?? '';
      _locationController.text = _profile!.location ?? '';
      _bioController.text = _profile!.bio ?? '';
      _linkedinController.text = _profile!.linkedInURL ?? '';
      _githubController.text = _profile!.gitHubURL ?? '';
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString.startsWith('http') ? urlString : 'https://$urlString');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch URL')));
      }
    }
  }

  Future<void> _pickAndUploadResume() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isUploading = true);

      File file = File(result.files.single.path!);
      String? newUrl = await _controller.uploadResume(file);

      if (mounted) {
        if (newUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resume uploaded successfully!'), backgroundColor: AppColors.successGreen));
          _loadProfile();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload resume.'), backgroundColor: AppColors.errorRed));
        }
        setState(() => _isUploading = false);
      }
    }
  }

  String _formatDateRange(DateTime start, DateTime? end, bool isCurrent) {
    final DateFormat formatter = DateFormat('MMM yyyy');
    String startStr = formatter.format(start);
    String endStr = isCurrent ? 'Present' : (end != null ? formatter.format(end) : 'N/A');
    return '$startStr - $endStr';
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onAddPressed}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          if (onAddPressed != null && _isEditing)
            TextButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add_circle, color: AppColors.primaryBlue, size: 20),
              label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryBlue),
            ),
        ],
      ),
    );
  }

  // 👉 Updated Editable Field builder
  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required Widget icon,
    int maxLines = 1,
    bool isReadOnly = false,
    bool isLink = false
  }) {
    if (!_isEditing) {
      final isEmpty = controller.text.trim().isEmpty;

      String displayValue = controller.text;
      if (isEmpty) {
        displayValue = '-';
      } else if (isLink) {
        displayValue = 'Profile';
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
              child: icon,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 4),

                  // 👉 Added StatefulBuilder to manage hover state locally
                  StatefulBuilder(
                      builder: (context, setLinkState) {
                        bool isHovered = false;

                        return MouseRegion(
                          cursor: (!isEmpty && isLink) ? SystemMouseCursors.click : SystemMouseCursors.basic,
                          onEnter: (_) => setLinkState(() => isHovered = true),
                          onExit: (_) => setLinkState(() => isHovered = false),
                          child: GestureDetector(
                            onTap: (!isEmpty && isLink) ? () => _launchURL(controller.text) : null,
                            child: Text(
                                displayValue,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: (!isEmpty && isLink) ? AppColors.primaryBlue : Colors.black87,
                                  // 👉 Decoration now depends on isHovered state
                                  decoration: (isHovered && !isEmpty && isLink)
                                      ? TextDecoration.underline
                                      : TextDecoration.none,
                                  height: 1.5,
                                )
                            ),
                          ),
                        );
                      }
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Edit Mode remains the same
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        readOnly: isReadOnly,
        style: TextStyle(color: isReadOnly ? Colors.grey.shade500 : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12.0),
            child: icon,
          ),
          filled: true,
          fillColor: isReadOnly ? Colors.grey.shade200 : Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // Only the QR Code button stays here now
          if (!_isEditing && _profile != null)
            IconButton(
              icon: const Icon(Icons.qr_code, color: Colors.black),
              onPressed: _showQRCodeDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : _profile == null
          ? const Center(child: Text('Failed to load profile.'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(UiConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 👉 Basic Information Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isEditing) ...[
                    Text(_profile!.fullName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 24),
                  ],

                  // 👉 Fields
                  // 👉 Fields
                  if (_isEditing) _buildEditableField(label: 'Full Name', controller: _nameController, icon: Icon(Icons.person, color: Colors.grey.shade600, size: 20)),
                  _buildEditableField(label: 'Email', controller: _emailController, icon: Icon(Icons.email, color: Colors.grey.shade600, size: 20), isReadOnly: true),
                  _buildEditableField(label: 'Phone Number', controller: _phoneController, icon: Icon(Icons.phone, color: Colors.grey.shade600, size: 20)),
                  _buildEditableField(label: 'Location', controller: _locationController, icon: Icon(Icons.location_on, color: Colors.grey.shade600, size: 20)),
                  _buildEditableField(label: 'Bio / About Me', controller: _bioController, icon: Icon(Icons.book, color: Colors.grey.shade600, size: 20), maxLines: 4),
                  _buildEditableField(label: 'LinkedIn URL', controller: _linkedinController, icon: FaIcon(FontAwesomeIcons.linkedin, color: Colors.grey.shade600, size: 20), isLink: true),
                  _buildEditableField(label: 'GitHub URL', controller: _githubController, icon: FaIcon(FontAwesomeIcons.github, color: Colors.grey.shade600, size: 20), isLink: true),
                ],
              ),
            ),

            // Resume Section
            _buildSectionHeader('Resume Document'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_profile!.resumeURL != null) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.errorRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.picture_as_pdf, color: AppColors.errorRed, size: 28),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(child: Text('Resume Uploaded', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                        TextButton.icon(
                          onPressed: () => FilePreviewHelper.previewNetworkFile(context, _profile!.resumeURL!),
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('View'),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickAndUploadResume,
                      icon: _isUploading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_file),
                      label: Text(_profile!.resumeURL != null ? 'Upload New Resume' : 'Upload Resume'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryBlue,
                          side: const BorderSide(color: AppColors.primaryBlue),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 👉 Work Experience Section
            _buildSectionHeader('Work Experience', onAddPressed: () => _showAddExperienceSheet(context)),
            if (_profile!.workExperience.isEmpty)
              const Text('No work experience added yet.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
            else
              ..._profile!.workExperience.map((exp) => Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.work, color: AppColors.primaryBlue, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(exp.jobTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text(exp.companyName, style: TextStyle(color: Colors.grey.shade700, fontSize: 15, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(_formatDateRange(exp.startDate, exp.endDate, exp.isCurrent), style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          if (exp.description != null && exp.description!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(exp.description!, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4)),
                          ],
                        ],
                      ),
                    ),
                    if (_isEditing && exp.experienceID != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                        onPressed: () => _controller.deleteWorkExperience(context: context, experienceId: exp.experienceID!, onSuccess: _loadProfile),
                      ),
                  ],
                ),
              )),

            // 👉 Education Section
            _buildSectionHeader('Education', onAddPressed: () => _showAddEducationSheet(context)),
            if (_profile!.education.isEmpty)
              const Text('No education details added yet.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
            else
              ..._profile!.education.map((edu) => Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.school, color: Colors.orange, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 👉 Updated: Combine Degree and Field of Study if it exists
                          Text(
                            edu.fieldOfStudy != null && edu.fieldOfStudy!.isNotEmpty
                                ? '${edu.degree} - ${edu.fieldOfStudy}'
                                : edu.degree,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Text(edu.institutionName, style: TextStyle(color: Colors.grey.shade700, fontSize: 15, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(_formatDateRange(edu.startDate, edu.endDate, edu.isCurrent), style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),

                          // 👉 Added: Show Description if it exists
                          if (edu.description != null && edu.description!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(edu.description!, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4)),
                          ],
                        ],
                      ),
                    ),
                    if (_isEditing && edu.educationID != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                        onPressed: () => _controller.deleteEducation(context: context, educationId: edu.educationID!, onSuccess: _loadProfile),
                      ),
                  ],
                ),
              )),

            const SizedBox(height: 60),
          ],
        ),
      ),
      // 👉 1. The Edit Floating Button (Only shows when NOT editing)
      floatingActionButton: (!_isEditing && _profile != null)
          ? FloatingActionButton.extended(
        onPressed: () => setState(() => _isEditing = true),
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryBlue,
        elevation: 4,
      )
          : null,

      // 👉 2. The Sticky Save/Cancel Bar (Only shows WHEN editing)
      bottomNavigationBar: _isEditing
          ? SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _isEditing = false);
                    _populateControllers();
                  },
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    if (_nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty.')));
                      return;
                    }

                    final updatedModel = JobSeekerModel(
                      seekerID: _profile!.seekerID,
                      fullName: _nameController.text.trim(),
                      email: _profile!.email,
                      resumeURL: _profile!.resumeURL,
                      phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
                      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
                      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
                      linkedInURL: _linkedinController.text.trim().isEmpty ? null : _linkedinController.text.trim(),
                      gitHubURL: _githubController.text.trim().isEmpty ? null : _githubController.text.trim(),
                    );

                    setState(() => _isEditing = false);
                    await _controller.updateProfileBasics(context: context, updatedModel: updatedModel, onSucess: _loadProfile);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: const Text('Save Details', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      )
          : null,
    );
  }

  void _showQRCodeDialog() {
    if (_profile == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('My Profile QR', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Let recruiters scan this to view your resume and experience.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              height: 220,
              child: QrImageView(
                data: 'profile:${_profile!.seekerID}', // The data your scanner will read
                version: QrVersions.auto,
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // BOTTOM SHEETS (Modernized)
  // =========================================================================

  Future<DateTime?> _pickDate(BuildContext context, DateTime? initialDate) async {
    return await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primaryBlue),
          ),
          child: child!,
        );
      },
    );
  }

  // 👉 Helper for modern input decoration
  InputDecoration _sheetInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2)),
    );
  }

  void _showAddExperienceSheet(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final companyController = TextEditingController();
    final descController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    bool isCurrentRole = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),

                    const Text('Add Work Experience', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: titleController,
                      decoration: _sheetInputDecoration('Job Title*', Icons.work),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: companyController,
                      decoration: _sheetInputDecoration('Company Name*', Icons.business),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await _pickDate(context, startDate);
                              if (date != null) setModalState(() => startDate = date);
                            },
                            child: InputDecorator(
                              decoration: _sheetInputDecoration('Start Date*', Icons.calendar_today),
                              child: Text(startDate == null ? 'Select' : DateFormat('yMd').format(startDate!), style: TextStyle(color: startDate == null ? Colors.grey.shade600 : Colors.black87)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: isCurrentRole ? null : () async {
                              final date = await _pickDate(context, endDate);
                              if (date != null) setModalState(() => endDate = date);
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'End Date',
                                prefixIcon: Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
                                filled: true,
                                fillColor: isCurrentRole ? Colors.grey.shade200 : Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              ),
                              child: Text(
                                isCurrentRole ? 'Present' : (endDate == null ? 'Select' : DateFormat('yMd').format(endDate!)),
                                style: TextStyle(color: (endDate == null && !isCurrentRole) ? Colors.grey.shade600 : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (startDate == null)
                      const Padding(
                        padding: EdgeInsets.only(left: 12.0, top: 6),
                        child: Text('Start date required', style: TextStyle(color: AppColors.errorRed, fontSize: 12)),
                      ),

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                            value: isCurrentRole,
                            activeColor: AppColors.primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (v) {
                              setModalState(() {
                                isCurrentRole = v ?? false;
                                if (isCurrentRole) endDate = null;
                              });
                            }
                        ),
                        const Text('I currently work here', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descController,
                      decoration: _sheetInputDecoration('Description', Icons.description),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate() && startDate != null) {
                          if (!isCurrentRole && endDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an end date or mark as current role.')));
                            return;
                          }
                          if (!isCurrentRole && endDate != null && endDate!.isBefore(startDate!)) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date cannot be before start date.')));
                            return;
                          }
                          final newExp = WorkExperienceModel(
                            seekerID: '',
                            companyName: companyController.text.trim(),
                            jobTitle: titleController.text.trim(),
                            startDate: startDate!,
                            endDate: endDate,
                            isCurrent: isCurrentRole,
                            description: descController.text.trim(),
                          );
                          Navigator.pop(context);
                          _controller.addWorkExperience(context: context, experience: newExp, onSucess: _loadProfile);
                        } else if (startDate == null) {
                          setModalState(() {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Add Experience', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddEducationSheet(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final institutionController = TextEditingController();
    final fieldOfStudyController = TextEditingController();
    final descController = TextEditingController(); // 👉 Added description controller
    DateTime? startDate;
    DateTime? endDate;
    bool isCurrent = false;

    final List<String> degreeOptions = [
      'High School / SPM',
      'Certificate',
      'Diploma',
      "Bachelor's Degree",
      "Master's Degree",
      'Doctorate / PhD',
      'Other'
    ];
    String? selectedDegree;

    // 👉 Logic updated: Diploma and above requires Field of Study
    bool isDiplomaOrAbove(String? degree) {
      return degree == 'Diploma' ||
          degree == "Bachelor's Degree" ||
          degree == "Master's Degree" ||
          degree == 'Doctorate / PhD';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 20),

                    const Text('Add Education', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: institutionController,
                      decoration: _sheetInputDecoration('Institution Name*', Icons.school),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // 👉 Replaced 'value' with 'initialValue' to resolve the warning
                    DropdownButtonFormField<String>(
                      decoration: _sheetInputDecoration('Degree/Qualification*', Icons.history_edu),
                      initialValue: selectedDegree,
                      items: degreeOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setModalState(() {
                          selectedDegree = newValue;
                          if (!isDiplomaOrAbove(newValue)) {
                            fieldOfStudyController.clear();
                          }
                        });
                      },
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    if (isDiplomaOrAbove(selectedDegree)) ...[
                      TextFormField(
                        controller: fieldOfStudyController,
                        decoration: _sheetInputDecoration('Field of Study*', Icons.menu_book),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await _pickDate(context, startDate);
                              if (date != null) setModalState(() => startDate = date);
                            },
                            child: InputDecorator(
                              decoration: _sheetInputDecoration('Start Date*', Icons.calendar_today),
                              child: Text(startDate == null ? 'Select' : DateFormat('yMd').format(startDate!), style: TextStyle(color: startDate == null ? Colors.grey.shade600 : Colors.black87)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: isCurrent ? null : () async {
                              final date = await _pickDate(context, endDate);
                              if (date != null) setModalState(() => endDate = date);
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'End Date',
                                prefixIcon: Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 20),
                                filled: true,
                                fillColor: isCurrent ? Colors.grey.shade200 : Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                              ),
                              child: Text(
                                isCurrent ? 'Current' : (endDate == null ? 'Select' : DateFormat('yMd').format(endDate!)),
                                style: TextStyle(color: (endDate == null && !isCurrent) ? Colors.grey.shade600 : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (startDate == null)
                      const Padding(
                        padding: EdgeInsets.only(left: 12.0, top: 6),
                        child: Text('Start date required', style: TextStyle(color: AppColors.errorRed, fontSize: 12)),
                      ),

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                            value: isCurrent,
                            activeColor: AppColors.primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (v) {
                              setModalState(() {
                                isCurrent = v ?? false;
                                if (isCurrent) endDate = null;
                              });
                            }
                        ),
                        const Text('I am currently studying here', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),

                    // 👉 Added Description Field
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descController,
                      decoration: _sheetInputDecoration('Description / Achievements', Icons.description),
                      maxLines: 4,
                    ),

                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate() && startDate != null) {
                          if (!isCurrent && endDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an end date or mark as current study.')));
                            return;
                          }
                          if (!isCurrent && endDate != null && endDate!.isBefore(startDate!)) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date cannot be before start date.')));
                            return;
                          }

                          final newEdu = EducationModel(
                            institutionName: institutionController.text.trim(),
                            degree: selectedDegree!,
                            fieldOfStudy: isDiplomaOrAbove(selectedDegree) ? fieldOfStudyController.text.trim() : null,
                            description: descController.text.trim(), // 👉 Added
                            startDate: startDate!,
                            endDate: endDate,
                            isCurrent: isCurrent,
                          );

                          Navigator.pop(context);
                          _controller.addEducation(context: context, education: newEdu, onSucess: _loadProfile);
                        } else if (startDate == null) {
                          setModalState(() {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Add Education', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}