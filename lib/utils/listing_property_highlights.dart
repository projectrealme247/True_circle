import 'package:flutter/material.dart';

import 'listing_data.dart';

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

    if (ListingData.isRtbRegistered(item)) {
      highlights.add(
        const ListingHighlightCell(
          icon: Icons.verified_outlined,
          label: 'RTB Registered Landlord',
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

  /// Always returns exactly four cells — custom amenities first, then fallbacks.
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
}
