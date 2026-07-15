import '../utils/listing_sample_images.dart';

/// Shared builder for Dublin marketplace seed listings (v2 field coverage).
abstract final class DublinListingBuilder {
  static var _sharePhotoSlot = 0;
  static var _rentPhotoSlot = 0;

  static void resetPhotoSlots() {
    _sharePhotoSlot = 0;
    _rentPhotoSlot = 0;
  }

  /// Adds canonical aliases and defaults to legacy v1 seed rows.
  static Map<String, dynamic> enrichLegacy(Map<String, dynamic> raw) {
    final type = raw['type']?.toString() ?? 'Rent';
    final id = raw['id']?.toString() ?? '';
    final bedrooms = raw['bedrooms']?.toString();
    final food = raw['foodPreference']?.toString() ?? '';
    final langs = _languageList(raw['languages_spoken'] ?? raw['spoken_languages']);
    final trust = _legacyTrustForId(id);
    final availableFrom = raw['available_from']?.toString() ?? _availableFromForId(id);
    final availabilityFlexibility =
        raw['availability_flexibility']?.toString() ??
            _availabilityFlexibilityForId(id);

    final occupantRaw = raw['occupantType']?.toString();
    final preferredRaw = raw['preferred_tenant_occupant']?.toString() ??
        raw['preferredTenantOccupant']?.toString();
    final resolvedOccupant = occupantRaw ??
        preferredRaw ??
        (type == 'Share'
            ? _inferLegacyShareOccupant(raw)
            : _inferLegacyRentOccupant(raw));
    final resolvedPreferred = preferredRaw ??
        (type == 'Share' ? resolvedOccupant : null);

    return build(
      id: id,
      title: raw['title']?.toString() ?? '',
      price: raw['price']?.toString() ?? '',
      location: raw['location']?.toString() ?? '',
      type: type,
      description: raw['description']?.toString() ?? '',
      hostName: raw['hostName']?.toString() ?? '',
      hostCity: raw['hostCity']?.toString() ?? '',
      hostLanguage: raw['hostLanguage']?.toString() ?? '',
      hostMotherTongue: raw['hostMotherTongue']?.toString() ?? '',
      foodPreference: food,
      roomType: raw['room_type']?.toString(),
      furnishing: raw['furnishing']?.toString(),
      bedrooms: bedrooms,
      bhk: raw['bhk']?.toString() ?? _bhkFromBedrooms(bedrooms),
      bathrooms: raw['bathrooms']?.toString(),
      occupantType: resolvedOccupant,
      preferredTenantOccupant: resolvedPreferred,
      preferredTenantType: raw['preferredTenantType']?.toString(),
      preferredTenantFood: raw['preferred_tenant_food']?.toString(),
      bachelorPreference: raw['bachelorPreference']?.toString(),
      genderPreference: raw['gender_preference']?.toString(),
      currentOccupants: raw['current_occupants'] is int
          ? raw['current_occupants'] as int
          : null,
      smokingAllowed: raw['smoking_allowed'] == true,
      drinkingAllowed: raw['drinking_allowed'] == true,
      languagesSpoken: langs,
      spokenLanguages: langs,
      lifestyleFlags: raw['lifestyle_flags'] is List
          ? (raw['lifestyle_flags'] as List).map((e) => e.toString()).toList()
          : null,
      proximityData: raw['proximity_data'] is Map
          ? Map<String, dynamic>.from(raw['proximity_data'] as Map)
          : null,
      latitude: raw['latitude'] is num ? (raw['latitude'] as num).toDouble() : null,
      longitude: raw['longitude'] is num ? (raw['longitude'] as num).toDouble() : null,
      availableFrom: availableFrom,
      availabilityFlexibility: availabilityFlexibility,
      hostTrustStage: raw['host_trust_stage'] is int
          ? raw['host_trust_stage'] as int
          : trust,
    );
  }

