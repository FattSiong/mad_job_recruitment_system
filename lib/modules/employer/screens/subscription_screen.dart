import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/table_constants.dart';
import '../../../models/company_model.dart';

class SubscriptionScreen extends StatefulWidget {
  final String? initialCompanyId;

  const SubscriptionScreen({super.key, this.initialCompanyId});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _isLoadingData = true;

  final List<CompanyModel> _companies = [];
  CompanyModel? _selectedCompany;
  String? _selectedCompanyId;

  String _activePlanType = 'free';
  DateTime? _subscriptionEndsAt;
  bool _isSubscriptionExpired = false;

  final String publishableKey =
      'pk_test_51TPT4D8sWAvwhsmDNXUbF8LCTGtSuW7jRjuiAKqtMz0EYa0dNcG1cLXRzDP7LHAPKqtYfx0PuxLt3gl2erO0ttb000Wt76CdRo';
  final String secretKey =
      'sk_test_51TPT4D8sWAvwhsmD5iilTCVsbs5qqhjte28Ofz6T0ugvjzyjsksl2JHUy67ULUnTyBtHq1urXpAivqVrUHR0lIQD00IRQ57Ffg';

  @override
  void initState() {
    super.initState();

    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadCompanies();
    await _setupNotifications();
  }

  Future<void> _loadCompanies() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final response = await supabase
          .from(TableConstants.companyMember)
          .select('status, Company(*)')
          .eq('employerID', currentUser.id)
          .eq('status', 'active');

      final List<CompanyModel> loadedCompanies = [];
      for (final row in response) {
        if (row['Company'] != null) {
          loadedCompanies.add(CompanyModel.fromJson(row['Company']));
        }
      }

      if (!mounted) return;

