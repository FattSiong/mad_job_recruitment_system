import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared_widgets/state_message_card.dart';
import '../controllers/job_discovery_controller.dart';
import '../controllers/job_list_controller.dart';
import '../widgets/dashboard/job_search_sheet.dart';
import '../widgets/job_list_view.dart';
import '../../../shared_widgets/plain_app_bar.dart';

/// Jobs matching a search from Home. Tapping the search summary reopens
/// the search to change it.
class JobSearchResultsScreen extends StatefulWidget {
  final JobSearchFilters filters;

  const JobSearchResultsScreen({super.key, required this.filters});

  @override
  State<JobSearchResultsScreen> createState() => _JobSearchResultsScreenState();
}

class _JobSearchResultsScreenState extends State<JobSearchResultsScreen> {
  late final JobListController _jobs = JobListController(filters: widget.filters)..load();

  @override
  void dispose() {
    _jobs.dispose();
    super.dispose();
  }

  /// Opens the search with the current values; searches again with the changes.
  Future<void> _editSearch() async {
    final filters = await showJobSearchSheet(context, initial: _jobs.filters);
    if (filters != null) _jobs.search(filters);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PlainAppBar(title: 'Search Results'),
      body: SafeArea(
        top: false,
        child: JobListView(
          controller: _jobs,
          header: [_SearchSummary(controller: _jobs, onTap: _editSearch)],
          emptyState: StateMessageCard(
            icon: Icons.search_off_rounded,
            title: 'No matching jobs',
            message: 'Try a broader keyword, another location or fewer filters.',
            action: TextButton.icon(
              onPressed: _editSearch,
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Change search'),
            ),
          ),
        ),
      ),
    );
  }
}

/// What was searched (tap to change), the filters that are on, and how
/// many jobs were found.
class _SearchSummary extends StatelessWidget {
  final JobListController controller;
  final VoidCallback onTap;

  const _SearchSummary({required this.controller, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final f = controller.filters;
        final chips = [
          if (f.hasJobType) f.jobType!,
          if (f.hasSalary) '${f.salary!}+',
          if (f.hasWorkplaceType) f.workplaceType!,
          if (f.hasDatePosted) f.datePosted!,
        ];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: AppColors.textMuted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.query.isEmpty ? 'All jobs' : f.query,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                f.location.isEmpty ? 'Anywhere' : f.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final chip in chips) _FilterPill(label: chip)],
                ),
              ],
              if (controller.error == null) ...[
                const SizedBox(height: 14),
                Text(
                  controller.isLoading ? 'Searching...' : controller.countText,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A filter that is on, e.g. "Full-time".
class _FilterPill extends StatelessWidget {
  final String label;

  const _FilterPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
      ),
    );
  }
}
