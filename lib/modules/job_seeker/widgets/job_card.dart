import 'package:flutter/material.dart';
import '../../../models/job_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/location_helper.dart';

class JobCard extends StatelessWidget {
  final JobModel job;
  final VoidCallback onTap;

  const JobCard({super.key, required this.job, required this.onTap});

  String _formatSalary(String range, String? type) {
    if (type == 'Part-time') {
      return '$range / hr';
    } else {
      return '$range / mo';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Title
              Text(
                job.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Row 2 & 3: Company and Location
              Text(
                job.companyName ?? 'Unknown Company',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    // 👉 Use FutureBuilder to calculate the city name on the fly!
                    child: FutureBuilder<String>(
                      future: LocationHelper.getCityFromCoordinates(job.latitude, job.longitude),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'Loading location...', // Shows while calculating
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Chips: Job Type and Salary
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (job.jobType != null)
                    _buildChip(job.jobType!, Icons.work_outline),
                  _buildChip(_formatSalary(job.salaryRange, job.jobType), Icons.attach_money),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}