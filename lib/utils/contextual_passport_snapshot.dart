import '../models/move_in_timing.dart';
import '../models/applicant_trust_tier.dart';
import '../models/profile_onboarding_models.dart';
import '../models/seeker_onboarding_enums.dart';
import '../services/active_mode_service.dart';
import '../services/trust_service.dart';
import 'profile_data.dart';

/// Normalized passport payload for the 4-track contextual profile view.
class ContextualPassportSnapshot {
  const ContextualPassportSnapshot({
    required this.track,
    required this.displayName,
    required this.trustTier,
    required this.personaEmoji,
    required this.personaLabel,
    this.budgetMax,
    this.listingBudgetRequirement,
    this.moveInTimeline = '',
    this.destinationHub = '',
    this.maxCommuteMinutes,
    this.compatibilityChips = const [],
    this.budgetTierLabel = '',
    this.householdBreakdown = '',
    this.verificationRows = const [],
    this.hostTrustMultiplier,
    this.houseRules = const [],
    this.homeLanguages = const [],
    this.flatmatePreferences = const [],
    this.idVerificationLabel = '',
    this.licensingLabel = '',
    this.responsivenessLabel = '',
    this.listingTypeLabel = '',
    this.languagesLabel = '',
    this.tenurePreferenceLabel = '',
    this.furnishingPreferenceLabel = '',
    this.propertyTypePreferenceLabel = '',
    this.bathroomPreferenceLabel = '',
    this.transportPreference = '',
    this.verificationProgressLabel = '',
    this.profileCompletionPercent = 0,
    this.profileCompletenessLevel = 'Just started',
    this.contactVerified = false,
  });

  final ProfileOnboardingTrack track;
  final String displayName;
  final ApplicantTrustTier trustTier;
  final String personaEmoji;
  final String personaLabel;

  // Track A — seeker shared
  final int? budgetMax;
  final int? listingBudgetRequirement;
  final String moveInTimeline;
  final String destinationHub;
  final int? maxCommuteMinutes;
  final List<ContextualPassportChip> compatibilityChips;

  // Track B — seeker full rental
  final String budgetTierLabel;
  final String householdBreakdown;
  final List<ContextualPassportVerificationRow> verificationRows;

  // Track C — landlord shared
  final double? hostTrustMultiplier;
  final List<String> houseRules;
  final List<String> homeLanguages;
  final List<String> flatmatePreferences;

  // Track D — landlord full rental
  final String idVerificationLabel;
  final String licensingLabel;
  final String responsivenessLabel;

  // Public passport (onboarding preview)
  final String listingTypeLabel;
  final String languagesLabel;
  final String tenurePreferenceLabel;
  final String furnishingPreferenceLabel;
  final String propertyTypePreferenceLabel;
  final String bathroomPreferenceLabel;
  final String transportPreference;
  final String verificationProgressLabel;
  final int profileCompletionPercent;
  final String profileCompletenessLevel;

  /// Contact-unlock badge — not derived from trust_tier / trust_stage.
  final bool contactVerified;

  bool get isVerifiedUser => contactVerified;

  String get trustBadgeEmoji => isVerifiedUser ? '✅' : '';

  String get trustBadgeLabel =>
      isVerifiedUser ? 'Verified User' : '';

