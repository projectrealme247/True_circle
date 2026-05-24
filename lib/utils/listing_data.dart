import 'package:flutter/foundation.dart';

import 'listing_sample_images.dart';
import 'profile_data.dart';
import 'viewer_profile.dart';

/// Compatibility between viewer profile and a listing host.
class ListingProfileMatch {
  const ListingProfileMatch({
    this.sameLocality = false,
    this.sameMotherTongue = false,
    this.dietMatch = false,
  });

  final bool sameLocality;
  final bool sameMotherTongue;
  final bool dietMatch;

  bool get hasAny => sameLocality || sameMotherTongue || dietMatch;
}

/// Safe accessors and normalization for listing objects in localStorage.
abstract final class ListingData {
  static const propertyTypes = ['Rent', 'Buy', 'Share'];

  /// Alias for forms — property listing mode (Rent / Buy / Share).
  static const listingTypes = propertyTypes;

  /// @deprecated Use [occupantTypes] — kept for legacy reads only.
  static const tenantTypes = ['Family', 'Working', 'Students'];

  static const occupantTypes = ['Family', 'Bachelors', 'Working Professionals', 'Students'];

  static const bachelorPreferences = [
    'Boys only',
    'Girls only',
    'Boys & Girls allowed',
  ];

  static const studentTypes = [
    'Family supported',
    'Self-funded',
    'Education loan (bank financed)',
  ];

  static const scheduleTypes = [
    'Day shift',
    'Night shift',
    'Flexible',
  ];

  static const lifestyleOptions = [
    'Veg',
    'Non-veg',
    'No pets',
  ];

  static String text(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final raw = value.toString().trim();
    if (raw.isEmpty || raw == 'null') return fallback;
    return raw;
  }

  static String id(Map<String, dynamic> item, {int? fallbackIndex}) {
    final raw = item['id'];
    if (raw != null && raw.toString().trim().isNotEmpty) {
      return raw.toString().trim();
    }
    if (fallbackIndex != null) return 'listing-$fallbackIndex';
    return '';
  }

  static String title(Map<String, dynamic> item) =>
      text(item['title'], fallback: 'Untitled listing');

  static String price(Map<String, dynamic> item) {
    final raw = text(item['price']);
    if (raw.isEmpty) return 'Price on request';
    return raw.contains('/') ? raw : '$raw/day';
  }

