import 'listing_data.dart';
import 'listing_search_intent.dart';
import 'viewer_profile.dart';

/// Category for grouping autocomplete rows in the search dropdown.
enum SearchSuggestionCategory {
  food,
  location,
  occupant,
  gender,
  fallback,
}

/// Dominant dimension the user is typing toward (drives group order + boosts).
enum SearchPrimaryIntent {
  occupant,
  food,
  location,
  gender,
  general,
}

/// Structured autocomplete item (label for UI, tokens for filters).
class SearchSuggestion {
  const SearchSuggestion({
    required this.label,
    required this.query,
    required this.category,
    this.foodPreference,
    this.city,
    this.occupantType,
    this.genderPreference,
    this.count = 0,
    this.isFallback = false,
  });

  final String label;
  final String query;
  final SearchSuggestionCategory category;
  final String? foodPreference;
  final String? city;
  final String? occupantType;
  final String? genderPreference;
  final int count;
  final bool isFallback;

  SearchIntent toSearchIntent() => toSearchFilters().toSearchIntent();

  /// Strips count suffix: `Veg in Mumbai (3)` → `Veg in Mumbai`.
  static final RegExp suggestionCountSuffix = RegExp(r'\s\(\d+\)$');

  static String stripCountSuffix(String raw) =>
      raw.replaceFirst(suggestionCountSuffix, '').trim();

  /// Structured filters for immediate search — uses the fields already set
  /// by the suggestion builder (no label scanning needed).
  ListingSearchFilters toSearchFilters() {
    final parsed = ListingSearchIntent.parseQuery(
      ListingSearchIntent.normalizeQuery(query),
    );
    return ListingSearchFilters(
      foodPreference: foodPreference ?? parsed.food,
      city: city ?? parsed.city,
      occupantType: occupantType ?? parsed.occupant,
      genderPreference: genderPreference ?? parsed.gender,
      keywords: parsed.remainingKeywords,
    );
  }

  @override
  String toString() =>
      'SearchSuggestion(label: $label, foodPreference: $foodPreference, '
      'city: $city, occupantType: $occupantType, '
      'genderPreference: $genderPreference, count: $count, query: $query)';

  static SearchSuggestion fromParts({
    required String label,
    required String query,
    required SearchSuggestionCategory category,
    int count = 0,
    bool isFallback = false,
  }) {
    final normalized = ListingSearchIntent.normalizeQuery(query);
    final parsed = ListingSearchIntent.parseQuery(normalized);
    return SearchSuggestion(
      label: label,
      query: normalized,
      category: category,
      foodPreference: parsed.food,
      city: parsed.city,
      occupantType: parsed.occupant,
      genderPreference: parsed.gender,
      count: count,
      isFallback: isFallback,
    );
  }
}

class SearchSuggestionGroup {
  const SearchSuggestionGroup({
    required this.title,
    required this.category,
    required this.items,
    this.isFallback = false,
  });

  final String title;
  final SearchSuggestionCategory category;
  final List<SearchSuggestion> items;
  final bool isFallback;
}

class _RankedSuggestion {
  const _RankedSuggestion({required this.item, required this.score});

  final SearchSuggestion item;
  final int score;
}

/// Data-driven autocomplete from live marketplace listings.
abstract final class ListingSearchSuggestions {
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

  /// Grouped suggestions from real listings (with profile + recency boosts).
  static List<SearchSuggestionGroup> suggestGrouped(
    String rawQuery, {
    required List<Map<String, dynamic>> listings,
    ViewerProfile? viewer,
    List<String> recentSearchQueries = const [],
    int maxPerCategory = 5,
  }) {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) return const [];

    final matched = _filterListingsPartial(listings, trimmed);
    if (matched.isEmpty) {
      return _fallbackGroups(viewer: viewer);
    }

    final intent = ListingSearchIntent.parseQuery(trimmed);
    final primary = _detectPrimaryIntent(intent, trimmed);
    final ranked = <_RankedSuggestion>[];

    final includeFood =
        primary != SearchPrimaryIntent.occupant || intent.food != null;
    final includeGenericLocation = intent.occupant == null;

