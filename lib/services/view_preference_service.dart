import '../screens/auth_screen.dart';
import 'profile_state_notifier.dart';
import 'profile_storage_service.dart';

/// Polymorphic dashboard context: seeking vs hosting.
enum DashboardViewMode {
  seeker,
  host;

  String get storageToken => switch (this) {
        DashboardViewMode.seeker => 'seeker',
        DashboardViewMode.host => 'landlord',
      };

  static DashboardViewMode? fromOverrideToken(String? raw) {
    final token = raw?.trim().toLowerCase() ?? '';
    return switch (token) {
      'seeker' => DashboardViewMode.seeker,
      'landlord' || 'host' => DashboardViewMode.host,
      _ => null,
    };
  }
}

/// Resolves and persists `view_preference_override` on the user session.
abstract final class ViewPreferenceService {
  static const _sessionKey = 'view_preference_override';

  static DashboardViewMode resolve({
    required Map<String, dynamic>? session,
    required int ownedListingCount,
  }) {
    final override = DashboardViewMode.fromOverrideToken(
      session?[_sessionKey]?.toString(),
    );
    if (override != null) return override;
    return ownedListingCount > 0
        ? DashboardViewMode.host
        : DashboardViewMode.seeker;
  }

  static bool isHostContext({
    required Map<String, dynamic>? session,
    required int ownedListingCount,
  }) =>
      resolve(session: session, ownedListingCount: ownedListingCount) ==
      DashboardViewMode.host;

  static bool isMultiListingHost(int ownedListingCount) =>
      ownedListingCount > 1;

  static Future<void> setOverride(DashboardViewMode mode) async {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;

    session[_sessionKey] = mode.storageToken;
    AuthScreen.currentUserSession = session;
    profileStateNotifier.commitPersisted(session);
    profileStateNotifier.broadcast();
    await ProfileStorageService.save(session);
  }

  static String toggleLabel({
    required DashboardViewMode current,
  }) =>
      current == DashboardViewMode.seeker
          ? 'Switch to Hosting'
          : 'Switch to Searching';
}