  /// Parses numeric amount from price strings like `22000/month` or `₹25,000/month`.
  static int? listingPriceAmount(Map<String, dynamic> item) {
    final raw = text(item['price']);
    if (raw.isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  static String location(Map<String, dynamic> item) {
    final loc = text(item['location']);
    if (loc.isNotEmpty) return loc;
    return text(item['owner_city']);
  }

  static String propertyType(Map<String, dynamic> item) {
    final raw = text(item['type']);
    if (propertyTypes.contains(raw)) return raw;
    return 'Rent';
  }

  static String type(Map<String, dynamic> item) => propertyType(item);

  static String description(Map<String, dynamic> item) => text(item['description']);

  static String hostName(Map<String, dynamic> item) {
    final host = text(item['hostName']);
    if (host.isNotEmpty) return host;
    return text(item['owner_name'], fallback: 'Guest host');
  }

  static String hostCity(Map<String, dynamic> item) {
    final city = text(item['hostCity']);
    if (city.isNotEmpty) return city;
    return text(item['owner_city']);
  }

  static String hostLanguage(Map<String, dynamic> item) {
    final lang = text(item['hostLanguage']);
    if (lang.isNotEmpty) return lang;
    final langs = ProfileData.languageList(item['spoken_languages']);
    if (langs.isNotEmpty) return langs.join(', ');
    return hostMotherTongue(item);
  }

  static String hostMotherTongue(Map<String, dynamic> item) {
    final mother = text(item['hostMotherTongue']);
    if (mother.isNotEmpty) return mother;
    return text(item['owner_mother_tongue']);
  }

  static String hostFoodPreference(Map<String, dynamic> item) {
    final food = text(item['hostFoodPreference']);
    if (food.isNotEmpty) return food;
    final legacy = text(item['foodPreference']);
    if (legacy.isNotEmpty) return legacy;
    return text(item['owner_food_pref']);
  }

  /// Normalized food token: `veg`, `non-veg`, or empty.
  static String foodPreferenceToken(Map<String, dynamic> item) {
    final raw = hostFoodPreference(item).toLowerCase();
    if (raw.isEmpty) return '';
    if (raw.contains('veg') && !raw.contains('non')) return 'veg';
    if (raw.contains('non')) return 'non-veg';
    return '';
  }

  /// Canonical city keys → lowercase terms matched via location/hostCity [String.contains].
  static const cityFilterAliases = <String, List<String>>{
    'hyderabad': [
      'hyderabad',
      'hyd',
      'secunderabad',
      'hitech',
      'hitec',
      'gachibowli',
    ],
    'bangalore': [
      'bangalore',
      'bengaluru',
      'blr',
      'bang',
      'koramangala',
      'whitefield',
    ],
    'chennai': ['chennai', 'madras', 'chn', 'omr', 'velachery'],
    'mumbai': ['mumbai', 'bombay', 'andheri', 'bandra', 'powai', 'navi mumbai'],
    'delhi': ['delhi', 'ncr', 'dwarka', 'noida', 'gurgaon', 'gurugram'],
  };

  static Set<String> _cityFilterTerms(String filterCity) {
    final needle = filterCity.trim().toLowerCase();
    final terms = <String>{needle};
    if (needle.isEmpty) return terms;

    final direct = cityFilterAliases[needle];
    if (direct != null) terms.addAll(direct);

    for (final entry in cityFilterAliases.entries) {
      if (entry.value.any((alias) => alias == needle)) {
        terms.add(entry.key);
        terms.addAll(entry.value);
      }
    }
    return terms;
  }

  /// Flexible city match: case-insensitive substring on location / host city.
  static bool matchesCityFilter(Map<String, dynamic> item, String filterCity) {
    final terms = _cityFilterTerms(filterCity);
    if (terms.every((t) => t.isEmpty)) return true;

    final loc = location(item).toLowerCase();
    final host = hostCity(item).toLowerCase();

    for (final term in terms) {
      if (term.isEmpty) continue;
      if (loc.contains(term) || host.contains(term)) return true;
    }
    return false;
  }

  /// Flexible food match: case-insensitive equality on stored preference + tokens.
  static bool matchesFoodPreferenceFilter(
    Map<String, dynamic> item,
    String filterFood,
  ) {
    final expected = filterFood.trim().toLowerCase();
    if (expected.isEmpty) return true;

    final listingFood = hostFoodPreference(item).trim().toLowerCase();
    if (listingFood.isNotEmpty && listingFood == expected) return true;

    final token = foodPreferenceToken(item);
    if (token.isNotEmpty && token.toLowerCase() == expected) return true;

    if (listingFood.isEmpty) return false;

    return switch (expected) {
      'veg' => listingFood.contains('veg') && !listingFood.contains('non'),
      'non-veg' => listingFood.contains('non'),
      _ => listingFood.contains(expected),
    };
  }

  /// Flexible occupant match: case-insensitive equality.
  static bool matchesOccupantTypeFilter(
    Map<String, dynamic> item,
    String filterOccupant,
  ) =>
      matchesOccupantType(item, filterOccupant);

  /// Search filter match for food (delegates to [matchesFoodPreferenceFilter]).
  static bool matchesFoodPreference(Map<String, dynamic> item, String foodToken) =>
      matchesFoodPreferenceFilter(item, foodToken);

  /// Card/search label: `Veg`, `Non-veg`, or empty.
  static String foodPreferenceLabel(Map<String, dynamic> item) {
    return switch (foodPreferenceToken(item)) {
      'veg' => 'Veg',
      'non-veg' => 'Non-veg',
      _ => '',
    };
  }

  /// Extra search terms for intent and keyword matching.
  static List<String> foodPreferenceSearchTerms(Map<String, dynamic> item) {
    return switch (foodPreferenceToken(item)) {
      'veg' => const ['veg', 'vegetarian', 'vegetarians', 'foodpreference veg'],
      'non-veg' => const [
          'non-veg',
          'non veg',
          'nonvegetarian',
          'non-vegetarian',
          'foodpreference non-veg',
        ],
      _ => const [],
    };
  }

  static List<String> imageDataUris(Map<String, dynamic> item) {
    final raw = item['images'];
    if (raw is! List) return const [];
    return raw.map((e) => text(e)).where((s) => s.isNotEmpty).toList();
  }

  static String? coverImageDataUri(Map<String, dynamic> item) {
    final images = imageDataUris(item);
    return images.isEmpty ? null : images.first;
  }

  static String coverImageUrl(Map<String, dynamic> item) => text(item['coverImageUrl']);

  /// Network URL when no uploaded cover exists (sample / placeholder photos).
  static String? networkCoverUrl(Map<String, dynamic> item) {
    if (coverImageDataUri(item) != null) return null;
    final stored = coverImageUrl(item);
    if (stored.isNotEmpty) return stored;
    final listingId = id(item);
    if (listingId.isEmpty) return null;
    return ListingSampleImages.urlFor(listingId, propertyType(item));
  }

  /// Lowercase text blob for homepage search (partial + multi-keyword).
  static String searchText(Map<String, dynamic> item) {
    final bachelor = bachelorPreference(item);
    final student = studentType(item);
    final parts = <String>[
      title(item),
      location(item),
      price(item),
      propertyType(item),
      type(item),
      bhk(item),
      bhk(item).replaceAll(' ', ''),
      furnishing(item),
      propertyCategory(item),
      possessionStatus(item),
      roomType(item),
      hostName(item),
      hostCity(item),
      hostLanguage(item),
      hostMotherTongue(item),
      hostFoodPreference(item),
      foodPreferenceLabel(item),
      ...foodPreferenceSearchTerms(item),
      occupantType(item),
      bachelor,
      student,
      bachelorPreferenceBadgeLabel(bachelor),
      studentBackgroundBadgeLabel(student),
      description(item),
      preferredTenantType(item),
      openToSameLanguage(item),
      ...lifestylePreferences(item).where((pref) {
        final lower = pref.trim().toLowerCase();
        return lower != 'veg' && lower != 'non-veg' && !lower.contains('non-veg');
      }),
    ];
    return parts
        .map((p) => p.trim().toLowerCase())
        .where((p) => p.isNotEmpty)
        .join(' ');
  }

  static bool matchesSearch(Map<String, dynamic> item, String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return true;

    final blob = searchText(item);
    final keywords = trimmed.split(RegExp(r'\s+')).where((k) => k.isNotEmpty);
    return keywords.every((keyword) => blob.contains(keyword));
  }

  static List<Map<String, dynamic>> filterBySearch(
    List<Map<String, dynamic>> listings,
    String query,
  ) {
    return listings.where((item) => matchesSearch(item, query)).toList();
  }

  static String? videoDataUri(Map<String, dynamic> item) {
    final video = text(item['video']);
    return video.isEmpty ? null : video;
  }

  static String preferredTenantType(Map<String, dynamic> item) =>
      text(item['preferredTenantType']);

  static String occupantType(Map<String, dynamic> item) {
    final value = text(item['occupantType']);
    if (value.isNotEmpty) return value;
    final legacy = text(item['preferredTenantType']);
    if (legacy == 'Working') return 'Working Professionals';
    if (legacy == 'Bachelors') return 'Working Professionals';
    if (occupantTypes.contains(legacy)) return legacy;
    return '';
  }

  static const _occupantAliases = {
    'bachelors': 'working professionals',
    'working professionals': 'bachelors',
    'working': 'working professionals',
  };

  /// Flexible match: listing occupant type equals [expected], case-insensitive.
  /// Treats "Bachelors" and "Working Professionals" as equivalent.
  static bool matchesOccupantType(Map<String, dynamic> item, String expected) {
    final actual = occupantType(item).trim().toLowerCase();
    final filter = expected.trim().toLowerCase();
    if (actual.isEmpty || filter.isEmpty) return false;
    if (actual == filter) return true;
    final alias = _occupantAliases[filter];
    return alias != null && actual == alias;
  }

  /// Splits legacy conflated `type` values into property + occupant fields.
  static Map<String, String> resolvePropertyAndOccupant(Map<String, dynamic> raw) {
    var property = text(raw['type']);
    var occupant = text(raw['occupantType']);

    if (occupant.isEmpty) {
      final legacyTenant = text(raw['preferredTenantType']);
      if (legacyTenant == 'Working' || legacyTenant == 'Bachelors') {
        occupant = 'Working Professionals';
      } else if (occupantTypes.contains(legacyTenant)) {
        occupant = legacyTenant;
      }
    }

    if (occupantTypes.contains(property)) {
      if (occupant.isEmpty) occupant = property;
      property = 'Rent';
    } else if (property == 'Working' || property == 'Bachelors') {
      if (occupant.isEmpty) occupant = 'Working Professionals';
      property = 'Rent';
    } else if (!propertyTypes.contains(property)) {
      property = 'Rent';
    }

    return {'type': property, 'occupantType': occupant};
  }

  static String bachelorPreference(Map<String, dynamic> item) =>
      text(item['bachelorPreference']);

  static String studentType(Map<String, dynamic> item) => text(item['studentType']);

  /// Short, card-friendly label for bachelor sub-preference.
  static String bachelorPreferenceBadgeLabel(String value) {
    return switch (value) {
      'Boys only' => 'Boys only',
      'Girls only' => 'Girls only',
      'Boys & Girls allowed' => 'Mixed',
      _ => '',
    };
  }

  /// Short, card-friendly label for student background.
  static String studentBackgroundBadgeLabel(String value) {
    return switch (value) {
      'Family supported' => 'Family supported',
      'Self-funded' => 'Self-funded',
      'Education loan (bank financed)' => 'Education loan',
      _ => '',
    };
  }

  /// Sub-preference badge for cards (null when none).
  static String? occupantSubBadgeLabel(Map<String, dynamic> item) {
    final type = occupantType(item);
    if (type == 'Bachelors') {
      final label = bachelorPreferenceBadgeLabel(bachelorPreference(item));
      return label.isEmpty ? null : label;
    }
    if (type == 'Students') {
      final label = studentBackgroundBadgeLabel(studentType(item));
      return label.isEmpty ? null : label;
    }
    return null;
  }

  /// Detail-page value for preferred occupants / student background.
  static String occupantSubPreferenceDetail(Map<String, dynamic> item) {
    final type = occupantType(item);
    if (type == 'Bachelors') {
      return bachelorPreferenceBadgeLabel(bachelorPreference(item));
    }
    if (type == 'Students') {
      final raw = studentType(item);
      if (raw.isEmpty) return '';
      return studentBackgroundBadgeLabel(raw).isEmpty ? raw : studentBackgroundBadgeLabel(raw);
    }
    return '';
  }

  static String openToSameLanguage(Map<String, dynamic> item) =>
      text(item['openToSameLanguage']);

  // ── Tower-specific structured fields ────────────────────────────

  static const bhkOptions = ['1 RK', '1 BHK', '2 BHK', '3 BHK', '4+ BHK'];
  static const furnishingOptions = ['Furnished', 'Semi-furnished', 'Unfurnished'];
  static const propertyCategoryOptions = ['Apartment', 'House', 'Villa', 'Plot'];
  static const possessionStatusOptions = ['Ready to move', 'Under construction'];
  static const roomTypeOptions = ['Private room', 'Shared room'];

  static String bhk(Map<String, dynamic> item) => text(item['bhk']);
  static String furnishing(Map<String, dynamic> item) => text(item['furnishing']);
  static String propertyCategory(Map<String, dynamic> item) => text(item['property_category']);
  static String possessionStatus(Map<String, dynamic> item) => text(item['possession_status']);
  static String roomType(Map<String, dynamic> item) => text(item['room_type']);
  static int currentOccupants(Map<String, dynamic> item) => (item['current_occupants'] is int) ? item['current_occupants'] as int : 0;

  // ── Trust & mutual matching fields ─────────────────────────────

  static int hostTrustStage(Map<String, dynamic> item) {
    final v = item['host_trust_stage'];
    return v is int ? v : 1;
  }

  static double hostTrustMultiplier(Map<String, dynamic> item) {
    final v = item['host_trust_multiplier'];
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return ViewerProfile.trustMultiplierForStage(hostTrustStage(item));
  }

  static String? hostLinkedinBadge(Map<String, dynamic> item) {
    final v = text(item['host_linkedin_badge']);
    return v.isEmpty ? null : v;
  }

  static bool hostVerifiedBadge(Map<String, dynamic> item) =>
      item['host_verified_badge'] == true;

  static String preferredTenantOccupant(Map<String, dynamic> item) =>
      text(item['preferred_tenant_occupant']);

  static String preferredTenantFood(Map<String, dynamic> item) =>
      text(item['preferred_tenant_food']);

  static bool smokingAllowed(Map<String, dynamic> item) =>
      item['smoking_allowed'] == true;

  static bool drinkingAllowed(Map<String, dynamic> item) =>
      item['drinking_allowed'] == true;

  static bool quietHours(Map<String, dynamic> item) =>
      item['quiet_hours'] == true;

  static String scheduleType(Map<String, dynamic> item) =>
      text(item['schedule_type']);

  static List<String> lifestylePreferences(Map<String, dynamic> item) {
    final raw = item['lifestylePreferences'];
    if (raw is! List) return const [];
    return raw.map((e) => text(e)).where((s) => s.isNotEmpty).toList();
  }

  /// Host fields from the signed-in user profile (localStorage).
  static Map<String, String> hostFieldsFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) {
      return const {
        'hostName': 'Guest host',
        'hostCity': '',
        'hostLanguage': '',
        'hostMotherTongue': '',
        'hostFoodPreference': '',
      };
    }

    final name = ProfileData.text(profile['full_name']);
    final city = ProfileData.text(profile['detected_city']);
    final mother = ProfileData.text(profile['mother_tongue']);
    final food = ProfileData.text(profile['food_preference']);
    final spoken = ProfileData.languageList(profile['spoken_languages']);
    final language = spoken.isNotEmpty ? spoken.join(', ') : mother;

    return {
      'hostName': name.isEmpty ? 'Guest host' : name,
      'hostCity': city,
      'hostLanguage': language,
      'hostMotherTongue': mother,
      'hostFoodPreference': food,
    };
  }

