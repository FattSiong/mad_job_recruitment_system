import 'package:flutter/material.dart';
import '../../../models/job_model.dart';
import '../../../services/employer_service.dart';

class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({super.key});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  // 1. Controllers to grab text from the input fields
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _salaryController = TextEditingController();

  // 2. State variables
  final _employerService = EmployerService();
  bool _isLoading = false;

  // 3. The function that runs when you hit Submit
  Future<void> _submitJob() async {
    // Basic validation: Don't submit if fields are empty
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in title and description')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Package the UI text into our Blueprint (JobModel)
    // NOTE: We are using dummy IDs here because we haven't built the Login/Auth system yet!
    final newJob = JobModel(
      companyID: '685e6b04-14fd-4a6a-88cd-0b12614f7206',
      employerID: '469885d6-45ac-4e96-b11f-a95fb0bafd78',
      title: _titleController.text,
      description: _descriptionController.text,
      salaryRange: _salaryController.text,
      status: 'active',
    );

    // Send it to the Kitchen (EmployerService)
    final result = await _employerService.createJobPosting(newJob);

    setState(() => _isLoading = false);

    // Check if it worked
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job Posted Successfully!')),
      );
      Navigator.pop(context); // Go back to the dashboard
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post job. Check terminal.')),
      );
    }
  }

  @override
  void dispose() {
    // Always clean up controllers to prevent memory leaks on your device
    _titleController.dispose();
    _descriptionController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Job')),
      // ListView prevents pixel overflow errors when the keyboard pops up
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Job Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Job Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _salaryController,
            decoration: const InputDecoration(
              labelText: 'Salary Range (e.g., RM 3000 - RM 4500)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 32),

          // Show a loading spinner if sending data, otherwise show the button
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
            onPressed: _submitJob,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Publish Job', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}