    if (includeFood) {
      _addFoodSuggestions(
        towerListings: listings,
        matched: matched,
        intent: intent,
        primary: primary,
        ranked: ranked,
        viewer: viewer,
        recentSearchQueries: recentSearchQueries,
      );
    }

    if (includeGenericLocation) {
      _addLocationSuggestions(
        towerListings: listings,
        matched: matched,
        intent: intent,
        primary: primary,
        ranked: ranked,
        viewer: viewer,
        recentSearchQueries: recentSearchQueries,
      );
    }

    _addOccupantSuggestions(
      towerListings: listings,
      matched: matched,
      intent: intent,
      primary: primary,
      ranked: ranked,
      viewer: viewer,
      recentSearchQueries: recentSearchQueries,
    );

    if (intent.occupant != null) {
      _addOccupantLocationCombinations(
        towerListings: listings,
        intent: intent,
        primary: primary,
        ranked: ranked,
        viewer: viewer,
        recentSearchQueries: recentSearchQueries,
      );
      if (intent.food == null) {
        _addOccupantFoodCombinations(
          towerListings: listings,
          intent: intent,
          primary: primary,
          ranked: ranked,
          viewer: viewer,
          recentSearchQueries: recentSearchQueries,
        );
      }
    }

    if (intent.food != null && intent.occupant == null) {
      _addFoodOccupantCombinations(
        towerListings: listings,
        intent: intent,
        primary: primary,
        ranked: ranked,
        viewer: viewer,
        recentSearchQueries: recentSearchQueries,
      );
    }

    if (intent.occupant == 'Bachelors' || primary == SearchPrimaryIntent.gender) {
      _addGenderSuggestions(
        towerListings: listings,
        matched: matched,
        intent: intent,
        primary: primary,
        ranked: ranked,
        viewer: viewer,
        recentSearchQueries: recentSearchQueries,
      );
    }

