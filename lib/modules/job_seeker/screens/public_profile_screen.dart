import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../core/utils/file_preview_helper.dart';
import '../../../models/job_seeker_model.dart';
import '../controllers/profile_controller.dart';

class PublicProfileScreen extends StatefulWidget {
  final String seekerId; // Received from the QR Scanner

  const PublicProfileScreen({super.key, required this.seekerId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final ProfileController _controller = ProfileController();
  JobSeekerModel? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPublicProfile();
  }

  Future<void> _loadPublicProfile() async {
    // 👉 Uses the new method you just created in Step 1
    final profile = await _controller.fetchPublicProfile(widget.seekerId);
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
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

  String _formatDateRange(DateTime start, DateTime? end, bool isCurrent) {
    final DateFormat formatter = DateFormat('MMM yyyy');
    String startStr = formatter.format(start);
    String endStr = isCurrent ? 'Present' : (end != null ? formatter.format(end) : 'N/A');
    return '$startStr - $endStr';
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
    );
  }

  Widget _buildField({required String label, required String? value, required Widget icon, bool isLink = false}) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();

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
                GestureDetector(
                  onTap: isLink ? () => _launchURL(value) : null,
                  child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        color: isLink ? AppColors.primaryBlue : Colors.black87,
                        decoration: isLink ? TextDecoration.underline : TextDecoration.none,
                        height: 1.5,
                      )
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Candidate Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : _profile == null
          ? const Center(child: Text('Profile not found.'))
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
                  Text(_profile!.fullName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  const SizedBox(height: 24),

                  _buildField(label: 'Email', value: _profile!.email, icon: Icon(Icons.email, color: Colors.grey.shade600, size: 20)),
                  _buildField(label: 'Phone Number', value: _profile!.phoneNumber, icon: Icon(Icons.phone, color: Colors.grey.shade600, size: 20)),
                  _buildField(label: 'Location', value: _profile!.location, icon: Icon(Icons.location_on, color: Colors.grey.shade600, size: 20)),
                  _buildField(label: 'Bio / About Me', value: _profile!.bio, icon: Icon(Icons.book, color: Colors.grey.shade600, size: 20)),
                  _buildField(label: 'LinkedIn URL', value: _profile!.linkedInURL, icon: FaIcon(FontAwesomeIcons.linkedin, color: Colors.grey.shade600, size: 20), isLink: true),
                  _buildField(label: 'GitHub URL', value: _profile!.gitHubURL, icon: FaIcon(FontAwesomeIcons.github, color: Colors.grey.shade600, size: 20), isLink: true),
                ],
              ),
            ),

            // 👉 Resume Section
            if (_profile!.resumeURL != null) ...[
              _buildSectionHeader('Resume Document'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
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
              ),
            ],

            // 👉 Work Experience Section
            if (_profile!.workExperience.isNotEmpty) ...[
              _buildSectionHeader('Experience'),
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
                  ],
                ),
              )),
            ],

            // 👉 Education Section
            if (_profile!.education.isNotEmpty) ...[
              _buildSectionHeader('Education'),
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
                          Text(edu.degree, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text(edu.institutionName, style: TextStyle(color: Colors.grey.shade700, fontSize: 15, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(_formatDateRange(edu.startDate, edu.endDate, edu.isCurrent), style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            ],

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}