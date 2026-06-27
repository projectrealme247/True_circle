import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart' show AppColors, AppButtonStyles, AppTypography;
import '../services/marketplace_context_notifier.dart';

/// Returning-user prompt to resume or change marketplace space.
class SpaceContinueScreen extends StatelessWidget {
  const SpaceContinueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final space = marketplaceContextNotifier.lastActiveSpace;
    if (space == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/space-gateway');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final spaceLabel = space.label;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Continue exploring $spaceLabel?',
                      textAlign: TextAlign.center,
                      style: AppTypography.h2,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pick up where you left off or switch to a different space.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySecondary,
                    ),
                    const SizedBox(height: 40),
                    FilledButton(
                      onPressed: () => context.go('/'),
                      style: AppButtonStyles.primaryFilled,
                      child: const Text('Continue'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.go('/space-gateway'),
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
