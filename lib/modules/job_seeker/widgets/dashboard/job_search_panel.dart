import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../job_filters.dart';
import '../../../../core/theme/app_button_styles.dart';
import '../../../../core/theme/app_input_decoration.dart';

/// "Search smarter" card on the dashboard: keyword, location, buttons and filter chips.
/// All state lives in the dashboard; this widget only shows it and reports taps.
class JobSearchPanel extends StatelessWidget {
  final TextEditingController keywordController;
  final TextEditingController locationController;
  final String selectedDatePosted;
  final String selectedJobType;
  final String selectedSalary;
  final VoidCallback onSearch;
  final VoidCallback onReset;
  final VoidCallback onOpenLocation;
  final VoidCallback onClearLocation;
  final ValueChanged<String> onFilterTap;

  const JobSearchPanel({
    super.key,
    required this.keywordController,
    required this.locationController,
    required this.selectedDatePosted,
    required this.selectedJobType,
    required this.selectedSalary,
    required this.onSearch,
    required this.onReset,
    required this.onOpenLocation,
    required this.onClearLocation,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search smarter',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Refine by role, location, job type, posted date, and salary.',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: keywordController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: filledInputDecoration(
              hint: 'Job title, keywords, or company',
              icon: Icons.search,
              radius: 18,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: locationController,
            readOnly: true,
            onTap: onOpenLocation,
            decoration: filledInputDecoration(
              hint: 'City, state, or postcode',
              icon: Icons.location_on_outlined,
              suffixIcon: locationController.text.isNotEmpty
                  ? IconButton(
                      onPressed: onClearLocation,
                      icon: const Icon(Icons.close, size: 18),
                    )
                  : IconButton(
                      onPressed: onOpenLocation,
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
              radius: 18,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Search Jobs'),
                  style: AppButtonStyles.filled(),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset'),
                style: AppButtonStyles.outlined(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                JobFilterChip(
                  label: JobFilterOptions.datePosted,
                  value: selectedDatePosted,
                  defaultValue: JobFilterOptions.anyDate,
                  onTap: () => onFilterTap(JobFilterOptions.datePosted),
                ),
                JobFilterChip(
                  label: JobFilterOptions.jobType,
                  value: selectedJobType,
                  defaultValue: JobFilterOptions.anyJobType,
                  onTap: () => onFilterTap(JobFilterOptions.jobType),
                ),
                JobFilterChip(
                  label: JobFilterOptions.salary,
                  value: selectedSalary,
                  defaultValue: JobFilterOptions.anySalary,
                  onTap: () => onFilterTap(JobFilterOptions.salary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
