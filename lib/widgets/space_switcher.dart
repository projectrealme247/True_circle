import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart' show AppColors;
import '../models/marketplace_space.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';

/// Segmented control for Independent Places vs Shared Living (Option 2 verbiage).
class SpaceSwitcher extends StatelessWidget {
  const SpaceSwitcher({
    super.key,
    required this.activeSpace,
    required this.onSelected,
    this.enabledSpaces,
  });

  final MarketplaceSpace activeSpace;
  final ValueChanged<MarketplaceSpace> onSelected;
  final List<MarketplaceSpace>? enabledSpaces;

  @override
  Widget build(BuildContext context) {
    final spaces = enabledSpaces ?? MarketplaceSpace.enabledForMarket();
    if (spaces.length <= 1) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.searchSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HomeMarketplaceTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: [
            for (var i = 0; i < spaces.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _SpacePill(
                  title: spaces[i].option2Title,
                  subtitle: spaces[i].option2Subtitle,
                  selected: activeSpace == spaces[i],
                  onTap: () => onSelected(spaces[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpacePill extends StatelessWidget {
  const _SpacePill({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Semantics(
      button: true,
      selected: selected,
      label: '$title — $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.searchTabLabel(selected: selected).copyWith(
                fontSize: AppTypography.textSm,
                fontWeight: FontWeight.w700,
              ),
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
