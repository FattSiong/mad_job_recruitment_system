import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- SHARED ADMIN STYLING ---
const Color _backgroundColor = Color(0xFFF4F7FB);
const Color _surfaceColor = Colors.white;
const Color _heroStart = Color(0xFF12343B); // Forest Green
const Color _heroEnd = Color(0xFF2A6B66);   // Teal Green
const Color _textPrimary = Color(0xFF1B2433);
const Color _textSecondary = Color(0xFF687588);
const Color _selectedBg = Color(0xFFD9ECE8); // Teal highlight

class AdminSubscriptionListScreen extends StatefulWidget {
  const AdminSubscriptionListScreen({super.key});

  @override
  State<AdminSubscriptionListScreen> createState() => _AdminSubscriptionListScreenState();
}

class _AdminSubscriptionListScreenState extends State<AdminSubscriptionListScreen> {
  final supabase = Supabase.instance.client;
  String _selectedStatus = 'All'; // 'All', 'active', 'expired'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // Use 'paymentID' as primary key based on your table schema
        stream: supabase
            .from('PaymentSubscription')
            .stream(primaryKey: ['paymentID'])
            .order('paymentDate', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: _heroStart));

          final allSubscriptions = snapshot.data!;

          // Apply Filtering
          final filteredList = _selectedStatus == 'All'
              ? allSubscriptions
              : allSubscriptions.where((s) => s['status']?.toString().toLowerCase() == _selectedStatus.toLowerCase()).toList();

          return CustomScrollView(
            slivers: [
              // --- HERO HEADER ---
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_heroStart, _heroEnd]),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderChip(Icons.payments_outlined, "Billing Management"),
                      const SizedBox(height: 24),
                      const Text(
                        "Revenue & Plans",
                        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Tracking ${allSubscriptions.length} total payments across all company tiers.",
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              // --- PILL FILTERS ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildFilterPill("All"),
                      const SizedBox(width: 10),
                      _buildFilterPill("Active"),
                      const SizedBox(width: 10),
                      _buildFilterPill("Expired"),
                    ],
                  ),
                ),
              ),

              // --- LIST CONTENT ---
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: filteredList.isEmpty
                    ? const SliverToBoxAdapter(child: Center(child: Text("No records found", style: TextStyle(color: _textSecondary))))
                    : SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildSubscriptionCard(filteredList[index]),
                    childCount: filteredList.length,
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

  Widget _buildFilterPill(String label) {
    bool isSelected = _selectedStatus == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _selectedBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _heroEnd.withOpacity(0.2) : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _heroStart : _textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> sub) {
    final String planType = sub['planType']?.toString().toUpperCase() ?? "BASIC";
    final bool isActive = sub['status']?.toString().toLowerCase() == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF1D6F6A).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive ? Icons.star_rounded : Icons.person_outline_rounded,
                  color: isActive ? const Color(0xFF1D6F6A) : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Company ID",
                      style: TextStyle(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      sub['companyID']?.toString() ?? "N/A",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(sub['status']?.toString() ?? "Unknown"),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoCol("PLAN", planType),
              _buildInfoCol("AMOUNT", "RM ${sub['amountPaid'] ?? '0'}"),
              _buildInfoCol("EXPIRY", sub['endDate']?.toString().split('T')[0] ?? 'N/A'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary)),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    bool isActive = status.toLowerCase() == 'active';
    Color color = isActive ? const Color(0xFF1D6F6A) : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}