import 'package:flutter/material.dart';

import '../models/listing_creation_form_models.dart';
import '../models/neighborhood_amenity_tag.dart';
import '../models/proximity_display_chip.dart';
import '../services/overpass_amenities_service.dart';
import 'proximity_chip_keys.dart';
import 'transit_ranking.dart';

/// Snapshot of proximity fields used to build tiered display chips.
class ProximityDisplayInput {
  const ProximityDisplayInput({
    this.transportLine = '',
    this.transportWalkMin,
    this.groceryBrand = '',
    this.groceryWalkMin,
    this.groceries = const [],
    this.primarySchool = '',
    this.secondarySchool = '',
    this.collegeSchool = '',
    this.collegeWalkMin,
    this.crecheName = '',
    this.crecheWalkMin,
    this.gpClinic = '',
    this.gpWalkMin,
    this.extraTransit = const [],
    this.lifestyleTags = const [],
    this.customPoints = const [],
    this.hiddenChipKeys = const [],
    this.pinnedChipKeys = const [],
    this.includeHidden = false,
  });

  final String transportLine;
  final int? transportWalkMin;
  final String groceryBrand;
  final int? groceryWalkMin;
  final List<NearbyGroceryOption> groceries;
  final String primarySchool;
  final String secondarySchool;
  final String collegeSchool;
  final int? collegeWalkMin;
  final String crecheName;
  final int? crecheWalkMin;
  final String gpClinic;
  final int? gpWalkMin;
  final List<NearbyExtraTransit> extraTransit;
  final List<NeighborhoodAmenityTag> lifestyleTags;
  final List<CustomProximityPoint> customPoints;
  final List<String> hiddenChipKeys;
  final List<String> pinnedChipKeys;

  /// When true (edit mode), hidden chips remain visible so they can be restored.
  final bool includeHidden;
}

/// Builds neighborhood profile sections and tiered chips from structured fields.
abstract final class ProximityDisplayBuilder {
  static const _tier1GroceryBrands = {
    'tesco',
    'dunnes',
    'supervalu',
    'lidl',
    'aldi',
  };

  static List<ProximityProfileSection> buildProfile(ProximityDisplayInput input) {
    return [
      _finalizeSection(
        title: 'Transport',
        icon: Icons.directions_transit_outlined,
        category: ProximityChipKeys.transport,
        chips: _transportChips(input),
        input: input,
      ),
      _finalizeSection(
        title: 'Groceries',
        icon: Icons.shopping_bag_outlined,
        category: ProximityChipKeys.groceries,
        chips: _groceryChips(input),
        input: input,
      ),
      _finalizeSection(
        title: 'Education',
        icon: Icons.menu_book_outlined,
        category: ProximityChipKeys.education,
        chips: _educationChips(input),
        input: input,
      ),
      _finalizeSection(
        title: 'Healthcare',
        icon: Icons.health_and_safety_outlined,
        category: ProximityChipKeys.healthcare,
        chips: _healthcareChips(input),
        input: input,
      ),
      _finalizeSection(
        title: 'Lifestyle',
        icon: Icons.local_activity_outlined,
        category: ProximityChipKeys.lifestyle,
        chips: _lifestyleChips(input),
        input: input,
      ),
      _finalizeSection(
        title: 'Outdoors & local',
        icon: Icons.park_outlined,
        category: ProximityChipKeys.outdoors,
        chips: _outdoorsChips(input),
        input: input,
      ),
      _finalizeSection(
        title: 'Custom',
        icon: Icons.place_outlined,
        category: ProximityChipKeys.custom,
        chips: _customChips(input),
        input: input,
      ),
    ].where((section) => !section.isEmpty).toList();
  }

  static List<ProximityDisplayChip> build(ProximityDisplayInput input) {
    final chips = <ProximityDisplayChip>[];
    final seen = <String>{};

    for (final section in buildProfile(input)) {
      for (final chip in section.chips) {
        final key = '${chip.tier.name}|${_normalize(chip.label)}';
        if (seen.add(key)) chips.add(chip);
      }
    }

    chips.sort(_compareSectionChips);
    return chips;
  }

  static List<ProximityDisplayChip> forTier(
    List<ProximityDisplayChip> chips,
    ProximityDisplayTier tier,
  ) =>
      chips.where((c) => c.tier == tier).toList();