  static String _normalizeToken(String value) =>
      value.trim().toLowerCase();

  /// Compares logged-in user profile with listing host data.
  static ListingProfileMatch compareWithProfile(
    Map<String, dynamic> listing,
    Map<String, dynamic>? viewerProfile,
  ) {
    if (viewerProfile == null) {
      return const ListingProfileMatch();
    }

    final viewerCity = _normalizeToken(ProfileData.text(viewerProfile['detected_city']));
    final listingCity = _normalizeToken(location(listing));
    final hostCityValue = _normalizeToken(hostCity(listing));

    final sameLocality = viewerCity.isNotEmpty &&
        (viewerCity == listingCity ||
            (hostCityValue.isNotEmpty && viewerCity == hostCityValue));

    final viewerMother =
        _normalizeToken(ProfileData.text(viewerProfile['mother_tongue']));
    final hostMother = _normalizeToken(hostMotherTongue(listing));
    final viewerLanguages = ProfileData.languageList(
      viewerProfile['spoken_languages'],
    ).map(_normalizeToken).toSet();
    final hostLanguages = ProfileData.languageList(
      listing['spoken_languages'],
    ).map(_normalizeToken).toSet();

    if (hostMother.isNotEmpty) {
      hostLanguages.add(hostMother);
    }
    final hostLanguageLabel = _normalizeToken(hostLanguage(listing));
    if (hostLanguageLabel.isNotEmpty) {
      for (final part in hostLanguageLabel.split(RegExp(r'[,;]'))) {
        final token = part.trim();
        if (token.isNotEmpty) hostLanguages.add(token);
      }
    }

    final sameMotherTongue = viewerMother.isNotEmpty &&
        (viewerMother == hostMother ||
            viewerLanguages.contains(hostMother) ||
            hostLanguages.contains(viewerMother));

    final viewerFoodRaw = ProfileData.text(viewerProfile['food_preference']);
    final viewerFood = foodPreferenceToken({
      'hostFoodPreference': viewerFoodRaw,
      'foodPreference': viewerFoodRaw,
    });
    final listingFood = foodPreferenceToken(listing);
    final dietMatch =
        viewerFood.isNotEmpty &&
        listingFood.isNotEmpty &&
        viewerFood == listingFood;

    return ListingProfileMatch(
      sameLocality: sameLocality,
      sameMotherTongue: sameMotherTongue,
      dietMatch: dietMatch,
    );
  }

