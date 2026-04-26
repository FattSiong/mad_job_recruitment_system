import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart'; // 👈 OneSignal Import

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isLoadingData = true;

  // Stores the plan the user currently owns ('monthly', 'annually', or 'free')
  String? _activePlanType;

  // Track which plan is currently selected in the UI
  String _selectedPlan = 'monthly';

  final String publishableKey = "pk_test_51TPT4D8sWAvwhsmDNXUbF8LCTGtSuW7jRjuiAKqtMz0EYa0dNcG1cLXRzDP7LHAPKqtYfx0PuxLt3gl2erO0ttb000Wt76CdRo";
  final String secretKey = "sk_test_51TPT4D8sWAvwhsmD5iilTCVsbs5qqhjte28Ofz6T0ugvjzyjsksl2JHUy67ULUnTyBtHq1urXpAivqVrUHR0lIQD00IRQ57Ffg";

  @override
  void initState() {
    super.initState();
    Stripe.publishableKey = publishableKey;
    Stripe.urlScheme = 'myapp';

    _fetchCurrentPlan();
    _setupNotifications(); // 👈 Ask for notification permission when screen opens
  }

  // 👉 NEW: Ask for permission and save token
  Future<void> _setupNotifications() async {
    final hasPermission = await OneSignal.Notifications.requestPermission(true);

    if (hasPermission) {
      final user = supabase.auth.currentUser;

      await Future.delayed(const Duration(seconds: 2));
      final String? deviceToken = OneSignal.User.pushSubscription.id;

      if (user != null && deviceToken != null && deviceToken.isNotEmpty) {
        try {
          // 1. Get the Company ID for this user
          final memberData = await supabase
              .from('CompanyMember')
              .select('companyID')
              .eq('employerID', user.id)
              .limit(1)
              .maybeSingle();

          final companyId = memberData?['companyID'];

          // 2. Save the token to the Company table
          if (companyId != null) {
            await supabase
                .from('Company')
                .update({'notification_token': deviceToken})
                .eq('companyID', companyId);

            debugPrint("✅ OneSignal Token saved to Company: $companyId");
          }
        } catch (e) {
          debugPrint("❌ Failed to save token: $e");
        }
      }
    }
  }

  Future<void> _fetchCurrentPlan() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final memberData = await supabase.from('CompanyMember').select('companyID').eq('employerID', user.id).limit(1).maybeSingle();
      final companyId = memberData?['companyID'];

      if (companyId != null) {
        final companyData = await supabase.from('Company').select('currentPlanType').eq('companyID', companyId).limit(1).maybeSingle();
        final planType = companyData?['currentPlanType'] as String?;

        if (mounted) {
          setState(() {
            if (planType == 'MONTHLY') {
              _activePlanType = 'monthly';
            } else if (planType == 'ANNUALLY') {
              _activePlanType = 'annually';
            } else {
              _activePlanType = 'free';
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching active plan: $e");
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _handleStripePayment(String planId) async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "Please login first";

      final String stripeAmount = planId == 'monthly' ? '9900' : '99900';
      final double paidAmount = planId == 'monthly' ? 99.0 : 999.0;

      final paymentIntent = await _createPaymentIntent(stripeAmount, 'MYR');

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent['client_secret'],
          merchantDisplayName: 'MAD Job Recruitment',
          style: ThemeMode.light,
          returnURL: 'myapp://payment-return',
        ),
      );

      setState(() => _isLoading = false);

      await Stripe.instance.presentPaymentSheet();

      setState(() => _isLoading = true);

      await _syncSubscriptionToDatabase(user.id, planId, paidAmount);

      if (mounted) _showSuccessDialog(planId);

    } on StripeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Stripe Error: ${e.error.localizedMessage}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("System Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String planId) {
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
          content: Text("Your account is now upgraded to Premium ${planId.capitalize()}!", textAlign: TextAlign.center),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a56ff)),
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

  Future<void> _syncSubscriptionToDatabase(String userId, String planType, double amount) async {
    final now = DateTime.now();
    final int daysToAdd = planType == 'annually' ? 365 : 30;

    final existingSub = await supabase.from('PaymentSubscription').select().eq('paidByEmployerID', userId).limit(1).maybeSingle();

    DateTime baseDate = now;

    if (existingSub != null && existingSub['endDate'] != null) {
      final currentEndDate = DateTime.parse(existingSub['endDate']);
      if (currentEndDate.isAfter(now)) {
        baseDate = currentEndDate;
      }
    }

    final endDate = baseDate.add(Duration(days: daysToAdd));

    final memberData = await supabase.from('CompanyMember').select('companyID').eq('employerID', userId).limit(1).maybeSingle();
    final String? companyId = memberData?['companyID']?.toString();

    final Map<String, dynamic> subData = {
      'companyID': companyId,
      'paidByEmployerID': userId,
      'planType': planType,
      'amountPaid': amount,
      'paymentDate': now.toIso8601String(),
      'status': 'active',
      'startDate': now.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };

    if (existingSub == null) {
      await supabase.from('PaymentSubscription').insert(subData);
    } else {
      await supabase.from('PaymentSubscription').update(subData).eq('paidByEmployerID', userId);
    }

    if (companyId != null) {
      String exactPlanWord = planType == 'monthly' ? 'MONTHLY' : 'ANNUALLY';

      await supabase
          .from('Company')
          .update({'currentPlanType': exactPlanWord})
          .eq('companyID', companyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Upgrade Plan", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading || _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          children: [
            _buildPlanCard(
              id: 'monthly',
              title: 'Premium Monthly',
              price: '99',
              period: '/month',
              isMostPopular: false,
              features: [
                'All AI features unlocked',
                'AI Resume Ranking',
                'AI Question Generator',
                'Priority support',
                'Standard analytics'
              ],
            ),
            const SizedBox(height: 24),
            _buildPlanCard(
              id: 'annually',
              title: 'Premium Annually',
              price: '999',
              period: '/year',
              isMostPopular: true,
              features: [
                'Save ~20% compared to monthly',
                'All AI features unlocked',
                'AI Resume Ranking',
                'AI Question Generator',
                '24/7 dedicated support',
                'Advanced AI analytics'
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String id,
    required String title,
    required String price,
    required String period,
    required bool isMostPopular,
    required List<String> features,
  }) {
    bool isCurrentPlan = _activePlanType == id;
    bool isDowngradeAttempt = _activePlanType == 'annually' && id == 'monthly';
    Color cardColor = isCurrentPlan ? const Color(0xFF00C853) : const Color(0xFF1a56ff);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrentPlan ? cardColor : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: isCurrentPlan
                ? [BoxShadow(color: cardColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  if (isCurrentPlan)
                    Icon(Icons.check_circle, color: cardColor, size: 28)
                  else
                    const Icon(Icons.lock_outline, color: Colors.grey, size: 24),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text("RM", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
                  Text(price, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black)),
                  Text(period, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 24),
              ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(f, style: TextStyle(color: Colors.grey.shade800, fontSize: 14))),
                  ],
                ),
              )),

              if (!isCurrentPlan) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: (_isLoading || isDowngradeAttempt) ? null : () => _handleStripePayment(id),
                  icon: Icon(
                      isDowngradeAttempt ? Icons.info_outline : Icons.lock_open,
                      size: 18,
                      color: isDowngradeAttempt ? Colors.grey : Colors.white
                  ),
                  label: Text(
                      isDowngradeAttempt ? "Included in Annual" : "Unlock $title",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDowngradeAttempt ? Colors.grey : Colors.white
                      )
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDowngradeAttempt ? Colors.grey.shade200 : cardColor,
                    disabledBackgroundColor: Colors.grey.shade200,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ]
            ],
          ),
        ),

        if (isCurrentPlan || isMostPopular)
          Positioned(
            top: -14,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isCurrentPlan ? "Current Plan" : "Most Popular",
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}