import 'package:flutter/material.dart';

import '../config/market/market_config.dart';
import '../models/seeker_onboarding_enums.dart';
import 'listing_data.dart';
import 'shared_living_match_tokens.dart';

/// One cell in the listing detail highlights grid.
class ListingHighlightCell {
  const ListingHighlightCell({
    required this.icon,
    required this.label,
    this.isPlatformFallback = false,
  });

  final IconData icon;
  final String label;
  final bool isPlatformFallback;
}

/// Builds dynamic property highlight grids for listing detail views.
abstract final class ListingPropertyHighlights {
  static const _budgetProtection = ListingHighlightCell(
    icon: Icons.savings_outlined,
    label: 'Budget Protection Active',
    isPlatformFallback: true,
  );

  static const _verifiedLandlord = ListingHighlightCell(
    icon: Icons.verified_user_outlined,
    label: 'Verified Landlord Status',
    isPlatformFallback: true,
  );

  static const _extraFallbacks = <ListingHighlightCell>[
    ListingHighlightCell(
      icon: Icons.shield_outlined,
      label: 'TrueCircle Trust Verified',
      isPlatformFallback: true,
    ),
    ListingHighlightCell(
      icon: Icons.lock_outline,
      label: 'Secure Application Flow',
      isPlatformFallback: true,
    ),
  ];

  /// Active landlord-selected amenity highlights from listing booleans.
  /// Used by Shared Living detail + listing strength scoring.
  static List<ListingHighlightCell> activeHighlights(Map<String, dynamic> item) {
    final highlights = <ListingHighlightCell>[];

    if (ListingData.hasBikeStorage(item)) {
      highlights.add(
        const ListingHighlightCell(
          icon: Icons.pedal_bike_outlined,
          label: 'Secure Bike Storage Available',
        ),
      );
    }

    if (ListingData.parkingAvailable(item)) {
      final parkingLabel = ListingData.parkingDisplayLabel(item);
      highlights.add(
        ListingHighlightCell(
          icon: Icons.local_parking_outlined,
          label: parkingLabel.isNotEmpty
              ? parkingLabel
              : 'Parking Available',
        ),
      );
    }

    final furnishing = ListingData.furnishing(item).toLowerCase();
    if (furnishing.contains('furnished') && !furnishing.contains('unfurnished')) {
      highlights.add(
        const ListingHighlightCell(
          icon: Icons.weekend_outlined,
          label: 'Fully Furnished',
        ),
      );
    }

    final ber = ListingData.text(item['ber_rating']);
    if (ber.isNotEmpty) {
      highlights.add(
        ListingHighlightCell(
          icon: Icons.eco_outlined,
          label: 'BER $ber',
        ),
      );
    }

    return highlights;
  }

  /// Shared Living / legacy grid — always returns exactly four cells with
  /// platform fallbacks when amenities are sparse.
  static List<ListingHighlightCell> gridCells(Map<String, dynamic> item) {
    final grid = List<ListingHighlightCell?>.filled(4, null);
    final custom = activeHighlights(item);

    var customIndex = 0;
    for (var slot = 0; slot < 4 && customIndex < custom.length; slot++) {
      grid[slot] = custom[customIndex++];
    }

    grid[2] ??= _budgetProtection;
    grid[3] ??= _verifiedLandlord;

    for (var slot = 0; slot < 4; slot++) {
      if (grid[slot] != null) continue;
      grid[slot] = _extraFallbacks[slot % _extraFallbacks.length];
    }

    return grid.cast<ListingHighlightCell>();
  }

