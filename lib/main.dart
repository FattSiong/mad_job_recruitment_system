import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'shared_widgets/auth_gate.dart';

Future<void> main() async {
  // 1. Mandatory line for plugin initialization
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Load environment variables
  await dotenv.load(fileName: ".env");

  // 3. Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  // 4. Initialize OneSignal
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("595705d0-3319-4ced-90ab-22185bb761dc");

  // 5. THE OBSERVER: This listens for changes (like first-time permission)
  OneSignal.User.pushSubscription.addObserver((state) {
    if (state.current.id != null) {
      print("====================================================");
      print("NEW SUBSCRIPTION DETECTED!");
      print("PLAYER ID: ${state.current.id}");
      print("====================================================");
    }
  });

  // 6. THE DIRECT CHECK: This prints the ID immediately if already registered
  // We use a small delay to ensure the SDK is fully ready
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

  // 7. Trigger the permission popup (only shows if not already allowed)
  OneSignal.Notifications.requestPermission(true);

  runApp(const RecruitmentApp());
}

class RecruitmentApp extends StatelessWidget {
  const RecruitmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAD Job Recruitment System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}