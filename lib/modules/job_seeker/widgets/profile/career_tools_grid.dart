import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../screens/ai_career_advisor_screen.dart';
import '../../screens/guidance_reports_screen.dart';
import '../../screens/mock_interview_setup_screen.dart';
import '../../screens/skill_gap_analysis_screen.dart';

/// The four AI career tools as a 2 x 2 grid of tiles.
class CareerToolsGrid extends StatelessWidget {
  const CareerToolsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ToolTile(
                icon: Icons.smart_toy_outlined,
                label: 'AI Career Advisor',
                color: AppColors.primary,
                screen: AiCareerAdvisorScreen(),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _ToolTile(
                icon: Icons.record_voice_over_outlined,
                label: 'Mock Interview',
                color: AppColors.teal,
                screen: MockInterviewSetupScreen(),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ToolTile(
                icon: Icons.insights_outlined,
                label: 'Skill Gap Analysis',
                color: AppColors.coral,
                screen: SkillGapAnalysisScreen(),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _ToolTile(
                icon: Icons.assignment_outlined,
                label: 'Guidance Reports',
                color: AppColors.statusInterviewed,
                screen: GuidanceReportsScreen(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Widget screen;

  const _ToolTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.screen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
        child: Container(
          height: 104,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
