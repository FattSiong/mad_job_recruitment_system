import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/nearby_job_model.dart';
import '../../../../shared_widgets/button_spinner.dart';

/// A job in the drag-up list of the Nearby Jobs map. Fits in [height].
class NearbyJobCard extends StatelessWidget {
  /// Height of one card including the gap under it (the list's item size).
  static const double height = 104;

  final NearbyJob item;

  /// How many jobs share this job's spot (shows "3 here" when more than one).
  final int jobsHere;

  /// The job is being opened (shows a spinner instead of the arrow).
  final bool loading;
  final VoidCallback onTap;

  const NearbyJobCard({
    super.key,
    required this.item,
    required this.onTap,
    this.jobsHere = 1,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final job = item.job;
    final company = (job.companyName ?? '').trim();
    final radius = BorderRadius.circular(20);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: radius,
          border: Border.all(color: AppColors.border),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          job.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          company.isEmpty ? 'Company' : company,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _pill(Icons.near_me_rounded, item.distanceLabel, AppColors.primary),
                            if (jobsHere > 1) ...[
                              const SizedBox(width: 6),
                              _pill(Icons.layers_outlined, '$jobsHere here', AppColors.coral),
                            ],
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                job.salaryRange,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.all(4),
                      child: ButtonSpinner(color: AppColors.primary),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Small coloured pill with an icon (distance, jobs at the same spot).
  Widget _pill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
