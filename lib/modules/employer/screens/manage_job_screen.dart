import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/job_model.dart';
import '../../../services/employer_service.dart';
import 'create_job_screen.dart';
import 'job_detail_screen.dart';

class ManageJobsScreen extends StatefulWidget {
  const ManageJobsScreen({super.key});

  @override
  State<ManageJobsScreen> createState() => _ManageJobsScreenState();
}

class _ManageJobsScreenState extends State<ManageJobsScreen> {
  final _employerService = EmployerService();

  List<JobModel> _jobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      final fetchedJobs = await _employerService.getEmployerJobs(currentUser.id);

      if (mounted) {
        setState(() {
          _jobs = fetchedJobs;
          _isLoading = false;
        });
      }
    }
  }

  // Helper widget for a clean status badge
  Widget _buildStatusBadge(String? status) {
    final currentStatus = status?.toLowerCase() ?? 'active';
    final isClosed = currentStatus == 'inactive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isClosed ? Colors.grey.shade200 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        currentStatus.toUpperCase(),
        style: TextStyle(
          color: isClosed ? Colors.grey.shade700 : Colors.green.shade800,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Jobs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJobs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'You haven\'t posted any jobs yet.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _jobs.length,
        itemBuilder: (context, index) {
          final job = _jobs[index];

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                job.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Optional check if you have a salary range string
                  if (job.salaryRange.isNotEmpty)
                    Text('💰 ${job.salaryRange}'),
                  const SizedBox(height: 4),
                  Text(
                    job.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: _buildStatusBadge(job.status),
              onTap: () async {
                // Navigate to the Job Detail screen
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => JobDetailScreen(job: job),
                  ),
                );

                // Refresh the job list when returning, just in case they closed the job
                _loadJobs();
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to the create screen and wait for it to pop back
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateJobScreen()),
          );
          // Refresh the list automatically when returning
          _loadJobs();
        },
        icon: const Icon(Icons.add),
        label: const Text('Post New Job'),
      ),
    );
  }
}