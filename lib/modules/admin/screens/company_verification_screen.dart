import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/company_model.dart';

class CompanyVerificationScreen extends StatefulWidget {
  const CompanyVerificationScreen({super.key});

  @override
  State<CompanyVerificationScreen> createState() => _CompanyVerificationScreenState();
}

class _CompanyVerificationScreenState extends State<CompanyVerificationScreen> {
  String _selectedStatus = 'pending';
  final supabase = Supabase.instance.client;

  // 👉 1. 处理 Verify (核准) 逻辑
  Future<void> _handleVerify(String companyID, String companyName) async {
    try {
      debugPrint("DEBUG: Attempting to verify $companyName ($companyID)");

      await supabase.from('Company').update({
        'verificationStatus': 'verified',
        'isVerified': true, // 同时更新布尔值标志
      }).match({'companyID': companyID});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$companyName has been verified!")),
        );
      }
    } catch (e) {
      debugPrint("VERIFY ERROR: $e");
    }
  }

  // 👉 2. 处理 Reject (拒绝) 逻辑
  void _showRejectDialog(String companyID, String companyName) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Reject Company", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Reason for rejecting $companyName:"),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Enter reason..."),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) return;
                await supabase.from('Company').update({
                  'verificationStatus': 'rejected',
                  'rejectionReason': reasonController.text.trim(),
                }).match({'companyID': companyID});
                if (mounted) Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Reject", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('Company').stream(primaryKey: ['companyID']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final all = snapshot.data!;
        final filtered = all.where((d) => d['verificationStatus'] == _selectedStatus).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _filterBtn("Pending", "pending", all),
                  const SizedBox(width: 8),
                  _filterBtn("Verified", "verified", all),
                  const SizedBox(width: 8),
                  _filterBtn("Rejected", "rejected", all),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text("No records found"))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final data = filtered[index];

                  // 🛡️ 严格防 Null 保护
                  final Map<String, dynamic> safeData = {
                    'companyID': data['companyID']?.toString() ?? "",
                    'name': data['name']?.toString() ?? "N/A",
                    'description': data['description']?.toString() ?? "",
                    'registrationNumber': data['registrationNumber']?.toString() ?? "N/A",
                    'verificationStatus': data['verificationStatus']?.toString() ?? "pending",
                    'isVerified': data['isVerified'] ?? false,
                  };

                  final company = CompanyModel.fromJson(safeData);
                  return _buildCard(company, data['rejectionReason']?.toString() ?? "");
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _filterBtn(String label, String status, List all) {
    bool isSel = _selectedStatus == status;
    int count = all.where((d) => d['verificationStatus'] == status).length;
    return InkWell(
      onTap: () => setState(() => _selectedStatus = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? Colors.blueAccent : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text("$label ($count)", style: TextStyle(color: isSel ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCard(CompanyModel company, String reason) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(company.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("Reg: ${company.registrationNumber}", style: const TextStyle(color: Colors.grey)),

            if (_selectedStatus == 'rejected') ...[
              const Divider(),
              Text("Reason: $reason", style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],

            if (_selectedStatus == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      // 👉 这里改成了调用函数
                      onPressed: () => _handleVerify(company.companyID!, company.name),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text("Verify", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showRejectDialog(company.companyID!, company.name),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Reject", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}