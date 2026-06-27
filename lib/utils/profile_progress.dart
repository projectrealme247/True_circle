import '../services/profile_state_notifier.dart';
import 'profile_data.dart';

/// Single source of truth for profile completion % across home + profile surfaces.
abstract final class ProfileProgress {
  static int percent(
    Map<String, dynamic>? session, {
    required int ownedListingCount,
  }) =>
      ProfileData.calculateProfileCompletionPercentage(
        session ?? profileStateNotifier.session,
      );

  static List<String> missingFields(
    Map<String, dynamic>? session, {
    required int ownedListingCount,
  }) =>
      ProfileData.missingFieldsForCompletion(
        session ?? profileStateNotifier.session,
      );
}
