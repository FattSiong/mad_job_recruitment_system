import 'package:flutter/material.dart';

import '../../../../shared_widgets/state_message_card.dart';

/// Empty-list message used by the My Jobs tabs.
class MyJobsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const MyJobsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: StateMessageCard(icon: icon, title: title, message: subtitle),
      ),
    );
  }
}
