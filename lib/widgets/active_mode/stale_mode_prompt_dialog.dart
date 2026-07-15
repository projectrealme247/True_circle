import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/active_mode_service.dart';

/// Shown when dual-capable users return after 90+ days without a mode update.
abstract final class StaleModePromptDialog {
  static Future<ActiveMode?> show(BuildContext context) {
    return showDialog<ActiveMode>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Welcome back'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'What would you like to do today?',
                style: TextStyle(height: 1.45),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, ActiveMode.explore),
                style: AppButtonStyles.primaryFilled,
                child: const Text('Explore Places'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, ActiveMode.hosting),
                child: const Text('Manage Listings'),
              ),
            ],
          ),
        );
      },
    );
  }
}