  /// Independent Places Property Highlights V1 — property facts only, no fillers.
  ///
  /// Priority: Bedrooms → Bathrooms → Property Type → Furnishing → Availability →
  /// Parking → Pets → Lease/Tenure → BER.
  static List<ListingHighlightCell> independentPlaceFactCells(
    Map<String, dynamic> item,
  ) {
    final cells = <ListingHighlightCell>[];

    final beds = ListingData.bedsHighlightLabel(item);
    if (beds != 'Bedroom Count Not Listed') {
      cells.add(
        ListingHighlightCell(
          icon: Icons.bed_outlined,
          label: beds,
        ),
      );
    }

    final baths = _bathsLabel(item);
    if (baths != null) {
      cells.add(
        ListingHighlightCell(
          icon: Icons.bathtub_outlined,
          label: baths,
        ),
      );
    }

    final propertyType = ListingData.propertyCategory(item).trim();
    final propertySubType = ListingData.text(item['property_sub_type']).trim();
    if (propertyType.isNotEmpty) {
      cells.add(
        ListingHighlightCell(
          icon: Icons.home_work_outlined,
          label: propertyType,
        ),
      );
    } else if (propertySubType.isNotEmpty) {
      final label = switch (propertySubType.toLowerCase()) {
        'house' => 'House',
        'apartment' => 'Apartment',
        _ => propertySubType,
      };
      cells.add(
        ListingHighlightCell(
          icon: Icons.home_work_outlined,
          label: label,
        ),
      );
    }

    final furnishing = ListingData.furnishing(item).trim();
    if (furnishing.isNotEmpty) {
      final lower = furnishing.toLowerCase();
      final label = (lower.contains('furnished') &&
              !lower.contains('unfurnished') &&
              !lower.contains('semi'))
          ? 'Furnished'
          : (lower.contains('unfurnished') ? 'Unfurnished' : furnishing);
      cells.add(
        ListingHighlightCell(
          icon: Icons.weekend_outlined,
          label: label,
        ),
      );
    }

    final availability = ListingData.availableFromDisplayLabel(item);
    if (availability.isNotEmpty) {
      cells.add(
        ListingHighlightCell(
          icon: Icons.calendar_today_outlined,
          label: availability,
        ),
      );
    }

    final parkingCell = _parkingFactCell(item);
    if (parkingCell != null) cells.add(parkingCell);

    final petsCell = _petsFactCell(item);
    if (petsCell != null) cells.add(petsCell);

    final leaseCell = _leaseFactCell(item);
    if (leaseCell != null) cells.add(leaseCell);

    final ber = ListingData.text(item['ber_rating']);
    if (ber.isNotEmpty) {
      cells.add(
        ListingHighlightCell(
          icon: Icons.eco_outlined,
          label: 'BER $ber',
        ),
      );
    }

    return cells;
  }

  static String? _bathsLabel(Map<String, dynamic> item) {
    final raw = ListingData.bathrooms(item).trim();
    if (raw.isEmpty) return null;
    final count = int.tryParse(RegExp(r'(\d+)').firstMatch(raw)?.group(1) ?? '');
    if (count != null) {
      return count == 1 ? '1 Bath' : '$count Baths';
    }
    if (RegExp(r'bath', caseSensitive: false).hasMatch(raw)) {
      return raw;
    }
    return '$raw Baths';
  }

  static ListingHighlightCell? _parkingFactCell(Map<String, dynamic> item) {
    if (ListingData.parkingAvailable(item)) {
      final label = ListingData.parkingDisplayLabel(item);
      return ListingHighlightCell(
        icon: Icons.local_parking_outlined,
        label: label.isNotEmpty ? label : 'Parking Available',
      );
    }

    final type = ListingData.parkingType(item).toLowerCase();
    if (type == 'no_parking' ||
        type == 'not_available' ||
        item['parking_available'] == false) {
      return const ListingHighlightCell(
        icon: Icons.local_parking_outlined,
        label: 'No Parking',
      );
    }
    return null;
  }

