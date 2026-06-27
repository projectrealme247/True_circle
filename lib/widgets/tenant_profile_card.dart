import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart' show AppColors;
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/numeric_bounds.dart';

class TenantProfileCard extends StatelessWidget {
  const TenantProfileCard({
    super.key,
    required this.name,
    this.subtitle,
    this.checklistScore,
    this.scoreLabel,
    this.petPolicyConflict = false,
  });

  final String name;
  final String? subtitle;
  final int? checklistScore;
  final String? scoreLabel;
  final bool petPolicyConflict;

  @override
  Widget build(BuildContext context) {
    final score = checklistScore == null
        ? null
        : NumericBounds.clampPercentInt(checklistScore!);
    final badgeLabel = scoreLabel ?? (score == null ? null : '$score/100');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeMarketplaceTheme.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: HomeMarketplaceTheme.primary,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.cardTitle()),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: AppTypography.detail()),
                if (petPolicyConflict)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Pet policy conflict',
                      style: AppTypography.detail().copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (badgeLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: HomeMarketplaceTheme.searchSurface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: HomeMarketplaceTheme.border),
              ),
              child: Text(badgeLabel, style: AppTypography.detail()),
            ),
        ],
      ),
    );
  }
}
