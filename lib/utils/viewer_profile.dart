import '../models/move_in_timing.dart';
import '../models/financial_support_type.dart';
import 'accepted_district_recommendations.dart';
import 'profile_data.dart';
import 'shared_living_match_tokens.dart';
import 'target_search_areas.dart';

/// Primary seeker persona for trust gates and contact flows.
enum SeekerCohort {
  student,
  workingProfessional,
  arrivingFamily;

  bool get needsJitSocialGate =>
      this == SeekerCohort.workingProfessional ||
      this == SeekerCohort.arrivingFamily;
}

/// Normalized viewer profile used for tower-specific matching.
class ViewerProfile {
  const ViewerProfile({
    required this.city,
    required this.motherTongue,
    required this.spokenLanguages,
    required this.foodPreference,
    required this.occupantType,
    required this.genderPreference,
    required this.studentType,
    required this.company,
    required this.jobTitle,
    required this.budgetMin,
    required this.budgetMax,
    required this.preferredPropertyType,
    required this.completenessPercent,
    required this.hasCompany,
    this.preferredLayout = '',
    this.linkedinVerified = false,
    this.linkedinCompany = '',
    this.linkedinTitle = '',
    this.aadhaarVerified = false,
    this.passkeyBound = false,
    this.smokingOk = false,
    this.householdHasPets = false,
    this.drinkingOk = false,
    this.scheduleType = '',
    this.familyAdults = 0,
    this.familyChildren = 0,
    this.childrenAges = const [],
    this.groupSize = 1,
    this.targetSearchAreas = const [],
    this.acceptedDistrictRecommendations = const [],
    this.isPreArrivalSeeker = false,
    this.moveInWindow = '',
    this.earliestMoveInDate = '',
    this.hasVerifiedPreArrivalDocs = false,
    this.needsOnboarding = false,
    this.shareOccupantGender = SharedLivingMatchTokens.noPreference,
    this.shareBathroomPreference = SharedLivingMatchTokens.noPreference,
    this.shareRoomLayout = '',
  });

  final String city;
  final String motherTongue;
  final List<String> spokenLanguages;
  final String foodPreference;
  final String occupantType;
  final String genderPreference;
  final String studentType;
  final String company;
  final String jobTitle;
  final int? budgetMin;
  final int? budgetMax;
  final String preferredPropertyType;

  /// Seeker bed/room layout preference (`Studio`, `1 Bed`, `Ensuite Room`, …).
  final String preferredLayout;
  final int completenessPercent;
  final bool hasCompany;

  final bool linkedinVerified;
  final String linkedinCompany;
  final String linkedinTitle;
  final bool aadhaarVerified;
  final bool passkeyBound;
  final bool smokingOk;
  final bool householdHasPets;
  final bool drinkingOk;
  final String scheduleType;
  final int familyAdults;
  final int familyChildren;
  final List<String> childrenAges;
  final int groupSize;
  final List<String> targetSearchAreas;

  /// Accepted district recommendation signals (soft; unused by ranking until wired).
  final List<AcceptedDistrictRecommendation> acceptedDistrictRecommendations;

  final bool isPreArrivalSeeker;

  /// Seeker move-in window token (`this_month`, `next_month`, etc.).
  final String moveInWindow;

  /// Legacy exact-date field — read-only for migration; prefer [moveInWindow].
  final String earliestMoveInDate;

  /// Backend-verified inbound docs (university offer, employment contract, relocation letter).
  final bool hasVerifiedPreArrivalDocs;

  /// Profile shell exists but lacks fields required for meaningful matching.
  final bool needsOnboarding;

  /// Canonical Shared Living gender for matching (`male` / `female` / `no_preference`).
  final String shareOccupantGender;

  /// Canonical bathroom preference (`private_ensuite` / `shared_bathroom` / `no_preference`).
  final String shareBathroomPreference;

