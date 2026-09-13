class IdentityProfile {
  const IdentityProfile({
    this.email = '',
    this.fullName = '',
    this.companyName = '',
    this.contactPhone = '',
    this.contactPhoneE164 = '',
    this.prefersWhatsapp = false,
    this.motherTongue = '',
    this.languages = const [],
  });

  final String email;
  final String fullName;
  final String companyName;
  final String contactPhone;
  final String contactPhoneE164;
  final bool prefersWhatsapp;
  final String motherTongue;
  final List<String> languages;
}

class SeekerProfile {
  const SeekerProfile({
    this.maxBudget,
    this.roomBudget,
    this.moveInWindow = '',
    this.preferredLeaseMonths,
    this.occupantGroupFit = '',
    this.genderPreferences = '',
    this.foodPreference = '',
    this.wfhStatus = false,
    this.environmentPreferences = const [],
    this.primaryCommute = const {},
    this.secondaryCommute = const {},
  });

  final int? maxBudget;
  final int? roomBudget;
  final String moveInWindow;
  final int? preferredLeaseMonths;
  final String occupantGroupFit;
  final String genderPreferences;
  final String foodPreference;
  final bool wfhStatus;
  final List<String> environmentPreferences;
  final Map<String, dynamic> primaryCommute;
  final Map<String, dynamic> secondaryCommute;
}

class HostProfile {
  const HostProfile({
    this.languages = const [],
    this.currentHouseholdMakeup = const {},
    this.isOwnerOccupier = false,
    this.houseRules = const [],
  });

  final List<String> languages;
  final Map<String, dynamic> currentHouseholdMakeup;
  final bool isOwnerOccupier;
  final List<String> houseRules;
}

class ListingSeed {
  const ListingSeed({
    this.propertyNeighborhood = '',
    this.propertyEircode = '',
    this.isFurnished = false,
    this.listingMode = '',
    this.currentHouseholdMakeup = const {},
    this.houseRules = const [],
  });

  final String propertyNeighborhood;
  final String propertyEircode;
  final bool isFurnished;
  final String listingMode;
  final Map<String, dynamic> currentHouseholdMakeup;
  final List<String> houseRules;
}

enum ProfileOnboardingTrack {
  seekerEntirePlace('seeker_entire_place'),
  seekerSharedSpace('seeker_shared_space'),
  landlordEntirePlace('landlord_entire_place'),
  landlordSharedSpace('landlord_shared_space');

  const ProfileOnboardingTrack(this.storageToken);

  final String storageToken;

  bool get isSeeker =>
      this == ProfileOnboardingTrack.seekerEntirePlace ||
      this == ProfileOnboardingTrack.seekerSharedSpace;

  bool get isLandlord => !isSeeker;

  bool get isEntirePlace =>
      this == ProfileOnboardingTrack.seekerEntirePlace ||
      this == ProfileOnboardingTrack.landlordEntirePlace;

  bool get isSharedSpace => !isEntirePlace;

  static ProfileOnboardingTrack fromToken(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final track in ProfileOnboardingTrack.values) {
      if (track.storageToken == normalized) return track;
    }
    return ProfileOnboardingTrack.seekerEntirePlace;
  }
}

class ProfileInheritanceSnapshot {
  const ProfileInheritanceSnapshot({
    required this.track,
    required this.identityProfile,
    required this.seekerProfile,
    required this.hostProfile,
    required this.listingSeed,
  });

  final ProfileOnboardingTrack track;
  final IdentityProfile identityProfile;
  final SeekerProfile seekerProfile;
  final HostProfile hostProfile;
  final ListingSeed listingSeed;
}

class ListingCreationPrefill {
  const ListingCreationPrefill({
    required this.location,
    required this.eircode,
    required this.isFurnished,
    required this.listingMode,
    required this.householdLanguages,
    required this.houseRules,
    required this.currentHouseholdMakeup,
    required this.isOwnerOccupier,
  });

  final String location;
  final String eircode;
  final bool isFurnished;
  final String listingMode;
  final List<String> householdLanguages;
  final List<String> houseRules;
  final Map<String, dynamic> currentHouseholdMakeup;
  final bool isOwnerOccupier;

  Map<String, dynamic> toDraftMap() => {
        'location': location,
        // Eircode is entered on the listing step — never inherited from profile.
        'prefill_is_furnished': isFurnished,
        'prefill_listing_mode': listingMode,
        'type': listingMode == 'shared_space' ? 'Share' : 'Rent',
        'prefill_household_languages': householdLanguages,
        'prefill_house_rules': houseRules,
        'prefill_household_makeup': currentHouseholdMakeup,
        'prefill_is_owner_occupier': isOwnerOccupier,
      };
}

class InheritedFieldState<T> {
  const InheritedFieldState({
    required this.inheritedValue,
    required this.currentValue,
    required this.isOverridden,
    required this.isSatisfied,
  });

  final T? inheritedValue;
  final T? currentValue;
  final bool isOverridden;
  final bool isSatisfied;
}