  static ContextualPassportSnapshot fromSession(
    Map<String, dynamic> session, {
    int? listingBudgetRequirement,
  }) {
    final track = _resolveTrack(session);
    final trustTier = ApplicantTrustTier.fromSession(session);
    final contactVerified = TrustService.meetsContactVerification(session);
    final persona = _resolvePersona(session, track);
    final displayName = ProfileData.text(session['full_name']).trim();

    final verificationRows = _verificationRows(session);
    final completionPercent =
        ProfileData.calculateProfileCompletionPercentage(session);

    return ContextualPassportSnapshot(
      track: track,
      displayName: displayName,
      trustTier: trustTier,
      personaEmoji: persona.$1,
      personaLabel: persona.$2,
      budgetMax: _budgetMax(session, track),
      listingBudgetRequirement: listingBudgetRequirement,
      moveInTimeline: _moveInTimeline(session),
      destinationHub: _destinationHub(session),
      maxCommuteMinutes: _maxCommuteMinutes(session),
      compatibilityChips: _compatibilityChips(session),
      budgetTierLabel: _budgetTierLabel(session),
      householdBreakdown: _householdBreakdown(session),
      verificationRows: verificationRows,
      hostTrustMultiplier: null,
      houseRules: _houseRules(session),
      homeLanguages: _homeLanguages(session),
      flatmatePreferences: _flatmatePreferences(session),
      idVerificationLabel: _idVerificationLabel(session),
      licensingLabel: _licensingLabel(session),
      responsivenessLabel: _responsivenessLabel(session),
      listingTypeLabel: _listingTypeLabel(track),
      languagesLabel: _languagesLabel(session, track),
      tenurePreferenceLabel: _tenurePreferenceLabel(session, track),
      furnishingPreferenceLabel: _furnishingPreferenceLabel(session, track),
      propertyTypePreferenceLabel:
          _propertyTypePreferenceLabel(session, track),
      bathroomPreferenceLabel: _bathroomPreferenceLabel(session, track),
      transportPreference: _transportPreference(session),
      verificationProgressLabel:
          _verificationProgressLabel(verificationRows),
      profileCompletionPercent: completionPercent,
      profileCompletenessLevel: _profileCompletenessLevel(completionPercent),
      contactVerified: contactVerified,
    );
  }

  static String _listingTypeLabel(ProfileOnboardingTrack track) {
    if (track.isLandlord) {
      return track.isSharedSpace ? 'Shared Host' : 'Entire Place Host';
    }
    return track.isSharedSpace ? 'Shared Living' : 'Independent Place';
  }

  static String _languagesLabel(
    Map<String, dynamic> session,
    ProfileOnboardingTrack track,
  ) {
    // Language is a Shared Living matching signal only.
    if (!track.isLandlord && !track.isSharedSpace) return '';

    final langs = <String>[];
    void add(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      final exists = langs.any(
        (item) => item.toLowerCase() == trimmed.toLowerCase(),
      );
      if (!exists) langs.add(trimmed);
    }

    add('English');
    add(ProfileData.text(session['mother_tongue']));
    for (final language in ProfileData.languageList(session['spoken_languages'])) {
      add(language);
    }
    for (final language in ProfileData.languageList(
      session['preferred_spoken_languages'],
    )) {
      add(language);
    }
    return langs.join(', ');
  }

  static String _tenurePreferenceLabel(
    Map<String, dynamic> session,
    ProfileOnboardingTrack track,
  ) {
    if (track.isLandlord || track.isSharedSpace) return '';
    // IP seekers: legacy flexible displays as Long-Term via fromSession migration.
    return TenurePreference.fromSession(session)?.label ?? '';
  }

  static String _furnishingPreferenceLabel(
    Map<String, dynamic> session,
    ProfileOnboardingTrack track,
  ) {
    if (track.isLandlord || track.isSharedSpace) return '';
    return FurnishingPreference.fromSession(session)?.label ?? '';
  }

  static String _propertyTypePreferenceLabel(
    Map<String, dynamic> session,
    ProfileOnboardingTrack track,
  ) {
    if (track.isLandlord || track.isSharedSpace) return '';
    return PropertyTypePreference.fromSession(session)?.label ?? '';
  }

  static String _bathroomPreferenceLabel(
    Map<String, dynamic> session,
    ProfileOnboardingTrack track,
  ) {
    if (track.isLandlord) return '';
    return BathroomPreference.fromSession(session)?.label ?? '';
  }

  static String _transportPreference(Map<String, dynamic> session) {
    final profiles = session['commute_profiles'];
    if (profiles is List && profiles.isNotEmpty) {
      final first = profiles.first;
      if (first is Map) {
        final method = ProfileData.text(first['commute_method']);
        if (method.isNotEmpty) {
          return ProfileData.commuteMethod({'commute_method': method})
              .toDisplayLabel();
        }
      }
    }
    final raw = ProfileData.text(session['commute_method']);
    if (raw.isEmpty) return '';
    return ProfileData.commuteMethod(session).toDisplayLabel();
  }