  static ProximityProfileSection _finalizeSection({
    required String title,
    required IconData icon,
    required String category,
    required List<ProximityDisplayChip> chips,
    required ProximityDisplayInput input,
  }) {
    final hidden = input.hiddenChipKeys.toSet();
    final pinned = input.pinnedChipKeys.toSet();
    final applied = <ProximityDisplayChip>[];

    for (final chip in chips) {
      final matchName = chip.matchName.trim().isNotEmpty
          ? chip.matchName
          : ProximityChipKeys.normalizeName(chip.label);
      final key = ProximityChipKeys.build(category, matchName);
      final isHidden = key.isNotEmpty && hidden.contains(key);
      final isPinned = key.isNotEmpty && pinned.contains(key);
      if (isHidden && !input.includeHidden) continue;
      applied.add(
        chip.copyWith(
          chipCategory: category,
          matchName: matchName,
          isHidden: isHidden,
          isPinned: isPinned,
        ),
      );
    }

    applied.sort(_compareSectionChips);
    return ProximityProfileSection(title: title, icon: icon, chips: applied);
  }

  static int _compareSectionChips(ProximityDisplayChip a, ProximityDisplayChip b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    return _compareChips(a, b);
  }

  static List<ProximityDisplayChip> _transportChips(ProximityDisplayInput input) {
    final chips = <ProximityDisplayChip>[];
    final seen = <String>{};

    void addTransit(String? line, int? walkMin) {
      final trimmed = line?.trim() ?? '';
      if (trimmed.isEmpty) return;
      final key = _normalize(trimmed);
      if (!seen.add(key)) return;
      chips.add(_transitChip(trimmed, walkMin));
    }

    addTransit(_nearestTransitLine(input, 'DART')?.line,
        _nearestTransitLine(input, 'DART')?.walkMin);
    addTransit(_nearestTransitLine(input, 'Luas')?.line,
        _nearestTransitLine(input, 'Luas')?.walkMin);
    addTransit(_nearestTransitLine(input, 'Dublin Bus')?.line,
        _nearestTransitLine(input, 'Dublin Bus')?.walkMin);

    for (final transit in _sortedTransitLines(input)) {
      if (transit.line.startsWith('DART') ||
          transit.line.startsWith('Luas') ||
          transit.line.startsWith('Dublin Bus')) {
        continue;
      }
      addTransit(transit.line, transit.walkMin);
    }

    return chips;
  }

  static List<ProximityDisplayChip> _groceryChips(ProximityDisplayInput input) {
    NeighborhoodAmenityTag? asianTag;
    for (final tag in input.lifestyleTags) {
      if (tag.category == NeighborhoodAmenityCategory.asianStores) {
        asianTag = tag;
        break;
      }
    }
    final asianNameKey =
        asianTag == null ? '' : _normalize(asianTag.name);

    final mainstream = <ProximityDisplayChip>[];
    final seen = <String>{};

    void addMainstream(String brand, int? walkMin) {
      final trimmed = brand.trim();
      if (trimmed.isEmpty) return;
      final key = _normalize(trimmed);
      if (asianNameKey.isNotEmpty && key == asianNameKey) return;
      if (!seen.add(key)) return;
      mainstream.add(_groceryChip(trimmed, walkMin));
    }

    for (final grocery in input.groceries) {
      addMainstream(grocery.brand, grocery.walkMin);
    }

    if (mainstream.isEmpty) {
      addMainstream(input.groceryBrand, input.groceryWalkMin);
    }

    mainstream.sort(_compareChips);
    final chips = mainstream.take(3).toList();

    if (asianTag != null) {
      chips.add(
        _groceryChip(
          'Asian Grocery',
          _walkMinFromKm(asianTag.distanceKm),
          matchName: asianTag.name,
        ),
      );
    }

    return chips;
  }

  static List<ProximityDisplayChip> _educationChips(ProximityDisplayInput input) {
    final chips = <ProximityDisplayChip>[];

    final primary = input.primarySchool.trim();
    if (primary.isNotEmpty) {
      chips.add(_schoolChip(primary, prefix: 'Primary'));
    }

    final secondary = input.secondarySchool.trim();
    if (secondary.isNotEmpty) {
      chips.add(_schoolChip(secondary, prefix: 'Secondary'));
    }

    final college = input.collegeSchool.trim();
    if (college.isNotEmpty) {
      chips.add(
        ProximityDisplayChip(
          tier: ProximityDisplayTier.tier1,
          icon: Icons.school_outlined,
          label: _withWalk(college, input.collegeWalkMin),
          walkMin: input.collegeWalkMin,
          sortKey: 10300,
          matchName: college,
        ),
      );
    }

    final creche = input.crecheName.trim();
    if (creche.isNotEmpty) {
      chips.add(
        ProximityDisplayChip(
          tier: ProximityDisplayTier.tier2,
          icon: Icons.child_care_outlined,
          label: _withWalk(creche, input.crecheWalkMin),
          walkMin: input.crecheWalkMin,
          sortKey: 20020,
          matchName: creche,
        ),
      );
    }

    return chips;
  }

