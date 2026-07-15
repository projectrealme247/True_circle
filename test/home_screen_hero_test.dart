import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:true_circle/core/theme/app_theme.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/router/app_router.dart';
import 'package:true_circle/screens/home_screen.dart';
import 'package:true_circle/services/marketplace_context_notifier.dart';
import 'package:true_circle/theme/home_marketplace_theme.dart';

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await marketplaceContextNotifier.setActiveSpace(MarketplaceSpace.fullRental);
  });

  Future<void> pumpHomeScreen(
    WidgetTester tester,
    MarketplaceSpace space,
  ) async {
    await marketplaceContextNotifier.setActiveSpace(space);
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: appRouter,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  void expectHeroCopy(WidgetTester tester) {
    expect(find.text(HomeMarketplaceTheme.heroHeadline), findsOneWidget);
    expect(find.text(HomeMarketplaceTheme.heroSubheadline), findsOneWidget);
    expect(find.textContaining('Match with spaces'), findsNothing);
    expect(find.textContaining('connected by trust'), findsNothing);
  }

  void expectSearchAndFilters(WidgetTester tester) {
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Area'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('More Filters'), findsOneWidget);
  }

  testWidgets('Independent Places homepage hero golden', (tester) async {
    await pumpHomeScreen(tester, MarketplaceSpace.fullRental);

    expectHeroCopy(tester);
    expectSearchAndFilters(tester);
    expect(find.text('Independent Places'), findsWidgets);

    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/homepage_independent_places.png'),
    );
  });

  testWidgets('Shared Living homepage hero golden', (tester) async {
    await pumpHomeScreen(tester, MarketplaceSpace.sharedSpace);

    expectHeroCopy(tester);
    expectSearchAndFilters(tester);
    expect(find.text('Shared Living'), findsWidgets);

    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('goldens/homepage_shared_living.png'),
    );
  });
}