  /// Canonical Shared room layout (`private_room` / `shared_room` / empty for IP layouts).
  final String shareRoomLayout;

  static bool sessionNeedsOnboarding(Map<String, dynamic> raw) {
    return ProfileData.text(raw['detected_city']).isEmpty ||
        ProfileData.text(raw['budget_max']).isEmpty;
  }

  static bool _hasAuthenticatedProfileShell(Map<String, dynamic> raw) {
    return ProfileData.text(raw['supabase_user_id']).isNotEmpty ||
        ProfileData.text(raw['email']).isNotEmpty ||
        raw['demo_mode'] == true ||
        ProfileData.text(raw['active_marketplace_space']).isNotEmpty;
  }

  static ViewerProfile incompleteShell(Map<String, dynamic> raw) {
    return ViewerProfile(
      city: '',
      motherTongue: '',
      spokenLanguages: const [],
      foodPreference: '',
      occupantType: '',
      genderPreference: '',
      studentType: '',
      company: '',
      jobTitle: '',
      budgetMin: null,
      budgetMax: null,
      preferredPropertyType: ProfileData.text(raw['preferred_property_type']),
      preferredLayout: ProfileData.text(raw['preferred_layout']),
      completenessPercent: 0,
      hasCompany: false,
      needsOnboarding: true,
    );
  }

  static ViewerProfile? fromSession(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return null;

    final city = ProfileData.text(raw['detected_city']);
    final motherTongue = ProfileData.text(raw['mother_tongue']);
    final spoken = ProfileData.languageList(raw['spoken_languages']);
    final food = ProfileData.text(raw['food_preference']);
    final occupant = ProfileData.text(
      raw['occupant_type'] ?? raw['preferred_occupant_type'],
    );
    final gender = ProfileData.text(
      raw['gender_preference'] ?? raw['gender'],
    );
    final student = FinancialSupportType.fromSession(raw) ??
        ProfileData.text(raw['student_type']);
    // studentType on ViewerProfile holds financial-support label when present.
    final company = ProfileData.text(raw['company']);
    final jobTitle = ProfileData.text(raw['job_title']);
    final preferredType = ProfileData.text(raw['preferred_property_type']);
    final preferredLayout = ProfileData.text(raw['preferred_layout']);

    final budgetMin = _parseInt(raw['budget_min']);
    final budgetMax = _parseInt(raw['budget_max']);

    final completeness = _completenessPercent(raw);
    final needsOnboarding = sessionNeedsOnboarding(raw);

    if (city.isEmpty &&
        motherTongue.isEmpty &&
        food.isEmpty &&
        occupant.isEmpty) {
      if (_hasAuthenticatedProfileShell(raw)) {
        return incompleteShell(raw);
      }
      return null;
    }

    return ViewerProfile(
      city: city,
      motherTongue: motherTongue,
      spokenLanguages: spoken,
      foodPreference: food,
      occupantType: occupant,
      genderPreference: gender,
      studentType: student,
      company: company,
      jobTitle: jobTitle,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      preferredPropertyType: preferredType,
      preferredLayout: preferredLayout,
      completenessPercent: completeness,
      hasCompany: company.isNotEmpty,
      linkedinVerified: raw['linkedin_verified'] == true,
      linkedinCompany: ProfileData.text(raw['linkedin_company']),
      linkedinTitle: ProfileData.text(raw['linkedin_title']),
      aadhaarVerified: raw['is_aadhaar_verified'] == true,
      passkeyBound: ProfileData.text(raw['passkey_public_key']).isNotEmpty,
      smokingOk: raw['smoking_ok'] == true,
      householdHasPets: raw['household_has_pets'] == true || raw['has_pets'] == true,
      drinkingOk: raw['drinking_ok'] == true,
      scheduleType: ProfileData.text(raw['schedule_type']),
      familyAdults: (raw['family_adults'] is int) ? raw['family_adults'] as int : 0,
      familyChildren: (raw['family_children'] is int) ? raw['family_children'] as int : 0,
      childrenAges: _parseChildrenAges(raw),
      groupSize: (raw['group_size'] is int) ? raw['group_size'] as int : 1,
      targetSearchAreas: TargetSearchAreas.hydrateFromSession(raw),
      acceptedDistrictRecommendations:
          AcceptedDistrictRecommendations.hydrateFromSession(raw),
      isPreArrivalSeeker: _isPreArrivalSeeker(raw) &&
          ProfileData.text(raw['verified_university_email']).isEmpty,
      moveInWindow:
          SeekerMoveInWindow.fromSession(raw)?.storageToken ?? '',
      earliestMoveInDate: ProfileData.text(raw['earliest_move_in_date']),
      hasVerifiedPreArrivalDocs: _resolveVerifiedPreArrivalDocs(raw),
      needsOnboarding: needsOnboarding,
      shareOccupantGender: SharedLivingMatchTokens.genderFromSeekerSession(raw),
      shareBathroomPreference:
          SharedLivingMatchTokens.bathroomFromSeeker(raw),
      shareRoomLayout: SharedLivingMatchTokens.roomFromSeeker(raw),
    );
  }

