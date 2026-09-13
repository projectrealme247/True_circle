import '../models/listing_creation_draft.dart';
import '../models/listing_creation_field_keys.dart';
import '../utils/listing_data.dart';
import '../utils/student_track_preference.dart';
import 'listing_creation_validation_service.dart';

/// Maps a validated [ListingCreationDraft] / local listing map to app + Supabase shapes.
abstract final class ListingCreationPayloadBuilder {
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isUuid(String? raw) {
    final value = raw?.trim() ?? '';
    return value.isNotEmpty && _uuidPattern.hasMatch(value);
  }

  static Map<String, dynamic> toLocalListingMap(ListingCreationDraft draft) {
    final normalizedEircode = draft.eircode.trim().toUpperCase();
    final languages = _normalizedLanguages(draft);

    final map = <String, dynamic>{
      'title': draft.title.trim(),
      'price': draft.price.trim(),
      'location': '$normalizedEircode, Ireland',
      ListingCreationFieldKeys.eircode: normalizedEircode,
      'description': draft.description.trim(),
      'type': draft.category.towerPropertyType,
      'listing_type': draft.category.towerPropertyType,
      ListingCreationFieldKeys.marketplaceCategory: draft.category.storageToken,
      ListingCreationFieldKeys.publishedAt:
          DateTime.now().toUtc().toIso8601String(),
      if (draft.latitude != null) ListingCreationFieldKeys.latitude: draft.latitude,
      if (draft.longitude != null)
        ListingCreationFieldKeys.longitude: draft.longitude,
      'hostName': draft.hostName.trim(),
      'hostCity': draft.hostCity.trim(),
      'hostLanguage': draft.hostLanguage.trim(),
      'hostMotherTongue': draft.hostMotherTongue.trim(),
      'hostFoodPreference': draft.hostFoodPreference.trim(),
      if (draft.listingAuthorizationConfirmed)
        ListingCreationFieldKeys.listingAuthorizationConfirmed: true,
    };

    if (draft.category.isIndependent) {
      map.addAll(_independentFields(draft));
    } else {
      map.addAll(_sharedFields(draft, languages));
    }

    return ListingCreationValidationService.stripForbiddenKeys(map);
  }

