import 'package:flutter/material.dart';

import '../config/market/market_config.dart';
import '../models/applicant_trust_tier.dart';
import '../models/marketplace_space.dart';
import '../theme/trust_tier_design.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/dublin_transit_proximity_tier.dart';
import '../utils/listing_data.dart';
import '../utils/listing_match_engine.dart';
import '../utils/listing_media.dart';
import '../utils/numeric_bounds.dart';
import '../utils/polymorphic_identity.dart';
import '../utils/viewer_profile.dart';
import '../widgets/hoverable_listing_card.dart';
import '../widgets/listing_card_overlay_badge.dart';
import '../widgets/listing_gallery_nav_button.dart';
import '../debug/agent_log.dart';

class PropertyCard extends StatelessWidget {
  const PropertyCard({
    super.key,
    required this.listing,
    required this.match,
    required this.activeSpace,
    this.viewerProfile,
    required this.onTap,
  });

  static const double cardImageHeight = 152;
  static const double _bodyPaddingH = 12;
  static const double _bodyPaddingV = 14;

  static const double _priceLineHeight = 20;
  static const double _configLineHeight = 36;
  static const double _subtitleLineHeight = 18;
  static const double _lineGapAfterPrice = 6;
  static const double _lineGapBeforeSubtitle = 4;
  static const double _metadataBlockHeight =
      _priceLineHeight +
      _lineGapAfterPrice +
      _configLineHeight +
      _lineGapBeforeSubtitle +
      _subtitleLineHeight;
  static const double _transitSlotHeight = 30;

  /// Image + padded metadata block (price, config, subtitle, transit slot).
  static const double gridMainAxisExtent = 304;

  static const double _cardRadius = HomeMarketplaceTheme.cardRadius;

  final Map<String, dynamic> listing;
  final ListingMatchResult match;
  final MarketplaceSpace activeSpace;
  final Map<String, dynamic>? viewerProfile;
  final VoidCallback onTap;

  static int _propertyCardLogCount = 0;

