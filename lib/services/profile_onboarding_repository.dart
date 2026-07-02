import '../models/profile_onboarding_models.dart';
import '../utils/profile_data.dart';

abstract final class ProfileOnboardingRepository {
  static ProfileInheritanceSnapshot snapshotFromSession(
    Map<String, dynamic>? session,
  ) {
    final raw = session ?? const <String, dynamic>{};
    final identity = IdentityProfile(
      email: ProfileData.text(raw['email']),
      fullName: ProfileData.text(raw['full_name']),
      companyName: ProfileData.text(
        raw['company_name'] ?? raw['agency_name'] ?? raw['company'],
      ),
      contactPhone: ProfileData.text(raw['contact_phone'] ?? raw['phone']),
      contactPhoneE164: ProfileData.text(raw['contact_phone_e164']),
      prefersWhatsapp: raw['prefers_whatsapp'] == true,
      motherTongue: ProfileData.text(raw['mother_tongue']),
      nativePlace: ProfileData.text(raw['native_place']),
      languages: ProfileData.languageList(raw['spoken_languages']),
    );

    final track = _hydrateTrack(raw);
    final commuteProfiles = raw['commute_profiles'];
    final profiles = commuteProfiles is List
        ? List<Map<String, dynamic>>.from(
            commuteProfiles.whereType<Map>().map(Map<String, dynamic>.from),
          )
        : const <Map<String, dynamic>>[];

    final houseRules = _houseRulesFromSession(raw);
    final currentHouseholdMakeup = <String, dynamic>{
      'occupant_type': ProfileData.text(raw['occupant_type']),
      'group_size': raw['group_size'],
      'family_adults': raw['family_adults'],
      'family_children': raw['family_children'],
      'children_ages': raw['children_ages'],
    }..removeWhere((key, value) {
        if (value == null) return true;
        if (value is String) return value.trim().isEmpty;
        if (value is List) return value.isEmpty;
        return false;
      });

    final seeker = SeekerProfile(
      maxBudget: _parseInt(raw['budget_max']),
      roomBudget: _parseInt(raw['budget_max']),
      moveInWindow: ProfileData.text(raw['earliest_move_in_date']),
      preferredLeaseMonths: _parseInt(raw['preferred_lease_months']),
      occupantGroupFit: ProfileData.text(raw['occupant_type']),
      genderPreferences: ProfileData.text(raw['gender_preference']),
      foodPreference: ProfileData.text(raw['food_preference']),
      wfhStatus: ProfileData.text(raw['schedule_type']).toLowerCase() ==
              'flexible' ||
          raw['wfh_status'] == true,
      environmentPreferences: [
        if (raw['household_has_pets'] == true) 'Pets in household',
        if (raw['household_smoker'] == true) 'Smoker in household',
      ],
      primaryCommute: profiles.isNotEmpty ? profiles.first : const {},
      secondaryCommute: profiles.length > 1 ? profiles[1] : const {},
    );

    final host = HostProfile(
      languages: ProfileData.languageList(raw['hostProfile_languages']).isNotEmpty
          ? ProfileData.languageList(raw['hostProfile_languages'])
          : identity.languages,
      currentHouseholdMakeup: currentHouseholdMakeup,
      isOwnerOccupier: raw['is_owner_occupier'] == true,
      houseRules: houseRules,
    );

    final listingSeed = ListingSeed(
      propertyNeighborhood: ProfileData.text(
        raw['listingSeed_propertyNeighborhood'] ??
            raw['pending_listing_location'],
      ),
      propertyEircode: ProfileData.text(
        raw['listingSeed_propertyEircode'] ?? raw['pending_listing_eircode'],
      ),
      isFurnished: raw['listingSeed_isFurnished'] == true,
      listingMode: track.isSharedSpace ? 'shared_space' : 'entire_place',
      currentHouseholdMakeup: currentHouseholdMakeup,
      houseRules: houseRules,
    );

    return ProfileInheritanceSnapshot(
      track: track,
      identityProfile: identity,
      seekerProfile: seeker,
      hostProfile: host,
      listingSeed: listingSeed,
    );
  }

