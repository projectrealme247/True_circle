import '../config/market/market_config.dart';
import 'listing_data.dart';
import 'listing_search_intent.dart';
import 'marketplace_listing_pipeline.dart';
import 'target_search_areas.dart';
import 'tower_filter_policy.dart';
import 'weighted_listing_matcher.dart';

/// Per-option inventory impact for a marketplace filter.
class FilterOptionInventoryStats {
  const FilterOptionInventoryStats({
    required this.containingCount,
    required this.filteredOutCount,
    required this.referencePoolCount,
  });

  /// Listings in the tower inventory that carry this attribute.
  final int containingCount;

  /// Listings removed from the reference pool when this option is applied.
  final int filteredOutCount;

  /// Listings visible before this filter dimension is applied (other filters active).
  final int referencePoolCount;

  /// True when this option would remove more than half of [referencePoolCount].
  bool get removesMajority =>
      referencePoolCount > 0 && filteredOutCount > referencePoolCount ~/ 2;

  String get caption {
    final space = containingCount == 1 ? 'space' : 'spaces';
    if (filteredOutCount <= 0) {
      return '$containingCount $space with this';
    }
    final removed = filteredOutCount == 1 ? 'space' : 'spaces';
    return '$containingCount $space with this · $filteredOutCount $removed filtered out';
  }
}

/// Filter dimensions shown in the marketplace sidebar.
enum FilterInventoryDimension {
  area,
  food,
  occupant,
  gender,
  layoutKeyword,
  dwellingKeyword,
  propertyTypeKeyword,
  possessionKeyword,
  smokingKeyword,
  petsKeyword,
  moveInBucket,
  householdLanguage,
  budgetMax,
}

/// Computes listing counts per filter option for the filter drawer.
class FilterInventoryAnalyzer {
  static const _propertyTypeIds = {'apartment', 'villa', 'plot'};
  static const _possessionIds = {'ready', 'construction'};

  FilterInventoryAnalyzer({
    required List<Map<String, dynamic>> allListings,
    required this.towerPropertyType,
    required this.userSession,
    this.searchQuery = '',
  }) : _towerListings = [
          for (final item in allListings)
            if (ListingData.propertyType(item) == towerPropertyType) item,
        ];

  final String towerPropertyType;
  final Map<String, dynamic>? userSession;
  final String searchQuery;
  final List<Map<String, dynamic>> _towerListings;

  int get inventoryTotal => _towerListings.length;

  FilterOptionInventoryStats statsFor(
    ListingSearchFilters currentFilters,
    FilterInventoryDimension dimension,
    String optionId,
  ) {
    final baseFilters = _clearDimension(currentFilters, dimension);
    final referencePoolCount = _visibleCount(baseFilters);
    final withOption = _applyOption(baseFilters, dimension, optionId);
    final passingCount = _visibleCount(withOption);
    final containingCount = _containingCount(dimension, optionId);

    return FilterOptionInventoryStats(
      containingCount: containingCount,
      filteredOutCount: (referencePoolCount - passingCount).clamp(0, referencePoolCount),
      referencePoolCount: referencePoolCount,
    );
  }

  /// Active filter dimensions that remove >50% of the current reference pool.
  List<({String label, FilterOptionInventoryStats stats})> highImpactActiveFilters(
    ListingSearchFilters filters,
  ) {
    final impacts = <({String label, FilterOptionInventoryStats stats})>[];
    final seen = <String>{};

    void check(String label, FilterInventoryDimension dim, String optionId) {
      final key = '${dim.name}:$optionId';
      if (!seen.add(key)) return;
      final stats = statsFor(filters, dim, optionId);
      if (stats.removesMajority) {
        impacts.add((label: label, stats: stats));
      }
    }

    for (final pill in filters.appliedPills()) {
      final dim = _pillDimension(pill.id);
      if (dim == null) continue;
      final optionId = _pillOptionId(pill.id, filters);
      if (optionId == null) continue;
      check(pill.label, dim, optionId);
    }

    return impacts;
  }

  static FilterInventoryDimension? _pillDimension(String pillId) {
    return switch (pillId) {
      'city' || 'area_refinement' => FilterInventoryDimension.area,
      'food' => FilterInventoryDimension.food,
      'occupant' => FilterInventoryDimension.occupant,
      'gender' => FilterInventoryDimension.gender,
      'budget' => FilterInventoryDimension.budgetMax,
      'movein' => FilterInventoryDimension.moveInBucket,
      'household_language' => FilterInventoryDimension.householdLanguage,
      String id when id.startsWith('bhk:') ||
          id.startsWith('bed:') ||
          id.startsWith('kw:') =>
        _keywordDimension(id.split(':').last),
      _ => null,
    };
  }

