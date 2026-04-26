import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

import '../../../services/employer_service.dart';

class EditEmployerProfileScreen extends StatefulWidget {
  final String employerId;
  final String initialFullName;
  final String initialEmail;
  final String? initialProfilePictureUrl;

  const EditEmployerProfileScreen({
    super.key,
    required this.employerId,
    required this.initialFullName,
    required this.initialEmail,
    required this.initialProfilePictureUrl,
  });

  @override
  State<EditEmployerProfileScreen> createState() =>
      _EditEmployerProfileScreenState();
}

class _EditEmployerProfileScreenState extends State<EditEmployerProfileScreen> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;

  final EmployerService _employerService = EmployerService();

  bool _isSaving = false;
  File? _newProfileImage;
  String? _formError;
  String? _fullNameError;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.initialFullName);
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.png,
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Profile Picture',
          toolbarColor: const Color(0xFF163B65),
          toolbarWidgetColor: Colors.white,
          backgroundColor: Colors.black,
          activeControlsWidgetColor: const Color(0xFF163B65),
          lockAspectRatio: true,
          hideBottomControls: false,
          cropStyle: CropStyle.circle,
          showCropGrid: false,
          dimmedLayerColor: Colors.black54,
        ),
        IOSUiSettings(
          title: 'Adjust Profile Picture',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          cropStyle: CropStyle.circle,
        ),
      ],
    );

    if (croppedFile == null) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final profilePicturesDir = Directory('${appDir.path}/profile_pictures');

      if (!await profilePicturesDir.exists()) {
        await profilePicturesDir.create(recursive: true);
      }

      final savedImagePath =
          '${profilePicturesDir.path}/employer_profile_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedImage = await File(croppedFile.path).copy(savedImagePath);

      setState(() {
        _newProfileImage = savedImage;
        _formError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _formError = 'Failed to prepare the selected image. Please try again.';
      });
    }
  }

  Future<void> _saveChanges() async {
    setState(() {
      _formError = null;
      _fullNameError = null;
    });

    if (_fullNameController.text.trim().isEmpty) {
      setState(() {
        _fullNameError = 'Please enter your full name.';
        _formError = 'Please complete the required field before saving.';
      });
      return;
    }

    setState(() => _isSaving = true);

    final success = await _employerService.updateEmployerProfile(
      employerId: widget.employerId,
      fullName: _fullNameController.text.trim(),
      newProfileImage: _newProfileImage,
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() {
        _formError = 'Failed to update profile. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: _isSaving
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Profile Picture',
                    subtitle:
                        'Update the photo shown across your employer workspace.',
                    child: _buildPhotoEditor(),
                  ),
                  const SizedBox(height: 18),
                  _buildSectionCard(
                    title: 'Profile Information',
                    subtitle:
                        'Edit your employer details that appear on the dashboard.',
                    child: Column(
                      children: [
                        _buildStyledField(
                          controller: _fullNameController,
                          label: 'Full Name',
                          icon: Icons.person_rounded,
                          errorText: _fullNameError,
                          onChanged: (_) {
                            if (_fullNameError != null || _formError != null) {
                              setState(() {
                                _fullNameError = null;
                                _formError = null;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildStyledField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          readOnly: true,
                        ),
                      ],
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
            'Edit Profile',
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

  Widget _buildPhotoEditor() {
    final hasNewImage = _newProfileImage != null;
    final hasExistingImage = widget.initialProfilePictureUrl != null &&
        widget.initialProfilePictureUrl!.isNotEmpty;
    final initial = _fullNameController.text.trim().isEmpty
        ? 'E'
        : _fullNameController.text.trim().substring(0, 1).toUpperCase();

    return Column(
      children: [
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 54,
                backgroundColor: const Color(0xFFDCEBFB),
                backgroundImage: hasNewImage
                    ? FileImage(_newProfileImage!) as ImageProvider
                    : hasExistingImage
                        ? NetworkImage(widget.initialProfilePictureUrl!)
                        : null,
                child: !hasNewImage && !hasExistingImage
                    ? Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF163B65),
                        ),
                      )
                    : null,
              ),
              Material(
                color: const Color(0xFF163B65),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _pickImage,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Tap the camera button to upload a new profile picture.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF687588),
          ),
        ),
      ],
    );
  }

  Widget _buildStyledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? errorText,
    bool readOnly = false,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onChanged: onChanged,
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

  Widget _buildSavePanel() {
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
            'Save your changes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your updated name and profile picture will appear in the employer workspace after saving.',
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
            child: ElevatedButton(
              onPressed: _saveChanges,
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
}
