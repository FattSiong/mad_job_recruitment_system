import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'services/notification_service.dart';
import 'shared_widgets/auth_gate.dart';

Future<void> main() async {
  // 1. Mandatory line for plugin initialization
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Load environment variables
  await dotenv.load(fileName: ".env");

  Stripe.publishableKey =
  'pk_test_51TPT4D8sWAvwhsmDNXUbF8LCTGtSuW7jRjuiAKqtMz0EYa0dNcG1cLXRzDP7LHAPKqtYfx0PuxLt3gl2erO0ttb000Wt76CdRo';
  Stripe.urlScheme = 'myapp';
  await Stripe.instance.applySettings();

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("595705d0-3319-4ced-90ab-22185bb761dc");

  OneSignal.User.pushSubscription.addObserver((state) {
    if (state.current.id != null) {
      print("====================================================");
      print("NEW SUBSCRIPTION DETECTED!");
      print("PLAYER ID: ${state.current.id}");
      print("====================================================");
    }
  });

  Future.delayed(const Duration(seconds: 2), () {
    String? existingId = OneSignal.User.pushSubscription.id;
    if (existingId != null && existingId.isNotEmpty) {
      print("====================================================");
      print("CURRENT REGISTERED PLAYER ID: $existingId");
      print("====================================================");
    } else {
      print("----------------------------------------------------");
      print("PLAYER ID NOT FOUND YET. Ensure you clicked 'Allow' on the phone.");
      print("----------------------------------------------------");
    }
  });

  OneSignal.Notifications.requestPermission(true);
  // 4. Initialize push notifications and incoming call notification handling.
  await NotificationService.initialize();

  runApp(const RecruitmentApp());
}

class RecruitmentApp extends StatelessWidget {
  const RecruitmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAD Job Recruitment System',
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