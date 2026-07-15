import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/add_listing_screen.dart';
import '../screens/space_continue_screen.dart';
import '../screens/space_gateway_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_edit_screen.dart';
import '../screens/welcome_gate_screen.dart';
import '../screens/landlord_onboarding_screen.dart';
import '../screens/lease_replacement_wizard_screen.dart';
import '../screens/landlord_dashboard_screen.dart';
import '../screens/listing_detail_screen.dart';
import '../screens/social_verification_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/verification_screen.dart';
import 'app_routes.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      builder: (context, state) => HomeScreen(
        key: ValueKey(state.uri.queryParameters['refresh'] ?? 'home'),
      ),
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
      path: '/listing/:id/manage',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return LandlordDashboardScreen(initialListingId: id);
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
      path: '/replacement/:workflowId',
      builder: (context, state) {
        final id = state.pathParameters['workflowId'] ?? '';
        return LeaseReplacementWizardScreen(workflowId: id);
      },
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeGateScreen(),
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
      path: '/verify/id',
      builder: (context, state) => const VerificationScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri.path}'),
    ),
  ),
);
