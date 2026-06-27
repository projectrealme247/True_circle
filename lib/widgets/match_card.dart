import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../widgets/listing_card_overlay_badge.dart';

/// Sample flatmate / listing profile card styled with [AppTheme].
class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.title,
    required this.lifestyleTags,
    this.subtitle,
    this.imageUrl,
    this.matchPercent,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final List<String> lifestyleTags;
  final int? matchPercent;
  final VoidCallback? onTap;

  static const _horizontalPadding = 16.0;
  static const _verticalPadding = 16.0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: AppTheme.cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProfilePhoto(imageUrl: imageUrl, matchPercent: matchPercent),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _horizontalPadding,
                  _verticalPadding,
                  _horizontalPadding,
                  _verticalPadding + 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h3,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySecondary.copyWith(fontSize: 14),
                      ),
                    ],
                    if (lifestyleTags.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in lifestyleTags) _LifestyleTag(label: tag),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({
    required this.imageUrl,
    required this.matchPercent,
  });

  final String? imageUrl;
  final int? matchPercent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _PhotoPlaceholder(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const _PhotoPlaceholder(showLoader: true);
                  },
                )
              : const _PhotoPlaceholder(),
        ),
        if (matchPercent != null)
          Positioned(
            top: 12,
            right: 12,
            child: ListingCardMatchOverlayBadge(
              percentage: matchPercent!.toDouble(),
            ),
          ),
      ],
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.showLoader = false});

  final bool showLoader;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: showLoader
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            : Icon(
                Icons.person_outline_rounded,
                size: 48,
                color: AppColors.secondaryText.withValues(alpha: 0.45),
              ),
      ),
    );
  }
}

class _LifestyleTag extends StatelessWidget {
  const _LifestyleTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(label, style: AppTypography.caption),
    );
  }
}

/// Gallery of sample [MatchCard] widgets for design review.
class MatchCardShowcase extends StatelessWidget {
  const MatchCardShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Match cards', style: AppTypography.h2)),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: const [
          MatchCard(
            title: 'Ananya — Software engineer, Dublin 8',
            subtitle: 'Looking for a quiet flatshare near Trinity',
            imageUrl:
                'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=800&q=80',
            lifestyleTags: ['Veg', 'Non-Smoking', 'Early Riser', 'Telugu'],
            matchPercent: 92,
          ),
          SizedBox(height: AppSpacing.lg),
          MatchCard(
            title: 'Rahul — Masters student, UCD',
            subtitle: 'Prefers working professionals or students',
            lifestyleTags: ['Non-Veg', 'Pet friendly', 'Hindi'],
            matchPercent: 78,
          ),
        ],
      ),
    );
  }
}
