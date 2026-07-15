import 'listing_data.dart';
import 'listing_search_intent.dart';
import 'target_search_areas.dart';
import 'tower_filter_policy.dart';
import 'viewer_profile.dart';

/// Dublin-market weighted preference criteria — soft lifestyle filters only.
class WeightedFilterCriteria {
  const WeightedFilterCriteria({
    this.maxBudget,
    this.isSharedLiving = false,
    this.requiresWfh = false,
    this.requiresVeg = false,
    this.requiresNonVeg = false,
    this.preferredRoomType,
    this.preferredOccupant,
    this.preferredGender,
    this.preferredMoveInWindow,
    this.preferredHouseholdLanguages = const [],
  });

  final int? maxBudget;
  final bool isSharedLiving;
  final bool requiresWfh;
  final bool requiresVeg;
  final bool requiresNonVeg;
  final String? preferredRoomType;
  final String? preferredOccupant;
  final String? preferredGender;
  final String? preferredMoveInWindow;
  final List<String> preferredHouseholdLanguages;

  factory WeightedFilterCriteria.fromSearchContext({
    required ListingSearchFilters filters,
    required Map<String, dynamic>? userSession,
    required String towerPropertyType,
  }) {
    final viewer = ViewerProfile.fromSession(userSession);
    final maxBudget = filters.budgetMax ?? viewer?.budgetMax;
    final moveIn = filters.moveInWindow;
    final isShared = TowerFilterPolicy.isSharedLiving(towerPropertyType);
    final food = filters.foodPreference?.trim().toLowerCase();
    return WeightedFilterCriteria(
      maxBudget: maxBudget,
      isSharedLiving: isShared,
      requiresWfh: false,
      requiresVeg: isShared && food == 'veg',
      requiresNonVeg: isShared && food == 'non-veg',
      preferredRoomType: _preferredRoomTypeFromKeywords(filters.keywords),
      preferredOccupant: isShared ? filters.occupantType : null,
      preferredGender: null,
      preferredMoveInWindow:
          moveIn != null && moveIn.isNotEmpty ? moveIn : null,
      preferredHouseholdLanguages: isShared
          ? List<String>.from(filters.householdLanguages)
          : const [],
    );
  }

  static String? _preferredRoomTypeFromKeywords(List<String> keywords) {
    for (final keyword in keywords) {
      final lower = keyword.toLowerCase();
      if (lower.contains('ensuite')) return 'ensuite';
      if (lower.contains('private')) return 'private';
      if (lower.contains('shared') || lower.contains('bed')) return 'shared';
    }
    return null;
  }
}

/// Scored filtering: hard budget cap at 125%, soft lifestyle weighting thereafter.
abstract final class WeightedListingMatcher {
  /// Dublin-market premium buffer — listings above this are hard-excluded.
  static const budgetHardCapRatio = 1.25;

  /// Stretch zone begins above 110% of target budget.
  static const budgetStretchStartRatio = 1.10;

  /// Penalty applied inside the 110%–125% stretch band.
  static const stretchZonePenalty = 15.0;

  /// Hard exclusion — budget cap, area, lease, keywords, tower-specific compatibility.
  static bool passesHardExclusion(
    Map<String, dynamic> listing,
    WeightedFilterCriteria criteria,
    ListingSearchFilters filters, {
    required String towerPropertyType,
  }) {
    final resolution = filters.resolvedAreaSearch;
    if (!resolution.isAllDublin) {
      if (!TargetSearchAreas.listingMatchesResolved(resolution, listing)) {
        return false;
      }
    } else if (filters.effectiveAreaRefinements.isNotEmpty &&
        !TargetSearchAreas.listingMatchesTargets(
          filters.effectiveAreaTokens,
          listing,
          refinementTokens: filters.effectiveAreaRefinements,
        )) {
      return false;
    }

    if (criteria.maxBudget != null) {
      final amount = ListingData.listingPriceAmount(listing);
      if (amount == null) return false;
      final hardCap = (criteria.maxBudget! * budgetHardCapRatio).round();
      if (amount > hardCap) return false;
      if (filters.budgetMin != null && amount < filters.budgetMin!) {
        return false;
      }
    } else if (filters.budgetMin != null) {
      final amount = ListingData.listingPriceAmount(listing);
      if (amount == null || amount < filters.budgetMin!) return false;
    }

    if (filters.preferredLeaseMonths != null) {
      final leaseLength = int.tryParse(
        ListingData.text(listing['preferred_lease_months']),
      );
      if (leaseLength != null && leaseLength < filters.preferredLeaseMonths!) {
        return false;
      }
    }

    if (filters.keywords.isNotEmpty &&
        !ListingSearchIntent.matchesKeywords(listing, filters.keywords)) {
      return false;
    }

    if (TowerFilterPolicy.isSharedLiving(towerPropertyType) &&
        !TowerFilterPolicy.passesSharedLivingHardFilters(listing, filters)) {
      return false;
    }

    return true;
  }

