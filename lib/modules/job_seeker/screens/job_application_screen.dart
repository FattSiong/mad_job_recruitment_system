import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/job_model.dart';
import '../../../models/pre_screening_question_model.dart'; // 👉 1. Added import
import '../controllers/application_controller.dart';

class JobApplicationScreen extends StatefulWidget {
  final JobModel job;

  const JobApplicationScreen({super.key, required this.job});

  @override
  State<JobApplicationScreen> createState() => _JobApplicationScreenState();
}

class _JobApplicationScreenState extends State<JobApplicationScreen> {
  final ApplicationController _appController = ApplicationController();
  final PageController _pageController = PageController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentPage = 0;

  // 👉 2. Changed from List<Map> to List<PreScreeningQuestionModel>
  List<PreScreeningQuestionModel> _questions = [];
  String? _existingResumeUrl;

  final Map<String, dynamic> _answers = {};
  String _resumeSelection = 'existing';
  File? _newResumeFile;

  @override
  void initState() {
    super.initState();
    _loadApplicationData();
  }

  Future<void> _loadApplicationData() async {
    final questions = await _appController.getQuestions(widget.job.jobID!);
    final resumeUrl = await _appController.getSeekerResume();

    if (mounted) {
      setState(() {
        _questions = questions;
        _existingResumeUrl = resumeUrl;

        if (resumeUrl == null) {
          _resumeSelection = 'new';
        }

        _isLoading = false;
      });
    }
  }

  Future<void> _pickFile(Function(File) onFilePicked) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null && result.files.single.path != null) {
      onFilePicked(File(result.files.single.path!));
    }
  }

  Future<void> _submitApplication() async {
    setState(() => _isSubmitting = true);

    final success = await _appController.submitApplication(
      jobId: widget.job.jobID!,
      answers: _answers,
      existingResumeUrl: _resumeSelection == 'existing' ? _existingResumeUrl : null,
      newResumeFile: _newResumeFile,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application Submitted Successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit application.'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool hasQuestions = _questions.isNotEmpty;
    final int totalPages = hasQuestions ? 2 : 1;
    final double progress = (_currentPage + 1) / totalPages;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (_currentPage > 0) {
              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF0A66C2), fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.job.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text('${widget.job.companyName ?? 'Company'} - Kuala Lumpur', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.shade200,
                        color: const Color(0xFF0A66C2),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${(progress * 100).toInt()}%', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                if (hasQuestions) _buildQuestionsPage(),
                _buildResumePage(),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                  if (hasQuestions && _currentPage == 0) {
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
                  } else {
                    _submitApplication();
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF0A66C2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                  (hasQuestions && _currentPage == 0) ? 'Continue' : 'Submit Application',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Answer pre-screening questions', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('The employer requires answers to these questions.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),

          ..._questions.map((q) {
            // 👉 3. Use Model syntax (q.property) instead of Map syntax (q['property'])
            final questionId = q.questionID!;
            final isText = q.questionType == 'text';

            return Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q.questionText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),

                  if (isText)
                    TextField(
                      onChanged: (val) => _answers[questionId] = val,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        hintText: 'Enter your answer',
                      ),
                      maxLines: 3,
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => _pickFile((file) {
                        setState(() => _answers[questionId] = file);
                      }),
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        _answers[questionId] != null
                            ? (_answers[questionId] as File).path.split('/').last
                            : 'Upload File Answer',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResumePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add a resume for the employer', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          if (_existingResumeUrl != null)
            GestureDetector(
              onTap: () => setState(() => _resumeSelection = 'existing'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _resumeSelection == 'existing' ? const Color(0xFF0A66C2) : Colors.grey.shade300,
                    width: _resumeSelection == 'existing' ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.description, color: Colors.black87),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Use your existing Resume', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 4),
                          Text('Recommended', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    Icon(
                      _resumeSelection == 'existing' ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _resumeSelection == 'existing' ? const Color(0xFF0A66C2) : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),

          GestureDetector(
            onTap: () async {
              setState(() => _resumeSelection = 'new');
              await _pickFile((file) {
                setState(() => _newResumeFile = file);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _resumeSelection == 'new' ? const Color(0xFF0A66C2) : Colors.grey.shade300,
                  width: _resumeSelection == 'new' ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.upload_file, color: Colors.black87),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Upload a resume', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          _newResumeFile != null
                              ? 'Selected: ${_newResumeFile!.path.split('/').last}'
                              : 'Accepted file types are PDF, DOCX, RTF, or TXT.',
                          style: TextStyle(color: _newResumeFile != null ? Colors.green : Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _resumeSelection == 'new' ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: _resumeSelection == 'new' ? const Color(0xFF0A66C2) : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}