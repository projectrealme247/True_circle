import '../screens/auth_screen.dart';
import 'active_mode_service.dart';
import 'profile_state_notifier.dart';
import 'profile_storage_service.dart';

/// Polymorphic dashboard context: seeking vs hosting (legacy enum).
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

/// Legacy compatibility — prefer [ActiveModeService] for all new code.
abstract final class ViewPreferenceService {
  static DashboardViewMode resolve({
    required Map<String, dynamic>? session,
    required int ownedListingCount,
  }) {
    final caps = ActiveModeService.capabilitiesFor(session)
        .withOwnedListingCount(ownedListingCount);
    if (ActiveModeService.current == ActiveMode.hosting && caps.canHost) {
      return DashboardViewMode.host;
    }
    return DashboardViewMode.seeker;
  }

  static bool isHostContext({
    required Map<String, dynamic>? session,
    required int ownedListingCount,
  }) =>
      ActiveModeService.capabilitiesFor(session)
          .withOwnedListingCount(ownedListingCount)
          .canHost;

  static bool isMultiListingHost(int ownedListingCount) =>
      ownedListingCount > 1;

  @Deprecated('Use ActiveModeService.setMode — never call from onboarding')
  static Future<void> setOverride(DashboardViewMode mode) async {
    await ActiveModeService.setMode(
      mode == DashboardViewMode.host
          ? ActiveMode.hosting
          : ActiveMode.explore,
    );
  }

  static String toggleLabel({required DashboardViewMode current}) =>
      current == DashboardViewMode.seeker
          ? 'Switch to Hosting'
          : 'Switch to Searching';
}
