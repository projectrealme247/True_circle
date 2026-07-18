import '../models/marketplace_space.dart';
import '../models/move_in_timing.dart';
import '../models/profile_onboarding_models.dart';
import '../services/active_mode_service.dart';
import '../services/profile_storage_service.dart';
import '../utils/profile_data.dart';

abstract final class ProfileOnboardingRepository {
  /// Authoritative host listing track — shared by Host Profile UI and Listing Creation.
  ///
  /// Precedence: `profile_onboarding_track` → `active_marketplace_space` →
  /// `listingSeed_listingMode` → [ProfileOnboardingTrack.landlordEntirePlace].
  /// Does not use `preferred_arrangement` (seeker/tower residue).
  static ProfileOnboardingTrack resolveHostTrack(Map<String, dynamic> raw) {
    final explicit = ProfileData.text(raw['profile_onboarding_track']);
    if (explicit.isNotEmpty) {
      final track = ProfileOnboardingTrack.fromToken(explicit);
      if (track.isLandlord) return track;
    }

    final spaceToken = ProfileData.text(raw['active_marketplace_space']);
    if (spaceToken.isNotEmpty) {
      final space = MarketplaceSpace.fromStorageToken(spaceToken);
      return space == MarketplaceSpace.sharedSpace
          ? ProfileOnboardingTrack.landlordSharedSpace
          : ProfileOnboardingTrack.landlordEntirePlace;
    }

    final listingMode =
        ProfileData.text(raw['listingSeed_listingMode']).toLowerCase();
    if (listingMode.contains('shared')) {
      return ProfileOnboardingTrack.landlordSharedSpace;
    }
    if (listingMode.contains('entire')) {
      return ProfileOnboardingTrack.landlordEntirePlace;
    }

    return ProfileOnboardingTrack.landlordEntirePlace;
  }

  /// One-time backfill when [host_profile_complete] is set but track is missing.
  static Future<Map<String, dynamic>> ensureLegacyHostTrackPersisted(
    Map<String, dynamic> session,
  ) async {
    if (session['host_profile_complete'] != true) return session;
    if (ProfileData.text(session['profile_onboarding_track']).isNotEmpty) {
      return session;
    }
    final next = Map<String, dynamic>.from(session);
    next['profile_onboarding_track'] = resolveHostTrack(session).storageToken;
    await ProfileStorageService.save(next);
    return next;
  }

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
      moveInWindow: () {
        final direct = ProfileData.text(raw['move_in_window']);
        if (SeekerMoveInWindow.parse(direct) != null) return direct;
        return MoveInTimingMigration.fromLegacySession(raw)?.storageToken ?? '';
      }(),
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
      'spoken_languages': snapshot.identityProfile.languages,
      'agency_name': snapshot.identityProfile.companyName,
      'contact_phone': snapshot.identityProfile.contactPhone,
      'contact_phone_e164': snapshot.identityProfile.contactPhoneE164,
      'prefers_whatsapp': snapshot.identityProfile.prefersWhatsapp,
      'occupant_type': snapshot.seekerProfile.occupantGroupFit,
      'gender_preference': snapshot.seekerProfile.genderPreferences,
      if (snapshot.seekerProfile.moveInWindow.isNotEmpty)
        ...MoveInTimingMigration.seekerPayload(
          SeekerMoveInWindow.parse(snapshot.seekerProfile.moveInWindow) ??
              SeekerMoveInWindow.flexible,
        ),
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

    final caps = ActiveModeService.capabilitiesFor(raw);
    final intent = ProfileData.text(raw['onboarding_intent']).toLowerCase();

    if (caps.canHost && intent != 'seeker') {
      return resolveHostTrack(raw);
    }

    final arrangement =
        ProfileData.text(raw['preferred_arrangement']).toLowerCase();
    final listingMode =
        ProfileData.text(raw['listingSeed_listingMode']).toLowerCase();
    final isShared = arrangement.contains('shared') ||
        arrangement.contains('room') ||
        listingMode.contains('shared');

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