  /// Logs per-listing profile match results (for debugging).
  static void debugLogProfileMatches(
    List<Map<String, dynamic>> listings,
    Map<String, dynamic>? viewerProfile,
  ) {
    debugPrint('--- Listing profile match debug ---');
    if (viewerProfile == null) {
      debugPrint('No logged-in user profile — match badges disabled.');
      debugPrint('--- end match debug ---');
      return;
    }

    final viewerCity = ProfileData.text(viewerProfile['detected_city']);
    final viewerLang = ProfileData.text(viewerProfile['mother_tongue']);
    final viewerFood = ProfileData.text(viewerProfile['food_preference']);
    debugPrint(
      'Viewer profile → city: ${viewerCity.isEmpty ? "(empty)" : viewerCity}, '
      'language: ${viewerLang.isEmpty ? "(empty)" : viewerLang}, '
      'food: ${viewerFood.isEmpty ? "(empty)" : viewerFood}',
    );

    for (var i = 0; i < listings.length; i++) {
      final item = listings[i];
      final match = compareWithProfile(item, viewerProfile);
      debugPrint(_formatMatchDebugLine(i, item, match));
    }
    debugPrint('--- end match debug ---');
  }

  static String _formatMatchDebugLine(
    int index,
    Map<String, dynamic> item,
    ListingProfileMatch match,
  ) {
    final parts = <String>[];
    if (match.sameLocality) parts.add('city');
    if (match.sameMotherTongue) parts.add('language');
    if (match.dietMatch) parts.add('food preference');

    final label = title(item);
    if (parts.isEmpty) {
      return 'Listing ${index + 1} ($label) → matched: none';
    }
    return 'Listing ${index + 1} ($label) → matched: ${parts.join(' + ')}';
  }

