import 'listing_data.dart';

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
      final bhk = RegExp(r'^(\d)bhk$').firstMatch(keyword);
      if (bhk != null) {
        parts.add('${bhk.group(1)} BHK');
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

/// Explicit marketplace search filters (passed directly into search, not via delayed state).
class ListingSearchFilters {
  const ListingSearchFilters({
    this.foodPreference,
    this.city,
    this.occupantType,
    this.genderPreference,
    this.keywords = const [],
  });

  final String? foodPreference;
  final String? city;
  final String? occupantType;
  final String? genderPreference;

  /// Free-text tokens (e.g. `2bhk`, `furnished`) from the search box.
  final List<String> keywords;

  bool get isEmpty =>
      foodPreference == null &&
      city == null &&
      occupantType == null &&
      genderPreference == null &&
      keywords.isEmpty;

  ListingSearchFilters copyWith({
    String? foodPreference,
    String? city,
    String? occupantType,
    String? genderPreference,
    List<String>? keywords,
  }) {
    return ListingSearchFilters(
      foodPreference: foodPreference ?? this.foodPreference,
      city: city ?? this.city,
      occupantType: occupantType ?? this.occupantType,
      genderPreference: genderPreference ?? this.genderPreference,
      keywords: keywords ?? this.keywords,
    );
  }

  factory ListingSearchFilters.fromIntent(SearchIntent intent) {
    return ListingSearchFilters(
      foodPreference: intent.food,
      city: intent.city,
      occupantType: intent.occupant,
      genderPreference: intent.gender,
      keywords: intent.remainingKeywords,
    );
  }

  /// Merges explicit filters with a full query parse (keywords, BHK, etc.).
  SearchIntent toSearchIntent({String? mergeQuery}) {
    if (mergeQuery == null || mergeQuery.trim().isEmpty) {
      return SearchIntent(
        food: foodPreference,
        city: city,
        occupant: occupantType,
        gender: genderPreference,
        remainingKeywords: keywords,
      );
    }

    final parsed = ListingSearchIntent.parseQuery(mergeQuery);
    return SearchIntent(
      food: foodPreference ?? parsed.food,
      city: city ?? parsed.city,
      occupant: occupantType ?? parsed.occupant,
      gender: genderPreference ?? parsed.gender,
      remainingKeywords: _mergeKeywords(keywords, parsed.remainingKeywords),
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
    if (city != null) parts.add(city!);
    if (occupantType != null) parts.add(occupantType!.toLowerCase());
    if (genderPreference != null) parts.add(genderPreference!);
    parts.addAll(keywords);
    return ListingSearchIntent.normalizeQuery(parts.join(' '));
  }

  @override
  String toString() =>
      'ListingSearchFilters(foodPreference: $foodPreference, city: $city, '
      'occupantType: $occupantType, genderPreference: $genderPreference, '
      'keywords: $keywords)';

  /// Flexible AND filter — city uses substring; food/occupant use case-insensitive match.
  bool matchesListing(Map<String, dynamic> listing) {
    if (city != null &&
        !ListingData.matchesCityFilter(listing, city!)) {
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
  static const _cityAliases = <String, List<String>>{
    'hyderabad': ['hyderabad', 'hyd', 'secunderabad', 'hitech', 'hitec', 'gachibowli'],
    'bangalore': ['bangalore', 'bengaluru', 'blr', 'bang', 'koramangala', 'whitefield'],
    'chennai': ['chennai', 'madras', 'chn', 'omr', 'velachery'],
    'mumbai': ['mumbai', 'bombay', 'andheri', 'bandra', 'powai', 'navi mumbai'],
    'delhi': ['delhi', 'ncr', 'dwarka', 'noida', 'gurgaon', 'gurugram'],
  };

  /// City-level tokens only (whole-city filter). Localities use [remainingKeywords].
  static const _parseCityAliases = <String, List<String>>{
    'hyderabad': ['hyderabad', 'hyd', 'secunderabad'],
    'bangalore': ['bangalore', 'bengaluru', 'blr'],
    'chennai': ['chennai', 'madras', 'chn'],
    'mumbai': ['mumbai', 'bombay'],
    'delhi': ['delhi', 'ncr', 'noida', 'gurgaon', 'gurugram'],
  };

  /// Neighborhood / area tokens — match title & location text, not entire city.
  static const _localityKeywords = [
    'hitec',
    'hitech',
    'gachibowli',
    'koramangala',
    'whitefield',
    'indiranagar',
    'jubilee hills',
    'jubilee',
    'velachery',
    'omr',
    'andheri',
    'bandra',
    'powai',
    'dwarka',
    'banjara',
    'madhapur',
    'kondapur',
  ];

  static final Set<String> _localityKeywordSet =
      Set<String>.from(_localityKeywords);

  static const _localityDisplayNames = <String, String>{
    'hitec': 'HITEC',
    'hitech': 'HITEC',
    'gachibowli': 'Gachibowli',
    'koramangala': 'Koramangala',
    'whitefield': 'Whitefield',
    'indiranagar': 'Indiranagar',
    'jubilee': 'Jubilee Hills',
    'jubilee hills': 'Jubilee Hills',
    'velachery': 'Velachery',
    'omr': 'OMR',
    'andheri': 'Andheri',
    'bandra': 'Bandra',
    'powai': 'Powai',
    'dwarka': 'Dwarka',
    'banjara': 'Banjara Hills',
    'madhapur': 'Madhapur',
    'kondapur': 'Kondapur',
  };

  static String? localityDisplayName(String keyword) =>
      _localityDisplayNames[keyword];

  /// Step 1 — Normalize raw search text.
  static String normalizeQuery(String rawQuery) => _normalizeQuery(rawQuery);

  /// Step 2 — Convert query into structured filters.
  static SearchIntent parseQuery(String rawQuery) {
    final query = normalizeQuery(rawQuery);
    if (query.isEmpty) return const SearchIntent();
    return parse(query);
  }

  static const _cityDisplayNames = <String, String>{
    'hyderabad': 'Hyderabad',
    'bangalore': 'Bangalore',
    'chennai': 'Chennai',
    'mumbai': 'Mumbai',
    'delhi': 'Delhi',
  };

  static String cityDisplayName(String cityKey) =>
      _cityDisplayNames[cityKey] ?? SearchIntent._titleCase(cityKey);

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
      RegExp(r'(\d)\s*bhk', caseSensitive: false);
  static final RegExp _bhkCompactPattern =
      RegExp(r'(\d)bhk', caseSensitive: false);

  static SearchIntent parse(String normalizedQuery) {
    var working = normalizedQuery;
    String? food;
    String? city;
    String? occupant;
    String? gender;
    final bhkKeywords = <String>[];

    for (final match in _bhkSpacedPattern.allMatches(working)) {
      final beds = match.group(1);
      if (beds == null) continue;
      final token = '${beds}bhk';
      if (!bhkKeywords.contains(token)) bhkKeywords.add(token);
      working = working.replaceAll(match.group(0)!, ' ');
    }
    for (final match in _bhkCompactPattern.allMatches(working)) {
      final beds = match.group(1);
      if (beds == null) continue;
      final token = '${beds}bhk';
      if (!bhkKeywords.contains(token)) bhkKeywords.add(token);
      working = working.replaceAll(match.group(0)!, ' ');
    }

    const foodPhrases = [
      (['non veg', 'non-veg', 'nonvegetarian', 'non vegetarian'], 'non-veg'),
      (['vegetarian', 'vegetarians', 'veg'], 'veg'),
    ];
    for (final entry in foodPhrases) {
      for (final phrase in entry.$1) {
        if (working.contains(phrase)) {
          food = entry.$2;
          working = working.replaceAll(phrase, ' ');
        }
      }
    }

    final localityKeywords = <String>[];
    working = _consumeLocalitiesFromWorking(working, localityKeywords);

    for (final entry in _parseCityAliases.entries) {
      for (final alias in entry.value) {
        if (alias.length < 3) continue;
        if (working == alias ||
            working.split(RegExp(r'\s+')).contains(alias)) {
          city = entry.key;
          working = working.replaceAll(alias, ' ');
        }
      }
    }

    const occupantPhrases = [
      (['bachelors', 'bachelor', 'bachelors only'], 'Bachelors'),
      (['students', 'student'], 'Students'),
      (['family', 'families'], 'Family'),
    ];
    for (final entry in occupantPhrases) {
      for (final phrase in entry.$1) {
        if (working.contains(phrase)) {
          occupant = entry.$2;
          working = working.replaceAll(phrase, ' ');
        }
      }
    }

    const genderPhrases = [
      (['girls', 'girl', 'female', 'females'], 'girls'),
      (['boys', 'boy', 'male', 'males'], 'boys'),
    ];
    for (final entry in genderPhrases) {
      for (final phrase in entry.$1) {
        if (working.contains(phrase)) {
          gender = entry.$2;
          working = working.replaceAll(phrase, ' ');
        }
      }
    }

    final tokens = working
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && !_stopWords.contains(t))
        .toList();

    final remaining = <String>[...bhkKeywords, ...localityKeywords];

    for (final token in tokens) {
      food ??= _foodFromToken(token);
      city ??= _cityFromToken(token);
      occupant ??= _occupantFromToken(token);
      gender ??= _genderFromToken(token);

      if (token == 'bhk' && bhkKeywords.isNotEmpty) continue;
      if (RegExp(r'^\d$').hasMatch(token) &&
          bhkKeywords.any((b) => b.startsWith(token))) {
        continue;
      }
      if (_localityKeywordSet.contains(token) ||
          _localityKeywordSet.contains(_canonicalLocality(token))) {
        final loc = _canonicalLocality(token);
        if (!remaining.contains(loc)) remaining.add(loc);
        continue;
      }

      if (!_isConsumed(token, food, city, occupant, gender)) {
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
      'hyderabad',
      'bangalore',
      'mumbai',
      'delhi',
    ];
    for (final phrase in phrases) {
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
  static bool _blobContainsTerm(String blob, String term) {
    if (term.isEmpty) return true;
    if (RegExp(r'^\d+bhk$').hasMatch(term)) return blob.contains(term);

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

  static bool _keywordMatches(String blob, String keyword) {
    final k = keyword.trim().toLowerCase();
    if (k.isEmpty) return true;
    return _blobContainsTerm(blob, k);
  }

  static String _consumeLocalitiesFromWorking(
    String working,
    List<String> keywords,
  ) {
    var w = working.trim();
    if (w.isEmpty) return w;

    final sorted = [..._localityKeywords]
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final loc in sorted) {
      if (w == loc) {
        final canon = _canonicalLocality(loc);
        if (!keywords.contains(canon)) keywords.add(canon);
        return '';
      }
      if (w.contains(loc)) {
        final canon = _canonicalLocality(loc);
        if (!keywords.contains(canon)) keywords.add(canon);
        w = w.replaceAll(loc, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }

    final single = w.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (single.length == 1) {
      final token = single.first;
      if (token.length >= 4) {
        for (final loc in sorted) {
          if (loc.startsWith(token)) {
            final canon = _canonicalLocality(loc);
            if (!keywords.contains(canon)) keywords.add(canon);
            return '';
          }
        }
      }
    }

    return w;
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

  static bool _cityMatches(Map<String, dynamic> item, String city) =>
      ListingData.matchesCityFilter(item, city);

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