  static Map<String, dynamic> build({
    required String id,
    required String title,
    required String price,
    required String location,
    required String type,
    required String description,
    required String hostName,
    required String hostCity,
    required String hostLanguage,
    required String hostMotherTongue,
    required String foodPreference,
    String? roomType,
    String? furnishing,
    String? bedrooms,
    String? bhk,
    String? bathrooms,
    String? occupantType,
    String? preferredTenantOccupant,
    String? preferredTenantType,
    String? preferredTenantFood,
    String? bachelorPreference,
    String? genderPreference,
    int? currentOccupants,
    bool? smokingAllowed,
    bool? drinkingAllowed,
    List<String>? languagesSpoken,
    List<String>? spokenLanguages,
    List<String>? lifestyleFlags,
    Map<String, dynamic>? proximityData,
    double? latitude,
    double? longitude,
    String? availableFrom,
    String? availabilityFlexibility,
    int hostTrustStage = 1,
  }) {
    final lowerTitle = title.toLowerCase();
    final lowerDesc = description.toLowerCase();
    final lowerRoom = (roomType ?? '').toLowerCase();

    final resolvedBedrooms = bedrooms ?? _inferBedrooms(lowerTitle, lowerDesc);
    final resolvedBhk = bhk ?? _bhkFromBedrooms(resolvedBedrooms);
    final resolvedBathrooms =
        bathrooms ?? _inferBathrooms(resolvedBedrooms, lowerTitle, lowerDesc);
    final resolvedCategory =
        _inferPropertyCategory(lowerTitle, lowerDesc, type);
    final resolvedShareKind = type == 'Share'
        ? _inferShareRoomKind(lowerTitle, lowerRoom, lowerDesc, occupantType)
        : null;
    final layoutToken = type == 'Rent'
        ? _layoutTokenFrom(resolvedBedrooms, resolvedBathrooms)
        : null;

    final resolvedParking = _inferParking(lowerDesc);
    final resolvedLanguages = languagesSpoken ??
        spokenLanguages ??
        _inferHouseLanguages(hostMotherTongue, hostLanguage);
    final resolvedSpoken = spokenLanguages ?? resolvedLanguages;
    final resolvedFlags = lifestyleFlags ??
        (type == 'Share'
            ? _inferLifestyleFlags(foodPreference, lowerDesc)
            : null);
    final resolvedProximity =
        proximityData ?? _inferProximity('$lowerTitle $lowerDesc', location);
    final canonicalFood = _canonicalFood(foodPreference);
    final resolvedGender =
        genderPreference ?? _genderFromBachelor(bachelorPreference);

    return {
      'id': id,
      'title': title,
      'price': price,
      'location': location,
      'type': type,
      'description': description,
      'hostName': hostName,
      'hostCity': hostCity,
      'hostLanguage': hostLanguage,
      'hostMotherTongue': hostMotherTongue,
      'foodPreference': foodPreference,
      'food_preference': canonicalFood,
      if (roomType != null) 'room_type': roomType,
      if (furnishing != null) 'furnishing': furnishing,
      if (resolvedBedrooms != null) 'bedrooms': resolvedBedrooms,
      if (resolvedBhk != null) 'bhk': resolvedBhk,
      if (resolvedBathrooms != null) 'bathrooms': resolvedBathrooms,
      if (resolvedCategory != null) 'property_category': resolvedCategory,
      if (resolvedShareKind != null) 'share_room_kind': resolvedShareKind,
      if (layoutToken != null) 'layout_token': layoutToken,
      if (currentOccupants != null) 'current_occupants': currentOccupants,
      if (occupantType != null) 'occupantType': occupantType,
      if (bachelorPreference != null) 'bachelorPreference': bachelorPreference,
      if (preferredTenantOccupant != null)
        'preferred_tenant_occupant': preferredTenantOccupant,
      if (preferredTenantType != null) 'preferredTenantType': preferredTenantType,
      if (preferredTenantFood != null) 'preferred_tenant_food': preferredTenantFood,
      if (resolvedGender != null && resolvedGender.isNotEmpty)
        'gender_preference': resolvedGender,
      if (smokingAllowed != null) 'smoking_allowed': smokingAllowed,
      if (drinkingAllowed != null) 'drinking_allowed': drinkingAllowed,
      if (resolvedParking != null) 'parking_type': resolvedParking,
      if (resolvedLanguages != null && resolvedLanguages.isNotEmpty) ...{
        'languages_spoken': resolvedLanguages,
        'spoken_languages': resolvedSpoken ?? resolvedLanguages,
      },
      if (resolvedFlags != null && resolvedFlags.isNotEmpty)
        'lifestyle_flags': resolvedFlags,
      if (resolvedProximity != null) 'proximity_data': resolvedProximity,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (availableFrom != null && availableFrom.isNotEmpty)
        'available_from': availableFrom,
      if (availabilityFlexibility != null && availabilityFlexibility.isNotEmpty)
        'availability_flexibility': availabilityFlexibility,
      'host_trust_stage': hostTrustStage,
      'listing_type': type,
      'coverImageUrl': ListingSampleImages.photoAt(
        type == 'Share' ? _sharePhotoSlot++ : _rentPhotoSlot++,
        type,
      ),
    };
  }

