import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/add_listing_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/home_screen.dart';
import '../screens/listing_detail_screen.dart';
import '../screens/social_verification_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/verification_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => HomeScreen(
        key: ValueKey(state.uri.queryParameters['refresh'] ?? 'home'),
      ),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const UserProfileScreen(),
    ),
    GoRoute(
      path: '/add-listing',
      builder: (context, state) => const AddListingScreen(),
    ),
    GoRoute(
      path: '/listing/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ListingDetailScreen(listingId: id);
      },
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) {
        final initial = state.extra;
        return AuthScreen(
          isEditMode: true,
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
