import 'package:flutter/material.dart';

import '../../models/marketplace_space.dart';
import '../../theme/app_typography.dart';
import '../../theme/home_marketplace_theme.dart';
import '../../utils/listing_search_intent.dart';
import '../../widgets/filter_chip_bar.dart';
import '../../widgets/space_switcher.dart';

/// Premium marketplace hero — headline, search card, and filter pills.
class HomeMarketplaceHeroSection extends StatelessWidget {
  const HomeMarketplaceHeroSection({
    super.key,
    required this.activeSpace,
    required this.towerPropertyType,
    required this.activeFilters,
    required this.searchBar,
    required this.onSpaceSelected,
    required this.onFiltersChanged,
    required this.onClearAll,
    this.onMoreFiltersTap,
    this.moreFiltersActiveCount = 0,
  });

  final MarketplaceSpace activeSpace;
  final String towerPropertyType;
  final ListingSearchFilters activeFilters;
  final Widget searchBar;
  final ValueChanged<MarketplaceSpace> onSpaceSelected;
  final ValueChanged<ListingSearchFilters> onFiltersChanged;
  final VoidCallback onClearAll;
  final VoidCallback? onMoreFiltersTap;
  final int moreFiltersActiveCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _HeroCopy(),
        const SizedBox(height: 12),
        _SearchContainer(
          activeSpace: activeSpace,
          towerPropertyType: towerPropertyType,
          activeFilters: activeFilters,
          searchBar: searchBar,
          onSpaceSelected: onSpaceSelected,
          onFiltersChanged: onFiltersChanged,
          onClearAll: onClearAll,
          onMoreFiltersTap: onMoreFiltersTap,
          moreFiltersActiveCount: moreFiltersActiveCount,
        ),
      ],
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          HomeMarketplaceTheme.heroHeadline,
          textAlign: TextAlign.center,
          style: AppTypography.displayTitle(size: 28).copyWith(
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: HomeMarketplaceTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          HomeMarketplaceTheme.heroSubheadline,
          textAlign: TextAlign.center,
          style: AppTypography.heroSubtitle().copyWith(
            fontSize: AppTypography.textBase,
            color: HomeMarketplaceTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SearchContainer extends StatelessWidget {
  const _SearchContainer({
    required this.activeSpace,
    required this.towerPropertyType,
    required this.activeFilters,
    required this.searchBar,
    required this.onSpaceSelected,
    required this.onFiltersChanged,
    required this.onClearAll,
    this.onMoreFiltersTap,
    this.moreFiltersActiveCount = 0,
  });

  final MarketplaceSpace activeSpace;
  final String towerPropertyType;
  final ListingSearchFilters activeFilters;
  final Widget searchBar;
  final ValueChanged<MarketplaceSpace> onSpaceSelected;
  final ValueChanged<ListingSearchFilters> onFiltersChanged;
  final VoidCallback onClearAll;
  final VoidCallback? onMoreFiltersTap;
  final int moreFiltersActiveCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.surface,
        borderRadius: BorderRadius.circular(HomeMarketplaceTheme.searchBlockRadius),
        border: Border.all(color: HomeMarketplaceTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SpaceSwitcher(
              activeSpace: activeSpace,
              onSelected: onSpaceSelected,
            ),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: HomeMarketplaceTheme.canvas,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HomeMarketplaceTheme.border),
              ),
              child: searchBar,
            ),
            const SizedBox(height: 8),
            MarketplaceFilterBar(
              towerPropertyType: towerPropertyType,
              activeFilters: activeFilters,
              onFiltersChanged: onFiltersChanged,
              onClearAll: onClearAll,
              showAdvancedChips: true,
              horizontalChips: true,
              onMoreFiltersTap: onMoreFiltersTap,
              moreFiltersActiveCount: moreFiltersActiveCount,
            ),
          ],
        ),
      ),
    );
  }
}
