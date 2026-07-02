import '../config/market/market_config.dart';
import 'city_area_match.dart';
import 'listing_data.dart';
import 'dublin_macro_search.dart';
import 'target_search_areas.dart';

/// Structured filters parsed from a natural-language search query.
class SearchIntent {
  const SearchIntent({
    this.food,
    this.city,
    this.occupant,
    this.gender,
    this.remainingKeywords = const [],
  });

  /// `veg` or `non-veg`
  final String? food;

  /// Canonical city token, e.g. `hyderabad`
  final String? city;

  /// `Family`, `Bachelors`, or `Students`
  final String? occupant;

  /// `girls` or `boys`
  final String? gender;

  final List<String> remainingKeywords;

  bool get isEmpty =>
      food == null &&
      city == null &&
      occupant == null &&
      gender == null &&
      remainingKeywords.isEmpty;

  bool get hasStructuredFilters =>
      food != null ||
      city != null ||
      occupant != null ||
      gender != null ||
      remainingKeywords.isNotEmpty;

  /// Never relaxed: occupant type, gender, free-text keywords (e.g. 2bhk).
  bool get hasStrongFilters =>
      occupant != null || gender != null || remainingKeywords.isNotEmpty;

  /// May be relaxed when no results: food, city/location.
  bool get hasSoftFilters => food != null || city != null;

  /// Human-readable summary for the search results banner.
  String get displaySummary {
    final parts = <String>[];
    if (food != null) {
      parts.add(food == 'veg' ? 'Veg' : 'Non-veg');
    }
    if (city != null) {
      parts.add(ListingSearchIntent.cityDisplayName(city!));
    }
    if (occupant != null) parts.add(occupant!);
    if (gender != null) {
      parts.add(gender == 'girls' ? 'Girls' : 'Boys');
    }
    for (final keyword in remainingKeywords) {
      final bhk = RegExp(r'^(\d+)bhk$').firstMatch(keyword);
      if (bhk != null) {
        parts.add('${bhk.group(1)} BHK');
        continue;
      }
      final bed = RegExp(r'^(\d+)bed$').firstMatch(keyword);
      if (bed != null) {
        parts.add('${bed.group(1)} Bed');
        continue;
      }
      final locality = ListingSearchIntent.localityDisplayName(keyword);
      if (locality != null) {
        parts.add(locality);
        continue;
      }
      if (keyword.length >= 2) parts.add(_titleCase(keyword));
    }
    return parts.join(' • ');
  }

