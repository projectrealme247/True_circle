import '../data/dublin_mock_data.dart';
import '../models/profile_onboarding_models.dart';
import '../screens/auth_screen.dart';
import '../utils/profile_data.dart';
import 'listings_storage_service.dart';
import 'marketplace_context_notifier.dart';
import 'profile_state_notifier.dart';
import 'profile_storage_service.dart';

/// Explore (marketplace) vs Hosting (landlord dashboard) active shell.
enum ActiveMode {
  explore('explore'),
  hosting('hosting');

  const ActiveMode(this.storageToken);

  final String storageToken;

  static ActiveMode? fromStorageToken(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'explore' || 'seeker' => ActiveMode.explore,
      'hosting' || 'host' || 'landlord' => ActiveMode.hosting,
      _ => null,
    };
  }
}

/// What the signed-in user can do — not which mode is active.
class Capabilities {
  const Capabilities({
    required this.canSeek,
    required this.canHost,
    required this.ownedListingCount,
  });

  final bool canSeek;
  final bool canHost;
  final int ownedListingCount;

  bool get isDualCapable => canSeek && canHost;

  Capabilities withOwnedListingCount(int count) => Capabilities(
        canSeek: canSeek,
        canHost: canHost || count > 0,
        ownedListingCount: count,
      );
}

/// Cross-mode unread signals for the mode switch control.
class UnreadActivity {
  const UnreadActivity({
    this.hostBadgeCount = 0,
    this.seekerBadgeCount = 0,
  });

  final int hostBadgeCount;
  final int seekerBadgeCount;
}

/// Post-auth / cold-start landing decision.
enum LandingAction {
  navigate,
  showStaleModePrompt,
}

class LandingResolution {
  const LandingResolution._({
    required this.action,
    this.route,
  });

  final LandingAction action;
  final String? route;

  factory LandingResolution.navigate(String route) =>
      LandingResolution._(action: LandingAction.navigate, route: route);

  factory LandingResolution.stalePrompt() =>
      const LandingResolution._(action: LandingAction.showStaleModePrompt);
}

/// Single source of truth for active mode, capabilities, and landing routes.
///
/// **Option chosen:** new file (not in-place refactor of [ViewPreferenceService])
/// so legacy override keys can delegate here without mixing semantics.
abstract final class ActiveModeService {
  static const lastActiveModeKey = 'last_active_mode';
  static const lastModeUpdatedAtKey = 'last_mode_updated_at';
  static const legacyOverrideKey = 'view_preference_override';
  static const hostSignalsKey = 'host_profile_complete';
  static const onboardingIntentKey = 'onboarding_intent';
  static const onboardingTrackKey = 'profile_onboarding_track';
  static const hostingBaselineAppsKey = '_hosting_mode_app_baseline';
  static const exploreStrongMatchBaselineKey = '_explore_strong_match_baseline';

  static const staleModeThreshold = Duration(days: 90);

  static Map<String, dynamic>? get _session =>
      profileStateNotifier.session ?? AuthScreen.currentUserSession;

  static ActiveMode get current {
    final session = _session;
    final explicit = ActiveMode.fromStorageToken(
      session?[lastActiveModeKey]?.toString(),
    );
    if (explicit != null) return explicit;
    final legacy = _legacyModeFromOverride(session);
    if (legacy != null) return legacy;
    return ActiveMode.explore;
  }

  static String? get lastActiveMode =>
      _session?[lastActiveModeKey]?.toString();

