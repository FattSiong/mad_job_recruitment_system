import 'package:flutter/material.dart';
import '../../../models/company_model.dart';
import '../../../models/job_model.dart';
import '../../../services/employer_service.dart';
import 'create_job_screen.dart';
import 'job_detail_screen.dart';

class CompanyJobsScreen extends StatefulWidget {
  final CompanyModel company;

  const CompanyJobsScreen({super.key, required this.company});

  @override
  State<CompanyJobsScreen> createState() => _CompanyJobsScreenState();
}

class _CompanyJobsScreenState extends State<CompanyJobsScreen> {
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
    // 👉 Fetch jobs strictly for this one company
    final jobs = await _employerService.getJobsByCompanyId(widget.company.companyID!);
    if (mounted) {
      setState(() {
        _jobs = jobs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.company.name} Jobs'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
          ? const Center(child: Text('No jobs posted for this company yet.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _jobs.length,
        itemBuilder: (context, index) {
          final job = _jobs[index];
          final isActive = job.status.toLowerCase() == 'active';

          return Card(
            child: ListTile(
              title: Text(job.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(job.jobType),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade100 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  job.status.toUpperCase(),
                  style: TextStyle(color: isActive ? Colors.green : Colors.grey, fontSize: 12),
                ),
              ),
              onTap: () async {
                // View Job Details
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => JobDetailScreen(job: job)),
                );
                _loadJobs(); // Refresh if they edited or closed it
              },
            ),
          );
        },
      ),
      // 👉 Floating Action Button to Add a Job specifically for this company
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              // We pass the company down so the Create form knows who we are building for!
              builder: (context) => CreateJobScreen(preselectedCompany: widget.company),
            ),
          );
          _loadJobs(); // Refresh the list after they create a job
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Job'),
      ),
    );
  }
}