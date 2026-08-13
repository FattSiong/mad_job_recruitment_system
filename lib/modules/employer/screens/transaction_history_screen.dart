import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final _supabase = Supabase.instance.client;
  late final Future<List<Map<String, dynamic>>> _transactionsFuture;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _transactionsFuture = _loadTransactions();
  }

  Future<List<Map<String, dynamic>>> _loadTransactions() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from(TableConstants.paymentSubscription)
        .select(
          'paymentID, companyID, planType, amountPaid, paymentDate, status, startDate, endDate',
        )
        .eq('paidByEmployerID', user.id)
        .order('paymentDate', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _transactionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildPage(
                child: _buildMessageCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Could not load transactions',
                  message: 'Please check your connection and try again later.',
                ),
              );
            }

            final transactions = snapshot.data ?? [];
            final filteredTransactions = _selectedFilter == 'All'
                ? transactions
                : transactions.where((transaction) {
                    return (transaction['status'] ?? '').toString().toLowerCase() ==
                        _selectedFilter.toLowerCase();
                  }).toList();

            return _buildPage(
              child: Column(
                children: [
                  _buildHero(transactions),
                  const SizedBox(height: 20),
                  _buildFilterRow(transactions),
                  const SizedBox(height: 18),
                  if (filteredTransactions.isEmpty)
                    _buildMessageCard(
                      icon: Icons.receipt_long_outlined,
                      title: transactions.isEmpty
                          ? 'No transactions yet'
                          : 'No ${_selectedFilter.toLowerCase()} transactions',
                      message: transactions.isEmpty
                          ? 'Your Premium plan purchases will appear here after payment is completed.'
                          : 'Try choosing another transaction status to see more records.',
                    )
                  else
                    _buildTransactionList(filteredTransactions),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPage({required Widget child}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _buildTopBar(),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.arrow_back_rounded, color: Color(0xFF163B65)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Transaction History',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero(List<Map<String, dynamic>> transactions) {
    final totalPaid = transactions.fold<double>(0, (total, transaction) {
      return total + _toDouble(transaction['amountPaid']);
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF163B65), Color(0xFF335D8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroPill(),
          const SizedBox(height: 20),
          const Text(
            'Your payments',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Review Premium subscription purchases and their plan periods.',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroMetric(Icons.receipt_long_rounded, '${transactions.length} payments'),
              _buildHeroMetric(Icons.payments_rounded, 'RM ${totalPaid.toStringAsFixed(2)} paid'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_outlined, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Billing records', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildHeroMetric(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFilterRow(List<Map<String, dynamic>> transactions) {
    final statuses = transactions
        .map((transaction) => (transaction['status'] ?? '').toString().trim())
        .where((status) => status.isNotEmpty)
        .map((status) => status[0].toUpperCase() + status.substring(1).toLowerCase())
        .toSet()
        .toList();
    final filters = ['All', ...statuses];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = filter == _selectedFilter;
          return Material(
            color: isSelected ? const Color(0xFFDCEBFB) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => setState(() => _selectedFilter = filter),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF163B65) : const Color(0xFF687588),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionList(List<Map<String, dynamic>> transactions) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1B2433)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your latest subscription transactions are shown first.',
            style: TextStyle(fontSize: 13, color: Color(0xFF687588)),
          ),
          const SizedBox(height: 18),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildTransactionCard(transactions[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final plan = _planLabel(transaction['planType']);
    final status = (transaction['status'] ?? 'unknown').toString();
    final statusColor = _statusColor(status);
    final paymentDate = _parseDate(transaction['paymentDate']);
    final startDate = _parseDate(transaction['startDate']);
    final endDate = _parseDate(transaction['endDate']);
    final companyId = (transaction['companyID'] ?? 'Not available').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: const Color(0xFFDCEBFB), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF163B65)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1B2433))),
                    const SizedBox(height: 3),
                    Text('Paid ${_formatDate(paymentDate)}', style: const TextStyle(fontSize: 12, color: Color(0xFF687588))),
                  ],
                ),
              ),
              _buildStatusBadge(status, statusColor),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildTransactionDetail('Amount', 'RM ${_toDouble(transaction['amountPaid']).toStringAsFixed(2)}')),
              Expanded(child: _buildTransactionDetail('Plan period', '${_formatDate(startDate)} – ${_formatDate(endDate)}')),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Company ID: $companyId',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF687588)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF687588))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B2433))),
      ],
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildMessageCard({required IconData icon, required String title, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: const Color(0xFFDCEBFB), borderRadius: BorderRadius.circular(22)),
            child: Icon(icon, size: 36, color: const Color(0xFF163B65)),
          ),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFF1B2433))),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF687588))),
        ],
      ),
    );
  }

  double _toDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  DateTime? _parseDate(dynamic value) => value == null ? null : DateTime.tryParse(value.toString());

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not available';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _planLabel(dynamic plan) {
    switch (plan.toString().toLowerCase()) {
      case 'monthly':
        return 'Premium Monthly';
      case 'annually':
      case 'annual':
        return 'Premium Annually';
      default:
        return 'Premium Subscription';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'paid':
      case 'completed':
        return const Color(0xFF2D8A5D);
      case 'pending':
        return const Color(0xFFC28A22);
      case 'expired':
      case 'failed':
      case 'cancelled':
        return const Color(0xFFC24E4E);
      default:
        return const Color(0xFF687588);
    }
  }
}
