import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'services/notification_service.dart';
import 'services/password_recovery_service.dart';
import 'services/push_service.dart';
import 'shared_widgets/auth_gate.dart';

Future<void> main() async {
  // 1. Mandatory line for plugin initialization
  WidgetsFlutterBinding.ensureInitialized();

  Stripe.publishableKey =
  'pk_test_51TPT4D8sWAvwhsmDNXUbF8LCTGtSuW7jRjuiAKqtMz0EYa0dNcG1cLXRzDP7LHAPKqtYfx0PuxLt3gl2erO0ttb000Wt76CdRo';
  Stripe.urlScheme = 'myapp';
  await Stripe.instance.applySettings();

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  // Password reset link (myapp://reset-password) -> "Set a new password" screen.
  PasswordRecoveryService.initialize();

  // In-app notification bell (live updates for the logged-in user).
  await NotificationService.initialize();

  // Firebase Cloud Messaging: chat, calls, recruitment updates and the
  // Premium plan reminder.
  await PushService.initialize();

  runApp(const RecruitmentApp());
}

class RecruitmentApp extends StatelessWidget {
  const RecruitmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JobBoleh',
      debugShowCheckedModeBanner: false,
      navigatorKey: NotificationService.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
