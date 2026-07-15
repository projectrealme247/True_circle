import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart' as core;
import '../models/marketplace_space.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';

enum SpaceSwitcherStyle { standard, segmented }

/// Segmented control for Independent Places vs Shared Living (Option 2 verbiage).
class SpaceSwitcher extends StatelessWidget {
  const SpaceSwitcher({
    super.key,
    required this.activeSpace,
    required this.onSelected,
    this.enabledSpaces,
    this.floating = false,
    this.style = SpaceSwitcherStyle.standard,
  });

  final MarketplaceSpace activeSpace;
  final ValueChanged<MarketplaceSpace> onSelected;
  final List<MarketplaceSpace>? enabledSpaces;

  /// When true, renders with elevated surface styling above the search card.
  final bool floating;

  /// [segmented] matches the home explore pill toggle (text-only, white selection).
  final SpaceSwitcherStyle style;

  static const _radius = 12.0;

  @override
  Widget build(BuildContext context) {
    final spaces = enabledSpaces ?? MarketplaceSpace.enabledForMarket();
    if (spaces.length <= 1) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: floating && style == SpaceSwitcherStyle.standard
              ? HomeMarketplaceTheme.cardShadowRest
              : null,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: style == SpaceSwitcherStyle.segmented
                ? const Color(0xFFF0EBE6)
                : floating
                    ? HomeMarketplaceTheme.surface
                    : HomeMarketplaceTheme.searchSurface,
            borderRadius: BorderRadius.circular(_radius),
            border: style == SpaceSwitcherStyle.segmented
                ? null
                : Border.all(color: HomeMarketplaceTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                for (var i = 0; i < spaces.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: style == SpaceSwitcherStyle.segmented
                        ? _SegmentedPill(
                            label: spaces[i].option2Title,
                            selected: activeSpace == spaces[i],
                            onTap: () => onSelected(spaces[i]),
                          )
                        : _SpacePill(
                            emoji: spaces[i].option2HeroEmoji,
                            label: spaces[i].option2HeroText,
                            subtitle: spaces[i].option2Subtitle,
                            selected: activeSpace == spaces[i],
                            onTap: () => onSelected(spaces[i]),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpacePill extends StatelessWidget {
  const _SpacePill({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  static const _radius = 12.0;

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppTypography.searchTabLabel(selected: selected).copyWith(
      fontSize: AppTypography.textSm,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      color: selected ? core.AppColors.accent : HomeMarketplaceTheme.textSecondary,
      fontFamily: core.AppTypography.fontFamily,
      fontFamilyFallback: core.AppTypography.emojiFontFallback,
    );

    final pill = Semantics(
      button: true,
      selected: selected,
      label: '$emoji $label — $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_radius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: selected
                  ? core.AppColors.accent.withValues(alpha: 0.08)
                  : HomeMarketplaceTheme.canvas,
              borderRadius: BorderRadius.circular(_radius),
              border: selected
                  ? Border.all(
                      color: core.AppColors.accent.withValues(alpha: 0.35),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  emoji,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.1,
                    fontFamily: core.AppTypography.emojiFontFamily,
                    fontFamilyFallback: core.AppTypography.emojiFontFallback,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (kIsWeb || MediaQuery.sizeOf(context).width >= 768) {
      return Tooltip(
        message: subtitle,
        waitDuration: const Duration(milliseconds: 400),
        child: pill,
      );
    }

    return pill;
  }
}

class _SegmentedPill extends StatelessWidget {
  const _SegmentedPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SpaceSwitcher._radius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? core.AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(SpaceSwitcher._radius),
              boxShadow: selected ? HomeMarketplaceTheme.cardShadowRest : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.searchTabLabel(selected: selected).copyWith(
                fontSize: AppTypography.textSm,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? core.AppColors.primaryText
                    : HomeMarketplaceTheme.textSecondary,
                fontFamily: core.AppTypography.fontFamily,
                fontFamilyFallback: core.AppTypography.emojiFontFallback,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