  static String? _pillOptionId(String pillId, ListingSearchFilters filters) {
    return switch (pillId) {
      'city' => filters.effectiveAreaTokens.isNotEmpty
          ? filters.effectiveAreaTokens.first
          : null,
      'area_refinement' => filters.effectiveAreaRefinements.isNotEmpty
          ? filters.effectiveAreaRefinements.first
          : null,
      'food' => filters.foodPreference,
      'occupant' => filters.occupantType,
      'gender' => filters.genderPreference,
      'budget' => filters.budgetMax?.toString(),
      'movein' => filters.moveInWindow,
      'household_language' => filters.householdLanguages.isEmpty
          ? null
          : filters.householdLanguages.first,
      String id when id.contains(':') => id.split(':').last,
      _ => null,
    };
  }

  int _visibleCount(ListingSearchFilters filters) {
    return MarketplaceListingPipeline.runWithFilters(
      allListings: _towerListings,
      towerPropertyType: towerPropertyType,
      filters: filters,
      userSession: userSession,
      searchQuery: searchQuery,
    ).afterFilters.length;
  }

  int _containingCount(FilterInventoryDimension dimension, String optionId) {
    if (_towerListings.isEmpty) return 0;
    return _towerListings
        .where((listing) => _listingHasAttribute(listing, dimension, optionId))
        .length;
  }

  static FilterInventoryDimension? _keywordDimension(String keyword) {
    for (final tower in MarketConfig.current.enabledTowers) {
      for (final (id, _) in MarketConfig.current.layoutFilterOptionsFor(tower)) {
        if (id == keyword) return FilterInventoryDimension.layoutKeyword;
      }
    }
    for (final (id, _) in MarketConfig.current.dwellingFilterOptions) {
      if (id == keyword) return FilterInventoryDimension.dwellingKeyword;
    }
    if (_propertyTypeIds.contains(keyword)) {
      return FilterInventoryDimension.propertyTypeKeyword;
    }
    if (_possessionIds.contains(keyword)) {
      return FilterInventoryDimension.possessionKeyword;
    }
    return switch (keyword) {
      'smoking' || 'no-smoking' => FilterInventoryDimension.smokingKeyword,
      'pets' || 'no-pets' => FilterInventoryDimension.petsKeyword,
      _ when RegExp(r'^\d+bhk$').hasMatch(keyword) ||
          RegExp(r'^\d+bed').hasMatch(keyword) =>
        FilterInventoryDimension.layoutKeyword,
      _ => null,
    };
  }

  static bool _listingHasAttribute(
    Map<String, dynamic> listing,
    FilterInventoryDimension dimension,
    String optionId,
  ) {
    return switch (dimension) {
      FilterInventoryDimension.area => optionId == TargetSearchAreas.allDublinToken
          ? true
          : TargetSearchAreas.isMacroToken(optionId)
              ? TargetSearchAreas.listingMatchesResolved(
                  TargetSearchAreas.resolveSearch(
                    macroTokens: [optionId],
                    refinementTokens: const [],
                  ),
                  listing,
                )
              : TargetSearchAreas.listingMatchesTargets([optionId], listing),
      FilterInventoryDimension.food =>
        ListingSearchIntent.matchesFood(listing, optionId),
      FilterInventoryDimension.occupant =>
        ListingSearchIntent.matchesOccupant(listing, optionId),
      FilterInventoryDimension.gender => optionId == 'mixed' ||
          ListingSearchIntent.matchesGender(listing, optionId),
      FilterInventoryDimension.layoutKeyword ||
      FilterInventoryDimension.dwellingKeyword ||
      FilterInventoryDimension.propertyTypeKeyword ||
      FilterInventoryDimension.possessionKeyword ||
      FilterInventoryDimension.smokingKeyword ||
      FilterInventoryDimension.petsKeyword =>
        ListingSearchIntent.matchesKeywords(listing, [optionId]),
      FilterInventoryDimension.moveInBucket =>
        ListingSearchFilters(moveInWindow: optionId).passesMoveInWindow(listing),
      FilterInventoryDimension.householdLanguage =>
        TowerFilterPolicy.matchesHouseholdLanguageOverlap(listing, [optionId]),
      FilterInventoryDimension.budgetMax => _listingWithinBudgetMax(
          listing,
          int.tryParse(optionId),
        ),
    };
  }

  static bool _listingWithinBudgetMax(
    Map<String, dynamic> listing,
    int? maxBudget,
  ) {
    if (maxBudget == null) return true;
    final amount = ListingData.listingPriceAmount(listing);
    if (amount == null) return false;
    final hardCap =
        (maxBudget * WeightedListingMatcher.budgetHardCapRatio).round();
    return amount <= hardCap;
  }

  static bool _listingIsWfhFriendly(Map<String, dynamic> listing) {
    if (listing['wfh_friendly'] == true) return true;
    return ListingData.scheduleType(listing).toLowerCase() == 'flexible';
  }