  static String _verificationProgressLabel(
    List<ContextualPassportVerificationRow> rows,
  ) {
    if (rows.isEmpty) return 'Verification pending';
    final verified = rows.where((row) => row.verified).length;
    if (verified == 0) return 'Verification pending';
    return '$verified of ${rows.length} checks verified';
  }

  static String _profileCompletenessLevel(int percent) {
    if (percent >= 100) return 'Profile Complete';
    if (percent >= 80) return 'Almost Complete';
    if (percent >= 60) return 'Profile In Progress';
    return 'Just started';
  }

  static ProfileOnboardingTrack _resolveTrack(Map<String, dynamic> session) {
    final token = ProfileData.text(session['profile_onboarding_track']);
    if (token.isNotEmpty) {
      return ProfileOnboardingTrack.fromToken(token);
    }

    final caps = ActiveModeService.capabilitiesFor(session);
    final intent = ProfileData.text(session['onboarding_intent']).toLowerCase();
    final arrangement = ProfileData.text(session['preferred_arrangement']);
    final isShared = arrangement == 'shared' ||
        ProfileData.text(session['preferred_property_type']) == 'Share';

    if (caps.canHost && intent != 'seeker') {
      return isShared
          ? ProfileOnboardingTrack.landlordSharedSpace
          : ProfileOnboardingTrack.landlordEntirePlace;
    }

    return isShared
        ? ProfileOnboardingTrack.seekerSharedSpace
        : ProfileOnboardingTrack.seekerEntirePlace;
  }

  static (String, String) _resolvePersona(
    Map<String, dynamic> session,
    ProfileOnboardingTrack track,
  ) {
    if (track.isLandlord) {
      return track.isSharedSpace
          ? ('🏠', 'Shared Host')
          : ('🏢', 'Property Provider');
    }

    final persona = SeekerPersona.fromSession(session);
    if (persona != null) {
      return switch (persona) {
        SeekerPersona.student => ('🎓', 'Student'),
        SeekerPersona.family => ('👨‍👩‍👧‍👦', _familyPersonaLabel(session)),
        SeekerPersona.relocating => ('🌍', 'Relocating Professional'),
        SeekerPersona.professional => ('💼', 'Working Professional'),
      };
    }

    final occupant = ProfileData.text(session['occupant_type']);
    if (occupant == 'Students') return ('🎓', 'Student');
    if (occupant == 'Family') {
      return ('👨‍👩‍👧‍👦', _familyPersonaLabel(session));
    }
    if (occupant == 'Working Professionals') {
      return ('💼', 'Working Professional');
    }
    return ('👤', 'Seeker');
  }

  static String _familyPersonaLabel(Map<String, dynamic> session) {
    if (session['pre_arrival_seeker'] == true ||
        DublinLocationContext.fromSession(session) ==
            DublinLocationContext.arrivingSoon) {
      return 'Relocating Family';
    }
    return 'Family';
  }

  static int? _budgetMax(
    Map<String, dynamic> session,
    ProfileOnboardingTrack track,
  ) {
    final raw = track.isSharedSpace
        ? (session['room_budget'] ?? session['budget_max'])
        : session['budget_max'];
    if (raw is num) return raw.round();
    return int.tryParse(ProfileData.text(raw));
  }

  static String _moveInTimeline(Map<String, dynamic> session) {
    final window = SeekerMoveInWindow.fromSession(session);
    if (window != null) return window.label;
    final lease = session['preferred_lease_months'];
    if (lease is num && lease > 0) {
      return '${lease.round()}-month lease target';
    }
    return '';
  }