  static ListingHighlightCell? _petsFactCell(Map<String, dynamic> item) {
    final policy = ListingData.text(item['pets_policy']).toLowerCase();
    if (policy.isNotEmpty ||
        item['pets_allowed'] == true ||
        item['pets_allowed'] == false ||
        ListingData.lifestyleFlags(item).contains('no_pets')) {
      final allowed = ListingData.petsAllowed(item);
      return ListingHighlightCell(
        icon: Icons.pets_outlined,
        label: allowed ? 'Pets Allowed' : 'No Pets',
      );
    }
    return null;
  }

  static ListingHighlightCell? _leaseFactCell(Map<String, dynamic> item) {
    final tenure = TenurePreference.fromListing(item);
    if (tenure == null) return null;
    final duration = ListingData.text(item['sublet_duration_value']);
    final unit = ListingData.text(item['sublet_duration_unit']);
    if (duration.isNotEmpty) {
      final unitLabel = switch (unit.toLowerCase()) {
        'years' || 'year' => duration == '1' ? 'year' : 'years',
        'months' || 'month' => duration == '1' ? 'month' : 'months',
        'weeks' || 'week' => duration == '1' ? 'week' : 'weeks',
        _ => unit.isNotEmpty ? unit : '',
      };
      final suffix = unitLabel.isEmpty ? duration : '$duration $unitLabel';
      return ListingHighlightCell(
        icon: Icons.description_outlined,
        label: '${tenure.label} · $suffix',
      );
    }
    return ListingHighlightCell(
      icon: Icons.description_outlined,
      label: tenure.label,
    );
  }

  // ── Shared Living Detail Page V1 ───────────────────────────────────────────

  /// Room Snapshot — Room Type → Bathroom → Availability → Rent.
  static List<ListingHighlightCell> sharedLivingRoomSnapshotCells(
    Map<String, dynamic> item,
  ) {
    final cells = <ListingHighlightCell>[];

    final room = _sharedRoomTypeLabel(item);
    if (room != null) {
      cells.add(
        ListingHighlightCell(
          icon: Icons.bed_outlined,
          label: '🛏️ $room',
        ),
      );
    }

    final bath = _sharedBathroomLabel(item);
    if (bath != null) {
      cells.add(
        ListingHighlightCell(
          icon: Icons.bathtub_outlined,
          label: '🚿 $bath',
        ),
      );
    }

    final availability = ListingData.availableFromDisplayLabel(item);
    if (availability.isNotEmpty) {
      cells.add(
        ListingHighlightCell(
          icon: Icons.calendar_today_outlined,
          label: '📅 $availability',
        ),
      );
    }

    final rent = _sharedRentLabel(item);
    if (rent != null) {
      cells.add(
        ListingHighlightCell(
          icon: Icons.euro_outlined,
          label: '💶 $rent',
        ),
      );
    }

    return cells;
  }

  /// Household Snapshot — cohort + occupants (facts only).
  static List<ListingHighlightCell> sharedLivingHouseholdSnapshotCells(
    Map<String, dynamic> item,
  ) {
    final cells = <ListingHighlightCell>[];

    final household = _sharedHouseholdLabel(item);
    if (household != null) {
      final isStudent = household.toLowerCase().contains('student');
      cells.add(
        ListingHighlightCell(
          icon: isStudent ? Icons.school_outlined : Icons.groups_outlined,
          label: household,
        ),
      );
    }

    final occupants = ListingData.currentOccupants(item);
    if (occupants > 0) {
      cells.add(
        ListingHighlightCell(
          icon: Icons.person_outline,
          label: occupants == 1 ? '1 Occupant' : '$occupants Occupants',
        ),
      );
    }

    return cells;
  }

