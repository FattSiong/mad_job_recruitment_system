import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared_widgets/surface_card.dart';
import '../../../../models/profile_check.dart';

/// "Profile 70% complete" with a bar and a chip for each missing item.
/// Tapping a chip calls [onFix] so the screen can open the right place.
class ProfileCompletenessCard extends StatelessWidget {
  final int percent;
  final List<ProfileCheck> missing;
  final ValueChanged<ProfileCheck> onFix;

  const ProfileCompletenessCard({
    super.key,
    required this.percent,
    required this.missing,
    required this.onFix,
  });

  Color get _color {
    if (percent >= 100) return AppColors.successGreen;
    if (percent >= 60) return AppColors.primary;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    final complete = missing.isEmpty;
    return SurfaceCard(
      children: [
        Row(
          children: [
            Icon(
              complete ? Icons.verified_rounded : Icons.track_changes_rounded,
              color: _color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                complete ? 'Your profile is complete' : 'Profile $percent% complete',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(fontWeight: FontWeight.w800, color: _color),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 8,
            backgroundColor: AppColors.progressTrack,
            valueColor: AlwaysStoppedAnimation(_color),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          complete
              ? 'Employers and the AI career tools can see everything they need.'
              : 'A complete profile helps employers find you and gives the AI career tools more to work with. Tap to add:',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
        ),
        if (!complete) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in missing)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                  label: Text(item.label),
                  onPressed: () => onFix(item),
                  backgroundColor: AppColors.surfaceAlt,
                  side: const BorderSide(color: AppColors.borderSoft),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  labelStyle: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