  SearchIntent copyRelaxing({String? removeConstraint}) {
    return SearchIntent(
      food: removeConstraint == 'food' ? null : food,
      city: removeConstraint == 'city' ? null : city,
      occupant: occupant,
      gender: removeConstraint == 'gender' ? null : gender,
      remainingKeywords: remainingKeywords,
    );
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

/// Outcome of filter step with optional progressive relaxation.
class SearchFilterOutcome {
  const SearchFilterOutcome({
    required this.listings,
    required this.appliedIntent,
    required this.requestedIntent,
    this.relaxedConstraints = const [],
    this.usedClosestMatchFallback = false,
  });

  final List<Map<String, dynamic>> listings;
  final SearchIntent appliedIntent;
  final SearchIntent requestedIntent;
  final List<String> relaxedConstraints;
  final bool usedClosestMatchFallback;

  bool get wasRelaxed =>
      relaxedConstraints.isNotEmpty || usedClosestMatchFallback;
}

const _filterUnset = Object();

/// One active filter shown in the applied-pills row.
class AppliedFilterPill {
  const AppliedFilterPill({required this.id, required this.label});

  final String id;
  final String label;
}

/// Explicit marketplace search filters (passed directly into search, not via delayed state).
class ListingSearchFilters {
  const ListingSearchFilters({
    this.foodPreference,
    this.city,
    this.targetSearchAreas = const [],
    this.occupantType,
    this.genderPreference,
    this.budgetMin,
    this.budgetMax,
    this.preferredLeaseMonths,
    this.moveInWindow,
    this.wfhFriendly,
    this.keywords = const [],
  });

  final String? foodPreference;

  /// Legacy single city key — prefer [targetSearchAreas] when set.
  final String? city;

  /// Area tokens (`dublin4`, `ALL_DUBLIN`, …) — matches [TargetSearchAreas].
  final List<String> targetSearchAreas;

  final String? occupantType;
  final String? genderPreference;
  final int? budgetMin;
  final int? budgetMax;
  final int? preferredLeaseMonths;
  final String? moveInWindow;
  final bool? wfhFriendly;

  /// Free-text tokens (e.g. `2bhk`, `furnished`) from the search box.
  final List<String> keywords;

  List<String> get effectiveAreaTokens {
    if (targetSearchAreas.isNotEmpty) {
      return TargetSearchAreas.normalizeTokens(targetSearchAreas);
    }
    if (city != null && city!.isNotEmpty) return [city!];
    return const [];
  }

  bool get isAllDublinMacro =>
      TargetSearchAreas.hasAllDublin(effectiveAreaTokens);

  ListingSearchFilters withAllDublinArea() => copyWith(
        city: null,
        targetSearchAreas: TargetSearchAreas.allDublinFilterTokens,
      );

  ListingSearchFilters withoutAllDublinMacro() {
    if (!isAllDublinMacro) return this;
    return copyWith(city: null, targetSearchAreas: const []);
  }

  bool get isEmpty =>
      foodPreference == null &&
      effectiveAreaTokens.isEmpty &&
      occupantType == null &&
      genderPreference == null &&
      budgetMin == null &&
      budgetMax == null &&
      preferredLeaseMonths == null &&
      (moveInWindow == null || moveInWindow!.isEmpty) &&
      wfhFriendly == null &&
      keywords.isEmpty;

  ListingSearchFilters copyWith({
    Object? foodPreference = _filterUnset,
    Object? city = _filterUnset,
    List<String>? targetSearchAreas,
    Object? occupantType = _filterUnset,
    Object? genderPreference = _filterUnset,
    Object? budgetMin = _filterUnset,
    Object? budgetMax = _filterUnset,
    Object? preferredLeaseMonths = _filterUnset,
    Object? moveInWindow = _filterUnset,
    Object? wfhFriendly = _filterUnset,
    List<String>? keywords,
  }) {
    return ListingSearchFilters(
      foodPreference: identical(foodPreference, _filterUnset)
          ? this.foodPreference
          : foodPreference as String?,
      city: identical(city, _filterUnset) ? this.city : city as String?,
      targetSearchAreas: targetSearchAreas ?? this.targetSearchAreas,
      occupantType: identical(occupantType, _filterUnset)
          ? this.occupantType
          : occupantType as String?,
      genderPreference: identical(genderPreference, _filterUnset)
          ? this.genderPreference
          : genderPreference as String?,
      budgetMin:
          identical(budgetMin, _filterUnset) ? this.budgetMin : budgetMin as int?,
      budgetMax:
          identical(budgetMax, _filterUnset) ? this.budgetMax : budgetMax as int?,
      preferredLeaseMonths: identical(preferredLeaseMonths, _filterUnset)
          ? this.preferredLeaseMonths
          : preferredLeaseMonths as int?,
      moveInWindow: identical(moveInWindow, _filterUnset)
          ? this.moveInWindow
          : moveInWindow as String?,
      wfhFriendly: identical(wfhFriendly, _filterUnset)
          ? this.wfhFriendly
          : wfhFriendly as bool?,
      keywords: keywords ?? this.keywords,
    );
  }

  static String areaChipLabel(List<String> tokens) {
    if (tokens.isEmpty) return '';
    if (TargetSearchAreas.hasAllDublin(tokens)) {
      return 'Area: ${TargetSearchAreas.allDublinLabel}';
    }
    return 'Area: ${ListingSearchIntent.cityDisplayName(tokens.first)}';
  }

  /// Human-readable active filters for the chip bar pills row.
  List<AppliedFilterPill> appliedPills() {
    final pills = <AppliedFilterPill>[];
    final areaTokens = effectiveAreaTokens;
    if (areaTokens.isNotEmpty) {
      pills.add(AppliedFilterPill(
        id: 'city',
        label: areaChipLabel(areaTokens),
      ));
    }
    if (foodPreference != null) {
      pills.add(AppliedFilterPill(
        id: 'food',
        label: foodPreference == 'veg' ? 'Veg' : 'Non-veg',
      ));
    }
    if (occupantType != null) {
      pills.add(AppliedFilterPill(id: 'occupant', label: occupantType!));
    }
    if (genderPreference != null) {
      pills.add(AppliedFilterPill(
        id: 'gender',
        label: genderPreference == 'girls' ? 'Girls only' : 'Boys only',
      ));
    }
    if (budgetMin != null || budgetMax != null) {
      pills.add(AppliedFilterPill(
        id: 'budget',
        label: _budgetLabel(),
      ));
    }
    if (preferredLeaseMonths != null) {
      pills.add(AppliedFilterPill(
        id: 'lease',
        label: 'Lease: $preferredLeaseMonths mo',
      ));
    }
    if (moveInWindow != null && moveInWindow!.isNotEmpty) {
      pills.add(AppliedFilterPill(
        id: 'movein',
        label: 'Move-in: $moveInWindow',
      ));
    }
    if (wfhFriendly == true) {
      pills.add(const AppliedFilterPill(id: 'wfh', label: 'WFH Friendly'));
    }
    for (final keyword in keywords) {
      final configLabel = _filterKeywordLabel(keyword);
      if (configLabel != null) {
        pills.add(AppliedFilterPill(id: 'kw:$keyword', label: configLabel));
        continue;
      }
      final bhk = RegExp(r'^(\d+)bhk$').firstMatch(keyword);
      if (bhk != null) {
        pills.add(AppliedFilterPill(
          id: 'bhk:$keyword',
          label: '${bhk.group(1)} BHK',
        ));
        continue;
      }
      final bed = RegExp(r'^(\d+)bed$').firstMatch(keyword);
      if (bed != null) {
        pills.add(AppliedFilterPill(
          id: 'bed:$keyword',
          label: '${bed.group(1)} Bed',
        ));
        continue;
      }
      final locality = ListingSearchIntent.localityDisplayName(keyword);
      if (locality != null) {
        pills.add(AppliedFilterPill(id: 'kw:$keyword', label: locality));
        continue;
      }
      pills.add(AppliedFilterPill(
        id: 'kw:$keyword',
        label: _titleCaseKeyword(keyword),
      ));
    }
    return pills;
  }

  ListingSearchFilters withoutPill(String pillId) {
    if (pillId == 'city') {
      return copyWith(city: null, targetSearchAreas: const []);
    }
    if (pillId == 'food') return copyWith(foodPreference: null);
    if (pillId == 'occupant') return copyWith(occupantType: null);
    if (pillId == 'gender') return copyWith(genderPreference: null);
    if (pillId == 'budget') {
      return copyWith(budgetMin: null, budgetMax: null);
    }
    if (pillId == 'lease') return copyWith(preferredLeaseMonths: null);
    if (pillId == 'movein') return copyWith(moveInWindow: null);
    if (pillId == 'wfh') return copyWith(wfhFriendly: null);
    if (pillId.startsWith('bhk:') ||
        pillId.startsWith('bed:') ||
        pillId.startsWith('kw:')) {
      final token = pillId.contains(':') ? pillId.split(':').last : pillId;
      return copyWith(
        keywords: keywords.where((k) => k != token).toList(),
      );
    }
    return this;
  }

  String _budgetLabel() =>
      MarketConfig.current.formatBudgetRange(budgetMin, budgetMax);

  static String _titleCaseKeyword(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  static String? _filterKeywordLabel(String keyword) {
    for (final tower in MarketConfig.current.enabledTowers) {
      for (final (id, label) in MarketConfig.current.layoutFilterOptionsFor(tower)) {
        if (id == keyword) return label;
      }
    }
    for (final (id, label) in MarketConfig.current.dwellingFilterOptions) {
      if (id == keyword) return label;
    }
    return null;
  }

  factory ListingSearchFilters.fromIntent(SearchIntent intent) {
    return ListingSearchFilters(
      foodPreference: intent.food,
      city: null,
      targetSearchAreas:
          intent.city != null ? [intent.city!] : const [],
      occupantType: intent.occupant,
      genderPreference: intent.gender,
      keywords: intent.remainingKeywords,
    );
  }

  /// Merges explicit filters with a full query parse (keywords, BHK, etc.).
  SearchIntent toSearchIntent({String? mergeQuery}) {
    final areaTokens = effectiveAreaTokens;
    final areaCity = areaTokens.isEmpty || isAllDublinMacro
        ? null
        : areaTokens.first;

    if (mergeQuery == null || mergeQuery.trim().isEmpty) {
      return SearchIntent(
        food: foodPreference,
        city: areaCity,
        occupant: occupantType,
        gender: genderPreference,
        remainingKeywords: keywords,
      );
    }

    final parsed = isAllDublinMacro
        ? const SearchIntent()
        : ListingSearchIntent.parseQuery(mergeQuery);
    return SearchIntent(
      food: foodPreference ?? parsed.food,
      city: isAllDublinMacro ? null : (areaCity ?? parsed.city),
      occupant: occupantType ?? parsed.occupant,
      gender: genderPreference ?? parsed.gender,
      remainingKeywords: isAllDublinMacro
          ? keywords
          : _mergeKeywords(keywords, parsed.remainingKeywords),
    );
  }

  static List<String> _mergeKeywords(
    List<String> a,
    List<String> b,
  ) {
    final seen = <String>{};
    final out = <String>[];
    for (final k in [...a, ...b]) {
      final key = k.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(key);
    }
    return out;
  }

  /// Normalized query string for the listing pipeline.
  String toPipelineQuery() {
    final parts = <String>[];
    if (foodPreference != null) parts.add(foodPreference!);
    final tokens = effectiveAreaTokens;
    if (tokens.isNotEmpty && !isAllDublinMacro) {
      parts.add(tokens.first);
    }
    // ALL_DUBLIN is carried only in [targetSearchAreas] — never as query text
    // (parsing "all of dublin" incorrectly extracts a micro district like dublin4).
    if (occupantType != null) parts.add(occupantType!.toLowerCase());
    if (genderPreference != null) parts.add(genderPreference!);
    parts.addAll(keywords);
    return ListingSearchIntent.normalizeQuery(parts.join(' '));
  }

  /// Query string for the listing pipeline — never emits macro area text.
  String pipelineQueryText({String searchText = ''}) {
    final trimmed = searchText.trim();
    if (trimmed.isNotEmpty) {
      return ListingSearchIntent.normalizeQuery(trimmed);
    }
    if (isAllDublinMacro) return '';
    return toPipelineQuery();
  }

  @override
  String toString() =>
      'ListingSearchFilters(foodPreference: $foodPreference, city: $city, '
      'occupantType: $occupantType, genderPreference: $genderPreference, '
      'preferredLeaseMonths: $preferredLeaseMonths, moveInWindow: $moveInWindow, '
      'wfhFriendly: $wfhFriendly, keywords: $keywords)';

  /// Flexible AND filter — city uses substring; food/occupant use case-insensitive match.
  bool matchesListing(Map<String, dynamic> listing) {
    final tokens = effectiveAreaTokens;
    if (tokens.isNotEmpty &&
        !TargetSearchAreas.listingMatchesTargets(tokens, listing)) {
      return false;
    }
    if (foodPreference != null &&
        !ListingData.matchesFoodPreferenceFilter(listing, foodPreference!)) {
      return false;
    }
    if (occupantType != null &&
        !ListingData.matchesOccupantTypeFilter(listing, occupantType!)) {
      return false;
    }
    if (genderPreference != null &&
        !ListingSearchIntent.listingMatchesGender(
          listing,
          genderPreference!,
        )) {
      return false;
    }
    if (budgetMin != null || budgetMax != null) {
      final amount = ListingData.listingPriceAmount(listing);
      if (amount == null) return false;
      if (budgetMin != null && amount < budgetMin!) return false;
      if (budgetMax != null && amount > budgetMax!) return false;
    }
    if (preferredLeaseMonths != null) {
      final leaseLength = int.tryParse(
        ListingData.text(listing['preferred_lease_months']),
      );
      if (leaseLength != null && leaseLength < preferredLeaseMonths!) {
        return false;
      }
    }
    if (moveInWindow != null && moveInWindow!.isNotEmpty) {
      final requestedMoveIn = DateTime.tryParse(moveInWindow!);
      final availableFrom = DateTime.tryParse(
        ListingData.text(listing['available_from']),
      );
      if (requestedMoveIn != null &&
          availableFrom != null &&
          availableFrom.isAfter(requestedMoveIn)) {
        return false;
      }
    }
    if (wfhFriendly == true) {
      final schedule = ListingData.scheduleType(listing).toLowerCase();
      final supportsWfh = listing['wfh_friendly'] == true || schedule == 'flexible';
      if (!supportsWfh) return false;
    }
    if (keywords.isNotEmpty &&
        !ListingSearchIntent.matchesKeywords(listing, keywords)) {
      return false;
    }
    return true;
  }
}

/// Google-style intent search: map keywords → filters, AND matching, fuzzy fallback.
abstract final class ListingSearchIntent {
  static const _stopWords = {
    'in',
    'at',
    'on',
    'for',
    'the',
    'a',
    'an',
    'near',
    'with',
    'and',
    'or',
    'to',
    'of',
  };

  /// Broad aliases for listing → city grouping (suggestions, cards).
  static Map<String, List<String>> get _cityAliases =>
      MarketConfig.current.cityAliases;

  /// City-level tokens only (whole-city filter). Localities use [remainingKeywords].
  static Map<String, List<String>> get _parseCityAliases =>
      MarketConfig.current.parseCityAliases;

  /// Neighborhood / area tokens — match title & location text, not entire city.
  static List<String> get _localityKeywords =>
      MarketConfig.current.localityKeywords;

  static Set<String> get _localityKeywordSet =>
      Set<String>.from(_localityKeywords);

  static Map<String, String> get _localityDisplayNames =>
      MarketConfig.current.localityDisplayNames;

  static String? localityDisplayName(String keyword) =>
      _localityDisplayNames[keyword];

  /// Step 1 — Normalize raw search text.
  static String normalizeQuery(String rawQuery) => _normalizeQuery(rawQuery);

  /// Step 2 — Convert query into structured filters.
  static SearchIntent parseQuery(String rawQuery) {
    final query = normalizeQuery(rawQuery);
    if (query.isEmpty) return const SearchIntent();
    if (DublinMacroSearch.isExactMacroPhrase(rawQuery)) {
      return const SearchIntent();
    }
    return parse(query);
  }

  static Map<String, String> get _cityDisplayNames =>
      MarketConfig.current.cityDisplayNames;

  static String cityDisplayName(String cityKey) {
    if (cityKey == TargetSearchAreas.allDublinToken) {
      return TargetSearchAreas.allDublinLabel;
    }
    return _cityDisplayNames[cityKey] ?? SearchIntent._titleCase(cityKey);
  }

  /// Canonical city key from a listing's location/host city, if recognized.
  static String? canonicalCityForListing(Map<String, dynamic> item) {
    final loc = ListingData.location(item).toLowerCase();
    final host = ListingData.hostCity(item).toLowerCase();
    for (final entry in _cityAliases.entries) {
      for (final alias in entry.value) {
        if (loc.contains(alias) || host.contains(alias)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Whether [listing] matches a parsed gender filter.
  static bool listingMatchesGender(
    Map<String, dynamic> item,
    String gender,
  ) =>
      _genderMatches(item, gender);

  /// Step 2 — Strong + soft AND filters (occupant/gender/keywords, then food/city).
  static List<Map<String, dynamic>> applyFiltersStrict(
    List<Map<String, dynamic>> listings,
    SearchIntent intent,
  ) {
    if (intent.isEmpty) return listings;
    return [
      for (final item in listings)
        if (_matchesStrict(item, intent)) item,
    ];
  }

  /// Strong filters only: occupant, gender, keywords — never relaxed.
  static List<Map<String, dynamic>> applyStrongFilters(
    List<Map<String, dynamic>> listings,
    SearchIntent intent,
  ) {
    if (!intent.hasStrongFilters) return listings;
    return [
      for (final item in listings)
        if (_matchesStrongFilters(item, intent)) item,
    ];
  }

  /// Soft filters only: food, location — may be relaxed when no matches.
  static List<Map<String, dynamic>> applySoftFilters(
    List<Map<String, dynamic>> listings,
    SearchIntent intent,
  ) {
    if (!intent.hasSoftFilters) return listings;
    return [
      for (final item in listings)
        if (_matchesSoftFilters(item, intent)) item,
    ];
  }

  /// Parse → strong filters → soft filters → relax soft only if empty.
  static SearchFilterOutcome applyFiltersWithRelaxation(
    List<Map<String, dynamic>> listings,
    String rawQuery, {
    SearchIntent? intent,
  }) {
    final query = normalizeQuery(rawQuery);
    if (query.isEmpty) {
      return SearchFilterOutcome(
        listings: listings,
        appliedIntent: const SearchIntent(),
        requestedIntent: const SearchIntent(),
      );
    }

    final requested = intent ?? parse(query);
    if (requested.isEmpty) {
      final legacy = _legacyKeywordFilter(listings, query);
      return SearchFilterOutcome(
        listings: legacy.isNotEmpty ? legacy : listings,
        appliedIntent: requested,
        requestedIntent: requested,
        usedClosestMatchFallback: legacy.isEmpty && listings.isNotEmpty,
      );
    }

    final strongPool = applyStrongFilters(listings, requested);
    if (requested.hasStrongFilters && strongPool.isEmpty) {
      return SearchFilterOutcome(
        listings: const [],
        appliedIntent: requested,
        requestedIntent: requested,
      );
    }

    final base = requested.hasStrongFilters ? strongPool : listings;

    var applied = requested;
    var result = applySoftFilters(base, applied);
    if (result.isNotEmpty) {
      return SearchFilterOutcome(
        listings: result,
        appliedIntent: applied,
        requestedIntent: requested,
      );
    }

    if (!requested.hasSoftFilters) {
      return SearchFilterOutcome(
        listings: const [],
        appliedIntent: requested,
        requestedIntent: requested,
      );
    }

    const relaxOrder = ['city', 'food'];
    final relaxed = <String>[];

    for (final constraint in relaxOrder) {
      if (!_intentHas(applied, constraint)) continue;
      applied = applied.copyRelaxing(removeConstraint: constraint);
      relaxed.add(constraint);
      result = applySoftFilters(base, applied);
      if (result.isNotEmpty) {
        return SearchFilterOutcome(
          listings: result,
          appliedIntent: applied,
          requestedIntent: requested,
          relaxedConstraints: List.unmodifiable(relaxed),
        );
      }
    }

    if (requested.hasStrongFilters) {
      return SearchFilterOutcome(
        listings: const [],
        appliedIntent: requested,
        requestedIntent: requested,
        relaxedConstraints: List.unmodifiable(relaxed),
      );
    }

    final closest = _closestMatches(listings, requested, query);
    return SearchFilterOutcome(
      listings: closest,
      appliedIntent: requested,
      requestedIntent: requested,
      relaxedConstraints: List.unmodifiable(relaxed),
      usedClosestMatchFallback: closest.isNotEmpty,
    );
  }

  /// Step 3 — Apply filters (strict AND, then closest-match fallback).
  static List<Map<String, dynamic>> applyFilters(
    List<Map<String, dynamic>> listings,
    String rawQuery, {
    SearchIntent? intent,
  }) {
    return applyFiltersWithRelaxation(
      listings,
      rawQuery,
      intent: intent,
    ).listings;
  }

  static bool _intentHas(SearchIntent intent, String constraint) {
    return switch (constraint) {
      'city' => intent.city != null,
      'gender' => intent.gender != null,
      'occupant' => intent.occupant != null,
      'food' => intent.food != null,
      _ => false,
    };
  }

  /// Whether [listing] matches a single parsed search dimension (for ranking boosts).
  static bool matchesFood(Map<String, dynamic> listing, String food) =>
      ListingData.matchesFoodPreferenceFilter(listing, food);

  static bool matchesCity(Map<String, dynamic> listing, String city) =>
      ListingData.matchesCityFilter(listing, city);

  static bool matchesOccupant(Map<String, dynamic> listing, String occupant) =>
      ListingData.matchesOccupantTypeFilter(listing, occupant);

  static bool matchesKeywords(
    Map<String, dynamic> listing,
    List<String> keywords,
  ) {
    if (keywords.isEmpty) return true;
    final blob = ListingData.searchText(listing);
    return keywords.every((k) => _keywordMatches(blob, k));
  }

  /// Strict occupant filter — listing must have the exact occupant type set.
  static bool listingMatchesOccupantType(
    Map<String, dynamic> listing,
    String occupant,
  ) =>
      _occupantMatches(listing, occupant);

  static bool matchesGender(Map<String, dynamic> listing, String gender) =>
      _genderMatches(listing, gender);

  /// Parse + apply in one call (convenience).
  static List<Map<String, dynamic>> filter(
    List<Map<String, dynamic>> listings,
    String rawQuery,
  ) {
    final intent = parseQuery(rawQuery);
    return applyFilters(listings, rawQuery, intent: intent);
  }

  static final RegExp _bhkSpacedPattern =
      RegExp(r'(\d+)\s*bhk', caseSensitive: false);
  static final RegExp _bhkCompactPattern =
      RegExp(r'(\d+)bhk', caseSensitive: false);
  static final RegExp _bedSpacedPattern =
      RegExp(r'(\d+)\s*-?\s*bed(?:room)?s?', caseSensitive: false);
  static final RegExp _bedCompactPattern =
      RegExp(r'(\d+)bed(?!room)', caseSensitive: false);

  static SearchIntent parse(String normalizedQuery) {
    if (normalizedQuery.isEmpty) return const SearchIntent();

    final consumed = <_QuerySpan>[];
    final bedroomKeywords = <String>[];

    void consumeMatch(RegExpMatch match) {
      consumed.add(_QuerySpan(match.start, match.end));
    }

    for (final match in _bhkSpacedPattern.allMatches(normalizedQuery)) {
      if (!_spanAvailable(consumed, match.start, match.end)) continue;
      final beds = match.group(1);
      if (beds == null) continue;
      final token = '${beds}bhk';
      if (!bedroomKeywords.contains(token)) bedroomKeywords.add(token);
      consumeMatch(match);
    }
    for (final match in _bhkCompactPattern.allMatches(normalizedQuery)) {
      if (!_spanAvailable(consumed, match.start, match.end)) continue;
      final beds = match.group(1);
      if (beds == null) continue;
      final token = '${beds}bhk';
      if (!bedroomKeywords.contains(token)) bedroomKeywords.add(token);
      consumeMatch(match);
    }
    for (final match in _bedSpacedPattern.allMatches(normalizedQuery)) {
      if (!_spanAvailable(consumed, match.start, match.end)) continue;
      final beds = match.group(1);
      if (beds == null) continue;
      final token = '${beds}bed';
      if (!bedroomKeywords.contains(token)) bedroomKeywords.add(token);
      consumeMatch(match);
    }
    for (final match in _bedCompactPattern.allMatches(normalizedQuery)) {
      if (!_spanAvailable(consumed, match.start, match.end)) continue;
      final beds = match.group(1);
      if (beds == null) continue;
      final token = '${beds}bed';
      if (!bedroomKeywords.contains(token)) bedroomKeywords.add(token);
      consumeMatch(match);
    }

    final food = _extractBoundedPhrase(
      normalizedQuery,
      consumed,
      const [
        (['non veg', 'non-veg', 'nonvegetarian', 'non vegetarian'], 'non-veg'),
        (['vegetarian', 'vegetarians'], 'veg'),
        (['veg'], 'veg'),
      ],
    );

    final cityMatch = CityAreaMatch.findFirstMatch(
      normalizedQuery,
      isAvailable: (start, end) => _spanAvailable(consumed, start, end),
    );
    String? city;
    if (cityMatch != null) {
      city = cityMatch.$1;
      consumed.add(_QuerySpan(cityMatch.$2, cityMatch.$3));
    }

    final localityKeywords = <String>[];
    final sortedLocalities = [..._localityKeywords]
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final loc in sortedLocalities) {
      for (final match in CityAreaMatch.aliasPattern(loc).allMatches(
        normalizedQuery,
      )) {
        if (!_spanAvailable(consumed, match.start, match.end)) continue;
        final canon = _canonicalLocality(loc);
        if (!localityKeywords.contains(canon)) localityKeywords.add(canon);
        consumeMatch(match);
      }
    }

    final occupant = _extractBoundedPhrase(
      normalizedQuery,
      consumed,
      const [
        (['bachelors only', 'bachelors', 'bachelor'], 'Bachelors'),
        (['students', 'student'], 'Students'),
        (['families', 'family'], 'Family'),
      ],
    );

    final gender = _extractBoundedPhrase(
      normalizedQuery,
      consumed,
      const [
        (['females', 'female', 'girls', 'girl'], 'girls'),
        (['males', 'male', 'boys', 'boy'], 'boys'),
      ],
    );

    final working = _queryMinusSpans(normalizedQuery, consumed);
    final tokens = working
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && !_stopWords.contains(t))
        .toList();

    final remaining = <String>[...bedroomKeywords, ...localityKeywords];

    for (final token in tokens) {
      final parsedFood = food ?? _foodFromToken(token);
      final parsedCity = city ?? _cityFromToken(token);
      final parsedOccupant = occupant ?? _occupantFromToken(token);
      final parsedGender = gender ?? _genderFromToken(token);

      if (const {'bhk', 'bed', 'beds', 'bedroom', 'bedrooms'}.contains(token) &&
          bedroomKeywords.isNotEmpty) {
        continue;
      }
      if (RegExp(r'^\d+$').hasMatch(token) &&
          bedroomKeywords.any((b) => b.startsWith(token))) {
        continue;
      }
      if (_localityKeywordSet.contains(token) ||
          _localityKeywordSet.contains(_canonicalLocality(token))) {
        final loc = _canonicalLocality(token);
        if (!remaining.contains(loc)) remaining.add(loc);
        continue;
      }

      if (!_isConsumed(
        token,
        parsedFood,
        parsedCity,
        parsedOccupant,
        parsedGender,
      )) {
        if (_shouldAddKeywordToken(token)) {
          if (!remaining.contains(token)) remaining.add(token);
        }
      }
    }

    return SearchIntent(
      food: food,
      city: city,
      occupant: occupant,
      gender: gender,
      remainingKeywords: remaining,
    );
  }

  static RegExp _boundedPhrasePattern(String phrase) => RegExp(
        r'(?<![0-9a-z])' + RegExp.escape(phrase) + r'(?![0-9a-z])',
        caseSensitive: false,
      );

  static String? _extractBoundedPhrase(
    String query,
    List<_QuerySpan> consumed,
    List<(List<String> phrases, String value)> groups,
  ) {
    for (final entry in groups) {
      final sorted = [...entry.$1]..sort((a, b) => b.length.compareTo(a.length));
      for (final phrase in sorted) {
        for (final match in _boundedPhrasePattern(phrase).allMatches(query)) {
          if (!_spanAvailable(consumed, match.start, match.end)) continue;
          consumed.add(_QuerySpan(match.start, match.end));
          return entry.$2;
        }
      }
    }
    return null;
  }

  static bool _spanAvailable(List<_QuerySpan> spans, int start, int end) {
    for (final span in spans) {
      if (start < span.end && end > span.start) return false;
    }
    return true;
  }

  static String _queryMinusSpans(String query, List<_QuerySpan> spans) {
    if (spans.isEmpty) return query;
    final sorted = [...spans]..sort((a, b) => a.start.compareTo(b.start));
    final buf = StringBuffer();
    var cursor = 0;
    for (final span in sorted) {
      if (span.start > cursor) {
        buf.write(query.substring(cursor, span.start));
      }
      buf.write(' ');
      cursor = span.end;
    }
    if (cursor < query.length) {
      buf.write(query.substring(cursor));
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _normalizeQuery(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static bool _matchesStrongFilters(
    Map<String, dynamic> item,
    SearchIntent intent,
  ) {
    if (intent.occupant != null &&
        !ListingData.matchesOccupantType(item, intent.occupant!)) {
      return false;
    }
    if (intent.gender != null && !_genderMatches(item, intent.gender!)) {
      return false;
    }
    final blob = ListingData.searchText(item);
    for (final keyword in intent.remainingKeywords) {
      if (!_keywordMatches(blob, keyword)) return false;
    }
    return true;
  }

  static bool _matchesSoftFilters(
    Map<String, dynamic> item,
    SearchIntent intent,
  ) {
    if (intent.food != null && !_foodMatches(item, intent.food!)) return false;
    if (intent.city != null && !_cityMatches(item, intent.city!)) return false;
    return true;
  }

  static bool _matchesStrict(Map<String, dynamic> item, SearchIntent intent) {
    if (!_matchesStrongFilters(item, intent)) return false;
    if (!_matchesSoftFilters(item, intent)) return false;
    return true;
  }

  static String _canonicalLocality(String token) {
    return switch (token) {
      'hitech' => 'hitec',
      _ => token,
    };
  }

  /// Tokens that are still being typed toward a structured filter (e.g. `fam` → family).
  static bool _isIncompleteStructuredPrefix(String token) {
    final t = token.trim().toLowerCase();
    if (t.length < 2) return false;

    const phrases = [
      'family',
      'families',
      'bachelor',
      'bachelors',
      'student',
      'students',
      'vegetarian',
      'vegetarians',
      'nonveg',
      'non-veg',
      'non vegetarian',
      'non veg',
      'girls',
      'girl',
      'boys',
      'boy',
      'male',
      'female',
    ];
    final cityPhrases = [
      for (final entry in _parseCityAliases.entries) entry.key,
      for (final entry in _parseCityAliases.entries) ...entry.value,
    ];
    for (final phrase in [...phrases, ...cityPhrases]) {
      if (phrase.startsWith(t) && phrase != t) return true;
    }

    for (final entry in _parseCityAliases.entries) {
      for (final alias in entry.value) {
        if (alias.length >= 3 && alias.startsWith(t) && alias != t) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _shouldAddKeywordToken(String token) {
    if (RegExp(r'^\d+bhk$').hasMatch(token)) return true;
    if (RegExp(r'^\d+bed$').hasMatch(token)) return true;
    if (_localityKeywordSet.contains(token)) return true;
    if (_isIncompleteStructuredPrefix(token)) return false;
    return token.length >= 3;
  }

  static bool _isWordChar(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||
        (code >= 97 && code <= 122) ||
        (code >= 65 && code <= 90);
  }

  /// Avoid `hi` → `hindi`, `st` → `students`, `bh` → `bhk` false positives.
  static bool _bedBathMatches(String blob, String term) {
    final match = RegExp(r'^(\d+)bed(\d+)bath$').firstMatch(term);
    if (match == null) return false;
    final beds = match.group(1)!;
    final baths = match.group(2)!;
    if (blob.contains(term)) return true;
    final bedOk = RegExp(
      r'(?<![0-9])' + RegExp.escape(beds) + r'\s*-?\s*bed(?:room)?s?(?![0-9])',
      caseSensitive: false,
    ).hasMatch(blob);
    final bathOk = RegExp(
      r'(?<![0-9])' + RegExp.escape(baths) + r'\s*-?\s*bath(?:room)?s?(?![0-9])',
      caseSensitive: false,
    ).hasMatch(blob);
    return bedOk && bathOk;
  }

  static bool _shareRoomKindMatches(String blob, String term) {
    return switch (term) {
      'ensuite' => blob.contains('ensuite'),
      'double_ensuite' =>
        blob.contains('double ensuite') || blob.contains('ensuite double'),
      'bed_shared' =>
        blob.contains('bed in shared') ||
        blob.contains('bed_shared') ||
        blob.contains('sharing room') ||
        blob.contains('bed space'),
      'private_bath' =>
        blob.contains('private_bath') ||
        (blob.contains('private room') &&
            (blob.contains('bathroom') || blob.contains('own bath'))),
      'student_room' =>
        blob.contains('student_room') ||
        blob.contains('student room') ||
        blob.contains('students'),
      _ => false,
    };
  }

  static bool _dwellingMatches(String blob, String term) {
    return switch (term) {
      'apartment' =>
        blob.contains('apartment') ||
        blob.contains('flat') ||
        blob.contains('studio'),
      'house' => blob.contains('house') || blob.contains('cottage'),
      'duplex' => blob.contains('duplex') || blob.contains('townhouse'),
      _ => blob.contains(term),
    };
  }

  static bool _blobContainsTerm(String blob, String term) {
    if (term.isEmpty) return true;
    if (RegExp(r'^\d+bhk$').hasMatch(term)) return blob.contains(term);
    if (RegExp(r'^\d+bed\d+bath$').hasMatch(term)) {
      return _bedBathMatches(blob, term);
    }
    if (RegExp(r'^\d+bed$').hasMatch(term)) {
      return _bedCountMatches(blob, term);
    }
    if (_shareRoomKindMatches(blob, term)) return true;
    if (const {'apartment', 'house', 'duplex'}.contains(term)) {
      return _dwellingMatches(blob, term);
    }

    var index = 0;
    while (index < blob.length) {
      final found = blob.indexOf(term, index);
      if (found < 0) return false;
      final beforeOk = found == 0 || !_isWordChar(blob[found - 1]);
      final afterIndex = found + term.length;
      final afterOk =
          afterIndex >= blob.length || !_isWordChar(blob[afterIndex]);
      if (beforeOk && afterOk) return true;
      index = found + 1;
    }
    return false;
  }

  /// Match `3bed` against `3 bed`, `3-bed`, `3 bedroom` — not `13 bed` or `2 bed`.
  static bool _bedCountMatches(String blob, String term) {
    final match = RegExp(r'^(\d+)bed$').firstMatch(term);
    if (match == null) return false;
    final count = match.group(1)!;
    return RegExp(
      r'(?<![0-9])' +
          RegExp.escape(count) +
          r'\s*-?\s*bed(?:room)?s?(?![0-9])',
      caseSensitive: false,
    ).hasMatch(blob);
  }

  static bool _keywordMatches(String blob, String keyword) {
    final k = keyword.trim().toLowerCase();
    if (k.isEmpty) return true;
    return _blobContainsTerm(blob, k);
  }

  static int _relevanceScore(
    Map<String, dynamic> item,
    SearchIntent intent,
    String normalizedQuery,
  ) {
    if (intent.food != null && !matchesFood(item, intent.food!)) {
      return 0;
    }
    if (intent.occupant != null && !_occupantMatches(item, intent.occupant!)) {
      return 0;
    }

    var score = 0;

    if (intent.food != null && matchesFood(item, intent.food!)) score += 60;
    if (intent.city != null && _cityMatches(item, intent.city!)) score += 35;
    if (intent.occupant != null && _occupantMatches(item, intent.occupant!)) {
      score += 30;
    }
    if (intent.gender != null && _genderMatches(item, intent.gender!)) score += 25;

    final blob = ListingData.searchText(item);
    for (final keyword in intent.remainingKeywords) {
      if (!_keywordMatches(blob, keyword)) continue;
      if (RegExp(r'^\d+bhk$').hasMatch(keyword)) {
        score += 45;
      } else if (RegExp(r'^\d+bed$').hasMatch(keyword)) {
        score += 45;
      } else if (_localityKeywordSet.contains(keyword) ||
          _localityDisplayNames.containsKey(keyword)) {
        score += 50;
      } else {
        score += 12;
      }
    }

    if (intent.food == null) {
      if (normalizedQuery.isNotEmpty && blob.contains(normalizedQuery)) {
        score += 15;
      }
      for (final token in normalizedQuery.split(RegExp(r'\s+'))) {
        if (_isFoodToken(token)) continue;
        if (token.length >= 3 && _blobContainsTerm(blob, token)) score += 4;
      }
    }

    return score;
  }

  static bool _isFoodToken(String token) {
    return const {'veg', 'vegetarian', 'vegetarians', 'non', 'nonveg', 'non-veg'}
        .contains(token);
  }

  static List<Map<String, dynamic>> _closestMatches(
    List<Map<String, dynamic>> listings,
    SearchIntent intent,
    String normalizedQuery,
  ) {
    final scored = <({Map<String, dynamic> item, int score})>[];

    for (final item in listings) {
      if (intent.food != null && !matchesFood(item, intent.food!)) continue;
      if (intent.occupant != null &&
          !_occupantMatches(item, intent.occupant!)) {
        continue;
      }
      final score = _relevanceScore(item, intent, normalizedQuery);
      if (score > 0) scored.add((item: item, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    if (scored.isEmpty) {
      if (intent.remainingKeywords.isNotEmpty &&
          intent.food == null &&
          intent.city == null &&
          intent.occupant == null &&
          intent.gender == null) {
        return const [];
      }
      return _legacyKeywordFilter(listings, normalizedQuery);
    }

    final best = scored.first.score;
    final threshold = (best * 0.45).round().clamp(8, best);

    return [
      for (final entry in scored)
        if (entry.score >= threshold) entry.item,
    ];
  }

  static List<Map<String, dynamic>> _legacyKeywordFilter(
    List<Map<String, dynamic>> listings,
    String query,
  ) {
    final parsed = parse(query);
    if (parsed.hasStructuredFilters) {
      return applyFiltersStrict(listings, parsed);
    }

    final keywords = query.split(RegExp(r'\s+')).where((k) => k.isNotEmpty);
    return listings.where((item) {
      final blob = ListingData.searchText(item);
      return keywords.every((k) => blob.contains(k));
    }).toList();
  }

  static String? _foodFromToken(String token) {
    if (['veg', 'vegetarian', 'vegetarians'].contains(token)) return 'veg';
    if (['nonveg', 'non-veg', 'nonvegatarian'].contains(token)) return 'non-veg';
    if (token == 'non' || token == 'vegetarian') return null;
    return null;
  }

  static String? _cityFromToken(String token) {
    for (final entry in _parseCityAliases.entries) {
      for (final alias in entry.value) {
        if (token == alias) return entry.key;
      }
    }
    return null;
  }

  static String? _occupantFromToken(String token) {
    if (['family', 'families'].contains(token)) return 'Family';
    if (['bachelor', 'bachelors'].contains(token)) return 'Bachelors';
    if (['student', 'students'].contains(token)) return 'Students';
    if (token.length >= 4) {
      if ('students'.startsWith(token) || 'student'.startsWith(token)) {
        return 'Students';
      }
      if ('bachelors'.startsWith(token) || 'bachelor'.startsWith(token)) {
        return 'Bachelors';
      }
      if ('families'.startsWith(token) || 'family'.startsWith(token)) {
        return 'Family';
      }
    }
    return null;
  }

  static String? _genderFromToken(String token) {
    if (['girl', 'girls', 'female', 'females'].contains(token)) return 'girls';
    if (['boy', 'boys', 'male', 'males'].contains(token)) return 'boys';
    return null;
  }

  static bool _isConsumed(
    String token,
    String? food,
    String? city,
    String? occupant,
    String? gender,
  ) {
    if (food != null && _foodFromToken(token) == food) return true;
    if (city != null && _cityFromToken(token) == city) return true;
    if (_localityKeywordSet.contains(token) ||
        _localityKeywordSet.contains(_canonicalLocality(token))) {
      return true;
    }
    if (occupant != null && _occupantFromToken(token) == occupant) return true;
    if (gender != null && _genderFromToken(token) == gender) return true;
    return false;
  }

  static bool _foodMatches(Map<String, dynamic> item, String food) =>
      ListingData.matchesFoodPreferenceFilter(item, food);

  static bool _cityMatches(Map<String, dynamic> item, String city) {
    final canonical = canonicalCityForListing(item);
    if (canonical != null && canonical == city) return true;
    return ListingData.matchesCityFilter(item, city);
  }

  static bool _occupantMatches(Map<String, dynamic> item, String occupant) =>
      ListingData.matchesOccupantTypeFilter(item, occupant);

  static bool _genderMatches(Map<String, dynamic> item, String gender) {
    final pref = ListingData.bachelorPreference(item).toLowerCase();
    if (pref.isEmpty) return true;
    if (gender == 'girls') {
      return pref.contains('girl') || pref.contains('boys & girls');
    }
    if (gender == 'boys') {
      return pref.contains('boy') && !pref.contains('girl only');
    }
    return false;
  }
}

class _QuerySpan {
  const _QuerySpan(this.start, this.end);
  final int start;
  final int end;
}