  /// Household Culture — display-only; empty list means hide section.
  static List<ListingHighlightCell> sharedLivingCultureCells(
    Map<String, dynamic> item,
  ) {
    final cells = <ListingHighlightCell>[];

    final langs = ListingData.languagesSpokenInHouse(item);
    if (langs.isNotEmpty) {
      cells.add(
        ListingHighlightCell(
          icon: Icons.language_outlined,
          label: langs.join(', '),
        ),
      );
    } else {
      final hostLang = ListingData.hostLanguage(item).trim();
      if (hostLang.isNotEmpty) {
        cells.add(
          ListingHighlightCell(
            icon: Icons.language_outlined,
            label: hostLang,
          ),
        );
      }
    }

    final kitchen = _sharedKitchenCultureLabel(item);
    if (kitchen != null) {
      cells.add(
        ListingHighlightCell(
          icon: Icons.restaurant_outlined,
          label: kitchen,
        ),
      );
    }

    for (final flag in ListingData.lifestyleFlags(item)) {
      final label = switch (flag) {
        'no_pets' => 'No Pets',
        'no_smoking' => 'No Smoking',
        'quiet_hours_preferred' || 'quiet_hours' => 'Quiet Hours',
        _ => '',
      };
      if (label.isEmpty) continue;
      if (cells.any((c) => c.label == label)) continue;
      cells.add(
        ListingHighlightCell(
          icon: flag.contains('pet')
              ? Icons.pets_outlined
              : (flag.contains('smok')
                  ? Icons.smoke_free_outlined
                  : Icons.nightlife_outlined),
          label: label,
        ),
      );
    }

    if (ListingData.petsAllowed(item) &&
        ListingData.text(item['pets_policy']).toLowerCase() == 'allowed') {
      if (!cells.any((c) => c.label == 'Pets Allowed' || c.label == 'No Pets')) {
        cells.add(
          const ListingHighlightCell(
            icon: Icons.pets_outlined,
            label: 'Pets Allowed',
          ),
        );
      }
    }

    return cells;
  }

  /// Property Details — supporting facts only (no platform fillers).
  static List<ListingHighlightCell> sharedLivingPropertyDetailCells(
    Map<String, dynamic> item,
  ) {
    final cells = <ListingHighlightCell>[];

    final propertyType = ListingData.propertyCategory(item).trim();
    final propertySubType = ListingData.text(item['property_sub_type']).trim();
    if (propertyType.isNotEmpty) {
      cells.add(
        ListingHighlightCell(
          icon: Icons.home_work_outlined,
          label: propertyType,
        ),
      );
    } else if (propertySubType.isNotEmpty) {
      final label = switch (propertySubType.toLowerCase()) {
        'house' => 'House',
        'apartment' => 'Apartment',
        _ => propertySubType,
      };
      cells.add(
        ListingHighlightCell(
          icon: Icons.home_work_outlined,
          label: label,
        ),
      );
    }

    final furnishing = ListingData.furnishing(item).trim();
    if (furnishing.isNotEmpty) {
      final lower = furnishing.toLowerCase();
      final label = (lower.contains('furnished') &&
              !lower.contains('unfurnished'))
          ? 'Furnished'
          : (lower.contains('unfurnished') ? 'Unfurnished' : furnishing);
      cells.add(
        ListingHighlightCell(
          icon: Icons.weekend_outlined,
          label: label,
        ),
      );
    }

    final parking = _parkingFactCell(item);
    if (parking != null) cells.add(parking);

    if (ListingData.hasBikeStorage(item)) {
      cells.add(
        const ListingHighlightCell(
          icon: Icons.pedal_bike_outlined,
          label: 'Bike Storage',
        ),
      );
    }

    final ber = ListingData.text(item['ber_rating']);
    if (ber.isNotEmpty) {
      cells.add(
        ListingHighlightCell(
          icon: Icons.eco_outlined,
          label: 'BER $ber',
        ),
      );
    }

    return cells;
  }