  static String _canonicalFood(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('non')) return 'non-veg';
    if (lower.contains('veg')) return 'veg';
    if (lower.contains('mixed') || lower.contains('flex')) return 'mixed';
    return raw;
  }

  static String? _genderFromBachelor(String? bachelor) {
    if (bachelor == null || bachelor.isEmpty) return null;
    final lower = bachelor.toLowerCase();
    if (lower.contains('girls') || lower.contains('female')) return 'Female only';
    if (lower.contains('boys') || lower.contains('male')) return 'Male only';
    if (lower.contains('mixed') || lower.contains('allowed')) return 'Any/Mixed';
    return null;
  }

  static String? _bhkFromBedrooms(String? bedrooms) {
    if (bedrooms == null || bedrooms.isEmpty) return null;
    final lower = bedrooms.toLowerCase();
    if (lower.contains('studio')) return '1';
    final match = RegExp(r'(\d+)').firstMatch(bedrooms);
    return match?.group(1);
  }

  static List<String>? _languageList(dynamic raw) {
    if (raw is! List) return null;
    final langs = raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    return langs.isEmpty ? null : langs;
  }

  static int _legacyTrustForId(String id) {
    final n = int.tryParse(RegExp(r'(\d+)$').firstMatch(id)?.group(1) ?? '') ?? 0;
    if (n % 6 == 0) return 3;
    if (n % 3 == 0) return 2;
    return 1;
  }

  static String? _inferLegacyRentOccupant(Map<String, dynamic> raw) {
    final blob =
        '${raw['title'] ?? ''} ${raw['description'] ?? ''}'.toLowerCase();
    if (blob.contains('student')) return 'Students';
    if (blob.contains('family')) return 'Family';
    if (blob.contains('professional') || blob.contains('couple')) {
      return 'Working Professionals';
    }
    return 'Working Professionals';
  }

  static String? _inferLegacyShareOccupant(Map<String, dynamic> raw) {
    final blob =
        '${raw['title'] ?? ''} ${raw['description'] ?? ''}'.toLowerCase();
    if (blob.contains('student') ||
        blob.contains('dkit') ||
        blob.contains('ucd') ||
        blob.contains('trinity')) {
      return 'Students';
    }
    if (blob.contains('family')) return 'Family';
    if (blob.contains('professional')) return 'Working Professionals';
    return 'Working Professionals';
  }

  static String _availableFromForId(String id) {
    final n = int.tryParse(RegExp(r'(\d+)$').firstMatch(id)?.group(1) ?? '') ?? 1;
    final month = 8 + ((n - 1) % 5);
    final day = 1 + ((n * 3) % 27);
    return '2026-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  static String _availabilityFlexibilityForId(String id) {
    final n = int.tryParse(RegExp(r'(\d+)$').firstMatch(id)?.group(1) ?? '') ?? 1;
    return switch (n % 4) {
      0 => 'exact_date',
      1 => 'plus_15_days',
      2 => 'plus_1_month',
      _ => 'flexible',
    };
  }

  static String? _inferParking(String description) {
    if (description.contains('no parking')) return 'no_parking';
    if (description.contains('parking included') ||
        description.contains('free parking') ||
        description.contains('dedicated parking')) {
      return 'free_dedicated_parking';
    }
    if (description.contains('on-street') || description.contains('paid parking')) {
      return 'paid_on_street_parking';
    }
    return null;
  }

  static List<String>? _inferHouseLanguages(
    String motherTongue,
    String hostLanguage,
  ) {
    final langs = <String>{};
    if (motherTongue.trim().isNotEmpty) langs.add(motherTongue.trim());
    for (final part in hostLanguage.split(RegExp(r'[,;]'))) {
      final lang = part.trim();
      if (lang.isNotEmpty) langs.add(lang);
    }
    return langs.isEmpty ? null : langs.toList();
  }

  static List<String>? _inferLifestyleFlags(
    String foodPreference,
    String description,
  ) {
    final flags = <String>[];
    final food = foodPreference.toLowerCase();
    if (food.contains('veg') && !food.contains('non')) {
      flags.add('vegetarian_household');
    } else if (food.contains('non')) {
      flags.add('non_veg_allowed');
    }
    if (description.contains('no pet')) flags.add('no_pets');
    if (description.contains('no smoking')) flags.add('no_smoking');
    if (description.contains('quiet')) flags.add('quiet_hours_preferred');
    return flags.isEmpty ? null : flags;
  }

  static Map<String, dynamic>? _inferProximity(String description, String location) {
    final blob = '$description $location'.toLowerCase();
    if (blob.contains('dart')) {
      final mins = _minutesFromText(blob, fallback: 9);
      return {
        'dart_line': 'DART',
        'dart_minutes': mins,
        'nearest_transit_name': 'DART',
        'transit_headline': '$mins-min to DART',
        'source': 'seed',
      };
    }
    if (blob.contains('bus')) {
      final mins = _minutesFromText(blob, fallback: 12);
      return {
        'bus_routes': '46A,145',
        'bus_minutes': mins,
        'nearest_transit_name': 'Bus',
        'transit_headline': '$mins-min to bus stop',
        'source': 'seed',
      };
    }
    if (blob.contains('luas') ||
        blob.contains('green line') ||
        blob.contains('canal dock') ||
        blob.contains('cherrywood') ||
        blob.contains('sandyford')) {
      final mins = _minutesFromText(blob, fallback: 8);
      return {
        'luas_line': 'Green Line',
        'luas_minutes': mins,
        'nearest_transit_minutes': mins,
        'nearest_transit_name': 'Luas',
        'transit_headline': '$mins-min to Luas',
        'has_direct_luas': true,
        'source': 'seed',
      };
    }
    if (blob.contains('dkit')) {
      return {
        'bus_routes': '100X',
        'bus_minutes': 8,
        'nearest_transit_name': 'Bus',
        'transit_headline': '8-min to bus stop',
        'source': 'seed',
      };
    }
    return null;
  }

  static int _minutesFromText(String blob, {required int fallback}) {
    final match = RegExp(r'(\d+)\s*min').firstMatch(blob);
    return match != null ? int.tryParse(match.group(1)!) ?? fallback : fallback;
  }

  static String? _inferBedrooms(String title, String description) {
    final blob = '$title $description';
    final match =
        RegExp(r'(\d+)\s*bed(?:room)?s?', caseSensitive: false).firstMatch(blob);
    if (match != null) return '${match.group(1)} bed';
    if (blob.contains('studio')) return 'Studio';
    return null;
  }

  static String? _inferBathrooms(
    String? bedrooms,
    String title,
    String description,
  ) {
    final blob = '$title $description';
    final explicit =
        RegExp(r'(\d+)\s*bath(?:room)?s?', caseSensitive: false).firstMatch(blob);
    if (explicit != null) return '${explicit.group(1)} bath';

    final bedCount = RegExp(r'(\d+)').firstMatch(bedrooms ?? '')?.group(1);
    if (bedCount == null) return null;
    final beds = int.tryParse(bedCount) ?? 0;
    if (beds >= 3 && blob.contains('2 bath')) return '2 bath';
    return '1 bath';
  }

  static String? _inferPropertyCategory(String title, String description, String type) {
    if (type != 'Rent') return null;
    final blob = '$title $description';
    if (blob.contains('house') || blob.contains('cottage')) return 'house';
    if (blob.contains('duplex') || blob.contains('townhouse')) return 'duplex';
    if (blob.contains('apartment') ||
        blob.contains('flat') ||
        blob.contains('studio')) {
      return 'apartment';
    }
    return 'apartment';
  }

  static String? _inferShareRoomKind(
    String title,
    String roomType,
    String description,
    String? occupantType,
  ) {
    if (roomType.contains('ensuite')) return 'ensuite';
    if (roomType.contains('bed in shared') || roomType.contains('shared room')) {
      return 'bed_in_shared';
    }
    if (roomType.contains('private')) return 'private_room';
    if (title.contains('twin')) return 'twin_share';
    if (description.contains('couple')) return 'couple_friendly';
    if (occupantType != null && occupantType.toLowerCase().contains('student')) {
      return 'student_house';
    }
    return 'private_room';
  }

  static String? _layoutTokenFrom(String? bedrooms, String? bathrooms) {
    if (bedrooms == null) return null;
    final bedToken = bedrooms.replaceAll(' ', '');
    final bathToken = bathrooms?.replaceAll(' ', '') ?? '1bath';
    return '$bedToken-$bathToken';
  }

  // ── Proximity presets for deliberate test cases ────────────────

  static Map<String, dynamic> luasProximity({int minutes = 5}) => {
        'luas_line': 'Green Line',
        'luas_minutes': minutes,
        'nearest_transit_minutes': minutes,
        'nearest_transit_name': 'Luas',
        'transit_headline': '$minutes-min walk to Luas',
        'has_direct_luas': true,
        'source': 'seed',
      };

  static Map<String, dynamic> dartProximity({int minutes = 7}) => {
        'dart_line': 'DART',
        'dart_minutes': minutes,
        'nearest_transit_name': 'DART',
        'transit_headline': '$minutes-min to DART',
        'source': 'seed',
      };

  static Map<String, dynamic> busProximity({int minutes = 10}) => {
        'bus_routes': '46A,145',
        'bus_minutes': minutes,
        'nearest_transit_name': 'Bus',
        'transit_headline': '$minutes-min to bus',
        'source': 'seed',
      };

  static Map<String, dynamic> multiModalProximity({
    int luasMinutes = 6,
    int dartMinutes = 12,
    int busMinutes = 8,
  }) =>
      {
        'luas_line': 'Green Line',
        'luas_minutes': luasMinutes,
        'dart_line': 'DART',
        'dart_minutes': dartMinutes,
        'bus_routes': '46A,145',
        'bus_minutes': busMinutes,
        'transit_headline': 'Luas + DART + bus nearby',
        'source': 'seed',
      };
}
