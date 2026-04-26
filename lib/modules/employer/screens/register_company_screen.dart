import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/company_model.dart';
import '../../../services/employer_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'company_map_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/services.dart';


class RegisterCompanyScreen extends StatefulWidget {
  const RegisterCompanyScreen({super.key});

  @override
  State<RegisterCompanyScreen> createState() => _RegisterCompanyScreenState();
}

class _RegisterCompanyScreenState extends State<RegisterCompanyScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _regNumberController = TextEditingController();
  final RegExp _ssmRegex = RegExp(r'^\d{12}$');

  final _employerService = EmployerService();
  bool _isLoading = false;
  File? _selectedFile; // 👉 Variable to hold the chosen file

  double? _selectedLat;
  double? _selectedLng;
  String? _selectedAddress;

  String? _nameError;
  String? _regNumberError;
  String? _formError;
  String? _locationError;
  String? _documentError;

  // 👉 Function to open the device's file explorer
  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _documentError = null;
        _formError = null;
      });
    }
  }

  Future<void> _previewDocument() async {
    if (_selectedFile == null) return;

    // Ask the phone's OS to open the file path
    final result = await OpenFilex.open(_selectedFile!.path);

    // Handle the case where the emulator/phone doesn't have a PDF reader installed
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open file. You may need an app to read this format.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _openLocationPicker() async {
    // 1. Navigate to the map and wait for the user to confirm a location
    final LatLng? pickedLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyMapPickerScreen(
          initialLat: _selectedLat,
          initialLng: _selectedLng,
        ),
      ),
    );

    // 2. If they picked a location (didn't just hit the back button)
    if (pickedLocation != null) {
      // Show a temporary loading state while we translate the coordinates
      setState(() {
        _selectedAddress = 'Translating map coordinates...';
        _locationError = null;
        _formError = null;
      });

      try {
        // 3. Ask the Geocoding package to turn the GPS pin into a real street address
        List<Placemark> placemarks = await placemarkFromCoordinates(
          pickedLocation.latitude,
          pickedLocation.longitude,
        );

        String readableAddress = 'Unknown Location';
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          // Build a clean address string (e.g., "Jalan Genting Kelang, Setapak, Kuala Lumpur")
          readableAddress = '${place.street}, ${place.subLocality ?? place.locality}, ${place.administrativeArea}';

          // Clean up any weird formatting where street might be empty
          readableAddress = readableAddress.replaceAll(RegExp(r'^, |, $'), '').replaceAll(', ,', ',');
        }

        // 4. Update the UI with the final data!
        setState(() {
          _selectedLat = pickedLocation.latitude;
          _selectedLng = pickedLocation.longitude;
          _selectedAddress = readableAddress;
        });

      } catch (e) {
        // Fallback: If the internet fails during translation, just show the raw GPS coordinates
        setState(() {
          _selectedLat = pickedLocation.latitude;
          _selectedLng = pickedLocation.longitude;
          _selectedAddress = 'Coordinates: ${pickedLocation.latitude.toStringAsFixed(4)}, ${pickedLocation.longitude.toStringAsFixed(4)}';
        });
      }
    }
  }


  Future<void> _submitCompany() async {
    setState(() {
      _formError = null;
      _locationError = null;
      _documentError = null;
      _nameError = null;
      _regNumberError = null;
    });

    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) return;

    final name = _nameController.text.trim();
    final regNumber = _regNumberController.text.trim();

    if (name.isEmpty ||
        regNumber.isEmpty ||
        !_ssmRegex.hasMatch(regNumber) ||
        _selectedFile == null ||
        _selectedLat == null) {
      setState(() {
        if (name.isEmpty) {
          _nameError = 'Please enter your company name.';
        }

        if (regNumber.isEmpty) {
          _regNumberError = 'Please enter your registration number.';
        } else if (!_ssmRegex.hasMatch(regNumber)) {
          _regNumberError = 'SSM number must be exactly 12 digits.';
        }

        if (_selectedFile == null) {
          _documentError = 'Please upload a verification document.';
        }

        if (_selectedLat == null) {
          _locationError = 'Please choose your company HQ location.';
        }

        _formError = 'Please complete all required fields before submitting.';
      });
      return;
    }



    setState(() => _isLoading = true);

    String? uploadedUrl = await _employerService.uploadVerificationDocument(
      _selectedFile!,
      _nameController.text,
    );

    if (uploadedUrl == null) {
      setState(() {
        _isLoading = false;
        _documentError = 'We could not upload your document. Please try again.';
      });
      return;
    }


    final newCompany = CompanyModel(
      name: _nameController.text,
      description: _descriptionController.text,
      registrationNumber: _regNumberController.text,
      verificationDocumentURL: uploadedUrl,
      latitude: _selectedLat,
      longitude: _selectedLng,
      companyAddress: _selectedAddress,
    );

    final createdCompany = await _employerService.registerCompany(
      newCompany,
      currentUser.id,
    );

    setState(() => _isLoading = false);

    if (createdCompany != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company Registered! Awaiting Admin Approval.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _regNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _buildTopBar(context),
            const SizedBox(height: 16),
            _buildHeroCard(),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'Company Information',
              subtitle: 'Tell us the basics of your company profile.',
              child: Column(
                children: [
                  _buildStyledField(
                    controller: _nameController,
                    label: 'Company Name',
                    icon: Icons.business_rounded,
                    errorText: _nameError,
                  ),
                  const SizedBox(height: 16),
                  _buildStyledField(
                    controller: _regNumberController,
                    label: 'SSM / Registration Number',
                    icon: Icons.badge_rounded,
                    errorText: _regNumberError,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStyledField(
                    controller: _descriptionController,
                    label: 'Company Description (Optional)',
                    icon: Icons.notes_rounded,
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _buildSectionCard(
              title: 'Headquarters Location',
              subtitle: 'Pick your main company location on the map.',
              child: _buildLocationPanel(),
            ),
            const SizedBox(height: 18),
            _buildSectionCard(
              title: 'Verification Document',
              subtitle: 'Upload your business document for admin review.',
              child: _buildDocumentPanel(),
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
            'Register Company',
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
                Icon(Icons.apartment_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Employer Setup',
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
            'Create a polished company profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Add your company details, location, and verification file so your workspace can be reviewed and activated.',
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

  Widget _buildStyledField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? errorText,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        prefixIcon: Icon(icon),
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
          borderSide: const BorderSide(color: Color(0xFF163B65), width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFC24E4E)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFC24E4E), width: 1.4),
        ),
      ),
    );
  }

  Widget _buildLocationPanel() {
    final bool hasLocation = _selectedLat != null && _selectedLng != null;

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
                  'Company HQ Location',
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
            _selectedAddress ?? 'No location selected yet.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: hasLocation ? const Color(0xFF1B2433) : const Color(0xFF687588),
            ),
          ),
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
            child: ElevatedButton.icon(
              onPressed: _openLocationPicker,
              icon: const Icon(Icons.map_rounded),
              label: Text(
                hasLocation ? 'Change Location' : 'Search or Pick on Map',
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

  Widget _buildDocumentPanel() {
    final bool hasFile = _selectedFile != null;
    final String fileName = hasFile
        ? _selectedFile!.path.split(Platform.pathSeparator).last
        : 'No document selected';

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
                  color: const Color(0xFFE8F6EE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.upload_file_rounded,
                  color: Color(0xFF2D8A5D),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Business Document',
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
            fileName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: hasFile ? FontWeight.w600 : FontWeight.w400,
              color: hasFile ? const Color(0xFF1B2433) : const Color(0xFF687588),
            ),
          ),
          if (_documentError != null) ...[
            const SizedBox(height: 8),
            Text(
              _documentError!,
              style: const TextStyle(
                color: Color(0xFFC24E4E),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _pickDocument,
                icon: const Icon(Icons.upload_rounded),
                label: Text(hasFile ? 'Change File' : 'Upload File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF163B65),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (hasFile)
                OutlinedButton.icon(
                  onPressed: _previewDocument,
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('Review'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF163B65),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
            ],
          ),
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
            'Ready to submit?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your company will be sent for verification after submission.',
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _submitCompany,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF163B65),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Submit for Verification',
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
