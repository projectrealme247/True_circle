import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/navigate_after_identity.dart';
import '../screens/auth_screen.dart';
import 'profile_state_notifier.dart';
import 'profile_storage_service.dart';
import 'profile_onboarding_repository.dart';
import 'marketplace_context_notifier.dart';
import '../utils/viewer_profile.dart';

/// Supabase email/password auth + local profile hydration.
abstract final class AuthService {
  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;

  static Session? get currentSession => client.auth.currentSession;

  static bool get isAuthenticated => currentSession != null;

  /// True when the user has a real auth identity — not a marketplace-only browse shell.
  static bool hasSignedInIdentity(Map<String, dynamic>? session) {
    if (session == null || session.isEmpty) return false;
    if (session['demo_mode'] == true) return true;
    final email = session['email']?.toString().trim();
    if (email != null && email.isNotEmpty) return true;
    final userId = session['supabase_user_id']?.toString().trim();
    if (userId != null && userId.isNotEmpty) return true;
    return false;
  }

  static bool isSignedIn(Map<String, dynamic>? session) =>
      isAuthenticated || hasSignedInIdentity(session);

  /// Restore Supabase session into [AuthScreen.currentUserSession] on app start.
  static Future<void> bootstrap() async {
    await _hydrateSessionFromStorage();
  }

  /// Debug-only: logs whether Supabase Auth endpoint responds.
  static Future<void> debugProbeAuthReachable() async {
    if (!kDebugMode) return;
    try {
      await client.auth.signInWithPassword(
        email: '__circlekey_probe__@invalid.local',
        password: 'invalid-probe-password',
      );
      debugPrint('TrueCircle auth probe: unexpected success');
    } on AuthException catch (e) {
      final lower = e.message.toLowerCase();
      if (lower.contains('invalid login credentials')) {
        debugPrint('TrueCircle auth probe: OK (Supabase Auth reachable)');
        return;
      }
      debugPrint(
        'TrueCircle auth probe FAILED: ${e.message} '
        '(status ${e.statusCode ?? "?"}) â€” use env.dev.json + scripts/run_dublin.ps1',
      );
    } catch (e) {
      debugPrint('TrueCircle auth probe FAILED: $e');
    }
  }

  static const _authNetworkTimeout = Duration(seconds: 25);

