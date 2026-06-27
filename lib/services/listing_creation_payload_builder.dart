import '../models/listing_creation_draft.dart';
import '../models/listing_creation_field_keys.dart';
import 'listing_creation_validation_service.dart';

/// Maps a validated [ListingCreationDraft] to app + Supabase row shapes.
abstract final class ListingCreationPayloadBuilder {
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
      if (draft.latitude != null) ListingCreationFieldKeys.latitude: draft.latitude,
      if (draft.longitude != null)
        ListingCreationFieldKeys.longitude: draft.longitude,
      'hostName': draft.hostName.trim(),
      'hostCity': draft.hostCity.trim(),
      'hostLanguage': draft.hostLanguage.trim(),
      'hostMotherTongue': draft.hostMotherTongue.trim(),
      'hostFoodPreference': draft.hostFoodPreference.trim(),
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

    final row = <String, dynamic>{
      if (userId != null) 'user_id': userId,
      'title': local['title'],
      'price': local['price'],
      'location': local['location'],
      'description': local['description'] ?? '',
      'listing_type': local['listing_type'] ?? local['type'],
      ListingCreationFieldKeys.marketplaceCategory:
          local[ListingCreationFieldKeys.marketplaceCategory],
      if (local[ListingCreationFieldKeys.eircode] != null)
        ListingCreationFieldKeys.eircode: local[ListingCreationFieldKeys.eircode],
      if (lat is num) 'latitude': lat.toDouble(),
      if (lng is num) 'longitude': lng.toDouble(),
      if (lat is num && lng is num)
        ListingCreationFieldKeys.locationGeom: {
          'type': 'Point',
          'coordinates': [lng.toDouble(), lat.toDouble()],
        },
      'host_name': local['host_name'] ?? local['hostName'],
      'host_city': local['host_city'] ?? local['hostCity'],
      'host_language': local['host_language'] ?? local['hostLanguage'],
      'host_mother_tongue':
          local['host_mother_tongue'] ?? local['hostMotherTongue'],
      'host_food_preference':
          local['host_food_preference'] ?? local['hostFoodPreference'],
      if (local[ListingCreationFieldKeys.bedsCount] != null)
        ListingCreationFieldKeys.bedsCount: local[ListingCreationFieldKeys.bedsCount],
      if (local[ListingCreationFieldKeys.rtbStatus] != null)
        ListingCreationFieldKeys.rtbStatus: local[ListingCreationFieldKeys.rtbStatus],
      if (local['rtb_registered'] != null) 'rtb_registered': local['rtb_registered'],
      if (local[ListingCreationFieldKeys.parkingAvailable] != null)
        ListingCreationFieldKeys.parkingAvailable:
            local[ListingCreationFieldKeys.parkingAvailable],
      if (local['parking_type'] != null) 'parking_type': local['parking_type'],
      if (local[ListingCreationFieldKeys.roomType] != null)
        ListingCreationFieldKeys.roomType: local[ListingCreationFieldKeys.roomType],
      if (local['share_room_kind'] != null) 'share_room_kind': local['share_room_kind'],
      if (local['room_type'] != null) 'room_type': local['room_type'],
      if (local[ListingCreationFieldKeys.householdDynamic] != null)
        ListingCreationFieldKeys.householdDynamic:
            local[ListingCreationFieldKeys.householdDynamic],
      if (local[ListingCreationFieldKeys.kitchenCulture] != null)
        ListingCreationFieldKeys.kitchenCulture:
            local[ListingCreationFieldKeys.kitchenCulture],
      if (local[ListingCreationFieldKeys.languagesSpoken] is List)
        ListingCreationFieldKeys.languagesSpoken:
            local[ListingCreationFieldKeys.languagesSpoken]
      else if (local['languages_spoken'] is List)
        'languages_spoken': local['languages_spoken'],
      'metadata': _metadataOverflow(local),
    };

    return ListingCreationValidationService.stripForbiddenKeys(row);
  }

  static Map<String, dynamic> _independentFields(ListingCreationDraft draft) {
    final parking = draft.parkingAvailable!;
    final rtb = draft.rtbStatus!;

    return {
      ListingCreationFieldKeys.bedsCount: draft.bedsCount,
      'bedrooms': '${draft.bedsCount} bed',
      ListingCreationFieldKeys.rtbStatus: rtb.storageValue,
      'rtb_registered': rtb == ListingRtbStatus.registered,
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
      if (local[ListingCreationFieldKeys.eircode] != null)
        ListingCreationFieldKeys.eircode: local[ListingCreationFieldKeys.eircode],
      if (local['share_room_kind'] != null)
        'share_room_kind': local['share_room_kind'],
      if (local['preferred_tenant_occupant'] != null)
        'preferred_tenant_occupant': local['preferred_tenant_occupant'],
      if (local['foodPreference'] != null) 'foodPreference': local['foodPreference'],
    });
  }
}
