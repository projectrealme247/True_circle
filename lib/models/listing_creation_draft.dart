import 'listing_creation_category.dart';
import 'listing_creation_field_keys.dart';

/// In-memory listing creation payload — UI-agnostic draft state.
class ListingCreationDraft {
  const ListingCreationDraft({
    this.category = ListingCreationCategory.independentPlaces,
    this.title = '',
    this.price = '',
    this.description = '',
    this.eircode = '',
    this.latitude,
    this.longitude,
    this.bedsCount,
    this.parkingAvailable,
    this.roomType,
    this.householdDynamic,
    this.kitchenCulture,
    this.languagesSpoken = const [],
    this.hostName = '',
    this.hostCity = '',
    this.hostLanguage = '',
    this.hostMotherTongue = '',
    this.hostFoodPreference = '',
    this.listingAuthorizationConfirmed = false,
  });

  final ListingCreationCategory category;
  final String title;
  final String price;
  final String description;
  final String eircode;
  final double? latitude;
  final double? longitude;

  // Independent Places — wiped when switching to Shared Living.
  final int? bedsCount;
  final bool? parkingAvailable;

  // Shared Living — wiped when switching to Independent Places.
  final ListingShareRoomType? roomType;
  final ListingHouseholdDynamic? householdDynamic;
  final ListingKitchenCulture? kitchenCulture;
  final List<String> languagesSpoken;

  final String hostName;
  final String hostCity;
  final String hostLanguage;
  final String hostMotherTongue;
  final String hostFoodPreference;

  /// Required before publish — Shared Living and Entire Rental.
  final bool listingAuthorizationConfirmed;

  bool get hasResolvedCoordinates =>
      latitude != null && longitude != null && latitude!.isFinite && longitude!.isFinite;

  ListingCreationDraft copyWith({
    ListingCreationCategory? category,
    String? title,
    String? price,
    String? description,
    String? eircode,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
    int? bedsCount,
    bool clearBedsCount = false,
    bool? parkingAvailable,
    bool clearParkingAvailable = false,
    ListingShareRoomType? roomType,
    bool clearRoomType = false,
    ListingHouseholdDynamic? householdDynamic,
    bool clearHouseholdDynamic = false,
    ListingKitchenCulture? kitchenCulture,
    bool clearKitchenCulture = false,
    List<String>? languagesSpoken,
    String? hostName,
    String? hostCity,
    String? hostLanguage,
    String? hostMotherTongue,
    String? hostFoodPreference,
    bool? listingAuthorizationConfirmed,
  }) {
    return ListingCreationDraft(
      category: category ?? this.category,
      title: title ?? this.title,
      price: price ?? this.price,
      description: description ?? this.description,
      eircode: eircode ?? this.eircode,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      bedsCount: clearBedsCount ? null : (bedsCount ?? this.bedsCount),
      parkingAvailable: clearParkingAvailable
          ? null
          : (parkingAvailable ?? this.parkingAvailable),
      roomType: clearRoomType ? null : (roomType ?? this.roomType),
      householdDynamic: clearHouseholdDynamic
          ? null
          : (householdDynamic ?? this.householdDynamic),
      kitchenCulture:
          clearKitchenCulture ? null : (kitchenCulture ?? this.kitchenCulture),
      languagesSpoken: languagesSpoken ?? this.languagesSpoken,
      hostName: hostName ?? this.hostName,
      hostCity: hostCity ?? this.hostCity,
      hostLanguage: hostLanguage ?? this.hostLanguage,
      hostMotherTongue: hostMotherTongue ?? this.hostMotherTongue,
      hostFoodPreference: hostFoodPreference ?? this.hostFoodPreference,
      listingAuthorizationConfirmed: listingAuthorizationConfirmed ??
          this.listingAuthorizationConfirmed,
    );
  }

  /// FORCE RESET: wipe opposite-category conditional fields on toggle.
  ListingCreationDraft withCategory(ListingCreationCategory next) {
    if (next == category) return this;

    final base = copyWith(
      category: next,
      clearCoordinates: true,
      clearBedsCount: true,
      clearParkingAvailable: true,
      clearRoomType: true,
      clearHouseholdDynamic: true,
      clearKitchenCulture: true,
      languagesSpoken: const [],
    );

    if (next.isShared) {
      return base.copyWith(languagesSpoken: const ['English']);
    }

    return base;
  }

  ListingCreationDraft withCoordinates({
    required double latitude,
    required double longitude,
  }) {
    return copyWith(latitude: latitude, longitude: longitude);
  }
}
