import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/table_constants.dart';

// Import your screens here
import 'login_screen.dart';
import '../modules/employer/screens/employer_dashboard.dart';
import '../modules/job_seeker/screens/seeker_dashboard.dart';
import '../modules/admin/screens/admin_dashboard.dart';
import '../../../core/screens/temp_main_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _redirectUser();
  }

  Future<void> _redirectUser() async {
    // Wait a brief moment to ensure the widget tree is fully built before navigating
    await Future.delayed(Duration.zero);

    try {
      // 1. Check if Supabase has a saved session token on the device
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null) {
        // No saved session found. Send them to Login.
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          // MaterialPageRoute(builder: (context) => const LoginScreen()),
          MaterialPageRoute(builder: (context) => const TempMainScreen()),
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
          .single();

      final String? role = userData['role'] as String?;

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
          // MaterialPageRoute(builder: (context) => const LoginScreen()),
          MaterialPageRoute(builder: (context) => const TempMainScreen()),
        );
      }
    } catch (e) {
      // If the database check fails (e.g., no internet), send them to login safely
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        // MaterialPageRoute(builder: (context) => const LoginScreen()),
        MaterialPageRoute(builder: (context) => const TempMainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // This is what the user sees for a split second when they open the app.
    // You can customize this to show your App Logo instead of just a spinner!
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}