  static String? _sharedRoomTypeLabel(Map<String, dynamic> item) {
    final token = SharedLivingMatchTokens.roomFromListing(item);
    if (token == SharedLivingMatchTokens.privateRoom) return 'Private';
    if (token == SharedLivingMatchTokens.sharedRoom) return 'Shared';

    final kind = ListingData.shareRoomKind(item).toLowerCase();
    if (kind == 'bed_shared') return 'Shared';
    if (kind.isNotEmpty) return 'Private';

    final fallback = ListingData.cardRoomTypeLabel(item).toLowerCase();
    if (fallback.contains('shared') || fallback.contains('bed')) return 'Shared';
    if (fallback.contains('private') || fallback.contains('ensuite')) {
      return 'Private';
    }
    return null;
  }

  static String? _sharedBathroomLabel(Map<String, dynamic> item) {
    final kind = ListingData.shareRoomKind(item);
    switch (kind) {
      case 'ensuite':
      case 'double_ensuite':
      case 'private_bath':
        return 'Private Bathroom';
      case 'bed_shared':
      case 'student_room':
        return 'Shared Bathroom';
    }

    final token = SharedLivingMatchTokens.bathroomFromListing(item);
    if (token == SharedLivingMatchTokens.privateEnsuite) {
      return 'Private Bathroom';
    }
    if (token == SharedLivingMatchTokens.sharedBathroom) {
      return 'Shared Bathroom';
    }

    final room = SharedLivingMatchTokens.primarySharedRoom(item);
    final roomBath = ListingData.text(room?['bathroom_type']).toLowerCase();
    if (roomBath.contains('ensuite') ||
        roomBath.contains('private') ||
        roomBath == 'private_ensuite' ||
        roomBath == 'private_bathroom') {
      return 'Private Bathroom';
    }
    if (roomBath.contains('shared')) return 'Shared Bathroom';

    final blob = [
      ListingData.roomType(item),
      ListingData.cardRoomTypeLabel(item),
      ListingData.text(item['shared_room_architecture']),
      ListingData.text(item['bathroom_type']),
    ].join(' ').toLowerCase();

    if (blob.contains('ensuite') || blob.contains('private bath')) {
      return 'Private Bathroom';
    }
    if (blob.contains('shared bath') || blob.contains('shared bathroom')) {
      return 'Shared Bathroom';
    }

    return null;
  }

  static String? _sharedRentLabel(Map<String, dynamic> item) {
    final amount = ListingData.listingPriceAmount(item);
    if (amount == null) {
      final raw = ListingData.price(item).trim();
      return raw.isEmpty ? null : raw;
    }
    final symbol = MarketConfig.current.currencySymbol;
    final raw = ListingData.price(item);
    final periodMatch = RegExp(r'/(\w+)$').firstMatch(raw);
    final period = periodMatch != null ? '/${periodMatch.group(1)!}' : '/month';
    return '$symbol$amount$period';
  }

  static String? _sharedHouseholdLabel(Map<String, dynamic> item) {
    final occ = ListingData.occupantType(item);
    final fromOcc = _shortHouseholdFromRaw(occ);
    if (fromOcc != null) return fromOcc;

    final cohort = ListingData.text(
      item['flatmate_cohort'] ??
          item['household_cohort'] ??
          item['preferred_tenant_occupant'] ??
          item['cohort_type'],
    );
    return _shortHouseholdFromRaw(cohort);
  }

  static String? _shortHouseholdFromRaw(String raw) {
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower.contains('student')) return 'Students';
    if (lower.contains('working') || lower.contains('professional')) {
      return 'Professionals';
    }
    if (lower.contains('mixed') || lower.contains('open')) {
      return 'Mixed Household';
    }
    return null;
  }

  static String? _sharedKitchenCultureLabel(Map<String, dynamic> item) {
    final flags = ListingData.lifestyleFlags(item);
    if (flags.contains('vegetarian_household')) return 'Vegetarian household';
    if (flags.contains('non_veg_allowed')) return 'Mixed kitchen';

    final token = ListingData.foodPreferenceToken(item);
    return switch (token) {
      'veg' => 'Vegetarian household',
      'non-veg' => 'Mixed kitchen',
      _ => null,
    };
  }
}