  static Map<String, dynamic> applySnapshotToSession(
    Map<String, dynamic> baseline,
    ProfileInheritanceSnapshot snapshot,
  ) {
    return {
      ...baseline,
      'profile_onboarding_track': snapshot.track.storageToken,
      'identityProfile': {
        'email': snapshot.identityProfile.email,
        'fullName': snapshot.identityProfile.fullName,
        'companyName': snapshot.identityProfile.companyName,
        'contactPhone': snapshot.identityProfile.contactPhone,
        'contactPhoneE164': snapshot.identityProfile.contactPhoneE164,
        'prefersWhatsapp': snapshot.identityProfile.prefersWhatsapp,
        'motherTongue': snapshot.identityProfile.motherTongue,
        'nativePlace': snapshot.identityProfile.nativePlace,
        'languages': snapshot.identityProfile.languages,
      },
      'seekerProfile': {
        'maxBudget': snapshot.seekerProfile.maxBudget,
        'roomBudget': snapshot.seekerProfile.roomBudget,
        'moveInWindow': snapshot.seekerProfile.moveInWindow,
        'preferredLeaseMonths': snapshot.seekerProfile.preferredLeaseMonths,
        'occupantGroupFit': snapshot.seekerProfile.occupantGroupFit,
        'genderPreferences': snapshot.seekerProfile.genderPreferences,
        'wfhStatus': snapshot.seekerProfile.wfhStatus,
        'environmentPreferences': snapshot.seekerProfile.environmentPreferences,
        'primaryCommute': snapshot.seekerProfile.primaryCommute,
        'secondaryCommute': snapshot.seekerProfile.secondaryCommute,
      },
      'hostProfile': {
        'languages': snapshot.hostProfile.languages,
        'currentHouseholdMakeup': snapshot.hostProfile.currentHouseholdMakeup,
        'isOwnerOccupier': snapshot.hostProfile.isOwnerOccupier,
        'houseRules': snapshot.hostProfile.houseRules,
      },
      'listingSeed': {
        'propertyNeighborhood': snapshot.listingSeed.propertyNeighborhood,
        'propertyEircode': snapshot.listingSeed.propertyEircode,
        'isFurnished': snapshot.listingSeed.isFurnished,
        'listingMode': snapshot.listingSeed.listingMode,
        'currentHouseholdMakeup': snapshot.listingSeed.currentHouseholdMakeup,
        'houseRules': snapshot.listingSeed.houseRules,
      },
      'email': snapshot.identityProfile.email,
      'full_name': snapshot.identityProfile.fullName,
      'mother_tongue': snapshot.identityProfile.motherTongue,
      'native_place': snapshot.identityProfile.nativePlace,
      'spoken_languages': snapshot.identityProfile.languages,
      'agency_name': snapshot.identityProfile.companyName,
      'contact_phone': snapshot.identityProfile.contactPhone,
      'contact_phone_e164': snapshot.identityProfile.contactPhoneE164,
      'prefers_whatsapp': snapshot.identityProfile.prefersWhatsapp,
      'occupant_type': snapshot.seekerProfile.occupantGroupFit,
      'gender_preference': snapshot.seekerProfile.genderPreferences,
      'earliest_move_in_date': snapshot.seekerProfile.moveInWindow,
      'preferred_lease_months': snapshot.seekerProfile.preferredLeaseMonths,
      'budget_max': snapshot.track.isSharedSpace
          ? snapshot.seekerProfile.roomBudget
          : snapshot.seekerProfile.maxBudget,
      'wfh_status': snapshot.seekerProfile.wfhStatus,
      'hostProfile_languages': snapshot.hostProfile.languages,
      'is_owner_occupier': snapshot.hostProfile.isOwnerOccupier,
      'pending_listing_location': snapshot.listingSeed.propertyNeighborhood,
      'pending_listing_eircode': snapshot.listingSeed.propertyEircode,
      'listingSeed_propertyNeighborhood': snapshot.listingSeed.propertyNeighborhood,
      'listingSeed_propertyEircode': snapshot.listingSeed.propertyEircode,
      'listingSeed_isFurnished': snapshot.listingSeed.isFurnished,
    };
  }

  static ProfileOnboardingTrack _hydrateTrack(Map<String, dynamic> raw) {
    final explicit = ProfileData.text(raw['profile_onboarding_track']);
    if (explicit.isNotEmpty) {
      return ProfileOnboardingTrack.fromToken(explicit);
    }

    final intent = ProfileData.text(raw['onboarding_intent']).toLowerCase();
    final arrangement = ProfileData.text(raw['preferred_arrangement']).toLowerCase();
    final listingMode = ProfileData.text(raw['listingSeed_listingMode']).toLowerCase();
    final isShared = arrangement.contains('shared') ||
        arrangement.contains('room') ||
        listingMode.contains('shared');

    if (intent == 'provider' || intent == 'landlord' || intent == 'host') {
      return isShared
          ? ProfileOnboardingTrack.landlordSharedSpace
          : ProfileOnboardingTrack.landlordEntirePlace;
    }

    return isShared
        ? ProfileOnboardingTrack.seekerSharedSpace
        : ProfileOnboardingTrack.seekerEntirePlace;
  }

  static List<String> _houseRulesFromSession(Map<String, dynamic> raw) {
    final rules = <String>[];
    if (raw['smoking_ok'] == true || raw['smoking_allowed'] == true) {
      rules.add('Smoking allowed');
    } else {
      rules.add('No smoking');
    }
    if (raw['household_has_pets'] == true || raw['pets_allowed'] == true) {
      rules.add('Pets welcome');
    } else {
      rules.add('No pets');
    }
    if (raw['wfh_status'] == true ||
        ProfileData.text(raw['schedule_type']).toLowerCase() == 'flexible') {
      rules.add('WFH friendly');
    }
    if (ProfileData.text(raw['food_preference']).toLowerCase().contains('veg')) {
      rules.add('Veg kitchen');
    }
    return rules;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(ProfileData.text(value));
  }
}
