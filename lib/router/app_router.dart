import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/add_listing_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/space_continue_screen.dart';
import '../screens/space_gateway_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_edit_screen.dart';
import '../screens/landlord_onboarding_screen.dart';
import '../screens/lease_replacement_wizard_screen.dart';
import '../screens/landlord_dashboard_screen.dart';
import '../screens/landlord_decision_engine_screen.dart';
import '../screens/listing_detail_screen.dart';
import '../screens/application_conversation_screen.dart';
import '../screens/social_verification_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/verification_screen.dart';
import '../screens/pre_arrival_contact_screen.dart';
import '../screens/university_email_verify_screen.dart';
import '../screens/open_banking_verify_screen.dart';
import '../screens/open_banking_callback_screen.dart';
import '../models/onboarding_user_role.dart';
import '../services/auth_service.dart';
import 'app_routes.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

bool _isSignedIn() => AuthService.isSignedIn(AuthScreen.currentUserSession);

bool _isSeekerSurface(String loc) =>
    loc == '/profile' ||
    loc == '/profile/edit' ||
    loc == '/seeker-onboarding' ||
    (loc.startsWith('/profile/edit') && loc != '/profile/edit/host');

String? _redirectSeekerSurface(String loc) {
  if (!_isSeekerSurface(loc)) return null;

  final session = AuthScreen.currentUserSession;
  if (!_isSignedIn()) return AppRoutes.home;

  final role = UserRole.fromSession(session);
  switch (role) {
    case UserRole.landlord:
      return '/landlord-dashboard';
    case UserRole.seeker:
      return null;
    case UserRole.unassigned:
      return AppRoutes.home;
  }
}

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.home,
  refreshListenable: authSessionNotifier,
  redirect: (context, state) {
    final signedIn = _isSignedIn();
    final loc = state.matchedLocation;

    // Legacy welcome / role-gate → demo auth or seeker profile edit.
    if (loc == '/welcome') {
      if (!signedIn) return AppRoutes.home;
      final role = UserRole.fromSession(AuthScreen.currentUserSession);
      if (role == UserRole.landlord) return '/landlord-dashboard';
      return '/profile/edit';
    }
    // Product aliases → existing screens (no new UI).
    if (loc == '/browse') return AppRoutes.home;
    if (loc == '/seeker-onboarding') {
      return _redirectSeekerSurface('/profile') ?? '/profile';
    }

    final seekerRedirect = _redirectSeekerSurface(loc);
    if (seekerRedirect != null) return seekerRedirect;

    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      builder: (context, state) {
        // Unauthenticated entry: single Try TrueCircle demo auth screen.
        if (!_isSignedIn()) {
          return const AuthScreen();
        }
        return HomeScreen(
          key: ValueKey(state.uri.queryParameters['refresh'] ?? 'home'),
        );
      },
    ),
    GoRoute(
      path: '/space-gateway',
      builder: (context, state) => const SpaceGatewayScreen(),
    ),
    GoRoute(
      path: '/space-continue',
      builder: (context, state) => const SpaceContinueScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const UserProfileScreen(),
    ),
    GoRoute(
      path: '/add-listing',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is Map<String, dynamic>) {
          final draft = extra['listingDraft'];
          if (draft is Map<String, dynamic>) {
            return AddListingScreen(draftListing: draft);
          }
          final id = extra['id']?.toString() ?? extra['listing_id']?.toString();
          if (id != null && id.isNotEmpty) {
            return AddListingScreen(editingListing: extra);
          }
          if (extra.containsKey('location') ||
              extra.containsKey('eircode')) {
            return AddListingScreen(draftListing: extra);
          }
          return AddListingScreen(editingListing: extra);
        }
        return const AddListingScreen();
      },
    ),
    GoRoute(
      path: '/listing/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ListingDetailScreen(listingId: id);
      },
    ),
    GoRoute(
      path: '/application/:applicationId/conversation',
      builder: (context, state) {
        final id = state.pathParameters['applicationId'] ?? '';
        final extra = state.extra;
        return ApplicationConversationScreen(
          applicationId: id,
          args: extra is ApplicationConversationRouteArgs ? extra : null,
        );
      },
    ),
    GoRoute(
      path: '/listing/:id/manage',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return LandlordDashboardScreen(
          initialListingId: id.isEmpty ? null : id,
        );
      },
    ),
    GoRoute(
      path: '/landlord-dashboard',
      builder: (context, state) {
        final listingId = state.uri.queryParameters['listingId'];
        return LandlordDashboardScreen(initialListingId: listingId);
      },
    ),
    GoRoute(
      path: '/landlord-dashboard/legacy',
      builder: (context, state) {
        final listingId = state.uri.queryParameters['listingId'];
        return LandlordDashboardScreen(initialListingId: listingId);
      },
    ),
    GoRoute(
      path: '/landlord-dashboard/engine',
      builder: (context, state) {
        return const LandlordDecisionEngineScreen();
      },
    ),
    GoRoute(
      path: '/replacement/:workflowId',
      builder: (context, state) {
        final id = state.pathParameters['workflowId'] ?? '';
        return LeaseReplacementWizardScreen(workflowId: id);
      },
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) {
        final initial = state.extra;
        return ProfileEditScreen(
          initialProfile: initial is Map<String, dynamic> ? initial : null,
        );
      },
    ),
    GoRoute(
      path: '/profile/edit/host',
      builder: (context, state) {
        final initial = state.extra;
        return LandlordOnboardingScreen(
          initialProfile: initial is Map<String, dynamic> ? initial : null,
        );
      },
    ),
    GoRoute(
      path: '/verify/social',
      builder: (context, state) => const SocialVerificationScreen(),
    ),
    GoRoute(
      path: '/verify/pre-arrival',
      builder: (context, state) => const PreArrivalContactScreen(),
    ),
    GoRoute(
      path: '/verify/open-banking',
      builder: (context, state) => const OpenBankingVerifyScreen(),
    ),
    GoRoute(
      path: '/verify/id',
      builder: (context, state) => const VerificationScreen(),
      routes: [
        GoRoute(
          path: 'university-email',
          builder: (context, state) => const UniversityEmailVerifyScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/auth/open-banking/callback',
      builder: (context, state) => OpenBankingCallbackScreen(uri: state.uri),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri.path}'),
    ),
  ),
);
