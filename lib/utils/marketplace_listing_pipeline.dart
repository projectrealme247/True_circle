import 'package:flutter/foundation.dart';

import 'listing_data.dart';
import 'listing_match_engine.dart';
import 'listing_search_intent.dart';
import 'viewer_profile.dart';

/// Output of the unified marketplace pipeline (parse → filter → rank → display).
class MarketplaceListingPipelineResult {
  const MarketplaceListingPipelineResult({
    required this.requestedIntent,
    required this.appliedIntent,
    required this.afterTower,
    required this.afterFilters,
    required this.ranked,
    this.relaxedConstraints = const [],
    this.usedClosestMatchFallback = false,
  });

  final SearchIntent requestedIntent;
  final SearchIntent appliedIntent;
  final List<Map<String, dynamic>> afterTower;
  final List<Map<String, dynamic>> afterFilters;
  final List<ScoredListing> ranked;
  final List<String> relaxedConstraints;
  final bool usedClosestMatchFallback;

  bool get hasActiveSearch => !requestedIntent.isEmpty;

  bool get filtersWereRelaxed =>
      relaxedConstraints.isNotEmpty || usedClosestMatchFallback;

  String? get searchSummary {
    if (!hasActiveSearch) return null;
    final summary = appliedIntent.displaySummary;
    if (summary.isEmpty) return null;
    return 'Showing results for: $summary';
  }

  String? get relaxationNotice {
    if (!filtersWereRelaxed) return null;
    if (usedClosestMatchFallback && relaxedConstraints.isEmpty) {
      return 'Showing closest matches to your search';
    }
    final labels = relaxedConstraints.map((c) => switch (c) {
          'city' => 'location',
          'gender' => 'gender',
          'occupant' => 'occupant type',
          'food' => 'food preference',
          _ => c,
        }).join(', ');
    return 'Showing closest matches — relaxed $labels';
  }
}

abstract final class MarketplaceListingPipeline {
  /// Single entry point: runs search using explicit filters.
  static MarketplaceListingPipelineResult runWithFilters({
    required List<Map<String, dynamic>> allListings,
    required String towerPropertyType,
    required ListingSearchFilters filters,
    required Map<String, dynamic>? userSession,
    String searchQuery = '',
  }) {
    final normalized = searchQuery.trim().isNotEmpty
        ? ListingSearchIntent.normalizeQuery(searchQuery)
        : filters.toPipelineQuery();

    return run(
      allListings: allListings,
      towerPropertyType: towerPropertyType,
      searchQuery: normalized,
      userSession: userSession,
      searchIntent: filters.toSearchIntent(mergeQuery: normalized),
    );
  }

  static MarketplaceListingPipelineResult run({
    required List<Map<String, dynamic>> allListings,
    required String towerPropertyType,
    required String searchQuery,
    required Map<String, dynamic>? userSession,
    SearchIntent? searchIntent,
  }) {
    final afterTower = [
      for (final item in allListings)
        if (ListingData.propertyType(item) == towerPropertyType) item,
    ];

    final requestedIntent =
        searchIntent ?? ListingSearchIntent.parseQuery(searchQuery);

    final filterOutcome = ListingSearchIntent.applyFiltersWithRelaxation(
      afterTower,
      searchQuery,
      intent: requestedIntent,
    );

    var pool = filterOutcome.listings;

    if (requestedIntent.food != null) {
      pool = _enforceFoodFilter(pool, requestedIntent.food);
    }

    final searchIntentForRanking = requestedIntent.hasStructuredFilters
        ? requestedIntent
        : null;

    var ranked = ListingMatchEngine.rank(
      pool,
      userSession,
      searchIntent: searchIntentForRanking,
      appliedSearchIntent: filterOutcome.appliedIntent,
      filtersWereRelaxed: filterOutcome.wasRelaxed,
    );

    if (requestedIntent.food != null) {
      ranked = _enforceFoodOnRanked(ranked, requestedIntent.food);
    }

    return MarketplaceListingPipelineResult(
      requestedIntent: requestedIntent,
      appliedIntent: filterOutcome.appliedIntent,
      afterTower: afterTower,
      afterFilters: pool,
      ranked: ranked,
      relaxedConstraints: filterOutcome.relaxedConstraints,
      usedClosestMatchFallback: filterOutcome.usedClosestMatchFallback,
    );
  }

  static List<Map<String, dynamic>> _enforceFoodFilter(
    List<Map<String, dynamic>> listings,
    String? foodToken,
  ) {
    if (foodToken == null) return listings;
    return [
      for (final item in listings)
        if (ListingData.matchesFoodPreference(item, foodToken)) item,
    ];
  }

  static List<ScoredListing> _enforceFoodOnRanked(
    List<ScoredListing> ranked,
    String? foodToken,
  ) {
    if (foodToken == null) return ranked;
    return [
      for (final scored in ranked)
        if (ListingData.matchesFoodPreference(scored.listing, foodToken))
          scored,
    ];
  }

  static void debugLog(
    MarketplaceListingPipelineResult result,
    String rawSearchQuery, {
    Map<String, dynamic>? userSession,
  }) {
    debugPrint('--- Marketplace listing pipeline ---');
    debugPrint('Search: "${rawSearchQuery.trim()}"');
    final keywords = result.requestedIntent.remainingKeywords;
    debugPrint(
      'Parsed → food: ${result.requestedIntent.food ?? "-"}, '
      'city: ${result.requestedIntent.city ?? "-"}, '
      'occupant: ${result.requestedIntent.occupant ?? "-"}, '
      'gender: ${result.requestedIntent.gender ?? "-"}, '
      'keywords: ${keywords.isEmpty ? "-" : keywords.join(", ")}',
    );
    if (result.filtersWereRelaxed) {
      debugPrint(
        'Relaxed: ${result.relaxedConstraints.join(", ")} '
        'closest=${result.usedClosestMatchFallback}',
      );
    }
    debugPrint(
      'Counts → tower: ${result.afterTower.length}, '
      'after filters: ${result.afterFilters.length}, '
      'ranked: ${result.ranked.length}',
    );
    if (result.searchSummary != null) {
      debugPrint(result.searchSummary);
    }
    ListingMatchEngine.debugLogRanked(
      result.ranked,
      ViewerProfile.fromSession(userSession),
    );
    debugPrint('--- end pipeline ---');
  }
}
