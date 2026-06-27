import 'package:flutter/material.dart';

import '../navigation/home_explore_reset_notifier.dart';
import 'app_router.dart';

/// Named route paths for TrueCircle navigation.
abstract final class AppRoutes {
  static const home = '/';

  /// Hard-resets Explore tab, collapses modals, and re-routes to a fresh home shell.
  static void navigateHome(BuildContext context) {
    homeExploreResetNotifier.value = 0;
    Navigator.of(context, rootNavigator: true).popUntil(
      (Route<dynamic> route) => route.isFirst,
    );
    appRouter.pushReplacement('/');
  }
}