    if (ranked.isEmpty) {
      return [
        _freeTextSearchGroup(trimmed),
        ..._fallbackGroups(viewer: viewer),
      ];
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));

    final groups = _bucketRanked(
      ranked,
      maxPerCategory: maxPerCategory,
      primary: primary,
      intent: intent,
    );

    return [_freeTextSearchGroup(trimmed), ...groups];
  }

  /// Google-style "Search for: ..." item so users can always click to
  /// run a free-text search even when no structured suggestion matches.
  static SearchSuggestionGroup _freeTextSearchGroup(String query) {
    return SearchSuggestionGroup(
      title: 'Search',
      category: SearchSuggestionCategory.fallback,
      items: [
        SearchSuggestion(
          label: 'Search for: $query',
          query: query,
          category: SearchSuggestionCategory.fallback,
        ),
      ],
    );
  }

  static SearchPrimaryIntent _detectPrimaryIntent(
    SearchIntent intent,
    String rawQuery,
  ) {
    if (intent.occupant != null) return SearchPrimaryIntent.occupant;
    if (intent.food != null) return SearchPrimaryIntent.food;
    if (intent.city != null) return SearchPrimaryIntent.location;
    if (intent.gender != null) return SearchPrimaryIntent.gender;

    final q = ListingSearchIntent.normalizeQuery(rawQuery);
    if (_queryHintsOccupant(q)) return SearchPrimaryIntent.occupant;
    if (_queryHintsFood(q)) return SearchPrimaryIntent.food;
    if (_queryHintsLocation(q)) return SearchPrimaryIntent.location;

    return SearchPrimaryIntent.general;
  }

  static bool _queryHintsOccupant(String q) {
    if (RegExp(r'\b(family|families|bachelor|bachelors|student|students)\b')
        .hasMatch(q)) {
      return true;
    }
    return q.split(RegExp(r'\s+')).any(_isOccupantPrefixToken);
  }

  static bool _queryHintsFood(String q) {
    return RegExp(r'\b(veg|non-veg|non veg|vegetarian)\b').hasMatch(q);
  }

  static bool _queryHintsLocation(String q) {
    final parsed = ListingSearchIntent.parseQuery(q);
    if (parsed.city != null) return true;
    return q.split(RegExp(r'\s+')).any((t) {
      if (t.length < 3) return false;
      return ListingSearchIntent.parseQuery(t).city != null;
    });
  }

  static bool _isOccupantPrefixToken(String token) {
    if (token.length < 3) return false;
    const roots = ['family', 'families', 'bachelor', 'bachelors', 'student', 'students'];
    return roots.any((r) => r.startsWith(token) || token.startsWith(r));
  }

  static List<SearchSuggestion> suggest(
    String rawQuery, {
    required List<Map<String, dynamic>> listings,
    ViewerProfile? viewer,
    List<String> recentSearchQueries = const [],
    int maxSuggestions = 12,
  }) {
    return suggestGrouped(
      rawQuery,
      listings: listings,
      viewer: viewer,
      recentSearchQueries: recentSearchQueries,
    )
        .expand((g) => g.items)
        .take(maxSuggestions)
        .toList();
  }

  static List<Map<String, dynamic>> _filterListingsPartial(
    List<Map<String, dynamic>> listings,
    String normalizedQuery,
  ) {
    final intent = ListingSearchIntent.parseQuery(normalizedQuery);
    final tokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !_stopWords.contains(t))
        .toList();

    return [
      for (final item in listings)
        if (_listingMatchesPartial(item, normalizedQuery, intent, tokens)) item,
    ];
  }

  static bool _listingMatchesPartial(
    Map<String, dynamic> item,
    String normalizedQuery,
    SearchIntent intent,
    List<String> tokens,
  ) {
    if (intent.food != null &&
        !ListingData.matchesFoodPreference(item, intent.food!)) {
      return false;
    }
    if (intent.city != null &&
        !ListingSearchIntent.matchesCity(item, intent.city!)) {
      return false;
    }
    if (intent.occupant != null) {
      final occ = ListingData.occupantType(item);
      if (occ.isEmpty ||
          occ.toLowerCase() != intent.occupant!.toLowerCase()) {
        return false;
      }
    }
    if (intent.gender != null &&
        !ListingSearchIntent.listingMatchesGender(item, intent.gender!)) {
      return false;
    }

    if (tokens.isEmpty) return true;

    final blob = ListingData.searchText(item);
    final title = ListingData.title(item).toLowerCase();

    for (final token in tokens) {
      if (_tokenConsumedByIntent(token, intent)) continue;
      if (blob.contains(token) || title.contains(token)) continue;
      if (_tokenMatchesListingField(token, item)) continue;
      return false;
    }
    return true;
  }

  static bool _tokenConsumedByIntent(String token, SearchIntent intent) {
    if (intent.food != null && _foodFromToken(token) == intent.food) {
      return true;
    }
    if (intent.city != null && _cityFromToken(token) == intent.city) {
      return true;
    }
    if (intent.occupant != null &&
        _occupantFromToken(token) == intent.occupant) {
      return true;
    }
    if (intent.gender != null && _genderFromToken(token) == intent.gender) {
      return true;
    }
    return false;
  }

  /// Same strict AND logic as the marketplace pipeline (accurate suggestion counts).
  static int _strictMatchCount(
    List<Map<String, dynamic>> towerListings,
    SearchIntent intent,
  ) {
    return ListingSearchIntent.applyFiltersStrict(towerListings, intent).length;
  }

  static SearchIntent _intentWith({
    required SearchIntent base,
    String? food,
    String? city,
    String? occupant,
    String? gender,
  }) {
    return SearchIntent(
      food: food ?? base.food,
      city: city ?? base.city,
      occupant: occupant ?? base.occupant,
      gender: gender ?? base.gender,
      remainingKeywords: base.remainingKeywords,
    );
  }

  static bool _tokenMatchesListingField(String token, Map<String, dynamic> item) {
    final food = ListingData.foodPreferenceToken(item);
    if (food.startsWith(token) || token.startsWith(food)) return true;
    final city = ListingSearchIntent.canonicalCityForListing(item);
    if (city != null && (city.startsWith(token) || token.startsWith(city))) {
      return true;
    }
    final occ = ListingData.occupantType(item).toLowerCase();
    if (occ.startsWith(token) || token.startsWith(occ)) return true;
    return false;
  }

  static void _pushRanked({
    required List<_RankedSuggestion> ranked,
    required SearchSuggestion suggestion,
    required int count,
    required SearchPrimaryIntent primary,
    required ViewerProfile? viewer,
    required List<String> recentSearchQueries,
    String? food,
    String? city,
    String? occupant,
    String? gender,
  }) {
    ranked.add(
      _RankedSuggestion(
        item: suggestion,
        score: _scoreSuggestion(
          count: count,
          primary: primary,
          category: suggestion.category,
          viewer: viewer,
          recentSearchQueries: recentSearchQueries,
          query: suggestion.query,
          food: food ?? suggestion.foodPreference,
          city: city ?? suggestion.city,
          occupant: occupant ?? suggestion.occupantType,
          gender: gender ?? suggestion.genderPreference,
        ),
      ),
    );
  }

  static void _addFoodSuggestions({
    required List<Map<String, dynamic>> towerListings,
    required List<Map<String, dynamic>> matched,
    required SearchIntent intent,
    required SearchPrimaryIntent primary,
    required List<_RankedSuggestion> ranked,
    required ViewerProfile? viewer,
    required List<String> recentSearchQueries,
  }) {
    final foods = <String>{};
    for (final item in matched) {
      final food = ListingData.foodPreferenceToken(item);
      if (food.isNotEmpty) foods.add(food);
    }

    for (final food in foods) {
      final label = _foodDisplay(food);
      if (label == null) continue;
      final count = _strictMatchCount(
        towerListings,
        _intentWith(base: intent, food: food),
      );
      if (count == 0) continue;
      final query = food;
      final suggestion = SearchSuggestion(
        label: _withCount(label, count),
        query: query,
        category: SearchSuggestionCategory.food,
        foodPreference: food,
        count: count,
      );
      _pushRanked(
        ranked: ranked,
        suggestion: suggestion,
        count: count,
        primary: primary,
        viewer: viewer,
        recentSearchQueries: recentSearchQueries,
        food: food,
      );
    }
  }

  static void _addLocationSuggestions({
    required List<Map<String, dynamic>> towerListings,
    required List<Map<String, dynamic>> matched,
    required SearchIntent intent,
    required SearchPrimaryIntent primary,
    required List<_RankedSuggestion> ranked,
    required ViewerProfile? viewer,
    required List<String> recentSearchQueries,
  }) {
    final food = intent.food;
    final foodLabel = _foodDisplay(food);
    final cities = <String>{};

    for (final item in matched) {
      final city = ListingSearchIntent.canonicalCityForListing(item);
      if (city != null) cities.add(city);
    }

    for (final city in cities) {
      final count = _strictMatchCount(
        towerListings,
        _intentWith(base: intent, city: city),
      );
      if (count == 0) continue;

      final cityName = ListingSearchIntent.cityDisplayName(city);
      final String label;
      final String query;
      if (food != null && foodLabel != null) {
        label = _withCount('$foodLabel in $cityName', count);
        query = '$food $city';
      } else {
        label = _withCount('Listings in $cityName', count);
        query = city;
      }

      final suggestion = SearchSuggestion(
        label: label,
        query: query,
        category: SearchSuggestionCategory.location,
        foodPreference: food,
        city: city,
        count: count,
      );
      _pushRanked(
        ranked: ranked,
        suggestion: suggestion,
        count: count,
        primary: primary,
        viewer: viewer,
        recentSearchQueries: recentSearchQueries,
        food: food,
        city: city,
      );
    }
  }

  static void _addOccupantSuggestions({
    required List<Map<String, dynamic>> towerListings,
    required List<Map<String, dynamic>> matched,
    required SearchIntent intent,
    required SearchPrimaryIntent primary,
    required List<_RankedSuggestion> ranked,
    required ViewerProfile? viewer,
    required List<String> recentSearchQueries,
  }) {
    final food = intent.food;
    final foodLabel = _foodDisplay(food);
    final occupantTypes = intent.occupant != null
        ? [intent.occupant!]
        : const ['Family', 'Bachelors', 'Students'];

    for (final occupant in occupantTypes) {
      final count = _strictMatchCount(
        towerListings,
        _intentWith(base: intent, occupant: occupant),
      );
      if (count == 0) continue;

      final occLabel = intent.occupant != null
          ? _occupantSingular(occupant)
          : _occupantPhrase(occupant);
      final String label;
      final String query;
      if (food != null && foodLabel != null) {
        label = _withCount('$foodLabel for $occLabel', count);
        query = '$food ${occupant.toLowerCase()}';
      } else if (intent.occupant != null) {
        label = _withCount('All $occLabel listings', count);
        query = occupant.toLowerCase();
      } else {
        label = _withCount(occLabel, count);
        query = occupant.toLowerCase();
      }

      final suggestion = SearchSuggestion(
        label: label,
        query: query,
        category: SearchSuggestionCategory.occupant,
        foodPreference: food,
        occupantType: occupant,
        count: count,
      );
      _pushRanked(
        ranked: ranked,
        suggestion: suggestion,
        count: count,
        primary: primary,
        viewer: viewer,
        recentSearchQueries: recentSearchQueries,
        food: food,
        occupant: occupant,
      );
    }
  }

  /// e.g. Family in Hyderabad (5), Family in Bangalore (3)
  static void _addOccupantLocationCombinations({
    required List<Map<String, dynamic>> towerListings,
    required SearchIntent intent,
    required SearchPrimaryIntent primary,
    required List<_RankedSuggestion> ranked,
    required ViewerProfile? viewer,
    required List<String> recentSearchQueries,
  }) {
    final occupant = intent.occupant;
    if (occupant == null) return;

    final occLabel = _occupantSingular(occupant);
    final cities = <String>{};
    for (final item in towerListings) {
      if (!ListingData.matchesOccupantType(item, occupant)) continue;
      final city = ListingSearchIntent.canonicalCityForListing(item);
      if (city != null) cities.add(city);
    }

    for (final city in cities) {
      final count = _strictMatchCount(
        towerListings,
        _intentWith(base: intent, city: city),
      );
      if (count == 0) continue;

      final cityName = ListingSearchIntent.cityDisplayName(city);
      final query = '${occupant.toLowerCase()} $city';
      final suggestion = SearchSuggestion(
        label: _withCount('$occLabel in $cityName', count),
        query: query,
        category: SearchSuggestionCategory.occupant,
        occupantType: occupant,
        city: city,
        foodPreference: intent.food,
        count: count,
      );
      _pushRanked(
        ranked: ranked,
        suggestion: suggestion,
        count: count,
        primary: primary,
        viewer: viewer,
        recentSearchQueries: recentSearchQueries,
        occupant: occupant,
        city: city,
        food: intent.food,
      );
    }
  }

  /// Secondary: Family + Veg, Family + Non-veg
  static void _addOccupantFoodCombinations({
    required List<Map<String, dynamic>> towerListings,
    required SearchIntent intent,
    required SearchPrimaryIntent primary,
    required List<_RankedSuggestion> ranked,
    required ViewerProfile? viewer,
    required List<String> recentSearchQueries,
  }) {
    final occupant = intent.occupant;
    if (occupant == null) return;

    final occLabel = _occupantSingular(occupant);
    for (final food in const ['veg', 'non-veg']) {
      final foodLabel = _foodDisplay(food);
      if (foodLabel == null) continue;
      final count = _strictMatchCount(
        towerListings,
        _intentWith(base: intent, food: food),
      );
      if (count == 0) continue;

      final query = '${occupant.toLowerCase()} $food';
      final suggestion = SearchSuggestion(
        label: _withCount('$occLabel + $foodLabel', count),
        query: query,
        category: SearchSuggestionCategory.occupant,
        occupantType: occupant,
        foodPreference: food,
        city: intent.city,
        count: count,
      );
      _pushRanked(
        ranked: ranked,
        suggestion: suggestion,
        count: count,
        primary: primary,
        viewer: viewer,
        recentSearchQueries: recentSearchQueries,
        food: food,
        occupant: occupant,
        city: intent.city,
      );
    }
  }

  /// When food is primary: Veg for Families, etc.
  static void _addFoodOccupantCombinations({
    required List<Map<String, dynamic>> towerListings,
    required SearchIntent intent,
    required SearchPrimaryIntent primary,
    required List<_RankedSuggestion> ranked,
    required ViewerProfile? viewer,
    required List<String> recentSearchQueries,
  }) {
    final food = intent.food;
    final foodLabel = _foodDisplay(food);
    if (food == null || foodLabel == null) return;

    for (final occupant in const ['Family', 'Bachelors', 'Students']) {
      final count = _strictMatchCount(
        towerListings,
        _intentWith(base: intent, occupant: occupant),
      );
      if (count == 0) continue;

      final occLabel = _occupantPhrase(occupant);
      final query = '$food ${occupant.toLowerCase()}';
      final suggestion = SearchSuggestion(
        label: _withCount('$foodLabel for $occLabel', count),
        query: query,
        category: SearchSuggestionCategory.occupant,
        foodPreference: food,
        occupantType: occupant,
        count: count,
      );
      _pushRanked(
        ranked: ranked,
        suggestion: suggestion,
        count: count,
        primary: primary,
        viewer: viewer,
        recentSearchQueries: recentSearchQueries,
        food: food,
        occupant: occupant,
      );
    }
  }

  static void _addGenderSuggestions({
    required List<Map<String, dynamic>> towerListings,
    required List<Map<String, dynamic>> matched,
    required SearchIntent intent,
    required SearchPrimaryIntent primary,
    required List<_RankedSuggestion> ranked,
    required ViewerProfile? viewer,
    required List<String> recentSearchQueries,
  }) {
    final food = intent.food;
    final foodLabel = _foodDisplay(food);

    for (final gender in ['girls', 'boys']) {
      final count = _strictMatchCount(
        towerListings,
        _intentWith(base: intent, gender: gender),
      );
      if (count == 0) continue;

      final genderLabel = gender == 'girls' ? 'Girls' : 'Boys';
      final String label;
      final String query;
      if (food != null && foodLabel != null) {
        label = _withCount('$foodLabel for $genderLabel', count);
        query = '$food $gender';
      } else {
        label = _withCount('$genderLabel only', count);
        query = gender;
      }

      final suggestion = SearchSuggestion(
        label: label,
        query: query,
        category: SearchSuggestionCategory.gender,
        foodPreference: food,
        genderPreference: gender,
        count: count,
      );
      _pushRanked(
        ranked: ranked,
        suggestion: suggestion,
        count: count,
        primary: primary,
        viewer: viewer,
        recentSearchQueries: recentSearchQueries,
        food: food,
        gender: gender,
      );
    }
  }

  static int _scoreSuggestion({
    required int count,
    required SearchPrimaryIntent primary,
    required SearchSuggestionCategory category,
    required ViewerProfile? viewer,
    required List<String> recentSearchQueries,
    required String query,
    String? food,
    String? city,
    String? occupant,
    String? gender,
  }) {
    var score = count * 100 + _intentAlignmentBoost(primary, category);

    if (viewer != null) {
      if (food != null) {
        final viewerFood = _normFood(viewer.foodPreference);
        if (viewerFood == food) score += 60;
      }
      if (city != null) {
        final viewerCity = viewer.city.toLowerCase();
        if (viewerCity.contains(city) || city.contains(viewerCity)) {
          score += 50;
        }
      }
      if (occupant != null &&
          viewer.occupantType.toLowerCase() == occupant.toLowerCase()) {
        score += 40;
      }
      if (gender != null) {
        final g = viewer.genderPreference.toLowerCase();
        if ((gender == 'girls' && g.contains('girl')) ||
            (gender == 'boys' && g.contains('boy'))) {
          score += 35;
        }
      }
    }

    for (final recent in recentSearchQueries) {
      final recentNorm = ListingSearchIntent.normalizeQuery(recent);
      if (recentNorm == query || recentNorm.contains(query)) {
        score += 30;
      }
    }

    return score;
  }

  static int _intentAlignmentBoost(
    SearchPrimaryIntent primary,
    SearchSuggestionCategory category,
  ) {
    return switch ((primary, category)) {
      (SearchPrimaryIntent.occupant, SearchSuggestionCategory.occupant) => 800,
      (SearchPrimaryIntent.occupant, SearchSuggestionCategory.location) => 250,
      (SearchPrimaryIntent.occupant, SearchSuggestionCategory.food) => -400,
      (SearchPrimaryIntent.occupant, SearchSuggestionCategory.gender) => 100,
      (SearchPrimaryIntent.food, SearchSuggestionCategory.food) => 800,
      (SearchPrimaryIntent.food, SearchSuggestionCategory.location) => 350,
      (SearchPrimaryIntent.food, SearchSuggestionCategory.occupant) => 200,
      (SearchPrimaryIntent.food, SearchSuggestionCategory.gender) => 50,
      (SearchPrimaryIntent.location, SearchSuggestionCategory.location) => 800,
      (SearchPrimaryIntent.location, SearchSuggestionCategory.occupant) => 250,
      (SearchPrimaryIntent.location, SearchSuggestionCategory.food) => 300,
      (SearchPrimaryIntent.location, SearchSuggestionCategory.gender) => 50,
      (SearchPrimaryIntent.gender, SearchSuggestionCategory.gender) => 800,
      (SearchPrimaryIntent.gender, SearchSuggestionCategory.occupant) => 200,
      _ => 0,
    };
  }

  static List<SearchSuggestionGroup> _bucketRanked(
    List<_RankedSuggestion> ranked, {
    required int maxPerCategory,
    required SearchPrimaryIntent primary,
    required SearchIntent intent,
  }) {
    final food = <SearchSuggestion>[];
    final location = <SearchSuggestion>[];
    final occupant = <SearchSuggestion>[];
    final gender = <SearchSuggestion>[];

    for (final entry in ranked) {
      switch (entry.item.category) {
        case SearchSuggestionCategory.food:
          if (food.length < maxPerCategory) food.add(entry.item);
        case SearchSuggestionCategory.location:
          if (location.length < maxPerCategory) location.add(entry.item);
        case SearchSuggestionCategory.occupant:
          if (occupant.length < maxPerCategory) occupant.add(entry.item);
        case SearchSuggestionCategory.gender:
          if (gender.length < maxPerCategory) gender.add(entry.item);
        case SearchSuggestionCategory.fallback:
          break;
      }
    }

    final groups = <SearchSuggestionGroup>[];
    final order = _groupOrderFor(primary, intent);
    final buckets = <SearchSuggestionCategory, List<SearchSuggestion>>{
      SearchSuggestionCategory.food: food,
      SearchSuggestionCategory.location: location,
      SearchSuggestionCategory.occupant: occupant,
      SearchSuggestionCategory.gender: gender,
    };

    for (final category in order) {
      if (category == SearchSuggestionCategory.food &&
          primary == SearchPrimaryIntent.occupant &&
          intent.food == null) {
        continue;
      }
      final items = buckets[category];
      if (items == null || items.isEmpty) continue;
      groups.add(SearchSuggestionGroup(
        title: _groupTitle(primary, category),
        category: category,
        items: items,
      ));
    }
    return groups;
  }

  static List<SearchSuggestionCategory> _groupOrderFor(
    SearchPrimaryIntent primary,
    SearchIntent intent,
  ) {
    return switch (primary) {
      SearchPrimaryIntent.occupant => const [
          SearchSuggestionCategory.occupant,
          SearchSuggestionCategory.location,
          SearchSuggestionCategory.food,
          SearchSuggestionCategory.gender,
        ],
      SearchPrimaryIntent.food => const [
          SearchSuggestionCategory.food,
          SearchSuggestionCategory.location,
          SearchSuggestionCategory.occupant,
          SearchSuggestionCategory.gender,
        ],
      SearchPrimaryIntent.location => const [
          SearchSuggestionCategory.location,
          SearchSuggestionCategory.occupant,
          SearchSuggestionCategory.food,
          SearchSuggestionCategory.gender,
        ],
      SearchPrimaryIntent.gender => const [
          SearchSuggestionCategory.gender,
          SearchSuggestionCategory.occupant,
          SearchSuggestionCategory.location,
          SearchSuggestionCategory.food,
        ],
      SearchPrimaryIntent.general => const [
          SearchSuggestionCategory.occupant,
          SearchSuggestionCategory.location,
          SearchSuggestionCategory.food,
          SearchSuggestionCategory.gender,
        ],
    };
  }

  static String _groupTitle(
    SearchPrimaryIntent primary,
    SearchSuggestionCategory category,
  ) {
    return switch ((primary, category)) {
      (SearchPrimaryIntent.occupant, SearchSuggestionCategory.occupant) =>
        'Continue your search',
      (SearchPrimaryIntent.occupant, SearchSuggestionCategory.location) =>
        'Add a city',
      (SearchPrimaryIntent.occupant, SearchSuggestionCategory.food) =>
        'Refine with food',
      (SearchPrimaryIntent.food, SearchSuggestionCategory.food) =>
        'Food preferences',
      (SearchPrimaryIntent.food, SearchSuggestionCategory.location) =>
        'Add a city',
      (SearchPrimaryIntent.food, SearchSuggestionCategory.occupant) =>
        'Add occupant type',
      (SearchPrimaryIntent.location, SearchSuggestionCategory.location) =>
        'Locations',
      (SearchPrimaryIntent.location, SearchSuggestionCategory.occupant) =>
        'Occupant types',
      (SearchPrimaryIntent.location, SearchSuggestionCategory.food) =>
        'Food preferences',
      (_, SearchSuggestionCategory.gender) => 'Gender preference',
      (_, SearchSuggestionCategory.food) => 'Food preferences',
      (_, SearchSuggestionCategory.location) => 'Locations',
      (_, SearchSuggestionCategory.occupant) => 'Occupant types',
      _ => 'Suggestions',
    };
  }

  static String _occupantSingular(String occupant) {
    return switch (occupant) {
      'Family' => 'Family',
      'Bachelors' => 'Bachelor',
      'Students' => 'Student',
      _ => occupant,
    };
  }

  static List<SearchSuggestionGroup> _fallbackGroups({ViewerProfile? viewer}) {
    final city = viewer?.city.trim();
    final cityKey = city != null && city.isNotEmpty
        ? ListingSearchIntent.parseQuery(city).city
        : null;
    final cityName = cityKey != null
        ? ListingSearchIntent.cityDisplayName(cityKey)
        : 'Hyderabad';

    final items = [
      SearchSuggestion.fromParts(
        label: 'Try: $cityName',
        query: cityKey ?? 'hyderabad',
        category: SearchSuggestionCategory.fallback,
        isFallback: true,
      ),
      SearchSuggestion.fromParts(
        label: 'Try: Veg',
        query: 'veg',
        category: SearchSuggestionCategory.fallback,
        isFallback: true,
      ),
      SearchSuggestion.fromParts(
        label: 'Try: Family',
        query: 'family',
        category: SearchSuggestionCategory.fallback,
        isFallback: true,
      ),
    ];

    return [
      SearchSuggestionGroup(
        title: 'Popular searches',
        category: SearchSuggestionCategory.fallback,
        items: items,
        isFallback: true,
      ),
    ];
  }

  static String _withCount(String base, int count) {
    if (count <= 0) return base;
    return '$base ($count)';
  }

  static String? _foodDisplay(String? food) {
    return switch (food) {
      'veg' => 'Veg',
      'non-veg' => 'Non-veg',
      _ => null,
    };
  }

  static String _occupantPhrase(String occupant) {
    return switch (occupant) {
      'Family' => 'Families',
      'Bachelors' => 'Bachelors',
      'Students' => 'Students',
      _ => occupant,
    };
  }

  static String _normFood(String value) {
    final v = value.toLowerCase();
    if (v.contains('veg') && !v.contains('non')) return 'veg';
    if (v.contains('non')) return 'non-veg';
    return v;
  }

  static String? _foodFromToken(String token) {
    if (['veg', 'vegetarian', 'vegetarians'].contains(token)) return 'veg';
    if (['nonveg', 'non-veg'].contains(token)) return 'non-veg';
    return null;
  }

  static String? _cityFromToken(String token) {
    return ListingSearchIntent.parseQuery(token).city;
  }

  static String? _occupantFromToken(String token) {
    if (['family', 'families'].contains(token)) return 'Family';
    if (['bachelor', 'bachelors'].contains(token)) return 'Bachelors';
    if (['student', 'students'].contains(token)) return 'Students';
    return null;
  }

  static String? _genderFromToken(String token) {
    if (['girl', 'girls', 'female'].contains(token)) return 'girls';
    if (['boy', 'boys', 'male'].contains(token)) return 'boys';
    return null;
  }
}
