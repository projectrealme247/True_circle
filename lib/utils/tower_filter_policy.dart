import 'profile_data.dart';

import 'listing_data.dart';

import 'listing_search_intent.dart';



/// Tower-specific marketplace filter rules — Independent Places vs Shared Living.

///

/// ## FINAL filter architecture (frozen)

///

/// **Independent Places (`Rent`)** — "Can I live in this property?"

/// - Hard: area, budget, layout/bed/bath keywords, dwelling/property type keywords

/// - Soft: move-in timing

/// - Never hard-filter: suitable-for, student/professional/family, gender, food,

///   occupant type, household language (ranking signals only via match engine)

///

/// **Shared Living (`Share`)** — "Can I live with these people?"

/// - Hard: budget, room-type keywords, gender restriction, smoking/pet keywords,

///   host-explicit no-smoking / no-pets (via [ListingMatchEngine] profile gate)

/// - Soft: move-in timing; household type, household language, food preference

///   (stored on [ListingSearchFilters], scored in [WeightedListingMatcher])

abstract final class TowerFilterPolicy {

  static const independentTower = 'Rent';

  static const sharedTower = 'Share';



  static bool isIndependentPlace(String towerPropertyType) =>

      towerPropertyType == independentTower;



  static bool isSharedLiving(String towerPropertyType) =>

      towerPropertyType == sharedTower;



  /// Strips filter dimensions that must not apply to [towerPropertyType].

  static ListingSearchFilters scopeFilters(

    ListingSearchFilters filters,

    String towerPropertyType,

  ) {

    if (isSharedLiving(towerPropertyType)) {

      return filters.copyWith(wfhFriendly: null);

    }

    return filters.copyWith(

      foodPreference: null,

      occupantType: null,

      genderPreference: null,

      householdLanguages: const [],

      wfhFriendly: null,

    );

  }



  /// Search-intent dimensions scoped to tower query-time hard filters.

  ///

  /// Share: gender + keywords only — food/occupant are preference signals, not

  /// query exclusions. Rent: city + keywords only.

  static SearchIntent scopeSearchIntent(

    SearchIntent intent,

    String towerPropertyType,

  ) {

    if (isSharedLiving(towerPropertyType)) {

      return SearchIntent(

        city: intent.city,

        gender: intent.gender,

        remainingKeywords: intent.remainingKeywords,

      );

    }

    return SearchIntent(

      city: intent.city,

      remainingKeywords: intent.remainingKeywords,

    );

  }



  /// Shared Living query-time hard filters — gender restriction only.

  ///

  /// Budget, room type, smoking/pet keywords, and area are handled elsewhere.

  /// Household type, language, and food are preference/ranking signals only.

  static bool passesSharedLivingHardFilters(

    Map<String, dynamic> listing,

    ListingSearchFilters filters,

  ) {

    final gender = filters.genderPreference;

    if (gender != null &&

        gender.isNotEmpty &&

        !ListingSearchIntent.listingMatchesGender(listing, gender)) {

      return false;

    }

    return true;

  }



  /// Household Type preference match — Students, Professionals, Mixed Household.

  static bool matchesHouseholdTypeFilter(

    Map<String, dynamic> listing,

    String filterOccupant,

  ) {

    if (filterOccupant == 'Mixed Household') {

      final occupant = ListingData.occupantType(listing).toLowerCase();

      if (occupant.contains('mixed')) return true;

      final pref = ListingData.bachelorPreference(listing).toLowerCase();

      if (pref.contains('boys & girls') || pref.contains('mixed')) {

        return true;

      }

      return false;

    }

    return ListingData.matchesOccupantTypeFilter(listing, filterOccupant);

  }



  /// At least one language overlap between preference selection and listing household.

  static bool matchesHouseholdLanguageOverlap(

    Map<String, dynamic> listing,

    List<String> selectedLanguages,

  ) {

    if (selectedLanguages.isEmpty) return true;

    final listingLangs = ProfileData.languageList(

      listing['spoken_languages'] ?? listing['household_languages'],

    ).map((lang) => lang.trim().toLowerCase()).where((lang) => lang.isNotEmpty);

    final selected = selectedLanguages

        .map((lang) => lang.trim().toLowerCase())

        .where((lang) => lang.isNotEmpty)

        .toSet();

    if (selected.isEmpty) return true;

    for (final lang in listingLangs) {

      if (selected.contains(lang)) return true;

    }

    return false;

  }

}


