import 'package:flutter/material.dart';

import '../../../core/theme/app_button_styles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared_widgets/state_message_card.dart';

/// Shown when a list couldn't be loaded (instead of an empty-state message).
class LoadErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const LoadErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: StateMessageCard(
        boxed: false,
        icon: Icons.cloud_off_rounded,
        color: AppColors.danger,
        title: 'Something went wrong',
        message: message,
        action: ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try Again'),
          style: AppButtonStyles.filled(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
        ),
      ),
    );
  }
}
