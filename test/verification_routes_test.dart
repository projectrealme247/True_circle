import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:true_circle/config/market/market_config.dart';
import 'package:true_circle/router/app_router.dart';
import 'package:true_circle/screens/dublin_light_trust_screen.dart';
import 'package:true_circle/screens/open_banking_verify_screen.dart';
import 'package:true_circle/screens/pre_arrival_contact_screen.dart';
import 'package:true_circle/screens/university_email_verify_screen.dart';
import 'package:true_circle/screens/verification_screen.dart';

Set<String> _registeredPaths() {
  final paths = <String>{};
  void walk(List<RouteBase> routes, String parent) {
    for (final route in routes) {
      if (route is! GoRoute) continue;
      final path = route.path.startsWith('/')
          ? route.path
          : '$parent/${route.path}'.replaceAll('//', '/');
      paths.add(path);
      walk(route.routes, path);
    }
  }

  walk(appRouter.configuration.routes, '');
  return paths;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
    );
  });

  test('verification destinations are registered on GoRouter', () {
    final paths = _registeredPaths();
    expect(paths, contains('/verify/pre-arrival'));
    expect(paths, contains('/verify/id'));
    expect(paths, contains('/verify/id/university-email'));
    expect(paths, contains('/verify/social'));
    expect(paths, contains('/verify/open-banking'));
  });

  testWidgets('pre-arrival and university email routes open real screens',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: appRouter),
    );

    appRouter.go('/verify/pre-arrival');
    await tester.pumpAndSettle();
    expect(find.byType(PreArrivalContactScreen), findsOneWidget);

    appRouter.go('/verify/id/university-email');
    await tester.pumpAndSettle();
    expect(find.byType(UniversityEmailVerifyScreen), findsOneWidget);

    appRouter.go('/verify/open-banking');
    await tester.pumpAndSettle();
    expect(find.byType(OpenBankingVerifyScreen), findsOneWidget);

    appRouter.go('/verify/id');
    await tester.pumpAndSettle();
    if (MarketConfig.current.trustVerificationKind ==
        TrustVerificationKind.lightTrust) {
      expect(find.byType(DublinLightTrustScreen), findsOneWidget);
    } else {
      expect(find.byType(VerificationScreen), findsOneWidget);
    }
  });
}
