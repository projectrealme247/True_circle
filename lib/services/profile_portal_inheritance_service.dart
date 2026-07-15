import '../models/profile_onboarding_models.dart';
import '../models/seeker_onboarding_enums.dart';
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
          ? _canonicalOccupantFilter(snapshot.seekerProfile.occupantGroupFit)
          : null,
      genderPreference: snapshot.track == ProfileOnboardingTrack.seekerSharedSpace
          ? _normalizeGender(seeker.genderPreferences)
          : null,
      preferredLeaseMonths: seeker.preferredLeaseMonths,
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

  static String? _canonicalOccupantFilter(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final persona = SeekerPersona.fromSession({'occupant_type': trimmed});
    return persona?.occupantType ?? trimmed;
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
