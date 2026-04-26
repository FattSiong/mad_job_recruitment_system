import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/job_model.dart';

// --- SHARED ADMIN STYLING ---
const Color _backgroundColor = Color(0xFFF4F7FB);
const Color _surfaceColor = Colors.white;
const Color _heroStart = Color(0xFF12343B); // Forest Green
const Color _heroEnd = Color(0xFF2A6B66);   // Teal Green
const Color _textPrimary = Color(0xFF1B2433);
const Color _textSecondary = Color(0xFF687588);
const Color _selectedBg = Color(0xFFD9ECE8); // Teal highlight for pills

class AdminJobModerationScreen extends StatefulWidget {
  const AdminJobModerationScreen({super.key});

  @override
  State<AdminJobModerationScreen> createState() => _AdminJobModerationScreenState();
}

class _AdminJobModerationScreenState extends State<AdminJobModerationScreen> {
  final supabase = Supabase.instance.client;

  // Filter States
  bool _showOnlyFlagged = false;
  bool _isAlphabetical = false;

  void _showDeleteConfirmDialog(String jobID, String jobTitle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text("Remove Job Listing?", style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary)),
          content: Text("Are you sure you want to remove '$jobTitle'? This will hide the listing from the platform but keep the logs."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: _textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                await supabase.from('Job').update({'status': 'deleted'}).match({'jobID': jobID});
                await supabase.from('ReportedJob').update({'status': 'deleted'}).match({'jobID': jobID});
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE15A4F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("Confirm Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase.from('Job').stream(primaryKey: ['jobID']),
        builder: (context, jobSnapshot) {
          if (!jobSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: _heroStart));

          // Base data: non-deleted jobs
          List<Map<String, dynamic>> allJobData = jobSnapshot.data!
              .where((data) => data['status']?.toString() != 'deleted')
              .toList();

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase.from('ReportedJob').stream(primaryKey: ['reportID']),
            builder: (context, reportSnapshot) {
              final reportedJobIDs = reportSnapshot.hasData
                  ? reportSnapshot.data!
                  .where((r) => r['status'] != 'deleted')
                  .map((r) => r['jobID'].toString())
                  .toSet()
                  : <String>{};

              // --- APPLY FILTERS & SORTING ---
              List<Map<String, dynamic>> displayedJobs = List.from(allJobData);

              if (_showOnlyFlagged) {
                displayedJobs = displayedJobs.where((job) => reportedJobIDs.contains(job['jobID'].toString())).toList();
              }

              if (_isAlphabetical) {
                displayedJobs.sort((a, b) => (a['title'] ?? '').toString().toLowerCase().compareTo((b['title'] ?? '').toString().toLowerCase()));
              }

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // --- HERO SECTION ---
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_heroStart, _heroEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_outlined, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text('Security & Moderation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text('Manage Job Listings', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, height: 1.1)),
                          const SizedBox(height: 10),
                          Text(
                            'Reviewing ${allJobData.length} live listings and ${reportedJobIDs.length} flagged items.',
                            style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- FILTER PILL BAR ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          _buildFilterPill(
                            label: "Flagged Only",
                            isActive: _showOnlyFlagged,
                            onTap: () => setState(() => _showOnlyFlagged = !_showOnlyFlagged),
                            icon: Icons.flag_rounded,
                          ),
                          const SizedBox(width: 12),
                          _buildFilterPill(
                            label: "A-Z Order",
                            isActive: _isAlphabetical,
                            onTap: () => setState(() => _isAlphabetical = !_isAlphabetical),
                            icon: Icons.sort_by_alpha_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- LIST HEADER ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _showOnlyFlagged ? 'Reported Listings' : 'Active Listings',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Showing ${displayedJobs.length} items based on current filters.',
                            style: const TextStyle(fontSize: 14, color: _textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- JOB LIST ---
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: displayedJobs.isEmpty
                        ? const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.only(top: 50), child: Text("No jobs match these filters."))))
                        : SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final data = displayedJobs[index];
                          final String currentID = data['jobID']?.toString() ?? "";
                          final bool isFlagged = reportedJobIDs.contains(currentID);
                          final job = JobModel.fromJson(data);
                          return _buildModerationCard(job, isFlagged);
                        },
                        childCount: displayedJobs.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterPill({required String label, required bool isActive, required VoidCallback onTap, required IconData icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? _selectedBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isActive ? _heroStart.withOpacity(0.3) : Colors.grey.shade300),
          boxShadow: isActive ? null : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isActive ? _heroStart : _textSecondary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isActive ? _heroStart : _textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildModerationCard(JobModel job, bool isFlagged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: isFlagged ? Border.all(color: const Color(0xFFE15A4F).withOpacity(0.3), width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isFlagged ? const Color(0xFFE15A4F).withOpacity(0.12) : _heroEnd.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isFlagged ? Icons.report_problem_rounded : Icons.work_outline_rounded,
                    color: isFlagged ? const Color(0xFFE15A4F) : _heroEnd,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _textPrimary)),
                      const SizedBox(height: 2),
                      Text("ID: ${job.jobID?.substring(0, 12)}...", style: const TextStyle(fontSize: 13, color: _textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showDeleteConfirmDialog(job.jobID!, job.title),
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE15A4F)),
                  tooltip: 'Delete',
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _buildStatusChip(label: job.status.toUpperCase(), color: const Color(0xFF1D6F6A)),
                const SizedBox(width: 8),
                _buildStatusChip(label: job.salaryRange, color: const Color(0xFF355C9B)),
                if (isFlagged) ...[
                  const SizedBox(width: 8),
                  _buildStatusChip(label: "FLAGGED", color: const Color(0xFFE15A4F)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}