  static bool _isPreArrivalSeeker(Map<String, dynamic> raw) {
    if (raw['pre_arrival_student'] == true) return true;
    if (raw['pre_arrival_contact_ready'] == true) return true;
    return raw['invite_code_verified'] == true &&
        raw['onboarding_letter_verified'] == true;
  }

  static bool _resolveVerifiedPreArrivalDocs(Map<String, dynamic> raw) {
    if (raw['has_verified_pre_arrival_docs'] == true) return true;
    if (raw['pre_arrival_student'] == true) return true;
    if (raw['onboarding_letter_verified'] == true) return true;
    if (raw['employment_contract_verified'] == true) return true;
    if (raw['relocation_letter_verified'] == true) return true;
    return false;
  }

  static SeekerCohort seekerCohortFromSession(Map<String, dynamic>? session) {
    if (session == null) return SeekerCohort.student;
    final occupant = ProfileData.text(session['occupant_type']).toLowerCase();
    if (occupant.contains('family') ||
        (session['family_children'] is int &&
            (session['family_children'] as int) > 0)) {
      return SeekerCohort.arrivingFamily;
    }
    if (occupant.contains('professional') ||
        occupant.contains('working') ||
        ProfileData.text(session['company']).isNotEmpty) {
      return SeekerCohort.workingProfessional;
    }
    return SeekerCohort.student;
  }

  static List<String> _parseChildrenAges(Map<String, dynamic> raw) {
    final ages = raw['children_ages'];
    if (ages is List) return ages.map((e) => e.toString()).toList();
    final legacy = ProfileData.text(raw['children_age_range']);
    if (legacy.isEmpty) return const [];
    final count = (raw['family_children'] is int) ? raw['family_children'] as int : 1;
    return List.generate(count, (_) => legacy);
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    final digits = RegExp(r'\d+').stringMatch(value.toString().replaceAll(',', ''));
    if (digits == null) return null;
    return int.tryParse(digits);
  }

  static int _completenessPercent(Map<String, dynamic> raw) {
    const keys = [
      'full_name',
      'email',
      'detected_city',
      'mother_tongue',
      'food_preference',
      'spoken_languages',
      'occupant_type',
      'gender_preference',
      'financial_support_type',
      'company',
    ];
    var filled = 0;
    for (final key in keys) {
      if (key == 'financial_support_type') {
        if (FinancialSupportType.fromSession(raw) != null) filled++;
        continue;
      }
      final value = raw[key];
      if (value is List && value.isNotEmpty) {
        filled++;
      } else if (ProfileData.text(value).isNotEmpty) {
        filled++;
      }
    }
    return ((filled / keys.length) * 100).round();
  }
}

