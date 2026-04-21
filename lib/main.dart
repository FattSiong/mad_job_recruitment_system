import 'package:flutter/material.dart';
import 'core/screens/temp_main_screen.dart';

void main() {
  runApp(const RecruitmentApp());
}

class RecruitmentApp extends StatelessWidget {
  const RecruitmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recruitment Platform',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Point the home property to your new temporary main screen
      home: const TempMainScreen(),
    );
  }
}