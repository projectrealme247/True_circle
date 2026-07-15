import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' show AppColors, AppButtonStyles;
import '../../models/marketplace_space.dart';
import '../../theme/app_typography.dart';
import '../../theme/home_marketplace_theme.dart';
import '../../utils/listing_search_intent.dart';
import '../../widgets/truecircle_logo.dart';
import 'home_explore_header.dart';
import 'home_marketplace_hero.dart';

/// Breakpoint matching the Figma mobile / desktop blueprints.
const double kHomeExploreMobileBreakpoint = 600;

/// Responsive explore header — unified hero; desktop adds top navigation.
class HomeExploreResponsiveShell extends StatelessWidget {
  const HomeExploreResponsiveShell({
    super.key,
    required this.maxWidth,
    required this.activeSpace,
    required this.towerPropertyType,
    required this.activeFilters,
    required this.searchBar,
    required this.signedIn,
    required this.onLogoTap,
    required this.onSpaceSelected,
    required this.onFiltersChanged,
    required this.onClearAll,
    required this.onSignIn,
    required this.onListSpace,
    required this.profileTrailing,
    this.modeSwitch,
    this.onMoreFiltersTap,
    this.moreFiltersActiveCount = 0,
  });

  final double maxWidth;
  final MarketplaceSpace activeSpace;
  final String towerPropertyType;
  final ListingSearchFilters activeFilters;
  final Widget searchBar;
  final bool signedIn;
  final VoidCallback onLogoTap;
  final ValueChanged<MarketplaceSpace> onSpaceSelected;
  final ValueChanged<ListingSearchFilters> onFiltersChanged;
  final VoidCallback onClearAll;
  final VoidCallback onSignIn;
  final VoidCallback onListSpace;
  final Widget profileTrailing;
  final Widget? modeSwitch;
  final VoidCallback? onMoreFiltersTap;
  final int moreFiltersActiveCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, maxWidth);
        final isMobile = width < kHomeExploreMobileBreakpoint;

        final hero = HomeMarketplaceHeroSection(
          activeSpace: activeSpace,
          towerPropertyType: towerPropertyType,
          activeFilters: activeFilters,
          searchBar: searchBar,
          onSpaceSelected: onSpaceSelected,
          onFiltersChanged: onFiltersChanged,
          onClearAll: onClearAll,
          onMoreFiltersTap: onMoreFiltersTap,
          moreFiltersActiveCount: moreFiltersActiveCount,
        );

        final headerTrailing = _HeaderTrailing(
          signedIn: signedIn,
          onSignIn: onSignIn,
          onListSpace: onListSpace,
          modeSwitch: modeSwitch,
          profileTrailing: profileTrailing,
          compact: isMobile,
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HomeExploreHeader(
                onLogoTap: onLogoTap,
                trailing: headerTrailing,
              ),
              const SizedBox(height: 8),
              hero,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DesktopTopNav(
              onLogoTap: onLogoTap,
              trailing: headerTrailing,
            ),
            const SizedBox(height: 12),
            hero,
          ],
        );
      },
    );
  }
}

class _HeaderTrailing extends StatelessWidget {
  const _HeaderTrailing({
    required this.signedIn,
    required this.onSignIn,
    required this.onListSpace,
    required this.profileTrailing,
    this.modeSwitch,
    required this.compact,
  });

  final bool signedIn;
  final VoidCallback onSignIn;
  final VoidCallback onListSpace;
  final Widget profileTrailing;
  final Widget? modeSwitch;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!signedIn)
          TextButton(
            onPressed: onSignIn,
            child: Text(
              'Sign in',
              style: AppTypography.detail().copyWith(
                fontWeight: FontWeight.w600,
                color: HomeMarketplaceTheme.textPrimary,
              ),
            ),
          )
        else ...[
          if (modeSwitch != null) ...[
            modeSwitch!,
            SizedBox(width: compact ? 6 : 10),
          ],
          profileTrailing,
        ],
        SizedBox(width: compact ? 4 : 12),
        FilledButton(
          onPressed: onListSpace,
          style: AppButtonStyles.primaryFilled.copyWith(
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(
                horizontal: compact ? 12 : 18,
                vertical: compact ? 8 : 12,
              ),
            ),
            minimumSize: WidgetStatePropertyAll(
              Size(0, compact ? 36 : 40),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            compact ? 'List' : 'List a space',
            style: AppTypography.button().copyWith(
              fontSize: compact ? AppTypography.textSm : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopTopNav extends StatelessWidget {
  const _DesktopTopNav({
    required this.onLogoTap,
    required this.trailing,
  });

  final VoidCallback onLogoTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onLogoTap,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TrueCircleLogo.appBarMark(size: 28),
              const SizedBox(width: 10),
              Text(
                'TrueCircle',
                style: AppTypography.appBarBrand().copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: HomeMarketplaceTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        trailing,
      ],
    );
  }
}

/// Results metadata row — shared across breakpoints.
class HomeExploreResultsHeader extends StatelessWidget {
  const HomeExploreResultsHeader({
    super.key,
    required this.isMobile,
    required this.activeSpace,
    required this.resultCount,
    this.onMapView,
  });

  final bool isMobile;
  final MarketplaceSpace activeSpace;
  final int resultCount;
  final VoidCallback? onMapView;

  @override
  Widget build(BuildContext context) {
    final countLabel =
        '$resultCount ${resultCount == 1 ? 'match' : 'matches'} found';

    if (!isMobile) {
      return Text(
        countLabel,
        style: AppTypography.sectionTitle().copyWith(
          fontSize: AppTypography.textMd,
          fontWeight: FontWeight.w600,
          color: HomeMarketplaceTheme.textPrimary,
        ),
      );
    }

    final towerLabel = activeSpace == MarketplaceSpace.sharedSpace
        ? 'SHARED LIVING'
        : 'INDEPENDENT SPACES';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                towerLabel,
                style: AppTypography.meta().copyWith(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                  color: HomeMarketplaceTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                countLabel,
                style: AppTypography.sectionTitle().copyWith(
                  fontWeight: FontWeight.w700,
                  color: HomeMarketplaceTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (onMapView != null)
          TextButton(
            onPressed: onMapView,
            child: Text(
              'Map view >',
              style: AppTypography.detail().copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
      ],
    );
  }
}