  static List<ProximityDisplayChip> _healthcareChips(ProximityDisplayInput input) {
    final chips = <ProximityDisplayChip>[];
    final seen = <String>{};

    void addChip(ProximityDisplayChip chip) {
      final key =
          _normalize(chip.matchName.isNotEmpty ? chip.matchName : chip.label);
      if (!seen.add(key)) return;
      chips.add(chip);
    }

    for (final tag in input.lifestyleTags) {
      if (tag.category != NeighborhoodAmenityCategory.pharmacy) continue;
      final walkMin = _walkMinFromKm(tag.distanceKm);
      addChip(
        ProximityDisplayChip(
          tier: ProximityDisplayTier.tier2,
          icon: Icons.local_pharmacy_outlined,
          label: _withWalk(tag.name, walkMin),
          walkMin: walkMin,
          sortKey: 20022,
          matchName: tag.name,
        ),
      );
    }

    final gp = input.gpClinic.trim();
    if (gp.isNotEmpty) {
      addChip(
        ProximityDisplayChip(
          tier: ProximityDisplayTier.tier2,
          icon: Icons.medical_services_outlined,
          label: _withWalk('GP · $gp', input.gpWalkMin),
          walkMin: input.gpWalkMin,
          sortKey: 20021,
          matchName: 'GP · $gp',
        ),
      );
    }

    for (final extra in input.extraTransit) {
      if (!extra.line.toLowerCase().contains('hospital')) continue;
      addChip(
        ProximityDisplayChip(
          tier: ProximityDisplayTier.tier2,
          icon: Icons.local_hospital_outlined,
          label: _withWalk(extra.line, extra.walkMin),
          walkMin: extra.walkMin,
          sortKey: 20023,
          matchName: extra.line,
        ),
      );
    }

    return chips;
  }

  static List<ProximityDisplayChip> _lifestyleChips(ProximityDisplayInput input) {
    final chips = <ProximityDisplayChip>[];
    final seen = <String>{};

    void addChip(ProximityDisplayChip? chip) {
      if (chip == null) return;
      final key =
          _normalize(chip.matchName.isNotEmpty ? chip.matchName : chip.label);
      if (!seen.add(key)) return;
      chips.add(chip);
    }

    const lifestyleOrder = [
      NeighborhoodAmenityCategory.atms,
      NeighborhoodAmenityCategory.pizzaShops,
      NeighborhoodAmenityCategory.cafe,
      NeighborhoodAmenityCategory.restaurant,
      NeighborhoodAmenityCategory.pubs,
      NeighborhoodAmenityCategory.gym,
      NeighborhoodAmenityCategory.foodJoints,
    ];

    for (final category in lifestyleOrder) {
      for (final tag in input.lifestyleTags) {
        if (tag.category != category) continue;
        addChip(_lifestyleChip(tag));
      }
    }

    return chips;
  }

  static List<ProximityDisplayChip> _outdoorsChips(ProximityDisplayInput input) {
    final chips = <ProximityDisplayChip>[];
    final seen = <String>{};

    for (final tag in input.lifestyleTags) {
      if (tag.category != NeighborhoodAmenityCategory.park &&
          tag.category != NeighborhoodAmenityCategory.businessPark &&
          tag.category != NeighborhoodAmenityCategory.attraction) {
        continue;
      }
      final chip = _lifestyleChip(tag);
      if (chip == null) continue;
      final key =
          _normalize(chip.matchName.isNotEmpty ? chip.matchName : chip.label);
      if (!seen.add(key)) continue;
      chips.add(chip);
    }

    return chips;
  }

  static List<ProximityDisplayChip> _customChips(ProximityDisplayInput input) {
    final chips = <ProximityDisplayChip>[];
    final seen = <String>{};
    for (final point in input.customPoints) {
      final name = point.name.trim();
      if (name.isEmpty) continue;
      final key = _normalize(name);
      if (!seen.add(key)) continue;
      chips.add(_customPointChip(point));
    }
    return chips;
  }

  static ({String line, int? walkMin})? _nearestTransitLine(
    ProximityDisplayInput input,
    String prefix,
  ) {
    ({String line, int? walkMin})? best;
    for (final line in _collectTransitLines(input)) {
      if (!line.line.startsWith(prefix)) continue;
      if (best == null) {
        best = line;
        continue;
      }
      final walkA = line.walkMin ?? 999;
      final walkB = best.walkMin ?? 999;
      if (walkA < walkB) best = line;
    }
    return best;
  }

