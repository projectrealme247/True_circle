import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/active_mode_service.dart';
import '../services/demo_auth_service.dart';
import '../services/qa_test_auth_service.dart';
import '../services/marketplace_context_notifier.dart';
import '../widgets/active_mode/stale_mode_prompt_dialog.dart';

/// When false, cold-start landing is skipped (widget tests keep HomeScreen mounted).
bool identityColdStartEnabled = true;

/// Explore/Home with welcome feed. QA seekers must [GoRouter.go] here directly
/// from Auth — `/` is also the unsigned Auth route, so [navigateAfterIdentity]
/// can leave a pushed [AuthScreen] visible.
const String kQaSeekerWelcomeRoute = '/?welcomeFeed=1';

/// Post-auth and cold-start landing using [ActiveModeService] precedence.
///
/// [force] — always run (sign-in, demo entry). Without it, runs once per app
/// launch for cold-start session restoration.
Future<void> navigateAfterIdentity(
  BuildContext context, {
  bool allowStalePrompt = true,
  bool force = false,
  GoRouter? router,
}) async {
  if (!force && !identityColdStartEnabled) {
    _identityLandingHandled = true;
    return;
  }
  if (!force && _identityLandingHandled) return;

  // Prefer a caller-captured router (before DemoAuth persist/refresh). Falling
  // back to GoRouter.of(context) is only safe before AuthScreen is swapped out.
  final resolvedRouter = router ?? GoRouter.of(context);

  await marketplaceContextNotifier.refresh();

  final session = marketplaceContextNotifier.session;
  final resolution = await ActiveModeService.resolveLandingRouteAsync(
    session: session,
  );

  if (!force) _identityLandingHandled = true;

  if (resolution.action == LandingAction.showStaleModePrompt &&
      allowStalePrompt) {
    if (!context.mounted) {
      _goIfNeeded(resolvedRouter, _marketplaceRoute(session));
      return;
    }
    final choice = await StaleModePromptDialog.show(context);
    if (choice == null) {
      _goIfNeeded(resolvedRouter, _marketplaceRoute(session));
      return;
    }
    await ActiveModeService.setMode(choice);
    _goIfNeeded(
      resolvedRouter,
      choice == ActiveMode.hosting ? '/landlord-dashboard' : '/',
    );
    return;
  }

  _goIfNeeded(
    resolvedRouter,
    _routeWithWelcomeHints(resolution.route ?? '/', session),
  );
}

void _goIfNeeded(GoRouter router, String route) {
  // Use router.state (GoRouter InheritedWidget), NOT GoRouterState.of(context).
  // GoRouterState.of requires a RouteBase.builder subtree and throws from
  // AuthScreen after the signed-in rebuild, and from MaterialPageRoute pushes.
  if (router.state.uri.toString() == route) return;
  router.go(route);
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
  if (DemoAuthService.isDemoSeekerSession(session) ||
      QaTestAuthService.isQaSeekerSession(session)) {
    return kQaSeekerWelcomeRoute;
  }
  return route;
}

String _marketplaceRoute(Map<String, dynamic>? session) =>
    _routeWithWelcomeHints('/', session);