  static Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await client.auth
        .signInWithPassword(
          email: email.trim(),
          password: password,
        )
        .timeout(_authNetworkTimeout);
    if (response.session == null) {
      throw Exception('Sign in failed. Check your email and password.');
    }
    await _hydrateSessionFromStorage();
  }

  /// Creates the Supabase auth user. Returns whether a session is active
  /// (false when email confirmation is required).
  static Future<bool> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    if (response.user == null) {
      throw Exception('Could not create account. Try again.');
    }
    if (response.session != null) {
      await _hydrateSessionFromStorage();
      return true;
    }
    return false;
  }

  static Future<void> signOut() async {
    debugPrint('[Auth] Signing out: explicit user sign-out');
    await client.auth.signOut(scope: SignOutScope.global);
    AuthScreen.currentUserSession = null;
    profileStateNotifier.clear();
    await ProfileStorageService.clear();
    resetIdentityLanding();
    authSessionNotifier.refresh();
  }

  /// Local-only Supabase sign-out — only when auth is already gone and storage
  /// is demonstrably corrupted. Never for incomplete profiles.
  static Future<void> safeLocalSignOutIfAllowed({required String reason}) async {
    if (currentSession != null) {
      debugPrint(
        '[Auth] Blocked SignOutScope.local ($reason): '
        'Supabase auth session is still active',
      );
      return;
    }

    final stored = await ProfileStorageService.load();
    if (stored != null &&
        stored.isNotEmpty &&
        !isProfileStorageCorrupted(stored)) {
      debugPrint(
        '[Auth] Blocked SignOutScope.local ($reason): '
        'local profile is present and not corrupted '
        '(incomplete profile is allowed)',
      );
      return;
    }

    debugPrint('[Auth] Signing out due to $reason');
    await client.auth.signOut(scope: SignOutScope.local);
    AuthScreen.currentUserSession = null;
    profileStateNotifier.clear();
    if (stored != null && isProfileStorageCorrupted(stored)) {
      await ProfileStorageService.clear();
    }
  }

  static bool isProfileStorageCorrupted(Map<String, dynamic>? stored) {
    if (stored == null) return false;
    for (final entry in stored.entries) {
      final key = entry.key;
      if (key.trim().isEmpty || key.length > 160) return true;
      final value = entry.value;
      final valid = value == null ||
          value is String ||
          value is num ||
          value is bool ||
          value is List ||
          value is Map;
      if (!valid) return true;
    }
    return false;
  }

  static Future<void> _retainLocalProfileIfPresent({
    required String reason,
  }) async {
    final stored = await ProfileStorageService.load();
    if (stored == null || stored.isEmpty) {
      debugPrint('[Auth] $reason — no local profile to retain');
      AuthScreen.currentUserSession = null;
      profileStateNotifier.clear();
      return;
    }

    if (isProfileStorageCorrupted(stored)) {
      await safeLocalSignOutIfAllowed(
        reason: 'corrupted local profile storage',
      );
      return;
    }

    final retained = Map<String, dynamic>.from(stored);
    final migrated =
        await ProfileOnboardingRepository.ensureLegacyHostTrackPersisted(retained);
    final needsOnboarding = ViewerProfile.sessionNeedsOnboarding(migrated);
    debugPrint(
      '[Auth] $reason — retaining local profile '
      '(needsOnboarding=$needsOnboarding, keys=${migrated.keys.length})',
    );
    AuthScreen.currentUserSession = migrated;
    profileStateNotifier.commitPersisted(migrated);
    unawaited(marketplaceContextNotifier.refresh());
  }

  /// Atomic profile sync: persist â†’ mirror global session â†’ notify listeners.
  static Future<Map<String, dynamic>> persistProfileSession(
    Map<String, dynamic> profile,
  ) async {
    final user = currentUser;
    final payload = {
      ...profile,
      if (user != null) ...{
        'supabase_user_id': user.id,
        'email': user.email ?? profile['email'],
      },
    };

    await ProfileStorageService.save(payload);

    final synced = Map<String, dynamic>.from(payload);
    AuthScreen.currentUserSession = synced;
    profileStateNotifier.commitPersisted(synced);
    unawaited(marketplaceContextNotifier.refresh());
    authSessionNotifier.refresh();

    final displayName = synced['full_name']?.toString().trim();
    if (user != null && displayName != null && displayName.isNotEmpty) {
      await client.auth.updateUser(
        UserAttributes(data: {'full_name': displayName}),
      );
    }

    return synced;
  }

  /// Merge persisted profile with Supabase user id + email.
  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    await persistProfileSession(profile);
  }

  /// Re-reads local profile storage into [AuthScreen.currentUserSession].
  static Future<Map<String, dynamic>?> reloadProfileFromStorage() async {
    final stored = await ProfileStorageService.load();
    final current = AuthScreen.currentUserSession;

    if (stored == null && current == null) {
      profileStateNotifier.clear();
      return null;
    }

    // Storage wins on overlap so freshly persisted profile fields are kept.
    final merged = <String, dynamic>{
      if (current != null) ...current,
      if (stored != null) ...stored,
    };

    AuthScreen.currentUserSession = merged;
    profileStateNotifier.commitPersisted(merged);
    unawaited(marketplaceContextNotifier.refresh());
    profileStateNotifier.broadcast();
    return merged;
  }

  static bool _hydratingSession = false;

  static Future<void> _hydrateSessionFromStorage() async {
    if (_hydratingSession) return;
    _hydratingSession = true;
    try {
      final session = currentSession;
      if (session == null) {
        await _retainLocalProfileIfPresent(
          reason: 'Supabase session absent during hydration',
        );
        return;
      }

      final user = session.user;
      final metaName = user.userMetadata?['full_name']?.toString().trim();

      final stored = await ProfileStorageService.load();
      if (stored != null && isProfileStorageCorrupted(stored)) {
        await safeLocalSignOutIfAllowed(
          reason: 'corrupted circlekey_user_profile payload',
        );
        return;
      }

      var merged = <String, dynamic>{
        if (stored != null) ...stored,
        'supabase_user_id': user.id,
        'email': user.email ?? stored?['email'] ?? '',
        if (metaName != null && metaName.isNotEmpty) 'full_name': metaName,
      };

      merged =
          await ProfileOnboardingRepository.ensureLegacyHostTrackPersisted(merged);

      final needsOnboarding = ViewerProfile.sessionNeedsOnboarding(merged);
      debugPrint(
        '[Auth] Hydrated profile for ${merged['email']}; '
        'needsOnboarding=$needsOnboarding',
      );

      AuthScreen.currentUserSession = merged;
      profileStateNotifier.commitPersisted(merged);
      unawaited(marketplaceContextNotifier.refresh());
      await ProfileStorageService.save(merged);
    } finally {
      _hydratingSession = false;
    }
  }

  /// Label for header / avatar when [full_name] is missing.
  static String displayName([Map<String, dynamic>? session]) {
    final data = session ?? AuthScreen.currentUserSession;
    final name = data?['full_name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;

    final email = data?['email']?.toString().trim();
    if (email != null && email.isNotEmpty) {
      final at = email.indexOf('@');
      if (at > 0) return email.substring(0, at);
    }

    final user = currentUser;
    final meta = user?.userMetadata?['full_name']?.toString().trim();
    if (meta != null && meta.isNotEmpty) return meta;

    return 'User';
  }

  static String friendlyError(Object error) {
    if (error is AuthException) {
      return _messageForAuthFailure(error.message, statusCode: error.statusCode);
    }

    final text = error.toString();
    if (error is TimeoutException) {
      return 'Sign in timed out. Check your connection and try again.';
    }

    if (_looksLikeConnectivityFailure(text)) {
      return _connectivityMessage;
    }

    return 'Something went wrong. Please try again.';
  }

  static const _connectivityMessage =
      'Could not reach sign-in service. On Windows, use env.dev.json '
      '(copy env.dev.json.example) and run scripts/run_dublin.ps1 so your '
      'anon key is not broken by PowerShell. Also check Supabase â†’ Project '
      'Settings â†’ API for URL + anon key, and Email under Authentication.';

  static String _messageForAuthFailure(
    String message, {
    String? statusCode,
  }) {
    final lower = message.toLowerCase();
    final code = statusCode?.trim();

    if (code == '404' ||
        lower.contains('404') ||
        lower.contains('empty response') ||
        lower.contains('not found')) {
      return _connectivityMessage;
    }

    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }

    if (lower.contains('user already registered') ||
        lower.contains('already been registered')) {
      return 'An account with this email already exists. Sign in instead.';
    }

    if (lower.contains('password') && lower.contains('least')) {
      return 'Password must be at least 6 characters.';
    }

    if (lower.contains('invalid email') || lower.contains('valid email')) {
      return 'Enter a valid email address.';
    }

    if (lower.contains('email not confirmed')) {
      return 'Confirm your email first, then sign in.';
    }

    if (_looksLikeConnectivityFailure(message)) {
      return _connectivityMessage;
    }

    if (lower.contains('status code')) {
      return 'Incorrect email or password, or no account exists for this email yet.';
    }

    return message;
  }

  static bool _looksLikeConnectivityFailure(String text) {
    final lower = text.toLowerCase();
    return lower.contains('404') ||
        lower.contains('empty response') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('socketexception');
  }
}

/// Notifies GoRouter and UI when Supabase auth state changes.
final authSessionNotifier = AuthSessionNotifier();

final class AuthSessionNotifier extends ChangeNotifier {
  AuthSessionNotifier() {
    AuthService.client.auth.onAuthStateChange.listen((data) {
      debugPrint(
        '[Auth] onAuthStateChange: ${data.event.name} '
        'hasSession=${data.session != null}',
      );
      unawaited(_onAuthStateChanged(data.event));
    });
  }

  bool _handlingAuthChange = false;

  Future<void> _onAuthStateChanged(AuthChangeEvent event) async {
    if (_handlingAuthChange) return;
    _handlingAuthChange = true;
    try {
      if (event == AuthChangeEvent.signedOut &&
          AuthService.currentSession == null) {
        debugPrint(
          '[Auth] Auth state signedOut with no active token — '
          'hydrating without destructive local sign-out',
        );
      }
      await AuthService.bootstrap();
      refresh();
    } finally {
      _handlingAuthChange = false;
    }
  }

  bool get isAuthenticated => AuthService.isAuthenticated;

  void refresh() => notifyListeners();
}

