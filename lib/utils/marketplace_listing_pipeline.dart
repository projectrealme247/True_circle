import 'package:flutter/foundation.dart';

import '../debug/debug_session_log.dart';
import 'listing_data.dart';
import 'listing_match_engine.dart';
import 'listing_search_intent.dart';
import 'target_search_areas.dart';
import 'viewer_profile.dart';
import 'weighted_listing_matcher.dart';

const _p0TrackId = '6ab066eb-2750-42ce-a5c1-dee8cdf2b28c';

bool _p0IdInMaps(Iterable<Map<String, dynamic>> items) =>
    items.any((item) => item['id']?.toString() == _p0TrackId);

void _p0TrackLog(String stage, bool present, [String extra = '']) {
  print(
    '[P0 Track] $stage: ${present ? 'Present' : 'Missing'}'
    '${extra.isEmpty ? '' : ' $extra'}',
  );
}

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
    this.isCommuteDivergent = false,
    this.requiresOnboarding = false,
  });

  final SearchIntent requestedIntent;
  final SearchIntent appliedIntent;
  final List<Map<String, dynamic>> afterTower;
  final List<Map<String, dynamic>> afterFilters;
  final List<ScoredListing> ranked;
  final List<String> relaxedConstraints;
  final bool usedClosestMatchFallback;

  /// Path B — opposite-side commute hubs exceed max budget (zero-match feed).
  final bool isCommuteDivergent;

  /// Viewer has a profile shell but lacks fields required for ranking.
  final bool requiresOnboarding;

  bool get hasActiveSearch => !requestedIntent.isEmpty;

  bool get filtersWereRelaxed =>
      relaxedConstraints.isNotEmpty || usedClosestMatchFallback;

  String? get searchSummary {
    if (!hasActiveSearch) return null;
    final summary = appliedIntent.displaySummary;
    if (summary.isEmpty) return null;
    return 'Showing results for: $summary';
  }

  static const commuteDivergenceNotice =
      'Your commute endpoints are on opposite sides of Dublin. '
      'Consider adjusting your Maximum Commute Budget slider upward to reveal '
      'properties situated perfectly in the middle.';

  String? get relaxationNotice {
    if (isCommuteDivergent) return commuteDivergenceNotice;
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
    final normalized = filters.pipelineQueryText(
      searchText: searchQuery,
      towerPropertyType: towerPropertyType,
    );
    final scopedFilters = filters.scopedForTower(towerPropertyType);
    final weightedCriteria = WeightedFilterCriteria.fromSearchContext(
      filters: scopedFilters,
      userSession: userSession,
      towerPropertyType: towerPropertyType,
    );

    final result = run(
      allListings: allListings,
      towerPropertyType: towerPropertyType,
      searchQuery: normalized,
      userSession: userSession,
      searchIntent: scopedFilters.toSearchIntent(
        mergeQuery: normalized,
        towerPropertyType: towerPropertyType,
      ),
      weightedCriteria: weightedCriteria,
      searchFilters: scopedFilters,
    );

    // #region agent log
    debugSessionLog(
      location: 'marketplace_listing_pipeline.dart:runWithFilters',
      message: 'pipeline stage counts',
      hypothesisId: 'A,E',
      data: {
        'tower': towerPropertyType,
        'pipelineQuery': normalized,
        'filterOccupant': filters.occupantType,
        'filterGender': filters.genderPreference,
        'filterBudgetMax': filters.budgetMax,
        'afterTower': result.afterTower.length,
        'afterFilters': result.afterFilters.length,
        'ranked': result.ranked.length,
        'searchIntentOccupant': result.requestedIntent.occupant,
        'hasStrongFilters': result.requestedIntent.hasStrongFilters,
      },
    );
    // #endregion

    final resolution = scopedFilters.resolvedAreaSearch;
    var filtered = result.afterFilters;
    if (!resolution.isAllDublin) {
      filtered = [
        for (final item in filtered)
          if (TargetSearchAreas.listingMatchesResolved(resolution, item)) item,
      ];
    } else if (scopedFilters.effectiveAreaRefinements.isNotEmpty) {
      filtered = [
        for (final item in filtered)
          if (TargetSearchAreas.listingMatchesTargets(
            scopedFilters.effectiveAreaTokens,
            item,
            refinementTokens: scopedFilters.effectiveAreaRefinements,
          ))
            item,
      ];
    }

    final weightedPool = WeightedListingMatcher.fetchScoredListings(
      listings: filtered,
      criteria: weightedCriteria,
      filters: scopedFilters,
      towerPropertyType: towerPropertyType,
    );

    final rankOutcome = ListingMatchEngine.rank(
      weightedPool,
      userSession,
      searchIntent: result.requestedIntent.hasStructuredFilters
          ? result.requestedIntent
          : null,
      appliedSearchIntent: result.appliedIntent,
      filtersWereRelaxed: result.filtersWereRelaxed,
      weightedCriteria: weightedCriteria,
    );
    _p0TrackLog(
      'afterAreaFilter',
      _p0IdInMaps(filtered),
      'isAllDublin=${resolution.isAllDublin}',
    );
    _p0TrackLog('afterHardExclusion', _p0IdInMaps(weightedPool));
    _p0TrackLog(
      'afterRanking',
      rankOutcome.ranked.any(
        (s) => s.listing['id']?.toString() == _p0TrackId,
      ),
      'requiresOnboarding=${rankOutcome.requiresOnboarding} '
      'rankedCount=${rankOutcome.ranked.length}',
    );

    return MarketplaceListingPipelineResult(
      requestedIntent: result.requestedIntent,
      appliedIntent: result.appliedIntent,
      afterTower: result.afterTower,
      afterFilters: weightedPool,
      ranked: rankOutcome.ranked,
      relaxedConstraints: result.relaxedConstraints,
      usedClosestMatchFallback: result.usedClosestMatchFallback,
      isCommuteDivergent: rankOutcome.isCommuteDivergent,
      requiresOnboarding: rankOutcome.requiresOnboarding,
    );
  }

  static MarketplaceListingPipelineResult run({
    required List<Map<String, dynamic>> allListings,
    required String towerPropertyType,
    required String searchQuery,
    required Map<String, dynamic>? userSession,
    SearchIntent? searchIntent,
    WeightedFilterCriteria? weightedCriteria,
    ListingSearchFilters? searchFilters,
  }) {
    final afterTower = [
      for (final item in allListings)
        // Marketplace Separation V1: Rent / Share / Buy inventories never mix.
        if (ListingData.listingType(item) == towerPropertyType) item,
    ];
    Map<String, dynamic>? tracked;
    for (final item in allListings) {
      if (item['id']?.toString() == _p0TrackId) {
        tracked = item;
        break;
      }
    }
    _p0TrackLog(
      'afterTower',
      _p0IdInMaps(afterTower),
      tracked == null
          ? 'not in pipeline input tower=$towerPropertyType'
          : 'listingType=${ListingData.listingType(tracked)} '
              'expected=$towerPropertyType',
    );

    final requestedIntent =
        searchIntent ?? ListingSearchIntent.parseQuery(searchQuery);

    final filterOutcome = ListingSearchIntent.applyFiltersWithRelaxation(
      afterTower,
      searchQuery,
      intent: requestedIntent,
    );
    _p0TrackLog(
      'afterIntentFilters',
      _p0IdInMaps(filterOutcome.listings),
      'query="$searchQuery"',
    );

    final criteria = weightedCriteria ??
        (searchFilters != null
            ? WeightedFilterCriteria.fromSearchContext(
                filters: searchFilters,
                userSession: userSession,
                towerPropertyType: towerPropertyType,
              )
            : WeightedFilterCriteria.fromSearchContext(
                filters: ListingSearchFilters.fromIntent(requestedIntent),
                userSession: userSession,
                towerPropertyType: towerPropertyType,
              ));

    final activeFilters = searchFilters ??
        ListingSearchFilters.fromIntent(requestedIntent)
            .scopedForTower(towerPropertyType);

    final pool = WeightedListingMatcher.fetchScoredListings(
      listings: filterOutcome.listings,
      criteria: criteria,
      filters: activeFilters,
      towerPropertyType: towerPropertyType,
    );
    _p0TrackLog('afterHardExclusion(run)', _p0IdInMaps(pool));

    final searchIntentForRanking = requestedIntent.hasStructuredFilters
        ? requestedIntent
        : null;

    final rankOutcome = ListingMatchEngine.rank(
      pool,
      userSession,
      searchIntent: searchIntentForRanking,
      appliedSearchIntent: filterOutcome.appliedIntent,
      filtersWereRelaxed: filterOutcome.wasRelaxed,
      weightedCriteria: criteria,
    );

    return MarketplaceListingPipelineResult(
      requestedIntent: requestedIntent,
      appliedIntent: filterOutcome.appliedIntent,
      afterTower: afterTower,
      afterFilters: pool,
      ranked: rankOutcome.ranked,
      relaxedConstraints: filterOutcome.relaxedConstraints,
      usedClosestMatchFallback: filterOutcome.usedClosestMatchFallback,
      isCommuteDivergent: rankOutcome.isCommuteDivergent,
      requiresOnboarding: rankOutcome.requiresOnboarding,
    );
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