      setState(() {
        _companies
          ..clear()
          ..addAll(loadedCompanies);

        if (_companies.isNotEmpty) {
          _selectedCompany = widget.initialCompanyId != null
              ? _companies.firstWhere(
                  (c) => c.companyID == widget.initialCompanyId,
                  orElse: () => _companies.first,
                )
              : _companies.first;
          _selectedCompanyId = _selectedCompany!.companyID;
          _syncActivePlanFromSelectedCompany();
        } else {
          _selectedCompany = null;
          _selectedCompanyId = null;
          _activePlanType = 'free';
          _subscriptionEndsAt = null;
        }
      });
    } catch (e) {
      debugPrint('Error loading companies: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load companies: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  void _syncActivePlanFromSelectedCompany() {
    final company = _selectedCompany;
    if (company == null) {
      _activePlanType = 'free';
      _subscriptionEndsAt = null;
      _isSubscriptionExpired = false;
      return;
    }

    final normalizedPlan = company.currentPlanType.toUpperCase();
    final endDate = company.subscriptionEndsAt;
    final isExpired =
        normalizedPlan != 'FREE' &&
        endDate != null &&
        DateTime.now().isAfter(endDate);

    _subscriptionEndsAt = endDate;
    _isSubscriptionExpired = isExpired;

    if (isExpired) {
      _activePlanType = 'free';
      return;
    }

    if (normalizedPlan == 'MONTHLY') {
      _activePlanType = 'monthly';
    } else if (normalizedPlan == 'ANNUALLY') {
      _activePlanType = 'annually';
    } else {
      _activePlanType = 'free';
    }
  }

  Future<void> _setupNotifications() async {
    final hasPermission = await OneSignal.Notifications.requestPermission(true);
    if (!hasPermission) return;

    await Future.delayed(const Duration(seconds: 2));

    final deviceToken = OneSignal.User.pushSubscription.id;
    final companyId = _selectedCompanyId;

    if (deviceToken == null ||
        deviceToken.isEmpty ||
        companyId == null ||
        companyId.isEmpty) {
      return;
    }

    try {
      await supabase
          .from(TableConstants.company)
          .update({'notification_token': deviceToken})
          .eq('companyID', companyId);
    } catch (e) {
      debugPrint('Failed to save OneSignal token: $e');
    }
  }

  Future<void> _handleStripePayment(String planId) async {
    final user = supabase.auth.currentUser;
    final company = _selectedCompany;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (company == null || company.companyID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a company first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final stripeAmount = planId == 'monthly' ? '9900' : '99900';
      final paidAmount = planId == 'monthly' ? 99.0 : 999.0;

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

      await _syncSubscriptionToDatabase(
        employerId: user.id,
        companyId: company.companyID!,
        planType: planId,
        amount: paidAmount,
      );

      await _refreshSelectedCompany();

      if (mounted) {
        _showSuccessDialog(planId, company.name);
      }
    } on StripeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stripe Error: ${e.error.localizedMessage ?? 'Payment cancelled.'}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('System Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshSelectedCompany() async {
    final companyId = _selectedCompanyId;
    if (companyId == null) return;

    try {
      final response = await supabase
          .from(TableConstants.company)
          .select()
          .eq('companyID', companyId)
          .single();

      final refreshedCompany = CompanyModel.fromJson(response);
      final index = _companies.indexWhere(
        (company) => company.companyID == companyId,
      );

      if (!mounted) return;

      setState(() {
        if (index >= 0) {
          _companies[index] = refreshedCompany;
        }
        _selectedCompany = refreshedCompany;
        _syncActivePlanFromSelectedCompany();
      });
    } catch (e) {
      debugPrint('Failed to refresh selected company: $e');
    }
  }

  void _showSuccessDialog(String planId, String companyName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 60),
              SizedBox(height: 16),
              Text(
                'Payment Successful!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            '$companyName is now upgraded to Premium ${planId.capitalize()}!',
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56FF),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _createPaymentIntent(
    String amount,
    String currency,
  ) async {
    final body = {
      'amount': amount,
      'currency': currency,
      'payment_method_types[]': 'card',
    };

    final response = await http.post(
      Uri.parse('https://api.stripe.com/v1/payment_intents'),
      headers: {
        'Authorization': 'Bearer $secretKey',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body,
    );

    return json.decode(response.body);
  }

  Future<void> _syncSubscriptionToDatabase({
    required String employerId,
    required String companyId,
    required String planType,
    required double amount,
  }) async {
    final now = DateTime.now();
    final daysToAdd = planType == 'annually' ? 365 : 30;

    final latestSub = await supabase
        .from(TableConstants.paymentSubscription)
        .select()
        .eq('companyID', companyId)
        .order('endDate', ascending: false)
        .limit(1)
        .maybeSingle();

    DateTime startDate = now;

    if (latestSub != null && latestSub['endDate'] != null) {
      final currentEndDate = DateTime.parse(latestSub['endDate']);
      if (currentEndDate.isAfter(now)) {
        startDate = currentEndDate;
      }
    }

    final endDate = startDate.add(Duration(days: daysToAdd));
    final exactPlanWord = planType == 'monthly' ? 'MONTHLY' : 'ANNUALLY';

    final subData = {
      'companyID': companyId,
      'paidByEmployerID': employerId,
      'planType': planType,
      'amountPaid': amount,
      'paymentDate': now.toIso8601String(),
      'status': 'active',
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };

    await supabase
        .from(TableConstants.paymentSubscription)
        .insert(subData);

    await supabase.from(TableConstants.company).update({
      'currentPlanType': exactPlanWord,
      'subscriptionEndsAt': endDate.toIso8601String(),
    }).eq('companyID', companyId);
  }

  String _formatPlanLabel(String planType) {
    switch (planType.toUpperCase()) {
      case 'MONTHLY':
        return 'Premium Monthly';
      case 'ANNUALLY':
        return 'Premium Annually';
      default:
        return 'Free Plan';
    }
  }

  String _buildCurrentPlanStatusLabel() {
    final planLabel =
        _formatPlanLabel(_selectedCompany?.currentPlanType ?? 'FREE');

    if (_isSubscriptionExpired) {
      return '$planLabel (Expired)';
    }

    return planLabel;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Upgrade Plan',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading || _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _companies.isEmpty
          ? _buildEmptyState()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCompanySelectorCard(),
                  const SizedBox(height: 20),
                  _buildCurrentPlanCard(),
                  const SizedBox(height: 24),
                  _buildPlanCard(
                    id: 'monthly',
                    title: 'Premium Monthly',
                    price: '99',
                    period: '/month',
                    isMostPopular: false,
                    features: const [
                      'All AI features unlocked',
                      'AI Salary Suggestion',
                      'AI Pre-Screening Question Generator',
                      'AI Smart Candidate Ranking',
                      'Post-Interview AI Analytics & PDF Report',
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildPlanCard(
                    id: 'annually',
                    title: 'Premium Annually',
                    price: '999',
                    period: '/year',
                    isMostPopular: true,
                    features: const [
                      'Save ~20% compared to monthly',
                      'All AI features unlocked',
                      'AI Salary Suggestion',
                      'AI Pre-Screening Question Generator',
                      'AI Smart Candidate Ranking',
                      'Post-Interview AI Analytics & PDF Report',
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCompanySelectorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Company',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2433),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Subscriptions are applied to a company, not to your personal employer account.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF687588),
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: _selectedCompanyId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Company',
              prefixIcon: const Icon(
                Icons.business_rounded,
                color: Color(0xFF163B65),
              ),
              filled: true,
              fillColor: const Color(0xFFF7F9FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Color(0xFF163B65),
                  width: 1.4,
                ),
              ),
            ),
            items: _companies
                .map(
                  (company) => DropdownMenuItem<String>(
                    value: company.companyID,
                    child: Text(company.name),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null) return;

              final company = _companies.firstWhere(
                (item) => item.companyID == value,
              );

              setState(() {
                _selectedCompanyId = value;
                _selectedCompany = company;
                _syncActivePlanFromSelectedCompany();
              });

              await _setupNotifications();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanCard() {
    final company = _selectedCompany;
    final Color cardColor = _isSubscriptionExpired
        ? const Color(0xFFC24E4E)
        : const Color(0xFF163B65);
    final Color badgeBackground = _isSubscriptionExpired
        ? const Color(0xFFFCE9E9)
        : Colors.white.withOpacity(0.16);
    final Color badgeTextColor = _isSubscriptionExpired
        ? const Color(0xFFC24E4E)
        : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: badgeBackground,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _isSubscriptionExpired ? 'Expired Plan' : 'Current Subscription',
              style: TextStyle(
                color: badgeTextColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            company?.name ?? 'Selected Company',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _buildCurrentPlanStatusLabel(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_subscriptionEndsAt != null) ...[
            const SizedBox(height: 8),
            Text(
              _isSubscriptionExpired
                  ? 'Expired on ${_formatDate(_subscriptionEndsAt!)}'
                  : 'Active until ${_formatDate(_subscriptionEndsAt!)}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ],
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
    final isCurrentPlan = _activePlanType == id;
    final isDowngradeAttempt = _activePlanType == 'annually' && id == 'monthly';
    final cardColor = isCurrentPlan
        ? const Color(0xFF00C853)
        : const Color(0xFF1A56FF);

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
                ? [
                    BoxShadow(
                      color: cardColor.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (isCurrentPlan)
                    Icon(Icons.check_circle, color: cardColor, size: 28)
                  else
                    const Icon(
                      Icons.lock_outline,
                      color: Colors.grey,
                      size: 24,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text(
                    'RM',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    period,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.check, color: Colors.green, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          feature,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isCurrentPlan) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: (_isLoading || isDowngradeAttempt)
                      ? null
                      : () => _handleStripePayment(id),
                  icon: Icon(
                    isDowngradeAttempt ? Icons.info_outline : Icons.lock_open,
                    size: 18,
                    color: isDowngradeAttempt ? Colors.grey : Colors.white,
                  ),
                  label: Text(
                    isDowngradeAttempt ? 'Included in Annual' : 'Unlock $title',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDowngradeAttempt ? Colors.grey : Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDowngradeAttempt
                        ? Colors.grey.shade200
                        : cardColor,
                    disabledBackgroundColor: Colors.grey.shade200,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isCurrentPlan ? 'Current Plan' : 'Most Popular',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.business_center_rounded,
                size: 64,
                color: Color(0xFF163B65),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Company Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B2433),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You need to join at least one company before you can subscribe to a premium plan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF687588),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