  static String _destinationHub(Map<String, dynamic> session) {
    if (ProfileData.commuteDestinationUnknown(session)) {
      return 'Not sure yet';
    }
    var hub = ProfileData.text(session['commute_destination']);
    if (hub.isEmpty) {
      final profiles = session['commute_profiles'];
      if (profiles is List && profiles.isNotEmpty) {
        final first = profiles.first;
        if (first is Map) {
          hub = ProfileData.text(first['commute_destination']);
          if (hub.isEmpty) {
            final hubId = ProfileData.text(first['commute_destination_hub_id']);
            if (hubId.isNotEmpty) hub = hubId;
          }
        }
      }
    }
    if (hub.isEmpty) return '';

    // Labeling only — whose destination was entered (not dual optimization).
    final priority =
        ProfileData.text(session['dual_commute_priority']).toLowerCase();
    final household = session['household_commuters_count'];
    final partnerContext = household is num
        ? household >= 2
        : priority == 'person_b' || priority == 'personb';
    if (partnerContext && (priority == 'person_b' || priority == 'personb')) {
      return "Partner's: $hub";
    }
    return hub;
  }

  static int? _maxCommuteMinutes(Map<String, dynamic> session) {
    final profiles = session['commute_profiles'];
    if (profiles is List && profiles.isNotEmpty) {
      final first = profiles.first;
      if (first is Map) {
        final perProfile = first['max_commute_minutes'];
        if (perProfile is num && perProfile > 0) return perProfile.round();
      }
    }
    final fallback = session['maximum_commute_budget_minutes'];
    if (fallback is num && fallback > 0) return fallback.round();
    return null;
  }

  static List<ContextualPassportChip> _compatibilityChips(
    Map<String, dynamic> session,
  ) {
    final chips = <ContextualPassportChip>[];

    final window = SeekerMoveInWindow.fromSession(session);
    if (window != null) {
      chips.add(
        ContextualPassportChip(emoji: '📅', label: 'Move-in ${window.label}'),
      );
    }

    final budgetMax = _budgetMax(session, _resolveTrack(session));
    if (budgetMax != null && budgetMax > 0) {
      chips.add(
        ContextualPassportChip(emoji: '💶', label: 'Up to €$budgetMax'),
      );
    }

    final locationContext = DublinLocationContext.fromSession(session);
    if (locationContext != null) {
      final label = switch (locationContext) {
        DublinLocationContext.alreadyInDublin => 'In Dublin',
        DublinLocationContext.arrivingSoon => 'Arriving soon',
        DublinLocationContext.relocating => 'Relocating',
      };
      chips.add(ContextualPassportChip(emoji: '📍', label: label));
    }

    final guarantorStatus = GuarantorStatus.fromSession(session);
    if (guarantorStatus != null &&
        SeekerPersona.fromSession(session) == SeekerPersona.student) {
      final label = switch (guarantorStatus) {
        GuarantorStatus.yes => 'Guarantor ready',
        GuarantorStatus.no => 'No guarantor',
        GuarantorStatus.notSureYet => 'Guarantor optional',
      };
      chips.add(ContextualPassportChip(emoji: '📋', label: label));
    }

    final food = ProfileData.text(session['food_preference']).toLowerCase();
    if (food.isNotEmpty) {
      final label = switch (food) {
        'veg' || 'vegetarian' => 'Veg',
        'non_veg' || 'non-veg' || 'nonveg' => 'Non-Veg',
        _ => food[0].toUpperCase() + food.substring(1),
      };
      chips.add(ContextualPassportChip(emoji: '🍽️', label: label));
    }

    final schedule = ProfileData.text(session['schedule_type']);
    if (schedule.isNotEmpty) {
      chips.add(ContextualPassportChip(emoji: '🕒', label: schedule));
    }

    final languages = ProfileData.languageList(
      session['preferred_spoken_languages'] ?? session['spoken_languages'],
    );
    for (final language in languages.take(8)) {
      chips.add(ContextualPassportChip(emoji: '💬', label: language));
    }

    return chips;
  }

  static String _budgetTierLabel(Map<String, dynamic> session) {
    final verified = session['financial_verified'] == true ||
        session['open_banking_verification_seal'] != null ||
        session['employment_verified'] == true ||
        session['open_banking_verified_at'] != null;
    return verified ? 'Verifiable budget tier' : 'Self-declared budget';
  }

