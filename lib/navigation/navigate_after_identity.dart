import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/active_mode_service.dart';
import '../services/demo_auth_service.dart';
import '../services/marketplace_context_notifier.dart';
import '../widgets/active_mode/stale_mode_prompt_dialog.dart';

/// When false, cold-start landing is skipped (widget tests keep HomeScreen mounted).
bool identityColdStartEnabled = true;

/// Post-auth and cold-start landing using [ActiveModeService] precedence.
///
/// [force] — always run (sign-in, demo entry). Without it, runs once per app
/// launch for cold-start session restoration.
Future<void> navigateAfterIdentity(
  BuildContext context, {
  bool allowStalePrompt = true,
  bool force = false,
}) async {
  if (!force && !identityColdStartEnabled) {
    _identityLandingHandled = true;
    return;
  }
  if (!force && _identityLandingHandled) return;

  await marketplaceContextNotifier.refresh();
  if (!context.mounted) return;

  final session = marketplaceContextNotifier.session;
  final resolution = await ActiveModeService.resolveLandingRouteAsync(
    session: session,
  );

  if (!context.mounted) return;

  if (!force) _identityLandingHandled = true;

  if (resolution.action == LandingAction.showStaleModePrompt &&
      allowStalePrompt) {
    final choice = await StaleModePromptDialog.show(context);
    if (!context.mounted) return;
    if (choice == null) {
      _goIfNeeded(context, _marketplaceRoute(session));
      return;
    }
    await ActiveModeService.setMode(choice);
    if (!context.mounted) return;
    _goIfNeeded(
      context,
      choice == ActiveMode.hosting ? '/landlord-dashboard' : '/',
    );
    return;
  }

  _goIfNeeded(context, _routeWithWelcomeHints(resolution.route ?? '/', session));
}

void _goIfNeeded(BuildContext context, String route) {
  final current = GoRouterState.of(context).uri.toString();
  if (current == route) return;
  context.go(route);
}

/// Routes after explicit mode switch from the header control.
Future<void> navigateForActiveMode(
  BuildContext context,
  ActiveMode mode,
) async {
  await ActiveModeService.setMode(mode);
  if (!context.mounted) return;
  switch (mode) {
    case ActiveMode.explore:
      context.go('/');
    case ActiveMode.hosting:
      final caps = ActiveModeService.capabilities;
      if (caps.ownedListingCount == 0) {
        context.go('/add-listing');
      } else {
        context.go('/landlord-dashboard');
      }
  }
}

/// Clears the one-shot cold-start guard — call on sign-out.
void resetIdentityLanding() => _identityLandingHandled = false;

bool _identityLandingHandled = false;

String _routeWithWelcomeHints(String route, Map<String, dynamic>? session) {
  if (route != '/') return route;
  if (session == null) return route;
  if (DemoAuthService.isDemoSeekerSession(session)) {
    return '/?welcomeFeed=1';
  }
  return route;
}

String _marketplaceRoute(Map<String, dynamic>? session) =>
    _routeWithWelcomeHints('/', session);
