import 'package:flutter/material.dart';
import 'package:mad_job_recruitment_system/modules/job_seeker/screens/report_job_screen.dart';
import '../../../models/job_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/location_helper.dart';
import 'job_application_screen.dart';

class JobDetailsScreen extends StatefulWidget {
  final JobModel job;

  const JobDetailsScreen({super.key, required this.job});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  bool _isDescriptionExpanded = false;
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final isBottom = _scrollController.position.pixels >=
          (_scrollController.position.maxScrollExtent - 20);

      if (isBottom != _isAtBottom) {
        setState(() {
          _isAtBottom = isBottom;
        });
      }
    }
  }

  String _formatSalaryOnly() {
    String salary = widget.job.salaryRange;
    if (salary.isEmpty) return 'Salary not specified';

    String period = widget.job.jobType.toLowerCase().contains('part') ? 'an hour' : 'a month';
    return '$salary $period';
  }

  void _handleReportJob() {
    // Navigate to the new report screen instead of showing the modal
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportJobScreen(job: widget.job),
      ),
    );
  }

  // Helper widget to build rows with icons
  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.grey.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showReportButton = !_isDescriptionExpanded || _isAtBottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border, color: Colors.black87),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved to your jobs!')),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Job Title and Company Name
                Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.job.title,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.job.companyName ?? 'Unknown Company',
                        style: const TextStyle(fontSize: 16, color: Color(0xFF0A66C2), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                // First Divider
                const Divider(thickness: 1, height: 1),

                // 2. Salary, Job Type, and Location (with icons)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.attach_money, _formatSalaryOnly()),
                      const SizedBox(height: 14),
                      _buildInfoRow(Icons.work_outline, widget.job.jobType),
                      const SizedBox(height: 14),
                      FutureBuilder<String>(
                        future: LocationHelper.getCityFromCoordinates(widget.job.latitude, widget.job.longitude),
                        builder: (context, snapshot) {
                          return _buildInfoRow(Icons.location_on_outlined, snapshot.data ?? 'Loading location...');
                        },
                      ),
                    ],
                  ),
                ),

                // Second Divider
                const Divider(thickness: 1, height: 1),

                // 3. Full Job Description
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Full Job Description',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final textSpan = TextSpan(
                            text: widget.job.description,
                            style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                          );
                          final textPainter = TextPainter(
                            text: textSpan,
                            maxLines: _isDescriptionExpanded ? null : 8,
                            textDirection: TextDirection.ltr,
                          );
                          textPainter.layout(maxWidth: constraints.maxWidth);

                          final bool needsExpansion = textPainter.didExceedMaxLines;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.job.description,
                                style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                                maxLines: _isDescriptionExpanded ? null : 8,
                                overflow: _isDescriptionExpanded ? null : TextOverflow.fade,
                              ),
                              if (needsExpansion || _isDescriptionExpanded)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isDescriptionExpanded = !_isDescriptionExpanded;
                                        if (_isDescriptionExpanded) {
                                          _isAtBottom = false;
                                        }
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(50, 30),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      _isDescriptionExpanded ? 'Show less' : 'Show more',
                                      style: const TextStyle(color: Color(0xFF0A66C2), fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Fixed Bottom Action Bar (Apply & Report Buttons)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      offset: const Offset(0, -4),
                      blurRadius: 10
                  )
                ],
              ),
              child: SafeArea(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Apply Now Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => JobApplicationScreen(job: widget.job)));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A66C2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Apply Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),

                      // 👉 UPDATED: Report Job Button with background, icon, and black text
                      if (showReportButton)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: TextButton.icon(
                              onPressed: _handleReportJob,
                              icon: const Icon(Icons.flag_outlined, color: Colors.black87, size: 20),
                              label: const Text(
                                'Report Job',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87, // Black words
                                ),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.grey.shade200, // Light grey background
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}