  static List<({String line, int? walkMin})> _sortedTransitLines(
    ProximityDisplayInput input,
  ) {
    final lines = _collectTransitLines(input);
    lines.sort((a, b) {
      final walkA = a.walkMin ?? 999;
      final walkB = b.walkMin ?? 999;
      return TransitRanking.compare(
        walkMinA: walkA,
        walkMinB: walkB,
        distanceMetersA: walkA * 80.0,
        distanceMetersB: walkB * 80.0,
        lineA: a.line,
        lineB: b.line,
      );
    });
    return lines;
  }

  static List<({String line, int? walkMin})> _collectTransitLines(
    ProximityDisplayInput input,
  ) {
    final lines = <({String line, int? walkMin})>[];
    final transport = input.transportLine.trim();
    if (transport.isNotEmpty) {
      lines.add((line: transport, walkMin: input.transportWalkMin));
    }
    for (final extra in input.extraTransit) {
      final line = extra.line.trim();
      if (line.isEmpty) continue;
      if (line.toLowerCase().contains('hospital')) continue;
      lines.add((line: line, walkMin: extra.walkMin));
    }
    return lines;
  }

  static ProximityDisplayChip _transitChip(String line, int? walkMin) {
    return ProximityDisplayChip(
      tier: ProximityDisplayTier.tier1,
      icon: Icons.train_outlined,
      label: _withWalk(line, walkMin),
      walkMin: walkMin,
      sortKey: _transitSortKey(line, walkMin),
      matchName: line,
    );
  }

  static int _transitSortKey(String line, int? walkMin) =>
      (walkMin ?? 999) * 100 + TransitRanking.typeTieBreakRank(line);

  static ProximityDisplayChip _groceryChip(
    String brand,
    int? walkMin, {
    String? matchName,
  }) {
    final tier = _isTier1Grocery(brand)
        ? ProximityDisplayTier.tier1
        : ProximityDisplayTier.tier2;
    return ProximityDisplayChip(
      tier: tier,
      icon: Icons.shopping_bag_outlined,
      label: _withWalk(brand, walkMin),
      walkMin: walkMin,
      sortKey:
          (walkMin ?? 999) * 10 + (tier == ProximityDisplayTier.tier1 ? 0 : 1),
      matchName: matchName ?? brand,
    );
  }

  static ProximityDisplayChip _schoolChip(String name, {required String prefix}) {
    return ProximityDisplayChip(
      tier: ProximityDisplayTier.tier1,
      icon: Icons.school_outlined,
      label: '$prefix: $name',
      sortKey: prefix == 'Primary' ? 10100 : 10200,
      matchName: '$prefix: $name',
    );
  }

  static ProximityDisplayChip? _lifestyleChip(NeighborhoodAmenityTag tag) {
    final walkMin = _walkMinFromKm(tag.distanceKm);
    final label = _withWalk('${tag.emoji} ${tag.name}', walkMin);

    return switch (tag.category) {
      NeighborhoodAmenityCategory.asianStores => null,
      NeighborhoodAmenityCategory.pharmacy => null,
      NeighborhoodAmenityCategory.park => ProximityDisplayChip(
          tier: ProximityDisplayTier.tier3,
          icon: Icons.park_outlined,
          label: label,
          walkMin: walkMin,
          sortKey: 30030,
          matchName: tag.name,
        ),
      NeighborhoodAmenityCategory.gym => ProximityDisplayChip(
          tier: ProximityDisplayTier.tier3,
          icon: Icons.fitness_center_outlined,
          label: label,
          walkMin: walkMin,
          sortKey: 30031,
          matchName: tag.name,
        ),
      NeighborhoodAmenityCategory.businessPark => ProximityDisplayChip(
          tier: ProximityDisplayTier.tier3,
          icon: Icons.store_mall_directory_outlined,
          label: label,
          walkMin: walkMin,
          sortKey: 30032,
          matchName: tag.name,
        ),
      NeighborhoodAmenityCategory.attraction => ProximityDisplayChip(
          tier: ProximityDisplayTier.tier3,
          icon: Icons.attractions_outlined,
          label: label,
          walkMin: walkMin,
          sortKey: 30033,
          matchName: tag.name,
        ),
      NeighborhoodAmenityCategory.cafe ||
      NeighborhoodAmenityCategory.foodJoints =>
        ProximityDisplayChip(
          tier: ProximityDisplayTier.tier4,
          icon: Icons.local_cafe_outlined,
          label: label,
          walkMin: walkMin,
          sortKey: 40040,
          matchName: tag.name,
        ),
      NeighborhoodAmenityCategory.restaurant ||
      NeighborhoodAmenityCategory.pizzaShops =>
        ProximityDisplayChip(
          tier: ProximityDisplayTier.tier4,
          icon: Icons.restaurant_outlined,
          label: label,
          walkMin: walkMin,
          sortKey: 40041,
          matchName: tag.name,
        ),
      NeighborhoodAmenityCategory.pubs => ProximityDisplayChip(
          tier: ProximityDisplayTier.tier4,
          icon: Icons.sports_bar_outlined,
          label: label,
          walkMin: walkMin,
          sortKey: 40042,
          matchName: tag.name,
        ),
      NeighborhoodAmenityCategory.atms => ProximityDisplayChip(
          tier: ProximityDisplayTier.tier4,
          icon: Icons.atm_outlined,
          label: label,
          walkMin: walkMin,
          sortKey: 40043,
          matchName: tag.name,
        ),
    };
  }