  static Map<String, dynamic> toSupabaseRow(
    Map<String, dynamic> local, {
    required String? userId,
  }) {
    final lat = local[ListingCreationFieldKeys.latitude];
    final lng = local[ListingCreationFieldKeys.longitude];
    final listingType = ListingData.text(local['listing_type']).isNotEmpty
        ? ListingData.text(local['listing_type'])
        : ListingData.propertyType(local);
    final lifestyle = local['lifestyle_flags'];
    final languages = local[ListingCreationFieldKeys.languagesSpoken] ??
        local['languages_spoken'];
    final localId = local['id']?.toString();

    final row = <String, dynamic>{
      if (userId != null) 'user_id': userId,
      if (isUuid(localId)) 'id': localId,
      'title': ListingData.title(local).isNotEmpty
          ? ListingData.title(local)
          : local['title'],
      'price': ListingData.price(local).isNotEmpty
          ? ListingData.price(local)
          : local['price'],
      'location': ListingData.location(local).isNotEmpty
          ? ListingData.location(local)
          : local['location'],
      'description': ListingData.description(local).isNotEmpty
          ? ListingData.description(local)
          : (local['description'] ?? ''),
      'listing_type': listingType.isNotEmpty
          ? listingType
          : (local['listing_type'] ?? local['type']),
      ListingCreationFieldKeys.marketplaceCategory:
          local[ListingCreationFieldKeys.marketplaceCategory],
      if (local[ListingCreationFieldKeys.eircode] != null)
        ListingCreationFieldKeys.eircode: local[ListingCreationFieldKeys.eircode],
      'property_type': ListingData.text(local['property_type']).isNotEmpty
          ? ListingData.text(local['property_type'])
          : ListingData.text(
              local['property_structure'] ?? local['property_category'],
            ),
      if (lat is num) 'latitude': lat.toDouble(),
      if (lng is num) 'longitude': lng.toDouble(),
      if (lat is num && lng is num)
        ListingCreationFieldKeys.locationGeom: {
          'type': 'Point',
          'coordinates': [lng.toDouble(), lat.toDouble()],
        },
      'host_name': ListingData.hostName(local).isNotEmpty
          ? ListingData.hostName(local)
          : (local['host_name'] ?? local['hostName']),
      'host_city': ListingData.hostCity(local).isNotEmpty
          ? ListingData.hostCity(local)
          : (local['host_city'] ?? local['hostCity']),
      'host_language': local['host_language'] ?? local['hostLanguage'],
      'host_mother_tongue':
          local['host_mother_tongue'] ?? local['hostMotherTongue'],
      'host_food_preference':
          local['host_food_preference'] ?? local['hostFoodPreference'],
      'tenant_track_preference':
          ListingData.tenantTrackPreference(local).dbValue,
      if (local[ListingCreationFieldKeys.listingAuthorizationConfirmed] == true)
        ListingCreationFieldKeys.listingAuthorizationConfirmed: true,
      if (local[ListingCreationFieldKeys.bedsCount] != null)
        ListingCreationFieldKeys.bedsCount:
            local[ListingCreationFieldKeys.bedsCount],
      if (local[ListingCreationFieldKeys.parkingAvailable] != null)
        ListingCreationFieldKeys.parkingAvailable:
            local[ListingCreationFieldKeys.parkingAvailable],
      if (ListingData.parkingType(local).isNotEmpty)
        'parking_type': ListingData.parkingType(local)
      else if (local['parking_type'] != null)
        'parking_type': local['parking_type'],
      if (local[ListingCreationFieldKeys.roomType] != null)
        ListingCreationFieldKeys.roomType:
            local[ListingCreationFieldKeys.roomType],
      if (local['share_room_kind'] != null)
        'share_room_kind': local['share_room_kind'],
      if (local['room_type'] != null) 'room_type': local['room_type'],
      if (local[ListingCreationFieldKeys.householdDynamic] != null)
        ListingCreationFieldKeys.householdDynamic:
            local[ListingCreationFieldKeys.householdDynamic],
      if (local[ListingCreationFieldKeys.kitchenCulture] != null)
        ListingCreationFieldKeys.kitchenCulture:
            local[ListingCreationFieldKeys.kitchenCulture],
      if (lifestyle is List && lifestyle.isNotEmpty) 'lifestyle_flags': lifestyle,
      if (languages is List && languages.isNotEmpty)
        ListingCreationFieldKeys.languagesSpoken: languages,
      if (local['proximity_data'] != null)
        'proximity_data': local['proximity_data'],
      if (ListingData.text(local['room_configuration']).isNotEmpty)
        'room_configuration': ListingData.text(local['room_configuration']),
      if (ListingData.furnishing(local).isNotEmpty)
        'furnishing': ListingData.furnishing(local),
      if (ListingData.bhk(local).isNotEmpty) 'bhk': ListingData.bhk(local),
      if (ListingData.bedrooms(local).isNotEmpty)
        'bedrooms': ListingData.bedrooms(local),
      if (ListingData.currentOccupants(local) > 0)
        'current_occupants': ListingData.currentOccupants(local),
      'metadata': _metadataOverflow(local),
    };

    return ListingCreationValidationService.stripForbiddenKeys(row);
  }

  static Map<String, dynamic> fromSupabaseRow(Map<String, dynamic> row) {
    final metadata = row['metadata'];
    final meta = metadata is Map
        ? Map<String, dynamic>.from(metadata)
        : <String, dynamic>{};

    final lifestyle = row['lifestyle_flags'];
    final languages = row['languages_spoken'];

    return ListingCreationValidationService.stripForbiddenKeys({
      'id': row['id']?.toString() ?? meta['id'],
      'title': row['title'],
      'price': row['price'],
      'location': row['location'],
      'description': row['description'],
      'type': row['listing_type'] ?? meta['type'] ?? 'Rent',
      'listing_type': row['listing_type'],
      'property_type': row['property_type'],
      if (row['parking_type'] != null) 'parking_type': row['parking_type'],
      if (lifestyle is List) 'lifestyle_flags': lifestyle,
      if (languages is List) 'languages_spoken': languages,
      if (row['latitude'] != null) 'latitude': row['latitude'],
      if (row['longitude'] != null) 'longitude': row['longitude'],
      if (row['proximity_data'] != null) 'proximity_data': row['proximity_data'],
      if (row['room_configuration'] != null)
        'room_configuration': row['room_configuration'],
      if (row['furnishing'] != null) 'furnishing': row['furnishing'],
      if (row['bhk'] != null) 'bhk': row['bhk'],
      if (row['bedrooms'] != null) 'bedrooms': row['bedrooms'],
      if (row['current_occupants'] != null)
        'current_occupants': row['current_occupants'],
      'hostName': row['host_name'] ?? meta['hostName'],
      'hostCity': row['host_city'] ?? meta['hostCity'],
      'hostLanguage': row['host_language'] ?? meta['hostLanguage'],
      'hostMotherTongue': row['host_mother_tongue'] ?? meta['hostMotherTongue'],
      'hostFoodPreference':
          row['host_food_preference'] ?? meta['hostFoodPreference'],
      'tenant_track_preference':
          StudentTrackPreference.fromDbValue(row['tenant_track_preference'])
              .dbValue,
      if (meta['foodPreference'] != null) 'foodPreference': meta['foodPreference'],
      ...meta,
      if (ListingData.text(row[ListingData.publishedAtKey]).isNotEmpty)
        ListingData.publishedAtKey:
            ListingData.text(row[ListingData.publishedAtKey]),
    });
  }

