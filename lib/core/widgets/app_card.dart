import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../widgets/listing_card_overlay_badge.dart';

/// Airbnb-style floating card with optional tap, shadow, and border.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.borderRadius,
    this.showShadow = true,
    this.showBorder = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final bool showShadow;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.lg;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow ? AppShadows.card : null,
        border: showBorder ? Border.all(color: AppColors.divider) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: padding ?? AppSpacing.cardPadding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile or listing card with image header, badge, and match score.
class AppProfileCard extends StatelessWidget {
  const AppProfileCard({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.subtitle,
    this.badge,
    this.matchPercentage,
    this.onTap,
    this.onFavorite,
    this.isFavorited = false,
  });

  final String imageUrl;
  final String name;
  final String subtitle;
  final String? badge;
  final int? matchPercentage;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool isFavorited;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: AppColors.divider,
                    child: Icon(
                      Icons.person_rounded,
                      size: 48,
                      color: AppColors.secondaryText.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              if (onFavorite != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: onFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isFavorited
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: isFavorited
                            ? AppColors.accent
                            : AppColors.primaryText,
                      ),
                    ),
                  ),
                ),
              if (matchPercentage != null)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: ListingCardMatchOverlayBadge(
                    percentage: matchPercentage!.toDouble(),
                    frosted: false,
                  ),
                ),
            ],
          ),
          Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: AppTypography.h3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      ListingCardLabelOverlayBadge(label: badge!),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.bodySecondary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
