import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_job_screen.dart';
import 'register_company_screen.dart';
import 'subscription_screen.dart';

class EmployerDashboard extends StatefulWidget {
  const EmployerDashboard({super.key});

  @override
  State<EmployerDashboard> createState() => _EmployerDashboardState();
}

class _EmployerDashboardState extends State<EmployerDashboard> {
  final supabase = Supabase.instance.client;

  bool _isPremium = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final subInfo = await supabase
          .from('PaymentSubscription')
          .select('planType, status')
          .eq('paidByEmployerID', user.id)
          .eq('status', 'active')
          .eq('planType', 'premium')
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isPremium = (subInfo != null);
        });
      }
    } catch (e) {
      debugPrint("Error checking premium status: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employer Workspace', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _isPremium ? Colors.purple.shade50 : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  _isPremium ? Icons.workspace_premium : Icons.business_center,
                  size: 80,
                  color: _isPremium ? Colors.purple : Colors.blue
              ),
              const SizedBox(height: 20),

              Text(
                _isPremium ? 'Premium Employer Portal 👑' : 'Employer Portal',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _isPremium ? Colors.purple.shade700 : Colors.black
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isPremium
                    ? 'All AI Features are unlocked for your company!'
                    : 'Manage your company and job postings',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              _buildMenuButton(
                context,
                icon: Icons.app_registration,
                label: 'Register Company',
                color: Colors.blue,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterCompanyScreen()),
                  );
                },
              ),

              const SizedBox(height: 16),

              // ✅ 根据 _isPremium 状态决定显示升级按钮还是 Premium 勋章
              if (!_isPremium) ...[
                _buildMenuButton(
                  context,
                  icon: Icons.payments_outlined,
                  label: 'Upgrade to Premium',
                  color: Colors.purple,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                    );
                    // 付款页回来后自动刷新
                    _checkPremiumStatus();
                  },
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.workspace_premium, color: Colors.purple, size: 40),
                      SizedBox(height: 8),
                      Text(
                        "Premium Active",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple),
                      ),
                      Text(
                        "You have full access to all AI features.",
                        style: TextStyle(color: Colors.purple),
                      )
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateJobScreen()),
          );
        },
        backgroundColor: _isPremium ? Colors.purple : Colors.blue,
        icon: Icon(_isPremium ? Icons.auto_awesome : Icons.add, color: Colors.white),
        label: Text(
            _isPremium ? 'Post AI Job' : 'Post Job',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black87,
          backgroundColor: Colors.white,
          elevation: 0,
          side: BorderSide(color: Colors.grey.shade200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}