  static String _householdBreakdown(Map<String, dynamic> session) {
    final occupant = ProfileData.text(session['occupant_type']);
    if (occupant == 'Family') {
      final adults = session['adults_count'] ?? session['family_adults'];
      final children = session['children_count'] ?? session['family_children'];
      final adultCount = adults is num ? adults.round() : 2;
      final childCount = children is num ? children.round() : 0;
      if (childCount > 0) {
        return '$adultCount adults · $childCount ${childCount == 1 ? 'child' : 'children'}';
      }
      return '$adultCount ${adultCount == 1 ? 'adult' : 'adults'}';
    }

    final groupSize = session['group_size'];
    if (groupSize is num && groupSize > 1) {
      final count = groupSize.round();
      return '$count people household';
    }

    if (occupant == 'Students') return 'Student household';
    if (occupant == 'Working Professionals') return 'Professional household';
    return 'Single applicant';
  }

  static List<ContextualPassportVerificationRow> _verificationRows(
    Map<String, dynamic> session,
  ) {
    final rows = <ContextualPassportVerificationRow>[];

    if (session['employment_verified'] == true ||
        session['employment_letter_verified'] == true) {
      rows.add(
        const ContextualPassportVerificationRow(
          emoji: '📄',
          label: 'Employment Contract Verified',
          verified: true,
        ),
      );
    }

    final universityEmail = ProfileData.text(session['verified_university_email']);
    if (universityEmail.isNotEmpty || session['university_email_verified'] == true) {
      rows.add(
        const ContextualPassportVerificationRow(
          emoji: '🎓',
          label: 'University Acceptance Verified',
          verified: true,
        ),
      );
    }

    if (rows.isEmpty) {
      rows.add(
        const ContextualPassportVerificationRow(
          emoji: '🛡️',
          label: 'Verification pending',
          verified: false,
        ),
      );
    }

    return rows;
  }

  static List<String> _houseRules(Map<String, dynamic> session) {
    final fromProfile = ProfileData.languageList(session['house_rules']);
    if (fromProfile.isNotEmpty) return fromProfile;

    final fromSeed = ProfileData.languageList(
      session['listingSeed_houseRules'] ?? session['prefill_house_rules'],
    );
    if (fromSeed.isNotEmpty) return fromSeed;

    final rules = <String>[];
    if (session['smoking_ok'] != true) rules.add('No smoking indoors');
    if (session['drinking_ok'] != true) rules.add('Quiet hours respected');
    if (session['household_has_pets'] != true) rules.add('No pets');
    return rules;
  }

  static List<String> _homeLanguages(Map<String, dynamic> session) {
    return ProfileData.languageList(
      session['spoken_languages'] ?? session['household_languages'],
    );
  }

  static List<String> _flatmatePreferences(Map<String, dynamic> session) {
    final prefs = <String>[];

    final gender = ProfileData.text(session['gender_preference']);
    if (gender.isNotEmpty) prefs.add('Prefers $gender flatmates');

    final occupant = ProfileData.text(session['preferred_tenant_occupant']);
    if (occupant.isNotEmpty) prefs.add('Ideal: $occupant');

    final cohort = ProfileData.text(session['flatmate_cohort']);
    if (cohort.isNotEmpty) prefs.add(cohort);

    if (session['smoking_ok'] == true) {
      prefs.add('Smoking-friendly household');
    } else {
      prefs.add('Non-smoking household');
    }

    return prefs;
  }

  static String _idVerificationLabel(Map<String, dynamic> session) {
    if (TrustService.meetsContactVerification(session)) {
      return '✅ Verified User';
    }
    return 'Verification not yet complete';
  }

  static String _licensingLabel(Map<String, dynamic> session) {
    if (ProfileData.text(session['agency_name']).isNotEmpty) {
      return 'Agency-licensed provider';
    }
    return 'Licensing status pending';
  }

  static String _responsivenessLabel(Map<String, dynamic> session) {
    if (TrustService.meetsContactVerification(session)) {
      return 'Typically responds promptly';
    }
    return 'Response window not yet established';
  }
}

class ContextualPassportChip {
  const ContextualPassportChip({
    required this.emoji,
    required this.label,
  });

  final String emoji;
  final String label;
}

class ContextualPassportVerificationRow {
  const ContextualPassportVerificationRow({
    required this.emoji,
    required this.label,
    required this.verified,
  });

  final String emoji;
  final String label;
  final bool verified;
}
