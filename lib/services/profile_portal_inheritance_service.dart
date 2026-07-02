import '../models/profile_onboarding_models.dart';
import '../utils/listing_search_intent.dart';

abstract final class ProfilePortalInheritanceService {
  static ListingSearchFilters seekerFeedDefaults(
    ProfileInheritanceSnapshot snapshot,
  ) {
    if (!snapshot.track.isSeeker) return const ListingSearchFilters();

    final seeker = snapshot.seekerProfile;
    return ListingSearchFilters(
      budgetMax: snapshot.track == ProfileOnboardingTrack.seekerSharedSpace
          ? seeker.roomBudget
          : seeker.maxBudget,
      occupantType: snapshot.track == ProfileOnboardingTrack.seekerSharedSpace
          ? seeker.occupantGroupFit
          : null,
      genderPreference: snapshot.track == ProfileOnboardingTrack.seekerSharedSpace
          ? _normalizeGender(seeker.genderPreferences)
          : null,
      preferredLeaseMonths: seeker.preferredLeaseMonths,
      moveInWindow: seeker.moveInWindow.isEmpty ? null : seeker.moveInWindow,
      wfhFriendly: seeker.wfhStatus ? true : null,
      foodPreference: _normalizeFood(seeker.foodPreference),
    );
  }

  static ListingCreationPrefill listingPrefill(
    ProfileInheritanceSnapshot snapshot,
  ) {
    return ListingCreationPrefill(
      location: snapshot.listingSeed.propertyNeighborhood,
      eircode: snapshot.listingSeed.propertyEircode,
      isFurnished: snapshot.listingSeed.isFurnished,
      listingMode: snapshot.listingSeed.listingMode,
      householdLanguages: snapshot.hostProfile.languages,
      houseRules: snapshot.hostProfile.houseRules,
      currentHouseholdMakeup: snapshot.hostProfile.currentHouseholdMakeup,
      isOwnerOccupier: snapshot.hostProfile.isOwnerOccupier,
    );
  }

  static String? _normalizeGender(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.contains('girl')) return 'girls';
    if (normalized.contains('boy')) return 'boys';
    return null;
  }

  static String? _normalizeFood(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized.contains('veg') && !normalized.contains('non')) return 'veg';
    if (normalized.contains('non')) return 'non-veg';
    return null;
  }
}
