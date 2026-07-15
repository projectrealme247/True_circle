import 'package:flutter/material.dart';

import '../../theme/app_typography.dart';
import '../../theme/home_marketplace_theme.dart';
import '../../utils/listing_search_intent.dart';
import '../../utils/target_search_areas.dart';

/// Dublin macro area presets for the home explore chip row.
///
/// Derived from [TargetSearchAreas.primaryFilterOptions] so labels, order, and
/// keys stay aligned with the Area filter sheet / chips:
/// All Dublin → City Centre → North → South → West.
class HomeAreaQuickFilter {
  const HomeAreaQuickFilter({
    required this.id,
    required this.label,
    required this.areaKeys,
  });

  final String id;
  final String label;
  final List<String> areaKeys;

  /// Canonical homepage hierarchy — no local macro label list.
  static List<HomeAreaQuickFilter> get presets => [
        for (final (key, label) in TargetSearchAreas.primaryFilterOptions)
          HomeAreaQuickFilter(
            id: key,
            label: label,
            areaKeys: key == TargetSearchAreas.allDublinToken
                ? TargetSearchAreas.allDublinFilterTokens
                : [key],
          ),
      ];

  static String? activePresetId(ListingSearchFilters filters) {
    final tokens = filters.effectiveAreaTokens;
    if (tokens.isEmpty || TargetSearchAreas.hasAllDublin(tokens)) {
      return TargetSearchAreas.allDublinToken;
    }
    for (final preset in presets) {
      if (preset.id == TargetSearchAreas.allDublinToken) continue;
      if (_sameTokenSet(tokens, preset.areaKeys)) return preset.id;
    }
    return null;
  }

  static bool _sameTokenSet(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final setA = a.toSet();
    return b.every(setA.contains);
  }

  static ListingSearchFilters applyPreset(
    ListingSearchFilters current,
    HomeAreaQuickFilter preset,
  ) {
    if (preset.id == TargetSearchAreas.allDublinToken) {
      return current.copyWith(
        city: null,
        targetSearchAreas: TargetSearchAreas.allDublinFilterTokens,
        targetSearchAreaRefinements: const [],
      );
    }
    return current.copyWith(
      city: null,
      targetSearchAreas: List<String>.from(preset.areaKeys),
      targetSearchAreaRefinements: const [],
    );
  }
}

class HomeAreaQuickFilters extends StatelessWidget {
  const HomeAreaQuickFilters({
    super.key,
    required this.activeFilters,
    required this.onPresetSelected,
  });

  final ListingSearchFilters activeFilters;
  final ValueChanged<HomeAreaQuickFilter> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    final presets = HomeAreaQuickFilter.presets;
    final activeId = HomeAreaQuickFilter.activePresetId(activeFilters);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final preset = presets[index];
          final selected = activeId == preset.id ||
              (activeId == null &&
                  preset.id == TargetSearchAreas.allDublinToken &&
                  activeFilters.effectiveAreaTokens.isEmpty);

          return FilterChip(
            label: Text(
              preset.label,
              style: AppTypography.meta().copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? HomeMarketplaceTheme.textPrimary
                    : HomeMarketplaceTheme.textSecondary,
              ),
            ),
            selected: selected,
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            side: BorderSide(
              color: selected
                  ? HomeMarketplaceTheme.textPrimary
                  : HomeMarketplaceTheme.border,
            ),
            backgroundColor: HomeMarketplaceTheme.canvas,
            selectedColor: HomeMarketplaceTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onSelected: (_) => onPresetSelected(preset),
          );
        },
      ),
    );
  }
}
