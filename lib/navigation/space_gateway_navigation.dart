import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/marketplace_context_notifier.dart';

/// Routes authenticated users to space gateway or continue prompt after login.
Future<void> navigateAfterAuth(BuildContext context) async {
  await marketplaceContextNotifier.refresh();
  if (!context.mounted) return;

  final lastSpace = marketplaceContextNotifier.lastActiveSpace;
  if (lastSpace == null) {
    context.go('/space-gateway');
  } else {
    context.go('/space-continue');
  }
}
