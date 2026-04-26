import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/job_model.dart';

class AdminJobModerationScreen extends StatefulWidget {
  const AdminJobModerationScreen({super.key});

  @override
  State<AdminJobModerationScreen> createState() => _AdminJobModerationScreenState();
}

class _AdminJobModerationScreenState extends State<AdminJobModerationScreen> {
  final supabase = Supabase.instance.client;

  // 👉 软删除确认弹窗 (Soft Delete)
  void _showDeleteConfirmDialog(String jobID, String jobTitle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Delete Job Post?", style: TextStyle(fontWeight: FontWeight.bold)),
          // 💡 提示语稍微改一下，显得更专业
          content: Text("Are you sure you want to remove '$jobTitle'? This will mark the job as deleted but keep the records."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // 🔴 核心修改：不再使用 .delete()，而是更新 status 字段
                  await supabase
                      .from('Job')
                      .update({'status': 'deleted'})
                      .match({'jobID': jobID});

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Job status updated to 'deleted' (Soft Delete)")),
                    );
                  }
                } catch (e) {
                  debugPrint("Soft delete error: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      // ⚠️ 监听 Job 表
      stream: supabase.from('Job').stream(primaryKey: ['jobID']),
      builder: (context, jobSnapshot) {
        if (jobSnapshot.hasError) return Center(child: Text("Error: ${jobSnapshot.error}"));
        if (!jobSnapshot.hasData) return const Center(child: CircularProgressIndicator());

        // 🛡️ 核心过滤：只显示 status 不是 'deleted' 的职位
        final allJobData = jobSnapshot.data!
            .where((data) => data['status']?.toString() != 'deleted')
            .toList();

        return StreamBuilder<List<Map<String, dynamic>>>(
          // ⚠️ 监听 ReportedJob 表
          stream: supabase.from('ReportedJob').stream(primaryKey: ['reportID']),
          builder: (context, reportSnapshot) {
            final reportedJobIDs = reportSnapshot.hasData
                ? reportSnapshot.data!.map((r) => r['jobID'].toString()).toSet()
                : <String>{};

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Job Listing Moderation", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: allJobData.isEmpty
                      ? const Center(child: Text("No active jobs found"))
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: allJobData.length,
                    itemBuilder: (context, index) {
                      final data = allJobData[index];
                      final String currentID = data['jobID']?.toString() ?? "";
                      final bool isFlagged = reportedJobIDs.contains(currentID);

                      final Map<String, dynamic> safeJobData = {
                        'jobID': currentID,
                        'companyID': data['companyID']?.toString() ?? "",
                        'employerID': data['employerID']?.toString() ?? "",
                        'title': data['title']?.toString() ?? "Untitled Job",
                        'description': data['description']?.toString() ?? "",
                        'salaryRange': data['salaryRange']?.toString() ?? "N/A",
                        'status': data['status']?.toString() ?? "active",
                      };

                      try {
                        final job = JobModel.fromJson(safeJobData);
                        return _buildJobCard(job, isFlagged);
                      } catch (e) {
                        return ListTile(title: Text("Error loading job: $e"));
                      }
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildJobCard(JobModel job, bool isFlagged) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isFlagged ? Colors.orange.shade300 : Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Row(
          children: [
            if (isFlagged)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.report_problem, color: Colors.orange, size: 20),
              ),
            Expanded(
              child: Text(job.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            // 显示当前状态标签 (如果是 archived 也能看到)
            if (job.status == 'archived')
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                child: const Text("Archived", style: TextStyle(color: Colors.grey, fontSize: 10)),
              ),
            if (isFlagged)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                child: const Text("Flagged", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(job.salaryRange),
            if (isFlagged)
              const Text("This post has been reported by users.", style: TextStyle(color: Colors.red, fontSize: 11)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _showDeleteConfirmDialog(job.jobID ?? "", job.title ?? "Job"),
        ),
      ),
    );
  }
}