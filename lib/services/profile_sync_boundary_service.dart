import '../screens/auth_screen.dart';
import 'profile_onboarding_repository.dart';
import 'profile_state_notifier.dart';
import 'profile_storage_service.dart';

abstract final class ProfileSyncBoundaryService {
  static Future<Map<String, dynamic>?> syncFromListingPublish({
    required Map<String, dynamic>? currentProfile,
    required Map<String, dynamic> listingPayload,
  }) async {
    if (currentProfile == null) return null;

    final snapshot = ProfileOnboardingRepository.snapshotFromSession(
      currentProfile,
    );

    final updatedHostRules = <String>[
      if (listingPayload['smoking_allowed'] == true)
        'Smoking allowed'
      else
        'No smoking',
      if (listingPayload['pets_allowed'] == true)
        'Pets welcome'
      else
        'No pets',
      if (listingPayload['wfh_friendly'] == true) 'WFH friendly',
      if ((listingPayload['lifestyle_flags'] as List?)
              ?.contains('vegetarian_household') ==
          true)
        'Veg kitchen',
    ];

    final nextSnapshot = ProfileOnboardingRepository.snapshotFromSession({
      ...currentProfile,
      'hostProfile_languages':
          listingPayload['languages_spoken'] ?? snapshot.hostProfile.languages,
      'is_owner_occupier':
          listingPayload['is_owner_occupier'] ?? snapshot.hostProfile.isOwnerOccupier,
      'listingSeed_propertyNeighborhood':
          listingPayload['location'] ?? snapshot.listingSeed.propertyNeighborhood,
      'listingSeed_propertyEircode':
          listingPayload['eircode'] ?? snapshot.listingSeed.propertyEircode,
      'listingSeed_isFurnished':
          _isFurnished(listingPayload['furnishing']) ??
              snapshot.listingSeed.isFurnished,
      'smoking_allowed': listingPayload['smoking_allowed'],
      'pets_allowed': listingPayload['pets_allowed'],
      'wfh_status': listingPayload['wfh_friendly'],
      'food_preference': updatedHostRules.contains('Veg kitchen')
          ? 'Pure Veg'
          : currentProfile['food_preference'],
      'spoken_languages':
          listingPayload['languages_spoken'] ?? currentProfile['spoken_languages'],
      'family_adults':
          _readHouseholdInt(listingPayload, 'family_adults', 'current_occupants'),
      'group_size':
          _readHouseholdInt(listingPayload, 'group_size', 'current_occupants'),
      'listing_host_rules': updatedHostRules,
    });

    final updated = ProfileOnboardingRepository.applySnapshotToSession(
      Map<String, dynamic>.from(currentProfile),
      nextSnapshot,
    )..['hostProfile'] = {
        ...Map<String, dynamic>.from(currentProfile['hostProfile'] as Map? ?? {}),
        'languages': listingPayload['languages_spoken'] ?? snapshot.hostProfile.languages,
        'currentHouseholdMakeup': {
          ...snapshot.hostProfile.currentHouseholdMakeup,
          if (listingPayload['current_occupants'] != null)
            'current_occupants': listingPayload['current_occupants'],
        },
        'isOwnerOccupier':
            listingPayload['is_owner_occupier'] ?? snapshot.hostProfile.isOwnerOccupier,
        'houseRules': updatedHostRules,
      };

    AuthScreen.currentUserSession = updated;
    profileStateNotifier.commitPersisted(updated);
    await ProfileStorageService.save(updated);
    return updated;
  }

  static bool? _isFurnished(dynamic raw) {
    final text = raw?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty) return null;
    if (text.contains('unfurnished')) return false;
    if (text.contains('furnished')) return true;
    return null;
  }

  static int? _readHouseholdInt(
    Map<String, dynamic> payload,
    String primary,
    String fallback,
  ) {
    final primaryValue = payload[primary];
    if (primaryValue is int) return primaryValue;
    final fallbackValue = payload[fallback];
    if (fallbackValue is int) return fallbackValue;
    return null;
  }
}
