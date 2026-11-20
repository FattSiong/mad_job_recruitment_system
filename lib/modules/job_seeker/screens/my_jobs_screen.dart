import 'package:flutter/material.dart';

import '../widgets/my_jobs/applied_jobs_tab.dart';
import '../widgets/my_jobs/bookmarked_jobs_tab.dart';
import '../widgets/my_jobs/interviews_tab.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared_widgets/hero_card.dart';

/// My Jobs: Bookmarked / Applied / Interviews tabs.
/// Each tab lives in widgets/my_jobs/.
class MyJobsScreen extends StatelessWidget {
  final int initialTabIndex;

  const MyJobsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex.clamp(0, 2),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      children: [
                        HeroCard(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (canPop) ...[
                                    Material(
                                      color: Colors.white.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => Navigator.of(context).pop(),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.arrow_back_rounded,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  const HeroPill(icon: Icons.work_outline_rounded, label: 'My Jobs Workspace'),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Track every opportunity',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Review bookmarked roles, follow your applications, and keep interview updates in one place.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const TabBar(
                            dividerColor: Colors.transparent,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicatorPadding: EdgeInsets.symmetric(horizontal: 4),
                            indicator: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.all(Radius.circular(16)),
                            ),
                            labelColor: AppColors.primary,
                            unselectedLabelColor: AppColors.textMuted,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            tabs: [
                              Tab(text: 'Bookmarked'),
                              Tab(text: 'Applied'),
                              Tab(text: 'Interviews'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: const TabBarView(
              children: [
                BookmarkedJobsTab(),
                AppliedJobsTab(),
                InterviewsTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