  /// Canonical listing shape for localStorage.
  static Map<String, dynamic> normalizeItem(
    Map<String, dynamic> raw, {
    int? fallbackIndex,
  }) {
    final listingId = id(raw, fallbackIndex: fallbackIndex);
    final resolved = resolvePropertyAndOccupant(raw);
    final images = imageDataUris(raw);
    final lifestyle = lifestylePreferences(raw);
    final tenant = preferredTenantType(raw);
    final occupant = resolved['occupantType']!;
    final bachelor = bachelorPreference(raw);
    final student = studentType(raw);
    final openLang = openToSameLanguage(raw);
    final video = videoDataUri(raw);
    final listingIdKey = listingId.isEmpty
        ? (fallbackIndex != null ? 'listing-$fallbackIndex' : 'listing')
        : listingId.toString();
    // Always refresh network cover when there are no uploads (fixes stale 404 URLs).
    final resolvedCoverUrl = images.isEmpty
        ? ListingSampleImages.urlFor(listingIdKey, resolved['type']!)
        : '';

    final foodLabel = foodPreferenceLabel(raw);
    final foodHost = hostFoodPreference(raw);
    final canonicalFood = foodLabel.isNotEmpty
        ? foodLabel
        : (foodHost.isNotEmpty ? foodHost : '');

    return {
      'id': listingId.isEmpty
          ? DateTime.now().millisecondsSinceEpoch
          : listingId,
      'title': title(raw),
      'price': price(raw),
      'location': location(raw),
      'type': resolved['type']!,
      'description': description(raw),
      'hostName': hostName(raw),
      'hostCity': hostCity(raw),
      'hostLanguage': hostLanguage(raw),
      'hostMotherTongue': hostMotherTongue(raw),
      if (canonicalFood.isNotEmpty) ...{
        'hostFoodPreference': canonicalFood,
        'foodPreference': canonicalFood,
      },
      if (raw['spoken_languages'] is List)
        'spoken_languages': ProfileData.languageList(raw['spoken_languages']),
      if (images.isNotEmpty) 'images': images,
      if (resolvedCoverUrl.isNotEmpty && images.isEmpty)
        'coverImageUrl': resolvedCoverUrl,
      if (video != null) 'video': video,
      if (tenant.isNotEmpty && occupant.isEmpty) 'preferredTenantType': tenant,
      if (occupant.isNotEmpty) 'occupantType': occupant,
      if (occupant == 'Bachelors' && bachelor.isNotEmpty)
        'bachelorPreference': bachelor,
      if (occupant == 'Students' && student.isNotEmpty) 'studentType': student,
      if (openLang.isNotEmpty) 'openToSameLanguage': openLang,
      if (lifestyle.isNotEmpty) 'lifestylePreferences': lifestyle,
      if (bhk(raw).isNotEmpty) 'bhk': bhk(raw),
      if (furnishing(raw).isNotEmpty) 'furnishing': furnishing(raw),
      if (propertyCategory(raw).isNotEmpty) 'property_category': propertyCategory(raw),
      if (possessionStatus(raw).isNotEmpty) 'possession_status': possessionStatus(raw),
      if (roomType(raw).isNotEmpty) 'room_type': roomType(raw),
      if (currentOccupants(raw) > 0) 'current_occupants': currentOccupants(raw),
    };
  }