  /// Preference alignment score (0–100) from active soft lifestyle filters.
  static double computePreferenceScore(
    Map<String, dynamic> listing,
    WeightedFilterCriteria criteria,
  ) {
    var matchScore = 100.0;
    var totalSoftFilters = 0;
    var matchedSoftFilters = 0;

    if (criteria.requiresWfh) {
      totalSoftFilters++;
      if (_listingIsWfhFriendly(listing)) matchedSoftFilters++;
    }
    if (criteria.requiresVeg) {
      totalSoftFilters++;
      if (_listingIsPureVeg(listing)) matchedSoftFilters++;
    }
    if (criteria.requiresNonVeg) {
      totalSoftFilters++;
      if (!_listingIsPureVeg(listing)) matchedSoftFilters++;
    }
    if (criteria.preferredRoomType != null) {
      totalSoftFilters++;
      if (_listingMatchesRoomType(listing, criteria.preferredRoomType!)) {
        matchedSoftFilters++;
      }
    }
    if (criteria.preferredOccupant != null) {
      totalSoftFilters++;
      if (TowerFilterPolicy.matchesHouseholdTypeFilter(
        listing,
        criteria.preferredOccupant!,
      )) {
        matchedSoftFilters++;
      }
    }
    if (criteria.preferredGender != null) {
      totalSoftFilters++;
      if (ListingSearchIntent.listingMatchesGender(
        listing,
        criteria.preferredGender!,
      )) {
        matchedSoftFilters++;
      }
    }
    if (criteria.preferredMoveInWindow != null &&
        criteria.preferredMoveInWindow!.isNotEmpty) {
      totalSoftFilters++;
      if (ListingSearchFilters(moveInWindow: criteria.preferredMoveInWindow)
          .passesMoveInWindow(listing)) {
        matchedSoftFilters++;
      }
    }
    if (criteria.preferredHouseholdLanguages.isNotEmpty) {
      totalSoftFilters++;
      if (TowerFilterPolicy.matchesHouseholdLanguageOverlap(
        listing,
        criteria.preferredHouseholdLanguages,
      )) {
        matchedSoftFilters++;
      }
    }

    if (totalSoftFilters > 0) {
      matchScore = (matchedSoftFilters / totalSoftFilters) * 100;
    }

    final rent = ListingData.listingPriceAmount(listing);
    if (criteria.maxBudget != null &&
        rent != null &&
        rent > (criteria.maxBudget! * budgetStretchStartRatio).round()) {
      matchScore -= stretchZonePenalty;
    }

    return matchScore.clamp(0, 100);
  }

  /// Filter to hard-exclusion pool, score preferences, sort descending.
  static List<Map<String, dynamic>> fetchScoredListings({
    required List<Map<String, dynamic>> listings,
    required WeightedFilterCriteria criteria,
    required ListingSearchFilters filters,
    required String towerPropertyType,
  }) {
    final baseline = [
      for (final listing in listings)
        if (passesHardExclusion(
          listing,
          criteria,
          filters,
          towerPropertyType: towerPropertyType,
        ))
          listing,
    ];

    baseline.sort((a, b) {
      final scoreB = computePreferenceScore(b, criteria);
      final scoreA = computePreferenceScore(a, criteria);
      return scoreB.compareTo(scoreA);
    });

    return baseline;
  }

  static bool _listingIsWfhFriendly(Map<String, dynamic> listing) {
    if (listing['wfh_friendly'] == true) return true;
    return ListingData.scheduleType(listing).toLowerCase() == 'flexible';
  }

  static bool _listingIsPureVeg(Map<String, dynamic> listing) {
    if (ListingData.matchesFoodPreferenceFilter(listing, 'veg')) return true;
    return ListingData.lifestyleFlags(listing).contains('vegetarian_household');
  }

  static bool _listingMatchesRoomType(
    Map<String, dynamic> listing,
    String preferred,
  ) {
    final room = ListingData.roomType(listing).toLowerCase();
    final kind = ListingData.text(listing['share_room_kind']).toLowerCase();
    return switch (preferred) {
      'ensuite' => room.contains('ensuite') || kind == 'ensuite',
      'private' =>
        room.contains('private') || kind == 'private_bath',
      'shared' =>
        room.contains('shared') || kind == 'bed_shared',
      _ => room.contains(preferred),
    };
  }
}
