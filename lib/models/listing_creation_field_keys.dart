/// Canonical payload keys for Phase C listing creation.
abstract final class ListingCreationFieldKeys {
  ListingCreationFieldKeys._();

  static const marketplaceCategory = 'marketplace_category';
  static const eircode = 'eircode';
  static const bedsCount = 'beds_count';
  static const rtbStatus = 'rtb_status';
  static const parkingAvailable = 'parking_available';
  static const roomType = 'room_type';
  static const householdDynamic = 'household_dynamic';
  static const kitchenCulture = 'kitchen_culture';
  static const languagesSpoken = 'languages_spoken';
  static const latitude = 'latitude';
  static const longitude = 'longitude';
  static const locationGeom = 'location_geom';

  /// Permanently deprecated — never serialize on create.
  static const forbiddenKeys = <String>{
    'kitchen_usage_timing',
    'kitchen_utility_preference',
    'kitchen_utility',
    'kitchenUtilityPreference',
  };
}

/// RTB registration status for independent places.
enum ListingRtbStatus {
  registered('registered'),
  notRegistered('not_registered'),
  notProvided('not_provided');

  const ListingRtbStatus(this.storageValue);
  final String storageValue;

  static ListingRtbStatus? parse(String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? '';
    return switch (normalized) {
      'registered' || 'rtb_registered' || 'true' => registered,
      'not_registered' || 'unregistered' || 'false' => notRegistered,
      'not_provided' || 'unknown' || '' => notProvided,
      _ => null,
    };
  }
}

/// Share room configuration — Ensuite vs Shared bath.
enum ListingShareRoomType {
  ensuite('ensuite', 'Ensuite'),
  shared('shared', 'Shared');

  const ListingShareRoomType(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static ListingShareRoomType? parse(String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? '';
    return switch (normalized) {
      'ensuite' || 'private_bath' || 'double_ensuite' => ensuite,
      'shared' || 'bed_shared' || 'shared_bath' => shared,
      _ => null,
    };
  }
}

/// Household culture / occupant dynamic for shared living.
enum ListingHouseholdDynamic {
  professionals('professionals', 'Professionals Preferred'),
  students('students', 'Student Friendly'),
  family('family', 'Family Friendly'),
  open('open', 'Open Household');

  const ListingHouseholdDynamic(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static ListingHouseholdDynamic? parse(String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? '';
    return switch (normalized) {
      'professionals' || 'working professionals' => professionals,
      'students' || 'student' => students,
      'family' => family,
      'open' || 'mixed' => open,
      _ => null,
    };
  }
}

/// Kitchen culture for shared living (not utility timing).
enum ListingKitchenCulture {
  vegFriendly('veg_friendly', 'Veg-Friendly Kitchen'),
  nonVegFriendly('non_veg_friendly', 'Non-Veg Friendly Kitchen'),
  open('open', 'Open Kitchen');

  const ListingKitchenCulture(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static ListingKitchenCulture? parse(String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? '';
    return switch (normalized) {
      'veg' || 'veg_friendly' || 'vegetarian' => vegFriendly,
      'non_veg' || 'non_veg_friendly' || 'non-veg' => nonVegFriendly,
      'open' => open,
      _ => null,
    };
  }
}
