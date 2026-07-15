import 'package:flutter/material.dart';

import '../config/market/market_config.dart';
import '../core/theme/app_theme.dart' show AppColors;
import '../models/marketplace_space.dart';
import '../theme/app_typography.dart';
import '../utils/listing_data.dart';
import '../utils/listing_match_engine.dart';
import '../utils/listing_media.dart';
import '../utils/numeric_bounds.dart';
import '../widgets/hoverable_listing_card.dart';
import '../widgets/listing_gallery_nav_button.dart';
import 'trust_badge.dart';

/// Discovery listing card — hero image, match band, price/location, and match chips.
class PropertyCard extends StatelessWidget {
  const PropertyCard({
    super.key,
    required this.listing,
    required this.match,
    required this.activeSpace,
    this.viewerProfile,
    required this.onTap,
  });

  /// Includes 2px for the rest-state card border so inner content fits exactly.
  static const double gridMainAxisExtent = 220;
  static const double heroHeight = 110;
  static const double bodyHeight = 110;
  static const double contentPaddingH = 12;
  static const double bodyPaddingTop = 4;
  static const double metadataMidGap = 2;
  static const double sectionGap = 4;
  static const double bodyPaddingBottom = 5;
  static const double priceLineHeight = 19;
  static const double locationLineHeight = 14;
  static const double chipsHeight = 26;
  static const double trustPaddingTop = 8;
  static const double trustLineHeight = 26;
  static const double _cardRadius = 12;

  final Map<String, dynamic> listing;
  final ListingMatchResult match;
  final MarketplaceSpace activeSpace;
  final Map<String, dynamic>? viewerProfile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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

    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(height: gridMainAxisExtent),
      child: SizedBox(
        height: gridMainAxisExtent,
        width: double.infinity,
        child: HoverableListingCard(
          onTap: onTap,
          match: clampedMatch,
          borderRadius: _cardRadius,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_cardRadius),
            clipBehavior: Clip.hardEdge,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bodySlotHeight =
                    (constraints.maxHeight - heroHeight).clamp(0.0, bodyHeight);
                return Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: heroHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _PropertyCardCoverCarousel(
                            listing: listing,
                            onOpenGallery: (index) =>
                                _ListingCardGalleryPreview.show(
                              context,
                              listing: listing,
                              initialIndex: index,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            left: 6,
                            child: _MatchQualityBand(match: clampedMatch),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: bodySlotHeight,
                      child: _CardBody(
                        listing: listing,
                        match: clampedMatch,
                        activeSpace: activeSpace,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.listing,
    required this.match,
    required this.activeSpace,
  });

  final Map<String, dynamic> listing;
  final ListingMatchResult match;
  final MarketplaceSpace activeSpace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PropertyCard.contentPaddingH,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: PropertyCard.bodyPaddingTop),
          SizedBox(
            height: PropertyCard.priceLineHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _CardPriceLine(listing: listing),
            ),
          ),
          const SizedBox(height: PropertyCard.metadataMidGap),
          SizedBox(
            height: PropertyCard.locationLineHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 11,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      _CardCopy.locationLine(listing),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: AppTypography.detail().copyWith(
                        fontWeight: FontWeight.w400,
                        fontSize: 11,
                        height: 1.0,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: PropertyCard.sectionGap),
          SizedBox(
            height: PropertyCard.chipsHeight,
            child: ClipRect(
              child: _CardMatchChips(
                listing: listing,
                activeSpace: activeSpace,
                matchPercentage: match.percentage,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: PropertyCard.trustPaddingTop),
          Align(
            alignment: Alignment.centerLeft,
            child: _HostTrustLine(listing: listing),
          ),
          const SizedBox(height: PropertyCard.bodyPaddingBottom),
        ],
      ),
    );
  }
}

enum _MatchQualityBandKind {
  topPick(
    'Top Pick',
    Color(0xFF3D2C00),
    Color(0xFFF5CC6E),
    Icons.emoji_events_outlined,
  ),
  strongMatch(
    'Strong Match',
    Color(0xFF1A2E1A),
    Color(0xFF90C98A),
    Icons.star_outline,
  ),
  goodFit(
    'Good Fit',
    Color(0xFF1A2233),
    Color(0xFF8AB0D4),
    Icons.check_circle_outline,
  ),
  worthALook(
    'Worth a Look',
    Color(0xFF1E1E1E),
    Color(0xFF9A9A92),
    Icons.visibility_outlined,
  );

