import 'package:flutter/material.dart';
import '../../../models/job_model.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/report_controller.dart';

class ReportJobScreen extends StatefulWidget {
  final JobModel job;

  const ReportJobScreen({super.key, required this.job});

  @override
  State<ReportJobScreen> createState() => _ReportJobScreenState();
}

class _ReportJobScreenState extends State<ReportJobScreen> {
  final ReportController _reportController = ReportController();
  final TextEditingController _detailsController = TextEditingController();

  String? _selectedCategory;
  bool _isSubmitting = false;

  final List<String> _reportOptions = [
    "It's offensive and/or discriminatory",
    "Asking for money or seems like a fake job",
    "Incorrect company, location, or job details",
    "I think it's trying to sell something unrelated to the job",
    "Other"
  ];

  Future<void> _submitReport() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason for reporting.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await _reportController.submitJobReport(
      jobId: widget.job.jobID!,
      category: _selectedCategory!,
      details: _detailsController.text,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back to job details
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit report. Please try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Report Job'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reporting: ${widget.job.title}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a problem:',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),

                  // Radio Button Options
                  RadioGroup<String>(
                    groupValue: _selectedCategory, // Fixed parameter name
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                    child: Column(
                      children: _reportOptions.map((option) {
                        return RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(option, style: const TextStyle(fontSize: 15)),
                          value: option,
                          activeColor: AppColors.primaryBlue,
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Details Text Field
                  const Text(
                    'Describe your problem below:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _detailsController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Provide any additional details...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Submit Button at bottom
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}