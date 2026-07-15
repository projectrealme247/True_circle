import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:true_circle/core/theme/app_theme.dart';
import 'package:true_circle/models/marketplace_space.dart';
import 'package:true_circle/navigation/navigate_after_identity.dart';
import 'package:true_circle/router/app_router.dart';
import 'package:true_circle/screens/auth_screen.dart';
import 'package:true_circle/screens/home_screen.dart';
import 'package:true_circle/services/marketplace_context_notifier.dart';
import 'package:true_circle/services/profile_state_notifier.dart';
import 'package:true_circle/services/profile_storage_service.dart';
import 'package:true_circle/utils/profile_data.dart';
import 'package:true_circle/utils/profile_progress.dart';
import 'package:true_circle/widgets/home/home_profile_completion_banner.dart';

/// Partially complete seeker — below [ProfileData.isMatchingReady] threshold.
Map<String, dynamic> incompleteSeekerSession() => {
      'email': 'seeker@example.com',
      'demo_mode': true,
      'full_name': 'Ana',
      'mother_tongue': 'English',
      'spoken_languages': ['English', 'Hindi'],
      'maximum_commute_budget_minutes': 45,
    };

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
    identityColdStartEnabled = false;
    HomeProfileCompletionBannerSession.reset();
    resetIdentityLanding();
    AuthScreen.currentUserSession = null;
    profileStateNotifier.clear();
    await ProfileStorageService.clear();
    await marketplaceContextNotifier.setActiveSpace(MarketplaceSpace.fullRental);
  });

  Future<void> seedIncompleteProfile() async {
    final session = incompleteSeekerSession();
    await ProfileStorageService.save(session);
    AuthScreen.currentUserSession = Map<String, dynamic>.from(session);
    profileStateNotifier.commitPersisted(session);
  }

  group('HomeProfileCompletionBanner', () {
    testWidgets('compact banner golden at 30%', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 120));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: HomeProfileCompletionBanner(
                percent: 30,
                onContinue: () {},
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Complete Profile (30%)'), findsOneWidget);
      expect(
        find.text('Complete your profile for better matches.'),
        findsOneWidget,
      );
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);

      await expectLater(
        find.byType(HomeProfileCompletionBanner),
        matchesGoldenFile('goldens/profile_banner_compact.png'),
      );
    });

    testWidgets('dismiss hides banner for session', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HomeProfileCompletionBanner(
              percent: 30,
              onContinue: () {},
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Dismiss'));
      await tester.pump();

      expect(dismissed, isTrue);
    });
  });

  tearDown(() {
    identityColdStartEnabled = true;
  });

  group('HomeScreen profile completion banner', () {
    Future<void> pumpHomeWithIncompleteProfile(WidgetTester tester) async {
      await seedIncompleteProfile();
      expect(ProfileData.isProfileIncomplete(incompleteSeekerSession()), isTrue);

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

    testWidgets('shows compact banner on homepage', (tester) async {
      await pumpHomeWithIncompleteProfile(tester);

      expect(find.byType(HomeProfileCompletionBanner), findsOneWidget);
      final percent = ProfileProgress.percent(
        profileStateNotifier.session,
        ownedListingCount: 0,
      );
      expect(percent, greaterThan(0));
      expect(find.textContaining('Complete Profile ($percent%)'), findsOneWidget);
    });

    testWidgets('session dismiss removes banner from homepage', (tester) async {
      await pumpHomeWithIncompleteProfile(tester);
      expect(find.byType(HomeProfileCompletionBanner), findsOneWidget);

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeProfileCompletionBanner), findsNothing);
      expect(HomeProfileCompletionBannerSession.dismissed, isTrue);
    });

    testWidgets('homepage with compact banner golden', (tester) async {
      await pumpHomeWithIncompleteProfile(tester);

      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/homepage_with_compact_banner.png'),
      );
    });

    testWidgets('matching-ready profile auto-hides banner', (tester) async {
      final session = {
        'email': 'ready@example.com',
        'demo_mode': true,
        'full_name': 'Priya',
        'detected_city': 'Dublin',
        'mother_tongue': 'Telugu',
        'spoken_languages': ['Telugu', 'English'],
      };
      expect(ProfileData.isMatchingReady(session), isTrue);

      await ProfileStorageService.save(session);
      AuthScreen.currentUserSession = Map<String, dynamic>.from(session);
      profileStateNotifier.commitPersisted(session);

      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: appRouter,
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(HomeProfileCompletionBanner), findsNothing);
    });
  });
}
