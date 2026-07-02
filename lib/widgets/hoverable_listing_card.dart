import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/home_marketplace_theme.dart';
import '../utils/listing_match_engine.dart';
import '../debug/agent_log.dart';

/// Listing card shell with premium 3D hover lift on desktop/web.
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
  bool _isHovered = false;

  static const double _hoverBreakpoint = 768;

  bool _hoverEffectsEnabled(BuildContext context) {
    if (kIsWeb) return true;
    return MediaQuery.sizeOf(context).width >= _hoverBreakpoint;
  }

  double get _opacity {
    final m = widget.match;
    if (m == null) return 1.0;
    if (m.percentage < 25 && m.percentage > 0) return 0.88;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final hoverActive = _isHovered && _hoverEffectsEnabled(context);

    return MouseRegion(
      onEnter: (_) {
        if (_hoverEffectsEnabled(context)) {
          setState(() => _isHovered = true);
        }
      },
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: hoverActive
              ? (Matrix4.identity()..translate(0.0, -6.0, 0.0))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: HomeMarketplaceTheme.surface,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: hoverActive
                ? null
                : Border.all(color: HomeMarketplaceTheme.border),
            boxShadow: hoverActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : HomeMarketplaceTheme.cardShadowRest,
          ),
          clipBehavior: Clip.antiAlias,
          child: Opacity(
            opacity: _opacity,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
