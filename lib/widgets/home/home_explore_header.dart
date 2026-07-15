import 'package:flutter/material.dart';

import '../../config/market/market_config.dart';
import '../../core/theme/app_theme.dart' show AppColors;
import '../../theme/app_typography.dart';
import '../../theme/home_marketplace_theme.dart';
import '../../widgets/truecircle_logo.dart';

/// Location label + brand row for the Dwello-style home explore header.
class HomeExploreHeader extends StatelessWidget {
  const HomeExploreHeader({
    super.key,
    required this.onLogoTap,
    this.trailing,
  });

  final VoidCallback onLogoTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final marketLabel = switch (MarketConfig.current.id.name) {
      'dublin' => 'DUBLIN',
      _ => MarketConfig.current.appTitle.toUpperCase(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          marketLabel,
          style: AppTypography.meta().copyWith(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
            color: HomeMarketplaceTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            InkWell(
              onTap: onLogoTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TrueCircleLogo.appBarMark(size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'TrueCircle',
                      style: AppTypography.appBarBrand().copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (trailing != null)
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: trailing!,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
