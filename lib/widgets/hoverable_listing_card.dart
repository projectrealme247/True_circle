import 'package:flutter/material.dart';

import '../theme/home_marketplace_theme.dart';
import '../utils/listing_match_engine.dart';

/// Premium listing card shell with hover lift and soft shadow.
/// Clean Airbnb-style — no side stripes, just rounded corners and shadow.
class HoverableListingCard extends StatefulWidget {
  const HoverableListingCard({
    super.key,
    required this.onTap,
    required this.child,
    this.match,
    this.borderRadius = HomeMarketplaceTheme.cardRadius,
  });

  final VoidCallback onTap;
  final Widget child;
  final ListingMatchResult? match;
  final double borderRadius;

  @override
  State<HoverableListingCard> createState() => _HoverableListingCardState();
}

class _HoverableListingCardState extends State<HoverableListingCard> {
  bool _hovering = false;

  double get _opacity {
    final m = widget.match;
    if (m == null) return 1.0;
    if (m.percentage < 25 && m.percentage > 0) return 0.88;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Transform.scale(
          scale: _hovering ? 1.015 : 1,
          alignment: Alignment.center,
          transformHitTests: true,
          child: Opacity(
            opacity: _opacity,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: HomeMarketplaceTheme.surface,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: _hovering
                    ? HomeMarketplaceTheme.cardShadowHover
                    : HomeMarketplaceTheme.cardShadowRest,
              ),
              clipBehavior: Clip.antiAlias,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
