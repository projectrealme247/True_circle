import 'package:flutter/material.dart';

import '../config/market/market_config.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';

/// Primary tower navigation: Rent, Buy/Sell, Shared Spaces.
class HomeTowerTabs extends StatelessWidget {
  const HomeTowerTabs({
    super.key,
    required this.selectedPropertyType,
    required this.onSelected,
  });

  /// One of [ListingData.propertyTypes]: Rent, Buy, Share.
  final String selectedPropertyType;
  final ValueChanged<String> onSelected;

  static List<({String type, String label})> get tabs {
    return MarketConfig.current.enabledTowers.map((type) {
      final label = switch (type) {
        'Buy' => 'Buy / Sell',
        'Share' => 'Shared Spaces',
        _ => 'Rent',
      };
      return (type: type, label: label);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _TowerPill(
                  label: tabs[i].label,
                  selected: selectedPropertyType == tabs[i].type,
                  onTap: () => onSelected(tabs[i].type),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TowerPill extends StatelessWidget {
  const _TowerPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? HomeMarketplaceTheme.primary : Colors.transparent,
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
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.searchTabLabel(selected: selected),
          ),
        ),
      ),
    );
  }
}