  const _MatchQualityBandKind(
    this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
  );

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;

  static _MatchQualityBandKind? fromMatch(ListingMatchResult match) {
    final pct = match.percentage;
    if (pct <= 0) return null;
    if (pct >= 65) return _MatchQualityBandKind.topPick;
    if (pct >= 50) return _MatchQualityBandKind.strongMatch;
    if (pct >= 30) return _MatchQualityBandKind.goodFit;
    return _MatchQualityBandKind.worthALook;
  }
}

class _MatchQualityBand extends StatelessWidget {
  const _MatchQualityBand({required this.match});

  final ListingMatchResult match;

  @override
  Widget build(BuildContext context) {
    final band = _MatchQualityBandKind.fromMatch(match);
    if (band == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: band.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(band.icon, size: 12, color: band.foregroundColor),
          const SizedBox(width: 4),
          Text(
            band.label,
            style: AppTypography.detail().copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 11,
              height: 1.0,
              color: band.foregroundColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CardMatchChips extends StatelessWidget {
  const _CardMatchChips({
    required this.listing,
    required this.activeSpace,
    required this.matchPercentage,
  });

  final Map<String, dynamic> listing;
  final MarketplaceSpace activeSpace;
  final double matchPercentage;

  @override
  Widget build(BuildContext context) => _buildMatchChips();

  Widget _buildMatchChips() {
    final chips = <Widget>[];

    if (activeSpace == MarketplaceSpace.fullRental) {
      final beds = listing['bhk'] ?? listing['bedrooms'];
      final bedsLabel = beds?.toString().trim() ?? '';
      if (bedsLabel.isNotEmpty) {
        final normalizedBeds = bedsLabel.toLowerCase().contains('bed')
            ? bedsLabel
            : '$bedsLabel Bed';
        chips.add(_buildChip(Icons.bed_outlined, normalizedBeds));
      }

      final monthLabel = ListingData.availableFromDisplayLabel(listing);
      if (monthLabel.isNotEmpty) {
        chips.add(_buildChip(Icons.calendar_today_outlined, monthLabel));
      }

      final commute = _resolveCommuteLabel();
      if (commute != null) {
        chips.add(_buildChip(_commuteIcon(commute), commute));
      }

      if (matchPercentage >= 60) {
        chips.add(_buildChip(Icons.savings_outlined, 'Budget'));
      }
    } else {
      final occ = listing['occupantType'] ?? listing['preferredTenantType'];
      final occLabel = occ?.toString().trim() ?? '';
      if (occLabel.isNotEmpty) {
        final isStudent = occLabel.toLowerCase().contains('student');
        chips.add(_buildChip(
          isStudent ? Icons.school_outlined : Icons.work_outline,
          occLabel,
        ));
      }

      final langs = listing['spoken_languages'];
      if (langs is List && langs.isNotEmpty) {
        final langLabel = langs.first?.toString().trim() ?? '';
        if (langLabel.isNotEmpty) {
          chips.add(_buildChip(Icons.language_outlined, langLabel));
        }
      }

      final diet = listing['foodPreference'] ?? listing['food_preference'];
      final dietLabel = diet?.toString().trim() ?? '';
      if (dietLabel.isNotEmpty) {
        chips.add(_buildChip(Icons.restaurant_outlined, dietLabel));
      }

      final commute = _resolveCommuteLabel();
      if (commute != null) {
        chips.add(_buildChip(_commuteIcon(commute), commute));
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: chips.take(4).toList(),
    );
  }

  String? _resolveCommuteLabel() {
    final modes = <String>{};

    void scanText(String raw) {
      final mode = _transitModeFromText(raw);
      if (mode != null) modes.add(mode);
    }

    final proxMap =
        listing['proximity_data'] ?? listing['neighborhood_proximity'];
    if (proxMap is Map) {
      for (final entry in proxMap.entries) {
        scanText('${entry.key} ${entry.value}');
      }
    } else {
      scanText(proxMap?.toString() ?? '');
    }

    scanText(ListingData.transitTypeLabel(listing));
    scanText(ListingData.cardTransitHint(listing));

    if (modes.contains('Luas')) return 'Luas';
    if (modes.contains('DART')) return 'DART';
    if (modes.contains('Bus')) return 'Bus';
    return null;
  }

  static String? _transitModeFromText(String raw) {
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower.contains('luas')) return 'Luas';
    if (lower.contains('dart')) return 'DART';
    if (lower.contains('bus')) return 'Bus';
    return null;
  }

  static IconData _commuteIcon(String mode) => switch (mode) {
        'Luas' => Icons.tram_outlined,
        'DART' => Icons.train_outlined,
        'Bus' => Icons.directions_bus_outlined,
        _ => Icons.train_outlined,
      };

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.divider, width: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.secondaryText),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.secondaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _HostTrustLine extends StatelessWidget {
  const _HostTrustLine({required this.listing});

  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TrustBadge.fromHostTrustStage(
        ListingData.hostTrustStage(listing),
      ),
    );
  }
}

class _CardPriceLine extends StatelessWidget {
  const _CardPriceLine({required this.listing});

  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) {
    final price = Text(
      _CardCopy.displayPrice(listing),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: AppTypography.cardPrice().copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: AppColors.primaryText,
        letterSpacing: -0.2,
        height: 1.0,
      ),
    );

    if (!ListingData.isRoomShare(listing)) return price;

    return Tooltip(
      message: '+ Utilities',
      waitDuration: const Duration(milliseconds: 200),
      showDuration: const Duration(seconds: 3),
      child: price,
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

  static String locationLine(Map<String, dynamic> listing) {
    final raw = ListingData.location(listing);
    if (raw.isEmpty) {
      final area = ListingData.cardAreaName(listing);
      return area.isEmpty ? 'Dublin' : '$area, Dublin';
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

    if (formatted.isEmpty) return 'Dublin';
    if (!formatted.any((value) => value.toLowerCase() == 'dublin')) {
      formatted.add('Dublin');
    }
    return formatted.join(', ');
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
  const _PropertyCardCoverCarousel({
    required this.listing,
    required this.onOpenGallery,
  });

  final Map<String, dynamic> listing;
  final ValueChanged<int> onOpenGallery;

  @override
  State<_PropertyCardCoverCarousel> createState() =>
      _PropertyCardCoverCarouselState();
}

class _PropertyCardCoverCarouselState
    extends State<_PropertyCardCoverCarousel> {
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
      return GestureDetector(
        onTap: () {},
        child: const _ImageAccentPlaceholder(),
      );
    }

    final hasMultiple = images.length > 1;

    return GestureDetector(
      onTap: () => widget.onOpenGallery(_index),
      child: Stack(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
      ),
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

class _ListingCardGalleryPreview extends StatefulWidget {
  const _ListingCardGalleryPreview({
    required this.listing,
    required this.initialIndex,
  });

  final Map<String, dynamic> listing;
  final int initialIndex;

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> listing,
    int initialIndex = 0,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (_) => _ListingCardGalleryPreview(
        listing: listing,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  State<_ListingCardGalleryPreview> createState() =>
      _ListingCardGalleryPreviewState();
}

class _ListingCardGalleryPreviewState extends State<_ListingCardGalleryPreview> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
    final hasMultiple = images.length > 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: images.isEmpty
                  ? const _ImageAccentPlaceholder()
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: images.length,
                      onPageChanged: (next) => setState(() => _index = next),
                      itemBuilder: (context, index) {
                        final source = images[index];
                        if (_isNetworkUrl(source)) {
                          return Image.network(
                            source,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _ImageAccentPlaceholder(),
                          );
                        }
                        final bytes = ListingMedia.decodeDataUri(source);
                        if (bytes == null) {
                          return const _ImageAccentPlaceholder();
                        }
                        return Image.memory(bytes, fit: BoxFit.cover);
                      },
                    ),
            ),
          ),
          if (hasMultiple) ...[
            Positioned(
              left: 0,
              child: ListingGalleryNavButton(
                icon: Icons.chevron_left_rounded,
                enabled: _index > 0,
                onTap: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: ListingGalleryNavButton(
                icon: Icons.chevron_right_rounded,
                enabled: _index < images.length - 1,
                onTap: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    '${_index + 1} / ${images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
