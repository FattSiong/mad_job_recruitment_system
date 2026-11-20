import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/table_constants.dart';

// Import your screens here
import '../modules/job_seeker/screens/seeker_dashboard.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';
import '../services/password_recovery_service.dart';
import '../modules/employer/screens/employer_dashboard.dart';
import '../modules/admin/screens/admin_dashboard.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// Logged in, but the role couldn't be read because there is no
  /// connection: show "Try again" instead of sending them to log in again.
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _redirectUser();
  }

  Future<void> _retry() async {
    setState(() => _offline = false);
    await _redirectUser();
  }

  Future<void> _logOut() async {
    try {
      await AuthService().signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  Future<void> _redirectUser() async {
    // Wait a brief moment to ensure the widget tree is fully built before navigating
    await Future.delayed(Duration.zero);

    // Opened from the password reset email: go straight to "Set a new password".
    PasswordRecoveryService.appReady = true;
    if (PasswordRecoveryService.pending) {
      PasswordRecoveryService.pending = false;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ResetPasswordScreen()),
      );
      return;
    }

    try {
      // 1. Check if Supabase has a saved session token on the device
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null) {
        // No saved session found. Send them to Login.
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      // 2. Session exists! Now we need to know who they are.
      final String userId = session.user.id;

      // Fetch their role from your custom table using your constants
      final userData = await Supabase.instance.client
          .from(TableConstants.user)
          .select('role')
          .eq('userID', userId)
          .maybeSingle();

      final String? role = userData?['role'] as String?;

      if (!mounted) return;

      // 3. Route them to their specific dashboard based on the database role
      if (role == 'employer') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const EmployerDashboard()));
      } else if (role == 'job_seeker') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SeekerDashboard()));
      } else if (role == 'admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
      } else {
        // Fallback just in case something is wrong with their data
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // No connection: keep them logged in and let them try again
      if (AuthService.isNetworkError(e)) {
        setState(() => _offline = true);
        return;
      }
      // Anything else: log in again
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // This is what the user sees for a split second when they open the app.
    // You can customize this to show your App Logo instead of just a spinner!
    if (!_offline) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey.shade500),
                const SizedBox(height: 16),
                const Text(
                  'No internet connection',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check your connection, then try again. You are still logged in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
                TextButton(onPressed: _logOut, child: const Text('Log out')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
