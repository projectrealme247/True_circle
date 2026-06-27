import 'listing_data.dart';
import 'numeric_bounds.dart';
import 'profile_data.dart';

enum CohortType { studentOnly, professionalsOnly, openMixed }

abstract final class SharedSpaceCompatibilityScorer {
  static CohortType cohortFromListing(Map<String, dynamic> listing) {
    final raw = ProfileData.text(
      listing['cohort_type'] ?? listing['metadata']?['cohort_type'],
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
      score += 25;
    }

    final seekerLangs = ProfileData.languageList(
      seekerSession['spoken_languages'],
    );
    final hostLang = ProfileData.text(ListingData.hostLanguage(listing));
    if (seekerLangs.any(
      (lang) => hostLang.toLowerCase().contains(lang.toLowerCase()),
    )) {
      score += 20;
    }

    final cohort = cohortFromListing(listing);
    final studentType = ProfileData.text(seekerSession['student_type']);
    if (cohort == CohortType.studentOnly && studentType.isNotEmpty) {
      score += 20;
    } else if (cohort == CohortType.professionalsOnly &&
        studentType.isEmpty) {
      score += 20;
    } else if (cohort == CohortType.openMixed) {
      score += 15;
    }

    final schedule = ProfileData.text(seekerSession['schedule_type']);
    final listingSchedule = ProfileData.text(
      listing['schedule_type'] ?? listing['metadata']?['schedule_type'],
    );
    if (schedule.isNotEmpty &&
        listingSchedule.isNotEmpty &&
        schedule == listingSchedule) {
      score += 15;
    }

    if (seekerSession['household_smoker'] != true &&
        ListingData.lifestylePreferences(listing)
            .any((p) => p.toLowerCase().contains('no smoking'))) {
      score += 10;
    }

    return NumericBounds.clampPercentInt(score);
  }
}
