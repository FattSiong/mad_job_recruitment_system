import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  final String publishableKey = "pk_test_51TPT4D8sWAvwhsmDNXUbF8LCTGtSuW7jRjuiAKqtMz0EYa0dNcG1cLXRzDP7LHAPKqtYfx0PuxLt3gl2erO0ttb000Wt76CdRo";
  final String secretKey = "sk_test_51TPT4D8sWAvwhsmD5iilTCVsbs5qqhjte28Ofz6T0ugvjzyjsksl2JHUy67ULUnTyBtHq1urXpAivqVrUHR0lIQD00IRQ57Ffg";

  @override
  void initState() {
    super.initState();
    Stripe.publishableKey = publishableKey;
  }

  Future<void> _handleStripePayment(String planId) async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "Please login first";

      final paymentIntent = await _createPaymentIntent('9900', 'MYR');

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent['client_secret'],
          merchantDisplayName: 'MAD Job Recruitment',
          style: ThemeMode.light,
          // 🔴 必须和 AndroidManifest 里的暗号完全一致
          returnURL: 'madjob://stripe-redirect',
        ),
      );

      setState(() => _isLoading = false);
      await Stripe.instance.presentPaymentSheet();

      setState(() => _isLoading = true);
      await _syncSubscriptionToDatabase(user.id, planId);

      if (mounted) _showSuccessDialog();

    } on StripeException catch (e) {
      debugPrint("Stripe Error: ${e.error.localizedMessage}");
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 60),
              SizedBox(height: 16),
              Text("Payment Successful!", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text("Your account is now upgraded to Premium!", textAlign: TextAlign.center),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                child: const Text("Go to Dashboard", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _createPaymentIntent(String amount, String currency) async {
    Map<String, dynamic> body = {'amount': amount, 'currency': currency, 'payment_method_types[]': 'card'};
    var response = await http.post(
      Uri.parse('https://api.stripe.com/v1/payment_intents'),
      headers: {'Authorization': 'Bearer $secretKey', 'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    return json.decode(response.body);
  }

  Future<void> _syncSubscriptionToDatabase(String userId, String planId) async {
    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 30));
    final memberData = await supabase.from('CompanyMember').select('companyID').eq('employerID', userId).limit(1).maybeSingle();

    final Map<String, dynamic> subData = {
      'companyID': memberData?['companyID'].toString(),
      'paidByEmployerID': userId,
      'planType': planId,
      'amountPaid': 99.0,
      'paymentDate': now.toIso8601String(),
      'status': 'active',
      'startDate': now.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };

    final existingSub = await supabase.from('PaymentSubscription').select().eq('paidByEmployerID', userId).limit(1).maybeSingle();
    if (existingSub == null) {
      await supabase.from('PaymentSubscription').insert(subData);
    } else {
      await supabase.from('PaymentSubscription').update(subData).eq('paidByEmployerID', userId);
    }
  }

  // 👇 这里保持你原本好看的设计
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Billing & Plans", style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildPlanCard("Basic Plan", "0", Colors.blueGrey, "basic", ['Standard Job Posting']),
            const SizedBox(height: 24),
            _buildPlanCard("Premium AI", "99", Colors.purple, "premium", ['AI Question Generator', 'AI Resume Ranking']),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(String name, String price, Color color, String id, List<String> features) {
    bool isPremium = id == 'premium';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isPremium ? color : color.withOpacity(0.3), width: isPremium ? 2 : 1),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text(name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color))),
          const SizedBox(height: 8),
          Center(child: Text("RM $price / month", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Divider()),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(children: [Icon(Icons.check_circle, color: isPremium ? color : Colors.green, size: 20), const SizedBox(width: 12), Text(f)]),
          )),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => isPremium ? _handleStripePayment(id) : null,
            style: ElevatedButton.styleFrom(backgroundColor: color, minimumSize: const Size(double.infinity, 54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Select Plan", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}