  ListingSearchFilters _clearDimension(
    ListingSearchFilters filters,
    FilterInventoryDimension dimension,
  ) {
    return switch (dimension) {
      FilterInventoryDimension.area =>
        filters.copyWith(
          city: null,
          targetSearchAreas: const [],
          targetSearchAreaRefinements: const [],
        ),
      FilterInventoryDimension.food => filters.copyWith(foodPreference: null),
      FilterInventoryDimension.occupant => filters.copyWith(occupantType: null),
      FilterInventoryDimension.gender =>
        filters.copyWith(genderPreference: null),
      FilterInventoryDimension.layoutKeyword => filters.copyWith(
          keywords: _keywordsWithoutLayout(filters.keywords),
        ),
      FilterInventoryDimension.dwellingKeyword => filters.copyWith(
          keywords: _keywordsWithoutTokens(
            filters.keywords,
            MarketConfig.current.dwellingFilterOptions.map((e) => e.$1),
          ),
        ),
      FilterInventoryDimension.propertyTypeKeyword => filters.copyWith(
          keywords: _keywordsWithoutTokens(filters.keywords, _propertyTypeIds),
        ),
      FilterInventoryDimension.possessionKeyword => filters.copyWith(
          keywords: _keywordsWithoutTokens(filters.keywords, _possessionIds),
        ),
      FilterInventoryDimension.smokingKeyword => filters.copyWith(
          keywords: _keywordsWithoutTokens(
            filters.keywords,
            const {'smoking', 'no-smoking'},
          ),
        ),
      FilterInventoryDimension.petsKeyword => filters.copyWith(
          keywords: _keywordsWithoutTokens(
            filters.keywords,
            const {'pets', 'no-pets'},
          ),
        ),
      FilterInventoryDimension.moveInBucket =>
        filters.copyWith(moveInWindow: null),
      FilterInventoryDimension.householdLanguage =>
        filters.copyWith(householdLanguages: const []),
      FilterInventoryDimension.budgetMax =>
        filters.copyWith(budgetMin: null, budgetMax: null),
    };
  }

  ListingSearchFilters _applyOption(
    ListingSearchFilters filters,
    FilterInventoryDimension dimension,
    String optionId,
  ) {
    return switch (dimension) {
      FilterInventoryDimension.area => optionId == TargetSearchAreas.allDublinToken
          ? filters.withAllDublinArea()
          : filters.copyWith(
              city: null,
              targetSearchAreas: [optionId],
              targetSearchAreaRefinements: const [],
            ),
      FilterInventoryDimension.food =>
        filters.copyWith(foodPreference: optionId),
      FilterInventoryDimension.occupant =>
        filters.copyWith(occupantType: optionId),
      FilterInventoryDimension.gender => optionId == 'mixed'
          ? filters.copyWith(genderPreference: null)
          : filters.copyWith(genderPreference: optionId),
      FilterInventoryDimension.layoutKeyword => filters.copyWith(
          keywords: [..._keywordsWithoutLayout(filters.keywords), optionId],
        ),
      FilterInventoryDimension.dwellingKeyword => filters.copyWith(
          keywords: [
            ..._keywordsWithoutTokens(
              filters.keywords,
              MarketConfig.current.dwellingFilterOptions.map((e) => e.$1),
            ),
            optionId,
          ],
        ),
      FilterInventoryDimension.propertyTypeKeyword => filters.copyWith(
          keywords: [
            ..._keywordsWithoutTokens(filters.keywords, _propertyTypeIds),
            optionId,
          ],
        ),
      FilterInventoryDimension.possessionKeyword => filters.copyWith(
          keywords: [
            ..._keywordsWithoutTokens(filters.keywords, _possessionIds),
            optionId,
          ],
        ),
      FilterInventoryDimension.smokingKeyword => filters.copyWith(
          keywords: [
            ..._keywordsWithoutTokens(
              filters.keywords,
              const {'smoking', 'no-smoking'},
            ),
            optionId,
          ],
        ),
      FilterInventoryDimension.petsKeyword => filters.copyWith(
          keywords: [
            ..._keywordsWithoutTokens(
              filters.keywords,
              const {'pets', 'no-pets'},
            ),
            optionId,
          ],
        ),
      FilterInventoryDimension.moveInBucket =>
        filters.copyWith(moveInWindow: optionId),
      FilterInventoryDimension.householdLanguage => filters.copyWith(
          householdLanguages: filters.householdLanguages.contains(optionId)
              ? filters.householdLanguages
              : [...filters.householdLanguages, optionId],
        ),
      FilterInventoryDimension.budgetMax => filters.copyWith(
          budgetMin: null,
          budgetMax: int.tryParse(optionId),
        ),
    };
  }

  static List<String> _keywordsWithoutLayout(List<String> keywords) {
    final layoutIds = <String>{
      for (final tower in MarketConfig.current.enabledTowers)
        ...MarketConfig.current.layoutFilterOptionsFor(tower).map((e) => e.$1),
      ...MarketConfig.current.bedroomFilterOptions.map((e) => e.$1),
      'bed_shared',
      'student_room',
      'double_ensuite',
    };
    return keywords.where((k) => !layoutIds.contains(k)).toList();
  }

  static List<String> _keywordsWithoutTokens(
    List<String> keywords,
    Iterable<String> remove,
  ) {
    final block = remove.toSet();
    return keywords.where((k) => !block.contains(k)).toList();
  }
}