  static DateTime? get lastModeUpdatedAt {
    final raw = _session?[lastModeUpdatedAtKey]?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static Capabilities capabilitiesFor(Map<String, dynamic>? session) {
    final owned = _ownedListingCountSync(session);
    return Capabilities(
      canSeek: _canSeek(session),
      canHost: _canHost(session, ownedListingCount: owned),
      ownedListingCount: owned,
    );
  }

  static Capabilities get capabilities => capabilitiesFor(_session);

  static UnreadActivity unreadActivityFor({
    required Map<String, dynamic>? session,
    required ActiveMode activeMode,
    required int hostApplicantCount,
    required int seekerStrongMatchCount,
  }) {
    final caps = capabilitiesFor(session);
    var hostBadge = 0;
    var seekerBadge = 0;

    if (caps.canHost && activeMode == ActiveMode.explore) {
      final baseline = _readInt(session, hostingBaselineAppsKey);
      hostBadge = (hostApplicantCount - baseline).clamp(0, 99);
      if (hostBadge == 0 && hostApplicantCount > 0 && baseline == 0) {
        hostBadge = hostApplicantCount;
      }
    }

    if (caps.canSeek && activeMode == ActiveMode.hosting) {
      final baseline = _readInt(session, exploreStrongMatchBaselineKey);
      seekerBadge = (seekerStrongMatchCount - baseline).clamp(0, 99);
      if (seekerBadge == 0 && seekerStrongMatchCount > 0 && baseline == 0) {
        seekerBadge = seekerStrongMatchCount;
      }
    }

    return UnreadActivity(
      hostBadgeCount: hostBadge,
      seekerBadgeCount: seekerBadge,
    );
  }

  /// Resolves landing route using audit precedence (sync listing count variant).
  static LandingResolution resolveLandingRoute({
    Map<String, dynamic>? session,
    required int ownedListingCount,
  }) {
    final caps = capabilitiesFor(session).withOwnedListingCount(ownedListingCount);
    final mode = _modeForSession(session);

    if (caps.canHost && caps.ownedListingCount == 0) {
      return LandingResolution.navigate('/add-listing');
    }

    if (_shouldShowStaleModePrompt(session, caps)) {
      return LandingResolution.stalePrompt();
    }

    if (mode == ActiveMode.hosting &&
        caps.ownedListingCount > 0 &&
        caps.canHost) {
      return LandingResolution.navigate('/landlord-dashboard');
    }

    return LandingResolution.navigate('/');
  }

  static ActiveMode _modeForSession(Map<String, dynamic>? session) {
    return ActiveMode.fromStorageToken(
          session?[lastActiveModeKey]?.toString(),
        ) ??
        _legacyModeFromOverride(session) ??
        ActiveMode.explore;
  }

  static Future<LandingResolution> resolveLandingRouteAsync({
    Map<String, dynamic>? session,
  }) async {
    final owned = await _ownedListingCountAsync(session);
    return resolveLandingRoute(session: session, ownedListingCount: owned);
  }

  static bool _shouldShowStaleModePrompt(
    Map<String, dynamic>? session,
    Capabilities caps,
  ) {
    if (!caps.isDualCapable) return false;
    final updatedAt = lastModeUpdatedAtFor(session);
    if (updatedAt == null) return false;
    return DateTime.now().difference(updatedAt) > staleModeThreshold;
  }

  static DateTime? lastModeUpdatedAtFor(Map<String, dynamic>? session) {
    final raw = session?[lastModeUpdatedAtKey]?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// ONLY entry point for persisting active mode + timestamp.
  static Future<void> setMode(ActiveMode mode) async {
    final session = Map<String, dynamic>.from(_session ?? {});
    final previous = current;

    session[lastActiveModeKey] = mode.storageToken;
    session[lastModeUpdatedAtKey] = DateTime.now().toUtc().toIso8601String();

    if (previous != mode) {
      if (mode == ActiveMode.hosting) {
        session[hostingBaselineAppsKey] =
            session['_pending_host_applicant_baseline'] ?? 0;
      } else {
        session[exploreStrongMatchBaselineKey] =
            session['_pending_seeker_strong_match_baseline'] ?? 0;
      }
    }

    await _persistSession(session);
  }

  static Future<void> recordUnreadBaselines({
    required int hostApplicantCount,
    required int seekerStrongMatchCount,
  }) async {
    final session = Map<String, dynamic>.from(_session ?? {});
    session['_pending_host_applicant_baseline'] = hostApplicantCount;
    session['_pending_seeker_strong_match_baseline'] = seekerStrongMatchCount;
    await _persistSession(session);
  }

  static Future<void> _persistSession(Map<String, dynamic> session) async {
    AuthScreen.currentUserSession = session;
    profileStateNotifier.commitPersisted(session);
    profileStateNotifier.broadcast();
    await ProfileStorageService.save(session);
  }

  static Future<int> _ownedListingCountAsync(
    Map<String, dynamic>? session,
  ) async {
    var listings = await ListingsStorageService.ownedByCurrentUser(session);
    if (listings.isEmpty && _useMockHostListings(session)) {
      listings = DublinMockData.ownedListingsForHost();
    }
    return listings.length;
  }

  static int _ownedListingCountSync(Map<String, dynamic>? session) {
    final fromNotifier = marketplaceContextNotifier.ownedListingCount;
    if (fromNotifier > 0) return fromNotifier;
    if (_useMockHostListings(session)) {
      return DublinMockData.ownedListingsForHost().length;
    }
    return 0;
  }

  static Future<int> ownedListingCountFor(Map<String, dynamic>? session) =>
      _ownedListingCountAsync(session);

  static bool _canHost(
    Map<String, dynamic>? session, {
    required int ownedListingCount,
  }) {
    if (session == null || session.isEmpty) return false;
    if (session[hostSignalsKey] == true) return true;
    if (_isHostIntent(session[onboardingIntentKey]?.toString())) return true;
    if (_trackFromSession(session)?.isLandlord ?? false) return true;
    if (ownedListingCount > 0) return true;
    if (session['role']?.toString() == 'host' && session['demo_mode'] == true) {
      return true;
    }
    return false;
  }

  static bool _canSeek(Map<String, dynamic>? session) {
    if (session == null || session.isEmpty) return false;
    final intent = session[onboardingIntentKey]?.toString().trim().toLowerCase();
    if (intent == 'seeker') return true;
    if (_trackFromSession(session)?.isSeeker ?? false) return true;
    if (ProfileData.isMatchingReady(session)) return true;
    if (ProfileData.text(session['budget_max']).isNotEmpty) return true;
    if (ProfileData.text(session['detected_city']).isNotEmpty &&
        intent != 'provider') {
      return true;
    }
    if (session['role']?.toString() == 'seeker' && session['demo_mode'] == true) {
      return true;
    }
    return false;
  }

  static bool _isHostIntent(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'provider' || 'landlord' || 'host' => true,
      _ => false,
    };
  }

  static ProfileOnboardingTrack? _trackFromSession(Map<String, dynamic>? session) {
    if (session == null) return null;
    final token = ProfileData.text(session[onboardingTrackKey]);
    if (token.isEmpty) return null;
    return ProfileOnboardingTrack.fromToken(token);
  }

  static ActiveMode? _legacyModeFromOverride(Map<String, dynamic>? session) {
    final token = session?[legacyOverrideKey]?.toString();
    return switch (token?.trim().toLowerCase()) {
      'landlord' || 'host' => ActiveMode.hosting,
      'seeker' => ActiveMode.explore,
      _ => null,
    };
  }

  static bool _useMockHostListings(Map<String, dynamic>? session) {
    if (!DublinMockData.useMockHarness) return false;
    return _canHost(session, ownedListingCount: 0);
  }

  static int _readInt(Map<String, dynamic>? session, String key) {
    final raw = session?[key];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }
}