  static List<Map<String, dynamic>> normalizeList(List<Map<String, dynamic>> raw) {
    return [
      for (var i = 0; i < raw.length; i++) normalizeItem(raw[i], fallbackIndex: i),
    ];
  }

  static String listingFingerprint(Map<String, dynamic> item) {
    return '${title(item).toLowerCase()}|${location(item).toLowerCase()}|${price(item).toLowerCase()}';
  }

  /// Validates add-listing form fields; empty map means valid.
  static Map<String, String> validateListingForm({
    required String title,
    required String price,
    required String location,
    required String type,
    required String description,
  }) {
    final errors = <String, String>{};

    if (title.trim().length < 3) {
      errors['title'] = 'Enter a title (at least 3 characters).';
    }

    final priceText = price.trim();
    if (priceText.isEmpty) {
      errors['price'] = 'Enter a price (e.g. 2500/day).';
    } else if (!RegExp(r'^\d+').hasMatch(priceText)) {
      errors['price'] = 'Price should start with a number.';
    }

    if (location.trim().length < 2) {
      errors['location'] = 'Enter a location.';
    }

    if (!propertyTypes.contains(type)) {
      errors['type'] = 'Select a property type (Rent, Buy, or Share).';
    }

    if (description.trim().length < 10) {
      errors['description'] = 'Add a short description (at least 10 characters).';
    }

    return errors;
  }
}
