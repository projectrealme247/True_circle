import 'package:flutter/material.dart';

/// A single chip in the unified proximity list.
class ProximityDisplayChip {
  const ProximityDisplayChip({
    required this.tier,
    required this.label,
    required this.icon,
    this.walkMin,
    this.sortKey = 0,
    this.chipCategory = '',
    this.matchName = '',
    this.isPinned = false,
    this.isHidden = false,
  });

  final ProximityDisplayTier tier;
  final String label;
  final IconData icon;
  final int? walkMin;

  /// Lower values sort earlier within the same tier.
  final int sortKey;

  /// Section category for stable hide/pin preferences.
  final String chipCategory;

  /// Stable name without walk minutes / decorative prefixes.
  final String matchName;

  final bool isPinned;
  final bool isHidden;

  int get tierOrder => switch (tier) {
        ProximityDisplayTier.tier1 => 1,
        ProximityDisplayTier.tier2 => 2,
        ProximityDisplayTier.tier3 => 3,
        ProximityDisplayTier.tier4 => 4,
      };

  ProximityDisplayChip copyWith({
    ProximityDisplayTier? tier,
    String? label,
    IconData? icon,
    int? walkMin,
    int? sortKey,
    String? chipCategory,
    String? matchName,
    bool? isPinned,
    bool? isHidden,
  }) {
    return ProximityDisplayChip(
      tier: tier ?? this.tier,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      walkMin: walkMin ?? this.walkMin,
      sortKey: sortKey ?? this.sortKey,
      chipCategory: chipCategory ?? this.chipCategory,
      matchName: matchName ?? this.matchName,
      isPinned: isPinned ?? this.isPinned,
      isHidden: isHidden ?? this.isHidden,
    );
  }
}

/// Priority tier for unified proximity chip display.
enum ProximityDisplayTier {
  /// DART, rail, Luas, bus, major grocers, schools, colleges.
  tier1,

  /// Pharmacy, childcare, hospital, GP, other grocers.
  tier2,

  /// Parks, gyms, shopping centres.
  tier3,

  /// Cafés, restaurants, pubs, ATMs.
  tier4,
}

/// A grouped neighborhood profile section for proximity display.
class ProximityProfileSection {
  const ProximityProfileSection({
    required this.title,
    required this.icon,
    required this.chips,
  });

  final String title;
  final IconData icon;
  final List<ProximityDisplayChip> chips;

  bool get isEmpty => chips.isEmpty;
}
