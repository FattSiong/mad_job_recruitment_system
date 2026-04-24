import 'package:flutter/material.dart';
import '../../../models/job_model.dart';
import '../../../services/employer_service.dart';
import 'applicant_detail_screen.dart'; // We will build this next

class ManageApplicantsScreen extends StatefulWidget {
  final JobModel job;

  const ManageApplicantsScreen({super.key, required this.job});

  @override
  State<ManageApplicantsScreen> createState() => _ManageApplicantsScreenState();
}

class _ManageApplicantsScreenState extends State<ManageApplicantsScreen> {
  final _employerService = EmployerService();
  List<Map<String, dynamic>> _applicants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplicants();
  }

  Future<void> _loadApplicants() async {
    setState(() => _isLoading = true);
    final applicants = await _employerService.getJobApplicants(widget.job.jobID!);
    if (mounted) {
      setState(() {
        _applicants = applicants;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Applicants')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _applicants.isEmpty
          ? const Center(child: Text('No applicants for this job yet.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _applicants.length,
        itemBuilder: (context, index) {
          final data = _applicants[index];
          final seeker = data['JobSeeker'] ?? {};
          final name = seeker['fullName'] ?? 'Unknown Applicant';
          final status = data['applicationStatus'] ?? 'pending';

          // Formatting the date
          final appliedAt = data['appliedAt'] != null
              ? DateTime.parse(data['appliedAt']).toLocal().toString().split(' ')[0]
              : 'Unknown Date';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: const Icon(Icons.person, color: Colors.blue),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Applied: $appliedAt'),
              trailing: _buildStatusBadge(status),
              onTap: () async {
                // 👉 Open detailed view and refresh list when returning
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ApplicantDetailScreen(
                      applicantData: data,
                      jobTitle: widget.job.title,
                    ),
                  ),
                );
                _loadApplicants();
              },
            ),
          );
        },
      ),
    );
  }

  // A helper method to color-code statuses
  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'reviewed': color = Colors.orange; break;
      case 'interviewing': color = Colors.purple; break;
      case 'accepted': color = Colors.green; break;
      case 'rejected': color = Colors.red; break;
      default: color = Colors.grey; // Pending
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}