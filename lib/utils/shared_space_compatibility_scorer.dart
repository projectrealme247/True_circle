import 'listing_data.dart';
import 'numeric_bounds.dart';
import 'profile_data.dart';
import 'shared_living_match_tokens.dart';
import '../models/financial_support_type.dart';

enum CohortType { studentOnly, professionalsOnly, openMixed }

abstract final class SharedSpaceCompatibilityScorer {
  static CohortType cohortFromListing(Map<String, dynamic> listing) {
    final roomProfile = ProfileData.text(
      listing['room_profile'] ??
          listing['metadata']?['room_profile'] ??
          SharedLivingMatchTokens.primarySharedRoom(listing)?['room_profile'],
    ).toLowerCase();
    if (roomProfile.isNotEmpty) {
      return switch (roomProfile) {
        'students' || 'student' || 'student_only' => CohortType.studentOnly,
        'working_professionals' ||
        'working_professional' ||
        'professionals' ||
        'professionals_only' =>
          CohortType.professionalsOnly,
        _ => CohortType.openMixed,
      };
    }

    final raw = ProfileData.text(
      listing['cohort_type'] ??
          listing['metadata']?['cohort_type'] ??
          listing['flatmate_cohort'] ??
          listing['household_cohort'],
    ).toLowerCase();
    return switch (raw) {
      'student_only' || 'students' || 'student' => CohortType.studentOnly,
      'professionals_only' ||
      'working_professionals' ||
      'professionals' =>
        CohortType.professionalsOnly,
      _ => CohortType.openMixed,
    };
  }

  /// Canonical listing room token (`private_room` / `shared_room`).
  static String roomTypeMatchingToken(Map<String, dynamic> listing) {
    return SharedLivingMatchTokens.roomFromListing(listing);
  }

  /// Canonical listing required-occupant token (`male` / `female` / `no_preference`).
  static String requiredOccupantToken(Map<String, dynamic> listing) {
    return SharedLivingMatchTokens.genderFromListing(listing);
  }

  static String occupantTypeToken(Map<String, dynamic> listing) {
    return ProfileData.text(
      listing['occupant_type'] ??
          listing['metadata']?['occupant_type'] ??
          SharedLivingMatchTokens.primarySharedRoom(listing)?['occupant_type'],
    ).toLowerCase();
  }

  static int calculateCompatibility({
    required Map<String, dynamic> seekerSession,
    required Map<String, dynamic> listing,
  }) {
    var score = 0;

    final seekerFood = ProfileData.text(seekerSession['food_preference']);
    final hostFood = ListingData.hostFoodPreference(listing);
    if (seekerFood.isNotEmpty &&
        hostFood.isNotEmpty &&
        seekerFood.toLowerCase() == hostFood.toLowerCase()) {
      score += 20;
    }

    final seekerLangs = ProfileData.languageList(
      seekerSession['spoken_languages'],
    );
    final hostLang = ProfileData.text(ListingData.hostLanguage(listing));
    final listingLangs = ProfileData.languageList(listing['languages_spoken']);
    if (seekerLangs.any(
      (lang) =>
          hostLang.toLowerCase().contains(lang.toLowerCase()) ||
          listingLangs.any((h) => h.toLowerCase() == lang.toLowerCase()),
    )) {
      score += 15;
    }

    final cohort = cohortFromListing(listing);
    final support = FinancialSupportType.fromSession(seekerSession);
    final studentType = support ??
        ProfileData.text(seekerSession['student_type']);
    final seekerIsStudent = studentType.isNotEmpty ||
        ProfileData.text(seekerSession['seeker_persona']).toLowerCase() ==
            'student' ||
        ProfileData.text(seekerSession['persona']).toLowerCase() == 'student';
    if (cohort == CohortType.studentOnly && seekerIsStudent) {
      score += 20;
    } else if (cohort == CohortType.professionalsOnly && !seekerIsStudent) {
      score += 20;
    } else if (cohort == CohortType.openMixed) {
      score += 12;
    }

    final occupantType = occupantTypeToken(listing);
    if (occupantType == 'student' && seekerIsStudent) {
      score += 10;
    } else if (occupantType == 'working_professional' && !seekerIsStudent) {
      score += 10;
    } else if (occupantType == 'no_preference' || occupantType.isEmpty) {
      score += 5;
    }

    final listingRoom = roomTypeMatchingToken(listing);
    final seekerRoom = SharedLivingMatchTokens.roomFromSeeker(seekerSession);
    if (SharedLivingMatchTokens.roomCompatible(
      listingCanonical: listingRoom,
      seekerCanonical: seekerRoom,
    )) {
      if (seekerRoom == SharedLivingMatchTokens.sharedRoom &&
          listingRoom == SharedLivingMatchTokens.sharedRoom) {
        score += 10;
      } else if (seekerRoom == SharedLivingMatchTokens.privateRoom &&
          listingRoom == SharedLivingMatchTokens.privateRoom) {
        score += 8;
      } else if (seekerRoom.isEmpty) {
        score += 5;
      }
    }

    if (SharedLivingMatchTokens.bathroomCompatibleFor(
      listing: listing,
      seekerSession: seekerSession,
    )) {
      final seekerBath =
          SharedLivingMatchTokens.bathroomFromSeeker(seekerSession);
      if (seekerBath != SharedLivingMatchTokens.noPreference) {
        score += 8;
      } else {
        score += 3;
      }
    }

    if (seekerSession['household_smoker'] != true &&
        (ProfileData.text(listing['smoking_policy']).toLowerCase() ==
                'no_smoking' ||
            ListingData.lifestylePreferences(listing)
                .any((p) => p.toLowerCase().contains('no smoking')))) {
      score += 5;
    }

    return NumericBounds.clampPercentInt(score);
  }
}