  static Map<String, dynamic> _independentFields(ListingCreationDraft draft) {
    final parking = draft.parkingAvailable!;

    return {
      ListingCreationFieldKeys.bedsCount: draft.bedsCount,
      'bedrooms': '${draft.bedsCount} bed',
      ListingCreationFieldKeys.parkingAvailable: parking,
      'parking_type': parking ? 'free_dedicated_parking' : 'no_parking',
    };
  }

  static Map<String, dynamic> _sharedFields(
    ListingCreationDraft draft,
    List<String> languages,
  ) {
    final room = draft.roomType!;
    final household = draft.householdDynamic!;
    final kitchen = draft.kitchenCulture!;

    return {
      'room_type': room == ListingShareRoomType.ensuite
          ? 'Ensuite room'
          : 'Shared room',
      'share_room_kind': room == ListingShareRoomType.ensuite
          ? 'ensuite'
          : 'bed_shared',
      ListingCreationFieldKeys.householdDynamic: household.storageValue,
      'preferred_tenant_occupant': household.label,
      'occupantType': household.label,
      ListingCreationFieldKeys.kitchenCulture: kitchen.storageValue,
      'foodPreference': switch (kitchen) {
        ListingKitchenCulture.vegFriendly => 'Veg',
        ListingKitchenCulture.nonVegFriendly => 'Non-veg',
        ListingKitchenCulture.open => 'Any',
      },
      'languages_spoken': languages,
    };
  }

  static List<String> _normalizedLanguages(ListingCreationDraft draft) {
    final sanitized =
        ListingCreationValidationService.sanitizeLanguages(draft.languagesSpoken);
    if (sanitized.isNotEmpty) return sanitized;
    return const ['English'];
  }

  static Map<String, dynamic> _metadataOverflow(Map<String, dynamic> local) {
    return ListingCreationValidationService.stripForbiddenKeys({
      if (local['type'] != null) 'type': local['type'],
      if (local['intent_type'] != null) 'intent_type': local['intent_type'],
      if (local['hostName'] != null) 'hostName': local['hostName'],
      if (local['hostCity'] != null) 'hostCity': local['hostCity'],
      if (local['listing_area_key'] != null)
        'listing_area_key': local['listing_area_key'],
      if (local['hostLanguage'] != null) 'hostLanguage': local['hostLanguage'],
      if (local['hostMotherTongue'] != null)
        'hostMotherTongue': local['hostMotherTongue'],
      if (local['hostFoodPreference'] != null)
        'hostFoodPreference': local['hostFoodPreference'],
      if (local['foodPreference'] != null) 'foodPreference': local['foodPreference'],
      if (local['occupantType'] != null) 'occupantType': local['occupantType'],
      if (local['bachelorPreference'] != null)
        'bachelorPreference': local['bachelorPreference'],
      if (local['studentType'] != null) 'studentType': local['studentType'],
      if (local['preferred_tenant_occupant'] != null)
        'preferred_tenant_occupant': local['preferred_tenant_occupant'],
      if (local['preferred_tenant_food'] != null)
        'preferred_tenant_food': local['preferred_tenant_food'],
      if (local['room_type'] != null) 'room_type': local['room_type'],
      if (local['property_category'] != null)
        'property_category': local['property_category'],
      if (local['property_structure'] != null)
        'property_structure': local['property_structure'],
      if (local['share_room_kind'] != null)
        'share_room_kind': local['share_room_kind'],
      if (local['layout_token'] != null) 'layout_token': local['layout_token'],
      if (local['coverImageUrl'] != null) 'coverImageUrl': local['coverImageUrl'],
      if (local['images'] is List) 'images': local['images'],
      if (local['video'] != null) 'video': local['video'],
      if (local['spoken_languages'] is List)
        'spoken_languages': local['spoken_languages'],
      if (ListingData.text(local['security_deposit']).isNotEmpty)
        'security_deposit': ListingData.text(local['security_deposit']),
      if (local[ListingCreationFieldKeys.eircode] != null)
        ListingCreationFieldKeys.eircode: local[ListingCreationFieldKeys.eircode],
      if (ListingData.text(local[ListingData.publishedAtKey]).isNotEmpty)
        ListingData.publishedAtKey:
            ListingData.text(local[ListingData.publishedAtKey]),
      if (local[ListingCreationFieldKeys.listingAuthorizationConfirmed] == true)
        ListingCreationFieldKeys.listingAuthorizationConfirmed: true,
    });
  }
}