  static ProximityDisplayChip _customPointChip(CustomProximityPoint point) {
    final name = point.name.trim();
    final walk = point.walkMin > 0 ? point.walkMin : null;
    return switch (point.category) {
      ProximityPointCategory.transport => _transitChip(name, walk),
      ProximityPointCategory.grocery => _groceryChip(name, walk),
      ProximityPointCategory.school => _isCollegeName(name)
          ? ProximityDisplayChip(
              tier: ProximityDisplayTier.tier1,
              icon: Icons.school_outlined,
              label: _withWalk(name, walk),
              walkMin: walk,
              sortKey: 10300,
              matchName: name,
            )
          : _schoolChip(name, prefix: 'School'),
      ProximityPointCategory.amenity => _amenityCustomChip(name, walk),
    };
  }

  static ProximityDisplayChip _amenityCustomChip(String name, int? walkMin) {
    final lower = name.toLowerCase();
    final tier = switch (true) {
      _ when lower.contains('pharmacy') ||
            lower.contains('chemist') =>
        ProximityDisplayTier.tier2,
      _ when lower.contains('hospital') ||
            lower.contains('clinic') ||
            lower.contains(' gp') ||
            lower.startsWith('gp ') ||
            lower.contains('doctor') =>
        ProximityDisplayTier.tier2,
      _ when lower.contains('creche') ||
            lower.contains('childcare') ||
            lower.contains('nursery') =>
        ProximityDisplayTier.tier2,
      _ when lower.contains('park') => ProximityDisplayTier.tier3,
      _ when lower.contains('gym') || lower.contains('fitness') =>
        ProximityDisplayTier.tier3,
      _ when lower.contains('pub') ||
            lower.contains('bar') ||
            lower.contains('cafe') ||
            lower.contains('coffee') ||
            lower.contains('restaurant') ||
            lower.contains('atm') =>
        ProximityDisplayTier.tier4,
      _ => ProximityDisplayTier.tier3,
    };
    return ProximityDisplayChip(
      tier: tier,
      icon: Icons.place_outlined,
      label: _withWalk(name, walkMin),
      walkMin: walkMin,
      sortKey: tier == ProximityDisplayTier.tier2
          ? 20024
          : tier == ProximityDisplayTier.tier3
              ? 30034
              : 40044,
      matchName: name,
    );
  }

  static int _compareChips(ProximityDisplayChip a, ProximityDisplayChip b) {
    final aWalk = a.walkMin ?? 999;
    final bWalk = b.walkMin ?? 999;
    final byWalk = aWalk.compareTo(bWalk);
    if (byWalk != 0) return byWalk;
    final bySort = a.sortKey.compareTo(b.sortKey);
    if (bySort != 0) return bySort;
    return a.label.compareTo(b.label);
  }

  static int? _walkMinFromKm(double distanceKm) =>
      distanceKm > 0
          ? (distanceKm * 1000 / 80).ceil().clamp(1, 30)
          : null;

  static bool _isTier1Grocery(String brand) =>
      _tier1GroceryBrands.contains(brand.trim().toLowerCase());

  static bool _isCollegeName(String name) {
    final lower = name.toLowerCase();
    return lower.contains('college') ||
        lower.contains('university') ||
        lower.contains('institute');
  }

  static String _withWalk(String label, int? walkMin) {
    if (walkMin == null || walkMin <= 0) return label;
    if (label.contains('min walk')) return label;
    return '$label • $walkMin min walk';
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
