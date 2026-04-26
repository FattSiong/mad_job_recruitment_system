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

  static const Color _heroStart = Color(0xFF12343B);
  static const Color _heroEnd = Color(0xFF2A6B66);
  static const Color _selectedBg = Color(0xFFD9ECE8);
  static const Color _primaryGreen = Color(0xFF1D6F6A);

  Future<void> _handleVerify(String companyID, String companyName) async {
    try {
      await supabase.from('Company').update({
        'verificationStatus': 'verified',
        'isVerified': true,
      }).match({'companyID': companyID});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$companyName verified!")));
    } catch (e) { debugPrint("Error: $e"); }
  }

  void _showRejectDialog(String companyID, String companyName) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text("Reject Company", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(controller: reasonController, decoration: const InputDecoration(hintText: "Reason...")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await supabase.from('Company').update({
                'verificationStatus': 'rejected',
                'rejectionReason': reasonController.text.trim(),
              }).match({'companyID': companyID});
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Reject", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase.from('Company').stream(primaryKey: ['companyID']),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _heroStart));

          final all = snapshot.data!;
          final filtered = all.where((d) => d['verificationStatus'] == _selectedStatus).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [_heroStart, _heroEnd]), borderRadius: BorderRadius.circular(28)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildHeaderChip(Icons.business_center, "Business Verification"),
                    const SizedBox(height: 20),
                    const Text("Review business access", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                    const Text("Maintain platform trust by verifying registrations.", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    _buildPill("Pending", "pending", all),
                    const SizedBox(width: 10),
                    _buildPill("Verified", "verified", all),
                    const SizedBox(width: 10),
                    _buildPill("Rejected", "rejected", all),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: filtered.isEmpty
                    ? const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text("No records found", style: TextStyle(color: Colors.grey)))))
                    : SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) {
                      // 🛡️ CRITICAL FIX: Ensure no field is null before passing to model
                      final rawData = filtered[i];
                      final Map<String, dynamic> safeData = {
                        'companyID': rawData['companyID']?.toString() ?? "",
                        'name': rawData['name']?.toString() ?? "N/A",
                        'description': rawData['description']?.toString() ?? "",
                        'registrationNumber': rawData['registrationNumber']?.toString() ?? "N/A",
                        'verificationStatus': rawData['verificationStatus']?.toString() ?? "pending",
                        'isVerified': rawData['isVerified'] ?? false,
                      };

                      final company = CompanyModel.fromJson(safeData);
                      final reason = rawData['rejectionReason']?.toString() ?? "No reason provided.";

                      return _buildCompanyCard(company, reason);
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 16), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))]),
    );
  }

  Widget _buildPill(String label, String status, List all) {
    bool isSel = _selectedStatus == status;
    int count = all.where((d) => d['verificationStatus'] == status).length;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: isSel ? _selectedBg : Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Text("$label ($count)", style: TextStyle(color: isSel ? _heroStart : Colors.grey, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCompanyCard(CompanyModel company, String reason) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(company.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text("Reg: ${company.registrationNumber}", style: const TextStyle(color: Colors.grey)),
          if (_selectedStatus == 'pending') ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: ElevatedButton(onPressed: () => _handleVerify(company.companyID!, company.name), style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Verify", style: TextStyle(color: Colors.white)))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton(onPressed: () => _showRejectDialog(company.companyID!, company.name), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Reject", style: TextStyle(color: Colors.red)))),
            ]),
          ] else if (_selectedStatus == 'rejected') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
              child: Text("Reason: $reason", style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ]
        ],
      ),
    );
  }
}