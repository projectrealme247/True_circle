import 'package:flutter/foundation.dart';

import 'city_area_match.dart';
import 'commute_profile.dart';
import 'geo_math.dart';
import 'listing_sample_images.dart';
import 'profile_data.dart';
import 'rental_date_format.dart';
import 'address_privacy.dart';
import '../models/listing_creation_form_models.dart';
import '../services/commute_scoring_service.dart';
import 'student_track_preference.dart';
import 'target_search_areas.dart';

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
  /// Host declaration required before publish (Phase 1 listing accountability).
  static const listingAuthorizationConfirmedKey =
      'listing_authorization_confirmed';

  static const listingAuthorizationDeclaration =
      'I am authorised to advertise this property/room and the information provided is accurate.';

  /// First-publish timestamp (ISO-8601). Listing Freshness Phase 1.
  static const publishedAtKey = 'published_at';

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
    if (raw.isEmpty) return '';
    return raw.contains('/') ? raw : '$raw/month';
  }

  static String priceDisplayLabel(Map<String, dynamic> item) {
    final raw = price(item);
    if (raw.isEmpty) return 'Rent not set';
    return raw;
  }

  /// Card/chip label for listing availability — e.g. `4 Aug`.
  static String availableFromDisplayLabel(Map<String, dynamic> item) =>
      RentalDateFormat.formatRentalAvailabilityDate(text(item['available_from']));

  /// Parsed [published_at], or null when missing / unparseable.
  static DateTime? publishedAt(Map<String, dynamic> item) =>
      RentalDateFormat.parseDateTime(text(item[publishedAtKey]));

  /// Property-card freshness chip — empty when [published_at] is absent.
  ///
  /// `Listed today` | `Listed X days ago` | `Listed 60+ days ago`
  static String listedRelativeChipLabel(
    Map<String, dynamic> item, {
    DateTime? now,
  }) {
    final at = publishedAt(item);
    if (at == null) return '';

    final anchor = now ?? DateTime.now();
    final startToday = DateTime(anchor.year, anchor.month, anchor.day);
    final startListed = DateTime(at.year, at.month, at.day);
    final days = startToday.difference(startListed).inDays;

    if (days <= 0) return 'Listed today';
    if (days >= 60) return 'Listed 60+ days ago';
    return 'Listed $days days ago';
  }

  /// Detail-page line — empty when [published_at] is absent.
  ///
  /// `Listed on DD MMM YYYY`
  static String listedOnDisplayLabel(Map<String, dynamic> item) {
    final at = publishedAt(item);
    if (at == null) return '';
    final formatted = RentalDateFormat.formatListedOnDate(at);
    if (formatted.isEmpty) return '';
    return 'Listed on $formatted';
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
    if (item[AddressPrivacy.hideExactAddressKey] == true) {
      final public = text(item[AddressPrivacy.publicLocationKey]);
      if (public.isNotEmpty) return public;
    }
    final loc = text(item['location']);
    if (loc.isNotEmpty) return loc;
    return text(item['owner_city']);
  }

  /// Canonical marketplace tower: `Rent` | `Buy` | `Share`.
  ///
  /// Prefers [listing_type], then [type], then [marketplace_category].
  /// Used by discovery tower filtering — must stay aligned with [listingType].
  static String propertyType(Map<String, dynamic> item) {
    final listing = text(item['listing_type']);
    if (propertyTypes.contains(listing)) return listing;

    final raw = text(item['type']);
    if (propertyTypes.contains(raw)) return raw;

    final cat = text(item['marketplace_category']).toLowerCase();
    if (cat.contains('shared')) return 'Share';
    if (cat.contains('independent') ||
        cat.contains('full_rental') ||
        cat == 'full_rental') {
      return 'Rent';
    }

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

  /// Boundary-safe city match on location + host city text.
  static bool matchesCityFilter(Map<String, dynamic> item, String filterCity) {
    final key = filterCity.trim().toLowerCase();
    if (key.isEmpty) return true;

    final blob =
        '${location(item)} ${hostCity(item)}'.toLowerCase();
    return CityAreaMatch.blobMatchesFilter(blob, key);
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
      bedrooms(item),
      bedrooms(item).replaceAll(' ', ''),
      bathrooms(item),
      bathrooms(item).replaceAll(' ', ''),
      layoutSearchToken(item),
      shareRoomKind(item),
      ProfileData.text(item['shared_room_architecture']),
      propertyCategory(item),
      furnishing(item),
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
    'professional': 'working professionals',
    'professionals': 'working professionals',
    'student': 'students',
    'students': 'students',
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
      // Prefer explicit listing_type / marketplace_category over default Rent.
      final listing = text(raw['listing_type']);
      if (propertyTypes.contains(listing)) {
        property = listing;
      } else {
        final cat = text(raw['marketplace_category']).toLowerCase();
        if (cat.contains('shared')) {
          property = 'Share';
        } else if (cat.contains('independent') ||
            cat.contains('full_rental') ||
            cat == 'full_rental') {
          property = 'Rent';
        } else {
          property = 'Rent';
        }
      }
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

  static const commuteDestinationOptions = [
    'City Centre',
    'UCD',
    'TCD',
    'DCU',
    'Sandyford / Central Park',
    'Grand Canal Dock',
    'Other',
  ];

  /// Household weighting for dual-applicant commute scoring.
  static DualCommutePriority dualCommutePriority(Map<String, dynamic>? session) {
    if (session == null) return DualCommutePriority.balanced;
    final raw = text(session['dual_commute_priority']).toLowerCase();
    return switch (raw) {
      'person_b' || 'personb' => DualCommutePriority.personB,
      'balanced' => DualCommutePriority.balanced,
      'person_a' || 'persona' || _ => DualCommutePriority.personA,
    };
  }

  /// Per-commuter budget used when deriving scoreA / scoreB compatibility.
  static int commuteBudgetMinutesForProfile(
    CommuteProfileEntry profile,
    Map<String, dynamic>? session,
  ) {
    final fallback =
        ProfileData.maximumCommuteBudgetMinutes(session) ?? 45;

    final profilesRaw = session?['commute_profiles'];
    if (profilesRaw is List) {
      for (final entry in profilesRaw) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);
        if (text(map['id']) != profile.id) continue;
        final max = map['max_commute_minutes'];
        if (max is int) return max;
        final parsed = int.tryParse(text(max));
        if (parsed != null) return parsed;
      }
    }

    final perProfile = session?['commute_profile_max_minutes'];
    if (perProfile is Map) {
      final value = perProfile[profile.id];
      if (value is int) return value;
      final parsed = int.tryParse(text(value));
      if (parsed != null) return parsed;
    }

    return profile.maxCommuteMinutes ?? fallback;
  }

  static const kitchenUsageTimingOptions = [
    'Flexible',
    'Morning (6am–10am)',
    'Midday (11am–2pm)',
    'Evening (5pm–9pm)',
    'Late night (after 9pm)',
  ];

  static String kitchenUsageTiming(Map<String, dynamic> item) =>
      text(item['kitchen_usage_timing']);

  /// Maps legacy profile/listing keys to a valid timing option, or '' when unset.
  static String hydrateKitchenUsageTiming(Map<String, dynamic> raw) {
    final timing = text(raw['kitchen_usage_timing']);
    if (timing.isNotEmpty && kitchenUsageTimingOptions.contains(timing)) {
      return timing;
    }
    final legacy = text(raw['kitchen_utility_preference']);
    if (legacy.isNotEmpty && kitchenUsageTimingOptions.contains(legacy)) {
      return legacy;
    }
    return '';
  }

  static String bhk(Map<String, dynamic> item) => text(item['bhk']);
  static String bedrooms(Map<String, dynamic> item) => text(item['bedrooms']);
  static String bathrooms(Map<String, dynamic> item) => text(item['bathrooms']);
  static String shareRoomKind(Map<String, dynamic> item) =>
      text(item['share_room_kind']);

  static String layoutSearchToken(Map<String, dynamic> item) {
    final stored = text(item['layout_token']);
    if (stored.isNotEmpty) return stored;

    final bedMatch = RegExp(r'(\d+)').firstMatch(bedrooms(item));
    final bathMatch = RegExp(r'(\d+)').firstMatch(bathrooms(item));
    if (bedMatch == null || bathMatch == null) return '';
    return '${bedMatch.group(1)}bed${bathMatch.group(1)}bath';
  }

  static String furnishing(Map<String, dynamic> item) => text(item['furnishing']);
  static String propertyCategory(Map<String, dynamic> item) => text(item['property_category']);
  static String possessionStatus(Map<String, dynamic> item) => text(item['possession_status']);
  static String roomType(Map<String, dynamic> item) => text(item['room_type']);
  static int currentOccupants(Map<String, dynamic> item) => (item['current_occupants'] is int) ? item['current_occupants'] as int : 0;

  /// Bed count for card info lines (from [bedrooms], [bhk], or title).
  static int? bedCount(Map<String, dynamic> item) {
    for (final raw in [bedrooms(item), bhk(item)]) {
      if (raw.isEmpty) continue;
      final match = RegExp(r'(\d+)').firstMatch(raw);
      if (match != null) return int.tryParse(match.group(1)!);
    }
    final titleMatch = RegExp(
      r'(\d+)\s*bed(?:room)?s?',
      caseSensitive: false,
    ).firstMatch(title(item));
    if (titleMatch != null) {
      return int.tryParse(titleMatch.group(1)!);
    }
    return null;
  }

  /// Neighborhood label for cards — omits postal districts (e.g. "Dublin 18").
  static String cardAreaName(Map<String, dynamic> item) {
    final host = hostCity(item);
    if (host.isNotEmpty && !_isPostalDistrictLabel(host)) {
      return _titleCaseWords(host);
    }

    final loc = location(item);
    if (loc.isEmpty) return '';

    for (final part in loc.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty)) {
      if (!_isPostalDistrictLabel(part)) return _titleCaseWords(part);
    }
    return '';
  }

  static bool _isPostalDistrictLabel(String text) {
    final t = text.trim();
    if (t.isEmpty) return true;
    if (RegExp(r'^dublin\s+\d', caseSensitive: false).hasMatch(t)) return true;
    if (RegExp(r'^co\.?\s*dublin', caseSensitive: false).hasMatch(t)) return true;
    if (t.toLowerCase() == 'dublin') return true;
    if (RegExp(r'^county\s+', caseSensitive: false).hasMatch(t)) return true;
    return false;
  }

  static String _titleCaseWords(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.length == 1 ? w.toUpperCase() : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// Card-friendly property kind — Apartment, House, etc.
  static String cardPropertyKind(Map<String, dynamic> item) {
    final cat = propertyCategory(item).trim();
    if (cat.isNotEmpty) return _titleCaseWords(cat);

    final blob = '${title(item)} ${description(item)}'.toLowerCase();
    if (blob.contains('house') || blob.contains('cottage')) return 'House';
    if (blob.contains('villa')) return 'Villa';
    return 'Apartment';
  }

  /// Card-friendly room label for Share listings.
  static String cardRoomTypeLabel(Map<String, dynamic> item) {
    final raw = roomType(item).trim();
    if (raw.isNotEmpty) {
      final lower = raw.toLowerCase();
      if (lower.contains('ensuite')) return 'Ensuite Room';
      if (lower.contains('private')) return 'Private Room';
      if (lower.contains('shared') || lower.contains('bed in')) return 'Shared Room';
      return _titleCaseWords(raw);
    }

    return switch (shareRoomKind(item)) {
      'ensuite' || 'double_ensuite' => 'Ensuite Room',
      'private_bath' => 'Private Room',
      'bed_shared' => 'Shared Room',
      'student_room' => 'Student Room',
      _ => 'Room',
    };
  }

  /// Short transit hint parsed from listing text, e.g. "5-min to Luas".
  static String cardTransitHint(Map<String, dynamic> item) {
    final blob = '${title(item)} ${description(item)} ${location(item)}';
    final match = RegExp(
      r'(?:luas|green\s*line)[^\d]{0,24}(\d+)\s*min|(\d+)\s*min(?:ute)?s?[^\d]{0,24}(?:luas|green\s*line|rialto\s+luas|green\s+luas)',
      caseSensitive: false,
    ).firstMatch(blob);
    if (match == null) return '';
    final mins = match.group(1) ?? match.group(2);
    if (mins == null || mins.isEmpty) return '';
    return '$mins-min to Luas';
  }

  /// Same canonical tower as [propertyType] (listing_type → type → category).
  static String listingType(Map<String, dynamic> item) => propertyType(item);

  static bool isIndependentRental(Map<String, dynamic> item) =>
      listingType(item) == 'Rent';

  static bool isRoomShare(Map<String, dynamic> item) => listingType(item) == 'Share';

  /// True when secure bike parking is available (apartment listings).
  static bool hasBikeStorage(Map<String, dynamic> item) {
    if (item['secure_bike_storage'] == true) return true;
    if (item['has_bike_storage'] == true) return true;
    final features = ListingParkingFeature.parseFeatures(item);
    if (features.contains(ListingParkingFeature.bikeParking)) return true;
    return false;
  }

  static String parkingType(Map<String, dynamic> item) => text(item['parking_type']);

  /// True when the host explicitly provides parking (not no_parking / false flag).
  static bool parkingAvailable(Map<String, dynamic> item) {
    if (item['parking_available'] == false) return false;
    final features = ListingParkingFeature.parseFeatures(item);
    if (features.isNotEmpty) return true;
    final type = parkingType(item).toLowerCase();
    if (type.isEmpty) return item['parking_available'] == true;
    if (type == 'no_parking' || type == 'not_available') return false;
    return true;
  }

  static String parkingDisplayLabel(Map<String, dynamic> item) {
    final features = ListingParkingFeature.parseFeatures(item);
    if (features.isNotEmpty) {
      return features.map((f) => f.label).join(' · ');
    }
    return switch (parkingType(item)) {
      'not_available' || 'no_parking' => 'Not Available',
      'on_street' || 'paid_on_street_parking' => 'On Street',
      'driveway' || 'free_dedicated_parking' => 'Driveway',
      'garage' => 'Garage',
      'secure_bike_parking' || 'bike_parking' => 'Secure Bike Parking',
      'resident_car_parking' || 'resident_car' => 'Resident Car Parking',
      _ => '',
    };
  }

  /// Short parking label for listing-detail anatomy row.
  static String parkingHighlightLabel(Map<String, dynamic> item) {
    final label = parkingDisplayLabel(item);
    if (label.isEmpty) return 'Parking';
    return label;
  }

  /// Bed count label for listing-detail anatomy row (e.g. "2 Beds").
  static String bedsHighlightLabel(Map<String, dynamic> item) {
    final count = bedCount(item);
    if (count != null) return count == 1 ? '1 Bed' : '$count Beds';
    final raw = bedrooms(item).trim();
    if (raw.isNotEmpty) {
      if (RegExp(r'bed', caseSensitive: false).hasMatch(raw)) {
        return _titleCaseWords(raw);
      }
      return '${_titleCaseWords(raw)} Beds';
    }
    return 'Bedroom Count Not Listed';
  }

  /// Security deposit line for detail header (null when unknown).
  static String? securityDepositLabel(Map<String, dynamic> item) {
    final explicit = text(item['security_deposit']);
    if (explicit.isNotEmpty) {
      final digits = explicit.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.isNotEmpty && RegExp(r'^[€₹$]?\s?[\d,]+$').hasMatch(explicit.trim())) {
        return 'Deposit €$digits';
      }
      return explicit;
    }

    final desc = description(item);
    final lower = desc.toLowerCase();

    if (lower.contains('no deposit')) return 'No security deposit';

    final amountMatch = RegExp(
      r'deposit[:\s]+([€₹$]?\s?[\d,]+)',
      caseSensitive: false,
    ).firstMatch(desc);
    if (amountMatch != null) {
      final value = amountMatch.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        return 'Security deposit $value';
      }
    }

    if (lower.contains('deposit equals rent') ||
        lower.contains('deposit matches rent')) {
      return 'Security deposit equals one month\'s rent';
    }

    return null;
  }

  /// Full parking label for detail feature matrix.
  static String parkingMatrixLabel(Map<String, dynamic> item) {
    final label = parkingDisplayLabel(item);
    if (label.isNotEmpty) return label;
    return 'Ask Host About Parking';
  }

  /// Walk/transit profile parsed from listing copy when proximity data is absent.
  static ({int minutes, String destination})? detailTransitWalkProfile(
    Map<String, dynamic> item,
  ) {
    final walkMinutes = transitWalkMinutes(item);
    final transitType = transitTypeLabel(item);
    if (walkMinutes != null && transitType.isNotEmpty) {
      return (minutes: walkMinutes, destination: transitType);
    }

    final hint = cardTransitHint(item);
    if (hint.isNotEmpty) {
      final mins = RegExp(r'(\d+)').firstMatch(hint)?.group(1);
      final parsed = mins != null ? int.tryParse(mins) : null;
      if (parsed != null) {
        return (minutes: parsed, destination: 'Luas');
      }
    }

    final blob = '${description(item)} ${location(item)}';
    final walkPattern = RegExp(
      r'([A-Za-z][\w\s-]{2,50}?)\s+(\d+)\s*min(?:ute)?s?\s+walk',
      caseSensitive: false,
    );
    final walkMatches = walkPattern.allMatches(blob);
    if (walkMatches.isNotEmpty) {
      final match = walkMatches.last;
      final destination = match.group(1)!.trim();
      final minutes = int.tryParse(match.group(2)!);
      if (minutes != null && destination.isNotEmpty) {
        return (minutes: minutes, destination: destination);
      }
    }

    final forward = RegExp(
      r'(\d+)\s*min(?:ute)?s?\s+walk(?:\s+to\s+)?(.+?)(?:\.|,|;|$)',
      caseSensitive: false,
    ).firstMatch(blob);
    if (forward != null) {
      final minutes = int.tryParse(forward.group(1)!);
      var destination = forward.group(2)?.trim() ?? '';
      destination = destination.replaceAll(RegExp(r'\s+'), ' ');
      if (minutes != null && destination.isNotEmpty) {
        return (minutes: minutes, destination: destination);
      }
    }

    return null;
  }

  /// Share listing room + bath label for detail matrix.
  static String shareRoomMatrixLabel(Map<String, dynamic> item) {
    final kind = shareRoomKind(item);
    return switch (kind) {
      'ensuite' || 'double_ensuite' => 'Ensuite Room - Private Bath',
      'private_bath' => 'Private Room - Private Bath',
      'bed_shared' => 'Double Room - Shared Bath',
      'student_room' => 'Student Room - Shared Bath',
      _ => () {
        final room = cardRoomTypeLabel(item).toLowerCase();
        if (room.contains('ensuite')) return 'Ensuite Room - Private Bath';
        if (room.contains('shared') || room.contains('bed in')) {
          return 'Double Room - Shared Bath';
        }
        return '${cardRoomTypeLabel(item)} - Private Bath';
      }(),
    };
  }

  /// Household culture / occupant preference for share detail matrix.
  static String householdCultureMatrixLabel(Map<String, dynamic> item) {
    final preferred = text(item['preferred_tenant_occupant']);
    if (preferred.isNotEmpty) {
      final lower = preferred.toLowerCase();
      if (lower.contains('professional')) return 'Professionals Preferred';
      if (lower.contains('student')) return 'Student Friendly';
      if (lower.contains('family')) return 'Family Friendly';
      return '$preferred Preferred';
    }

    return switch (occupantType(item)) {
      'Students' => 'Student Friendly',
      'Working Professionals' => 'Professionals Preferred',
      'Family' => 'Family Friendly',
      'Bachelors' => () {
        final label = bachelorPreferenceBadgeLabel(bachelorPreference(item));
        return label.isNotEmpty ? label : 'Bachelors Preferred';
      }(),
      _ => 'Open Household',
    };
  }

  /// Dietary / kitchen rules for share detail matrix.
  static String dietaryKitchenMatrixLabel(Map<String, dynamic> item) {
    final token = foodPreferenceToken(item);
    final lifestyle = lifestylePreferences(item);
    final hasVegOnly = lifestyle.any((l) => l.toLowerCase() == 'veg') &&
        !lifestyle.any((l) => l.toLowerCase().contains('non'));

    return switch (token) {
      'veg' => hasVegOnly ? 'Strict Veg Only' : 'Veg-Friendly Kitchen',
      'non-veg' => 'Non-Veg Friendly Kitchen',
      _ => 'Open Kitchen',
    };
  }

  /// Primary languages spoken in the house for share detail matrix.
  static String houseLanguagesMatrixLabel(Map<String, dynamic> item) {
    final langs = languagesSpokenInHouse(item);
    if (langs.isNotEmpty) return langs.join(', ');
    final host = hostLanguage(item);
    if (host.isNotEmpty) return host;
    final mother = hostMotherTongue(item);
    return mother.isNotEmpty ? mother : 'Languages not listed';
  }

  /// Detail-page infrastructure rows (parking, culture, languages, transit).
  static List<MapEntry<String, String>> infrastructureDetailRows(
    Map<String, dynamic> item,
  ) {
    final rows = <MapEntry<String, String>>[];

    final parking = parkingDisplayLabel(item);
    if (parking.isNotEmpty) rows.add(MapEntry('Parking', parking));

    if (isRoomShare(item)) {
      final langs = languagesSpokenInHouse(item);
      if (langs.isNotEmpty) {
        rows.add(MapEntry('Languages in house', langs.join(', ')));
      }

      final culture = cultureChipLabels(item);
      if (culture.isNotEmpty) {
        rows.add(MapEntry('Household culture', culture.join(', ')));
      }
    }

    // Transit is rendered dynamically on the detail card via [CommuteScoreBadge].

    return rows;
  }

  static List<String> languagesSpokenInHouse(Map<String, dynamic> item) {
    final raw = item['languages_spoken'];
    if (raw is List) {
      return raw.map((e) => text(e)).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  static List<String> lifestyleFlags(Map<String, dynamic> item) {
    final seen = <String>{};
    final out = <String>[];

    void add(String flag) {
      final key = flag.trim();
      if (key.isEmpty || seen.contains(key)) return;
      seen.add(key);
      out.add(key);
    }

    final raw = item['lifestyle_flags'];
    if (raw is List) {
      for (final entry in raw) {
        add(text(entry));
      }
    }

    for (final pref in lifestylePreferences(item)) {
      add(switch (pref.trim().toLowerCase()) {
        'veg' => 'vegetarian_household',
        'non-veg' => 'non_veg_allowed',
        'no pets' => 'no_pets',
        _ => pref.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
      });
    }

    return out;
  }

  static const _cultureFlagChipLabels = {
    'vegetarian_household': 'Veg',
    'non_veg_allowed': 'Non-veg',
    'no_pets': 'No Pets',
    'no_smoking': 'No Smoking',
    'quiet_hours_preferred': 'Quiet Hours',
  };

  /// Culture / diet chips shown on the card (deduped).
  static List<String> cultureChipLabels(Map<String, dynamic> item) {
    final chips = <String>[];
    final food = foodPreferenceLabel(item);

    for (final flag in lifestyleFlags(item)) {
      final label = _cultureFlagChipLabels[flag] ?? '';
      if (label.isEmpty) continue;
      if (!chips.contains(label)) chips.add(label);
    }

    if (food.isNotEmpty) {
      chips.remove(food);
      chips.insert(0, food);
    }

    return chips;
  }

  /// Normalized labels for chips already rendered on the card.
  static Set<String> cardChipLabels(Map<String, dynamic> item) {
    final labels = <String>{};

    final furnish = furnishing(item);
    if (furnish.isNotEmpty) labels.add(furnish.toLowerCase());

    if (currentOccupants(item) > 0) labels.add('living');

    for (final chip in cultureChipLabels(item)) {
      labels.add(chip.toLowerCase());
    }

    final occupant = occupantType(item);
    if (occupant.isNotEmpty) labels.add(occupant.toLowerCase());

    final sub = occupantSubBadgeLabel(item);
    if (sub != null && sub.isNotEmpty) labels.add(sub.toLowerCase());

    return labels;
  }

  static String _parkingSubtextSegment(Map<String, dynamic> item) {
    return switch (parkingType(item)) {
      'free_dedicated_parking' || 'driveway' || 'garage' => '🅿️ Free Parking',
      'paid_on_street_parking' || 'on_street' => '🅿️ Paid Parking',
      'bike_parking' || 'secure_bike_parking' => '🚲 Bike Parking',
      'resident_car' || 'resident_car_parking' => '🅿️ Resident Parking',
      _ => ListingParkingFeature.parseFeatures(item).isNotEmpty
          ? '🅿️ Parking'
          : '',
    };
  }

  /// Path B proximity payload persisted on listings after transit extraction.
  static Map<String, dynamic>? proximityData(Map<String, dynamic> item) {
    final raw = item['proximity_data'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static String transitTypeLabel(Map<String, dynamic> item) {
    final proximity = proximityData(item);
    if (proximity == null) return '';
    final typed = text(proximity['transit_type']);
    if (typed.isNotEmpty) return typed;
    return text(proximity['luas_line']);
  }

  static int? transitWalkMinutes(Map<String, dynamic> item) {
    final proximity = proximityData(item);
    if (proximity == null) return null;
    for (final key in [
      'walk_minutes',
      'nearest_transit_minutes',
      'luas_minutes',
      'minutes',
    ]) {
      final value = proximity[key];
      if (value is num) return value.round();
      final parsed = int.tryParse(text(value));
      if (parsed != null) return parsed;
    }
    return null;
  }

  static bool hasTransitMacroTag(Map<String, dynamic> item) =>
      transitTypeLabel(item).isNotEmpty && transitWalkMinutes(item) != null;

  static LatLng? listingCoordinates(Map<String, dynamic> item) {
    final hidden = item[AddressPrivacy.hideExactAddressKey] == true;
    if (hidden) {
      final exactLat = item[AddressPrivacy.exactLatitudeKey];
      final exactLon = item[AddressPrivacy.exactLongitudeKey];
      if (exactLat is num && exactLon is num) {
        return LatLng(exactLat.toDouble(), exactLon.toDouble());
      }
    }
    final lat = item['latitude'];
    final lon = item['longitude'];
    if (lat is num && lon is num) {
      return LatLng(lat.toDouble(), lon.toDouble());
    }
    return null;
  }

  static String _transitSubtextSegment(Map<String, dynamic> item) {
    final proximity = proximityData(item);
    if (proximity != null) {
      final walkMinutes = transitWalkMinutes(item);
      final transitType = transitTypeLabel(item);
      if (walkMinutes != null && transitType.isNotEmpty) {
        return '🚇 $walkMinutes-min walk · $transitType';
      }

      final headline = text(
        proximity['transit_headline'] ?? proximity['commute_headline'],
      );
      if (headline.isNotEmpty) {
        return headline.startsWith('🚇') ? headline : '🚇 $headline';
      }

      final name = text(
        proximity['nearest_stop_name'] ??
            proximity['nearest_transit_name'] ??
            proximity['transit_name'] ??
            'Luas',
      );
      if (walkMinutes != null) {
        return '🚇 $walkMinutes-min to ${name.isEmpty ? 'Luas' : name}';
      }
    }

    final hint = cardTransitHint(item);
    if (hint.isEmpty) return '';
    return '🚇 $hint';
  }

  static String _viewerCommuteDestination(Map<String, dynamic>? viewerProfile) {
    if (viewerProfile == null) return '';
    return ProfileData.text(
      viewerProfile['commute_destination'] ??
          viewerProfile['primary_commute_destination'],
    );
  }

  static Set<String> _viewerLanguageTokens(Map<String, dynamic>? viewerProfile) {
    if (viewerProfile == null) return const {};

    final tokens = <String>{};
    for (final lang in ProfileData.languageList(
      viewerProfile['preferred_spoken_languages'],
    )) {
      final token = lang.trim().toLowerCase();
      if (token.isNotEmpty) tokens.add(token);
    }

    final mother = ProfileData.text(viewerProfile['mother_tongue']).trim().toLowerCase();
    if (mother.isNotEmpty) tokens.add(mother);

    return tokens;
  }

  static Iterable<String> _houseLanguageCandidates(Map<String, dynamic> item) sync* {
    for (final lang in languagesSpokenInHouse(item)) {
      if (lang.isNotEmpty) yield lang;
    }

    final mother = hostMotherTongue(item);
    if (mother.isNotEmpty) yield mother;

    for (final part in hostLanguage(item).split(RegExp(r'[,;]'))) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) yield trimmed;
    }
  }

  static bool _locationHintsCommuteDestination(
    Map<String, dynamic> item,
    String destination,
  ) {
    final dest = destination.trim().toLowerCase();
    if (dest.isEmpty) return false;

    final blob =
        '${location(item)} ${title(item)} ${description(item)}'.toLowerCase();
    final tokens = dest
        .split(RegExp(r'[/,\s]+'))
        .map((t) => t.trim())
        .where((t) => t.length > 3)
        .toList();
    if (tokens.isEmpty) return blob.contains(dest);
    return tokens.any(blob.contains);
  }

  /// Share-specific commute line, e.g. "Direct Luas to Citywest".
  static String _shareCommuteSubtextSegment(
    Map<String, dynamic> item,
    Map<String, dynamic>? viewerProfile,
  ) {
    final viewerDestination = _viewerCommuteDestination(viewerProfile);
    final proximity = item['proximity_data'];

    if (proximity is Map) {
      final preset = text(
        proximity['transit_headline'] ??
            proximity['commute_headline'] ??
            proximity['direct_commute_label'],
      );
      if (preset.isNotEmpty) {
        return preset.startsWith('🚇') ? preset : '🚇 $preset';
      }

      final line = text(proximity['luas_line'] ?? 'Luas');
      final directDest = text(
        proximity['direct_destination'] ??
            proximity['luas_destination'] ??
            proximity['commute_destination_label'],
      );
      if (directDest.isNotEmpty) {
        return '🚇 Direct $line to $directDest';
      }

      if (viewerDestination.isNotEmpty) {
        final destinations = proximity['destinations'];
        if (destinations is Map) {
          for (final entry in destinations.entries) {
            final key = text(entry.key).toLowerCase();
            if (!_commuteKeysAlign(key, viewerDestination)) continue;

            final value = entry.value;
            if (value is String && value.trim().isNotEmpty) {
              final label = value.trim();
              return label.startsWith('🚇') ? label : '🚇 $label';
            }
            if (value is Map) {
              final label = text(value['label'] ?? value['summary']);
              if (label.isNotEmpty) {
                return label.startsWith('🚇') ? label : '🚇 $label';
              }
              final destLabel = text(value['destination'] ?? value['name']);
              if (destLabel.isNotEmpty) {
                return '🚇 Direct $line to $destLabel';
              }
            }
          }
        }

        if (proximity['has_direct_luas'] == true ||
            proximity['direct_luas'] == true) {
          return '🚇 Direct $line to $viewerDestination';
        }
      }
    }

    final blob =
        '${title(item)} ${description(item)} ${location(item)}'.toLowerCase();
    final hasLuas =
        blob.contains('luas') || blob.contains('green line') || blob.contains('dart');

    if (viewerDestination.isNotEmpty && hasLuas) {
      final destLower = viewerDestination.toLowerCase();
      final directPhrase = RegExp(
        r'direct\s+(?:\w+\s+){0,3}(?:luas|green\s*line|dart)',
        caseSensitive: false,
      ).hasMatch(blob);
      if (directPhrase || _locationHintsCommuteDestination(item, viewerDestination)) {
        return '🚇 Direct Luas to $viewerDestination';
      }
      if (destLower.contains('citywest') &&
          (blob.contains('citywest') || blob.contains('city west'))) {
        return '🚇 Direct Luas to Citywest';
      }
    }

    return _transitSubtextSegment(item);
  }

  static bool _commuteKeysAlign(String proximityKey, String viewerDestination) {
    final key = proximityKey.trim().toLowerCase();
    final dest = viewerDestination.trim().toLowerCase();
    if (key.isEmpty || dest.isEmpty) return false;
    if (key == dest) return true;
    if (key.contains(dest) || dest.contains(key)) return true;

    final destTokens = dest
        .split(RegExp(r'[/,\s]+'))
        .map((t) => t.trim())
        .where((t) => t.length > 3);
    return destTokens.any((token) => key.contains(token));
  }

  static String? _matchedHouseLanguage(
    Map<String, dynamic> item,
    Map<String, dynamic>? viewerProfile,
  ) {
    final viewerLangs = _viewerLanguageTokens(viewerProfile);
    if (viewerLangs.isEmpty) return null;

    for (final houseLang in _houseLanguageCandidates(item)) {
      if (viewerLangs.contains(houseLang.trim().toLowerCase())) {
        return houseLang.trim();
      }
    }
    return null;
  }

  static bool _segmentRedundantWithChips(String segment, Set<String> chipLabels) {
    final lower = segment.toLowerCase();

    const keywordGroups = [
      ['veg', 'vegetarian'],
      ['non-veg', 'non veg'],
      ['no pets', 'pets'],
      ['no smoking', 'smoking'],
      ['quiet hours', 'quiet'],
    ];

    for (final group in keywordGroups) {
      if (group.any((key) => lower.contains(key)) &&
          chipLabels.any((chip) => group.any((key) => chip.contains(key)))) {
        return true;
      }
    }

    for (final chip in chipLabels) {
      if (chip.length >= 4 && lower.contains(chip)) return true;
    }
    return false;
  }

  /// Bottom-of-card intelligence line (joined with ·).
  static String cardDynamicSubtext(
    Map<String, dynamic> item, {
    Map<String, dynamic>? viewerProfile,
    Set<String>? excludeChipLabels,
  }) {
    final chipLabels = excludeChipLabels ?? cardChipLabels(item);
    final segments = <String>[];

    if (isIndependentRental(item)) {
      final parking = _parkingSubtextSegment(item);
      if (parking.isNotEmpty && !_segmentRedundantWithChips(parking, chipLabels)) {
        segments.add(parking);
      }
      final transit = _transitSubtextSegment(item);
      if (transit.isNotEmpty && !_segmentRedundantWithChips(transit, chipLabels)) {
        segments.add(transit);
      }
    } else if (isRoomShare(item)) {
      void addSegment(String segment) {
        if (segment.isEmpty) return;
        if (_segmentRedundantWithChips(segment, chipLabels)) return;
        segments.add(segment);
      }

      final language = _matchedHouseLanguage(item, viewerProfile);
      if (language != null) {
        addSegment('🗣️ Speaks $language');
      }

      final commute = _shareCommuteSubtextSegment(item, viewerProfile);
      addSegment(commute);
    }

    return segments.join(' · ');
  }

  /// Scannable descriptor line for listing cards (title area — no transit/parking).
  static String cardInfoLine(Map<String, dynamic> item) {
    final area = cardAreaName(item);
    final beds = bedCount(item);
    final kind = cardPropertyKind(item);
    final isShare = isRoomShare(item);

    final String core;
    if (isShare) {
      final room = cardRoomTypeLabel(item);
      final bedPart = beds != null ? '$beds Bed ' : '';
      core = '$room in a $bedPart$kind';
    } else {
      final bedPart = beds != null ? '$beds Bed ' : '';
      core = '$bedPart$kind';
    }

    var line = core;
    if (area.isNotEmpty) line = '$line • $area';

    return line;
  }

  // ── Trust & mutual matching fields ─────────────────────────────

  static int hostTrustStage(Map<String, dynamic> item) {
    final v = item['host_trust_stage'];
    return v is int ? v : 1;
  }

  static String? hostLinkedinBadge(Map<String, dynamic> item) {
    final v = text(item['host_linkedin_badge']);
    return v.isEmpty ? null : v;
  }

  static bool hostVerifiedBadge(Map<String, dynamic> item) =>
      item['host_verified_badge'] == true;

  static bool hostPreArrivalBadge(Map<String, dynamic> item) =>
      item['host_pre_arrival_badge'] == true;

  static String preferredTenantOccupant(Map<String, dynamic> item) =>
      text(item['preferred_tenant_occupant']);

  static String preferredTenantFood(Map<String, dynamic> item) =>
      text(item['preferred_tenant_food']);

  /// Landlord student verification track preference (defaults to all students).
  static StudentTrackPreference tenantTrackPreference(Map<String, dynamic> item) =>
      StudentTrackPreference.fromMap(item);

  static String tenantTrackPreferenceLabel(Map<String, dynamic> item) =>
      tenantTrackPreference(item).uiLabel;

  static bool smokingAllowed(Map<String, dynamic> item) =>
      item['smoking_allowed'] == true;

  static bool petsAllowed(Map<String, dynamic> item) {
    final policy = text(item['pets_policy']).toLowerCase();
    if (policy == 'allowed') return true;
    if (policy == 'not_allowed' || policy == 'case_by_case') return false;
    if (item['pets_allowed'] == true) return true;
    final flags = item['lifestyle_flags'];
    if (flags is List && flags.map((e) => e.toString()).contains('no_pets')) {
      return false;
    }
    return item['pets_allowed'] == true;
  }

  static String petsPolicyLabel(Map<String, dynamic> item) {
    return switch (text(item['pets_policy']).toLowerCase()) {
      'allowed' => 'Allowed',
      'not_allowed' => 'Not Allowed',
      'case_by_case' => 'Case-by-Case',
      _ => petsAllowed(item) ? 'Allowed' : 'Not Allowed',
    };
  }

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

    final targetTokens = TargetSearchAreas.hydrateFromSession(viewerProfile);
    final sameLocality = targetTokens.isNotEmpty &&
        TargetSearchAreas.listingMatchesTargets(targetTokens, listing);

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
    final flags = lifestyleFlags(raw);
    final houseLanguages = languagesSpokenInHouse(raw);
    final parking = parkingType(raw);
    // Single tower token for type + listing_type (Share must not collapse to Rent).
    final canonicalTower = propertyType({
      ...raw,
      'type': resolved['type']!,
    });
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
        ? ListingSampleImages.urlFor(listingIdKey, canonicalTower)
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
      if (text(raw['security_deposit']).isNotEmpty)
        'security_deposit': text(raw['security_deposit']),
      'location': location(raw),
      'type': canonicalTower,
      'listing_type': canonicalTower,
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
      if (flags.isNotEmpty) 'lifestyle_flags': flags,
      if (houseLanguages.isNotEmpty) 'languages_spoken': houseLanguages,
      if (parking.isNotEmpty) 'parking_type': parking,
      if (raw['latitude'] is num) 'latitude': (raw['latitude'] as num).toDouble(),
      if (raw['longitude'] is num) 'longitude': (raw['longitude'] as num).toDouble(),
      if (raw['proximity_data'] != null) 'proximity_data': raw['proximity_data'],
      if (bhk(raw).isNotEmpty) 'bhk': bhk(raw),
      if (furnishing(raw).isNotEmpty) 'furnishing': furnishing(raw),
      if (propertyCategory(raw).isNotEmpty) 'property_category': propertyCategory(raw),
      if (possessionStatus(raw).isNotEmpty) 'possession_status': possessionStatus(raw),
      if (roomType(raw).isNotEmpty) 'room_type': roomType(raw),
      if (currentOccupants(raw) > 0) 'current_occupants': currentOccupants(raw),
      if (bedrooms(raw).isNotEmpty) 'bedrooms': bedrooms(raw),
      if (bathrooms(raw).isNotEmpty) 'bathrooms': bathrooms(raw),
      if (scheduleType(raw).isNotEmpty) 'schedule_type': scheduleType(raw),
      if (raw['smoking_allowed'] == true) 'smoking_allowed': true,
      if (raw['drinking_allowed'] == true) 'drinking_allowed': true,
      if (raw['quiet_hours'] == true) 'quiet_hours': true,
      'tenant_track_preference': tenantTrackPreference(raw).dbValue,
      if (ProfileData.text(raw['owner_user_id']).isNotEmpty)
        'owner_user_id': ProfileData.text(raw['owner_user_id']),
      if (ProfileData.text(raw['landlord_id']).isNotEmpty)
        'landlord_id': ProfileData.text(raw['landlord_id']),
      if (ProfileData.text(raw['user_id']).isNotEmpty)
        'user_id': ProfileData.text(raw['user_id']),
      if (ProfileData.text(raw['owner_email']).isNotEmpty)
        'owner_email': ProfileData.text(raw['owner_email']),
      if (ProfileData.text(raw['ber_rating']).isNotEmpty)
        'ber_rating': ProfileData.text(raw['ber_rating']),
      if (ProfileData.text(raw['agreement_type']).isNotEmpty)
        'agreement_type': ProfileData.text(raw['agreement_type']),
      if (ProfileData.text(raw['property_sub_type']).isNotEmpty)
        'property_sub_type': ProfileData.text(raw['property_sub_type']),
      if (ProfileData.text(raw['available_from']).isNotEmpty)
        'available_from': ProfileData.text(raw['available_from']),
      if (ProfileData.text(raw[publishedAtKey]).isNotEmpty)
        publishedAtKey: ProfileData.text(raw[publishedAtKey]),
      if (raw[listingAuthorizationConfirmedKey] == true)
        listingAuthorizationConfirmedKey: true,
      if (ProfileData.text(raw['sublet_duration_value']).isNotEmpty)
        'sublet_duration_value': ProfileData.text(raw['sublet_duration_value']),
      if (ProfileData.text(raw['sublet_duration_unit']).isNotEmpty)
        'sublet_duration_unit': ProfileData.text(raw['sublet_duration_unit']),
      if (raw['neighborhood_proximity'] is Map)
        'neighborhood_proximity':
            Map<String, dynamic>.from(raw['neighborhood_proximity'] as Map),
      if (raw['neighborhood_lifestyle_tags'] is List)
        'neighborhood_lifestyle_tags':
            List<dynamic>.from(raw['neighborhood_lifestyle_tags'] as List),
      if (ProfileData.text(raw['shared_room_architecture']).isNotEmpty)
        'shared_room_architecture':
            ProfileData.text(raw['shared_room_architecture']),
      if (ProfileData.text(raw['flatmate_cohort']).isNotEmpty)
        'flatmate_cohort': ProfileData.text(raw['flatmate_cohort']),
      if (ProfileData.text(raw['target_tenant_preference']).isNotEmpty)
        'target_tenant_preference':
            ProfileData.text(raw['target_tenant_preference']),
      if (raw['monthly_electricity_cost'] != null)
        'monthly_electricity_cost': raw['monthly_electricity_cost'],
      if (raw['monthly_bins_cost'] != null)
        'monthly_bins_cost': raw['monthly_bins_cost'],
      if (raw['monthly_internet_cost'] != null)
        'monthly_internet_cost': raw['monthly_internet_cost'],
      if (raw['electricity_included_in_rent'] == true)
        'electricity_included_in_rent': true,
      if (raw['bins_included_in_rent'] == true)
        'bins_included_in_rent': true,
      if (raw['internet_included_in_rent'] == true)
        'internet_included_in_rent': true,
      if (raw['pets_allowed'] == true) 'pets_allowed': true,
      if (raw['wfh_friendly'] == true) 'wfh_friendly': true,
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

    if (description.trim().isNotEmpty && description.trim().length < 10) {
      errors['description'] =
          'If you add a description, use at least 10 characters.';
    }

    return errors;
  }
}
