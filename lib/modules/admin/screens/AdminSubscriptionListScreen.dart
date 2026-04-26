import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminSubscriptionListScreen extends StatefulWidget {
  const AdminSubscriptionListScreen({super.key});

  @override
  State<AdminSubscriptionListScreen> createState() => _AdminSubscriptionListScreenState();
}

class _AdminSubscriptionListScreenState extends State<AdminSubscriptionListScreen> {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Premium Subscriptions", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // 👉 关键：这里监听 PaymentSubscription 表
        stream: supabase
            .from('PaymentSubscription')
            .stream(primaryKey: ['paymentID'])
            .order('paymentDate', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final subscriptions = snapshot.data!;

          if (subscriptions.isEmpty) {
            return const Center(child: Text("No subscriptions found"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: subscriptions.length,
            itemBuilder: (context, index) {
              final sub = subscriptions[index];
              final String planType = sub['planType']?.toString() ?? "basic";
              final bool isPremium = planType.toLowerCase() == 'premium';

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isPremium ? Colors.purple.shade300 : Colors.grey.shade200,
                    width: isPremium ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: isPremium ? Colors.purple.shade50 : Colors.grey.shade50,
                    child: Icon(
                      isPremium ? Icons.star : Icons.person_outline,
                      color: isPremium ? Colors.purple : Colors.grey,
                    ),
                  ),
                  title: Text(
                    "Company ID: ${sub['companyID']}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text("Plan: ${planType.toUpperCase()}",
                        style: TextStyle(
                            color: isPremium ? Colors.purple : Colors.black87,
                            fontWeight: isPremium ? FontWeight.bold : FontWeight.normal
                        ),
                      ),
                      Text("Amount: RM ${sub['amountPaid']}"),
                      Text("Expiry: ${sub['endDate']?.toString().split('T')[0] ?? 'N/A'}", style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sub['status'] == 'active' ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sub['status']?.toString().toUpperCase() ?? "",
                      style: TextStyle(
                        color: sub['status'] == 'active' ? Colors.green : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}