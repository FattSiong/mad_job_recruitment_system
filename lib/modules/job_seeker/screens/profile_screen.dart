import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../models/job_seeker_model.dart';
import '../controllers/profile_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileController _profileController = ProfileController();

  bool _isLoading = true;
  bool _isUploading = false;

  JobSeekerModel? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final profileData = await _profileController.getProfile();

    if (mounted) {
      setState(() {
        _profile = profileData;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadResume() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null && result.files.single.path != null) {
      File selectedFile = File(result.files.single.path!);
      setState(() => _isUploading = true);

      final newUrl = await _profileController.uploadResume(selectedFile);

      if (mounted) {
        setState(() {
          if (newUrl != null && _profile != null) {
            _profile = JobSeekerModel(
              seekerID: _profile!.seekerID,
              fullName: _profile!.fullName,
              email: _profile!.email,
              resumeURL: newUrl,
            );
          }
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newUrl != null ? 'Resume updated successfully!' : 'Failed to upload resume.'),
            backgroundColor: newUrl != null ? Colors.green : AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_profile == null) {
      return const Scaffold(body: Center(child: Text('Failed to load profile data.')));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(UiConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _profile!.fullName,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _profile!.email ?? 'No email provided',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),

            const Text(
              'My Resume',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(UiConstants.defaultPadding),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
                color: AppColors.backgroundLight,
              ),
              child: Row(
                children: [
                  Icon(
                    _profile!.resumeURL != null ? Icons.description : Icons.warning_amber_rounded,
                    color: _profile!.resumeURL != null ? AppColors.primaryBlue : Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profile!.resumeURL != null ? 'Resume Uploaded' : 'No Resume Uploaded',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _profile!.resumeURL != null
                              ? 'Your resume is ready for applications.'
                              : 'Upload a resume to apply for jobs.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickAndUploadResume,
                icon: _isUploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.upload_file),
                label: Text(
                  _isUploading
                      ? 'Uploading...'
                      : (_profile!.resumeURL != null ? 'Replace Resume' : 'Upload Resume'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UiConstants.cornerRadius),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Accepted formats: PDF, DOC, DOCX (Max 5MB)',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}