  @override
  Widget build(BuildContext context) {
    // #region agent log
    if (_propertyCardLogCount < 2) {
      _propertyCardLogCount++;
      agentLog(
        location: 'property_card.dart:build',
        message: 'Property card rendering',
        hypothesisId: 'A',
        data: {
          'index': _propertyCardLogCount,
          'reasonCount': match.reasons.length,
          'firstReason': match.reasons.isEmpty ? '' : match.reasons.first,
          'inCircle': match.inCircle,
          'trustStage': match.trustStage.name,
        },
      );
    }
    // #endregion
    final displayPct = NumericBounds.clampPercent(match.percentage);
    final clampedMatch = ListingMatchResult(
      score: match.score,
      maxScore: match.maxScore,
      percentage: displayPct,
      label: match.label,
      reasons: match.reasons,
      excluded: match.excluded,
      tower: match.tower,
      trustStage: match.trustStage,
      inCircle: match.inCircle,
      preArrivalBadge: match.preArrivalBadge,
    );

    return SizedBox(
      height: gridMainAxisExtent,
      child: HoverableListingCard(
        onTap: onTap,
        match: clampedMatch,
        borderRadius: _cardRadius,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_cardRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                SizedBox(
                  height: cardImageHeight,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _PropertyCardCoverCarousel(listing: listing),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _FrostedTrustBadge(
                          match: clampedMatch,
                          listing: listing,
                        ),
                      ),
                      if (clampedMatch.percentage > 0)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: ListingCardMatchOverlayBadge(
                            percentage: clampedMatch.percentage,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _bodyPaddingH,
                      vertical: _bodyPaddingV,
                    ),
                    child: _CardDetails(listing: listing),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardDetails extends StatelessWidget {
  const _CardDetails({required this.listing});

  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) {
    final configurationLine = _CardCopy.configurationLine(listing);
    final locationSubtitle = _CardCopy.locationSubtitle(listing);
    final tier = DublinTransitProximityTier.fromListing(listing);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: PropertyCard._metadataBlockHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: PropertyCard._priceLineHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _CardCopy.displayPrice(listing),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cardPrice().copyWith(
                      fontWeight: FontWeight.w700,
                      color: HomeMarketplaceTheme.textPrimary,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: PropertyCard._lineGapAfterPrice),
              SizedBox(
                height: PropertyCard._configLineHeight,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    configurationLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.detail().copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      height: 1.35,
                      color: HomeMarketplaceTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: PropertyCard._lineGapBeforeSubtitle),
              SizedBox(
                height: PropertyCard._subtitleLineHeight,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    locationSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.detail().copyWith(
                      fontSize: 13,
                      height: 1.35,
                      color: HomeMarketplaceTheme.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          height: PropertyCard._transitSlotHeight,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: tier != null
                ? _InlineTransitChip(tier: tier)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

abstract final class _CardCopy {
  static String displayPrice(Map<String, dynamic> listing) {
    final label = ListingData.priceDisplayLabel(listing);
    if (label == 'Rent not set') return label;

    final raw = ListingData.price(listing);
    final amount = ListingData.listingPriceAmount(listing);
    final symbol = MarketConfig.current.currencySymbol;
    final periodMatch = RegExp(r'/(\w+)$').firstMatch(raw);
    final period = periodMatch != null ? '/${periodMatch.group(1)!}' : '';

    if (amount != null) {
      return '$symbol${_formatAmount(amount)}$period';
    }

    final trimmed = raw.trim();
    if (trimmed.startsWith(symbol) || trimmed.startsWith('₹')) return trimmed;
    return '$symbol$trimmed';
  }

  static String configurationLine(Map<String, dynamic> listing) {
    final parts = <String>[];

    if (ListingData.isRoomShare(listing)) {
      parts.add(ListingData.cardRoomTypeLabel(listing));
    }

    final kind = ListingData.cardPropertyKind(listing).toLowerCase();
    final bedLabel = ListingData.bedrooms(listing).trim();
    final bedCount = ListingData.bedCount(listing);

    if (bedLabel.isNotEmpty) {
      final normalized = bedLabel.toLowerCase().contains('bed')
          ? bedLabel.toLowerCase()
          : '${bedLabel.toLowerCase()} bed';
      parts.add('$normalized $kind');
    } else if (bedCount != null) {
      parts.add('$bedCount bed $kind');
    } else if (!ListingData.isRoomShare(listing)) {
      parts.add(kind);
    }

    final area = ListingData.cardAreaName(listing);
    if (area.isNotEmpty) parts.add(area);

    final transit = _transitToken(listing);
    if (transit.isNotEmpty) parts.add(transit);

    return parts.where((part) => part.trim().isNotEmpty).join(' · ');
  }

  static String locationSubtitle(Map<String, dynamic> listing) {
    final raw = ListingData.location(listing);
    if (raw.isEmpty) {
      final area = ListingData.cardAreaName(listing);
      return area.isEmpty ? '' : area;
    }

    final segments = raw
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);

    final formatted = <String>[];
    for (final segment in segments) {
      if (RegExp(r'^dublin\s+\d', caseSensitive: false).hasMatch(segment)) {
        if (!formatted.any((value) => value.toLowerCase() == 'dublin')) {
          formatted.add('Dublin');
        }
        continue;
      }
      if (segment.toLowerCase() == 'dublin' &&
          formatted.any((value) => value.toLowerCase() == 'dublin')) {
        continue;
      }
      formatted.add(_titleCase(segment));
    }

    return formatted.join(', ');
  }

  static String _transitToken(Map<String, dynamic> listing) {
    final transitType = ListingData.transitTypeLabel(listing).toLowerCase();
    if (transitType.contains('luas')) return 'Luas';
    if (transitType.contains('dart')) return 'DART';
    if (transitType.contains('dublin bus')) return 'Dublin Bus';
    if (ListingData.transitTypeLabel(listing).isNotEmpty) {
      return ListingData.transitTypeLabel(listing);
    }

    final hint = ListingData.cardTransitHint(listing).toLowerCase();
    if (hint.contains('luas')) return 'Luas';
    if (hint.contains('dart')) return 'DART';

    final blob =
        '${ListingData.title(listing)} ${ListingData.description(listing)}'
            .toLowerCase();
    if (blob.contains('luas') || blob.contains('green line')) return 'Luas';
    if (blob.contains('dart')) return 'DART';
    return '';
  }

  static String _formatAmount(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      if (i > 0 && fromEnd % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String _titleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map(
          (word) => word.length == 1
              ? word.toUpperCase()
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

class _FrostedTrustBadge extends StatelessWidget {
  const _FrostedTrustBadge({
    required this.match,
    required this.listing,
  });

  final ListingMatchResult match;
  final Map<String, dynamic> listing;

  bool get _showInCircleBadge {
    final matchScore = match.percentage / 100.0;
    return match.inCircle &&
        matchScore >= ListingMatchEngine.inCircleMinMatchFraction;
  }

  @override
  Widget build(BuildContext context) {
    if (_showInCircleBadge) {
      return const ListingCardInCircleOverlayBadge();
    }

    final tier = _resolveTrustTier();
    if (tier != null) {
      return ListingCardTrustTierOverlayBadge(tier: tier);
    }

    final label = _resolveSpecialLabel();
    if (label == null) return const SizedBox.shrink();

    return ListingCardLabelOverlayBadge(label: label);
  }

  ApplicantTrustTier? _resolveTrustTier() {
    final lightTrust =
        MarketConfig.current.trustVerificationKind == TrustVerificationKind.lightTrust;
    if (!lightTrust) return null;
    if (_showInCircleBadge) return null;
    if (match.preArrivalBadge) return null;
    if (PolymorphicIdentity.showVerifiedProfessionalHostBadge(listing)) {
      return null;
    }
    if (match.trustStage == TrustStage.anonymous) return null;

    return TrustTierDesign.fromTrustStage(match.trustStage);
  }

  String? _resolveSpecialLabel() {
    if (PolymorphicIdentity.showVerifiedProfessionalHostBadge(listing)) {
      return PolymorphicIdentity.verifiedProfessionalHostLabel;
    }
    if (_showInCircleBadge) return null;
    if (match.preArrivalBadge) return 'Pre-Arrival';

    final lightTrust =
        MarketConfig.current.trustVerificationKind == TrustVerificationKind.lightTrust;
    if (lightTrust) return null;

    return switch (match.trustStage) {
      TrustStage.idVerified => 'ID Verified',
      TrustStage.socialVerified => 'Verified Pro',
      TrustStage.casual => 'Casual',
      TrustStage.anonymous => null,
    };
  }
}

String? _resolveListingCoverUrl(Map<String, dynamic> listing) {
  final imageUrl = ListingData.text(
    listing['imageUrl'] ?? listing['image_url'],
  );
  if (imageUrl.isNotEmpty) return imageUrl;

  final coverUrl = ListingData.coverImageUrl(listing);
  if (coverUrl.isNotEmpty) return coverUrl;

  return ListingData.networkCoverUrl(listing);
}

class _PropertyCardCoverCarousel extends StatefulWidget {
  const _PropertyCardCoverCarousel({required this.listing});

  final Map<String, dynamic> listing;

  @override
  State<_PropertyCardCoverCarousel> createState() =>
      _PropertyCardCoverCarouselState();
}

class _PropertyCardCoverCarouselState extends State<_PropertyCardCoverCarousel> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_PropertyCardCoverCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (ListingData.id(oldWidget.listing) != ListingData.id(widget.listing)) {
      _index = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  List<String> _imageSources() {
    final uris = ListingData.imageDataUris(widget.listing);
    if (uris.isNotEmpty) return uris;
    final url = _resolveListingCoverUrl(widget.listing);
    if (url != null && url.trim().isNotEmpty) return [url];
    return const [];
  }

  bool _isNetworkUrl(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final images = _imageSources();
    if (images.isEmpty) {
      return const _ImageAccentPlaceholder();
    }

    final hasMultiple = images.length > 1;

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: images.length,
          onPageChanged: (next) => setState(() => _index = next),
          itemBuilder: (context, index) => _buildImage(images[index]),
        ),
        if (hasMultiple) ...[
          Positioned(
            left: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: ListingGalleryNavButton(
                icon: Icons.chevron_left_rounded,
                enabled: _index > 0,
                onTap: () => _goTo(_index - 1),
                compact: true,
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: ListingGalleryNavButton(
                icon: Icons.chevron_right_rounded,
                enabled: _index < images.length - 1,
                onTap: () => _goTo(_index + 1),
                compact: true,
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(
                  '${_index + 1}/${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImage(String source) {
    if (_isNetworkUrl(source)) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const _ImageAccentPlaceholder(),
      );
    }

    final bytes = ListingMedia.decodeDataUri(source);
    if (bytes == null) return const _ImageAccentPlaceholder();
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const _ImageAccentPlaceholder(),
    );
  }

  void _goTo(int index) {
    if (index < 0 || index >= _imageSources().length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    setState(() => _index = index);
  }
}

class _ImageAccentPlaceholder extends StatelessWidget {
  const _ImageAccentPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEDEDED),
      child: Center(
        child: Icon(
          Icons.home_work_outlined,
          size: 40,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}

class _InlineTransitChip extends StatelessWidget {
  const _InlineTransitChip({required this.tier});

  final DublinTransitProximityTier tier;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tier.tooltip,
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: HomeMarketplaceTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_transit_outlined,
              size: 14,
              color: HomeMarketplaceTheme.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              tier.shortLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.detail().copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: HomeMarketplaceTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
