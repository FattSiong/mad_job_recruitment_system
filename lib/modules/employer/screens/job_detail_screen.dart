import 'package:flutter/material.dart';
import '../../../models/job_model.dart';
import '../../../services/employer_service.dart';
import 'edit_job_screen.dart';
import 'manage_applicants_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final JobModel job;

  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _employerService = EmployerService();
  late JobModel _currentJob;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentJob = widget.job;
  }

  Future<void> _toggleJobStatus() async {
    setState(() => _isLoading = true);

    final newStatus = _currentJob.status == 'active' ? 'closed' : 'active';

    // We safely unwrap jobID because it should exist if it came from the database
    if (_currentJob.jobID != null) {
      final success = await _employerService.updateJobStatus(_currentJob.jobID!, newStatus);

      if (success && mounted) {
        setState(() {
          // Update the local state so the UI changes instantly
          _currentJob = JobModel(
            jobID: _currentJob.jobID,
            companyID: _currentJob.companyID,
            employerID: _currentJob.employerID,
            title: _currentJob.title,
            description: _currentJob.description,
            latitude: _currentJob.latitude,
            longitude: _currentJob.longitude,
            salaryRange: _currentJob.salaryRange,
            minExperienceYears: _currentJob.minExperienceYears,
            status: newStatus,
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Job marked as ${newStatus.toUpperCase()}')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Widget _buildStatusBadge(String status) {
    final isActive = status.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? Colors.green : Colors.grey),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _currentJob.status.toLowerCase() == 'active';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Job',
            onPressed: () async {
              // Wait for the edit screen to return a JobModel (if the user clicked save)
              final updatedJob = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditJobScreen(job: _currentJob), // Pass the new screen
                ),
              );

              // If they saved changes, update the local UI instantly
              if (updatedJob != null && updatedJob is JobModel) {
                setState(() {
                  _currentJob = updatedJob;
                });
              }
            },
          ),

          if (!_isLoading)
            TextButton.icon(
              onPressed: _toggleJobStatus,
              icon: Icon(isActive ? Icons.visibility_off : Icons.visibility, color: Colors.white),
              label: Text(
                  isActive ? 'Close Job' : 'Reopen',
                  style: const TextStyle(color: Colors.white)
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _currentJob.title,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                _buildStatusBadge(_currentJob.status),
              ],
            ),
            const SizedBox(height: 24),

            // ATS Gateway Card (The most important action for the employer)
            Card(
              color: Colors.blue.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.shade200),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.people_alt, color: Colors.white),
                ),
                title: const Text('Applicant Tracking System', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Review resumes, manage interviews, and hire candidates.'),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.blue),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageApplicantsScreen(job: _currentJob),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Job Requirements Details
            const Text('Job Requirements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Info Grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                      Icons.monetization_on,
                      'Salary',
                      _currentJob.salaryRange
                  ),
                  const Divider(),
                  _buildInfoRow(
                      Icons.work_history,
                      'Experience',
                      _currentJob.minExperienceYears == 0
                          ? 'Entry Level (Fresh Graduates)'
                          : 'Minimum ${_currentJob.minExperienceYears} Years'
                  ),
                  const Divider(),
                  _buildInfoRow(
                      Icons.location_on,
                      'Location',
                      (_currentJob.latitude != null && _currentJob.longitude != null)
                          ? 'Map Coordinates Set' // Later, you can reverse-geocode this if you implement Google Maps
                          : 'No location provided'
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Description
            const Text('Full Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(
              _currentJob.description,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to keep the UI clean
  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}