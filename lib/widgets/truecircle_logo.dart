import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../router/app_routes.dart';

enum _TrueCircleLogoLayout { vertical, appBar, appBarMark }

/// TrueCircle brand lockup — vertical for auth/marketing, compact for app bars.
class TrueCircleLogo extends StatelessWidget {
  const TrueCircleLogo({
    super.key,
    this.height = 80,
    this.width,
  })  : markSize = 32,
        _layout = _TrueCircleLogoLayout.vertical;

  const TrueCircleLogo.appBar({
    super.key,
    this.height = 56,
  })  : width = null,
        markSize = 32,
        _layout = _TrueCircleLogoLayout.appBar;

  /// Icon-only swirl mark clipped from [assetPath] (no baked-in PNG wordmark).
  const TrueCircleLogo.appBarMark({
    super.key,
    double size = 24,
  })  : markSize = size,
        height = size,
        width = null,
        _layout = _TrueCircleLogoLayout.appBarMark;

  /// Render height in logical pixels.
  final double height;

  /// Render width; defaults to proportional width for the trimmed vertical asset.
  final double? width;

  /// Swirl mark height for [TrueCircleLogo.appBarMark].
  final double markSize;

  final _TrueCircleLogoLayout _layout;

  static const assetPath = 'assets/images/logo.png';

  /// Trimmed PNG aspect ratio (288×271).
  static const _aspectRatio = 288 / 271;

  /// Fraction of the vertical PNG height that contains only the red swirl (excludes wordmark).
  static const _swirlBandFraction = 0.68;

  /// Dedicated mark sizing for app bars (square viewport).
  static const appBarMarkAssetPath = assetPath;

  @override
  Widget build(BuildContext context) {
    if (_layout == _TrueCircleLogoLayout.appBarMark) {
      return _buildSwirlMark(markSize);
    }

    if (_layout == _TrueCircleLogoLayout.appBar) {
      return _buildAppBarLockup();
    }

    final renderWidth = width ?? height * _aspectRatio;

    return SizedBox(
      height: height,
      width: renderWidth,
      child: Image.asset(
        assetPath,
        height: height,
        width: renderWidth,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        semanticLabel: 'TrueCircle',
        errorBuilder: (context, error, stackTrace) {
          debugPrint('TrueCircleLogo failed to load $assetPath: $error');
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'TrueCircle',
              style: AppTypography.h3.copyWith(
                fontSize: height * 0.28,
                color: AppColors.primaryText,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBarLockup() {
    final markSize = height * 0.64;
    final wordmarkSize = height * 0.26;

    return SizedBox(
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildSwirlMark(markSize),
          SizedBox(height: height * 0.04),
          Text(
            'TrueCircle',
            style: AppTypography.h3.copyWith(
              fontSize: wordmarkSize,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
              height: 1,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Square viewport showing the red swirl at native aspect — bottom wordmark clipped off.
  Widget _buildSwirlMark(double size) {
    // Scale so the swirl band (top [_swirlBandFraction] of the PNG) fills [size] px tall.
    final imageHeight = size / _swirlBandFraction;

    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: size,
          maxWidth: size,
          minHeight: imageHeight,
          maxHeight: imageHeight,
          child: Image.asset(
            appBarMarkAssetPath,
            width: size,
            height: imageHeight,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            semanticLabel: 'TrueCircle mark',
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: AppColors.accentLight,
              child: Icon(
                Icons.home_work_outlined,
                size: size * 0.55,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Interactive app-bar logo — routes to the primary home dashboard.
class TrueCircleHomeLogoButton extends StatefulWidget {
  const TrueCircleHomeLogoButton({
    super.key,
    this.markSize = 24,
    this.showWordmark = true,
  });

  final double markSize;
  final bool showWordmark;

  @override
  State<TrueCircleHomeLogoButton> createState() =>
      _TrueCircleHomeLogoButtonState();
}

class _TrueCircleHomeLogoButtonState extends State<TrueCircleHomeLogoButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => AppRoutes.navigateHome(context),
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.accent.withValues(alpha: 0.06),
          splashColor: AppColors.accent.withValues(alpha: 0.12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.accent.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TrueCircleLogo.appBarMark(size: widget.markSize),
                if (widget.showWordmark) ...[
                  const SizedBox(width: 10),
                  Text(
                    'TrueCircle',
                    style: TextStyle(
                      fontSize: widget.markSize * 0.92,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF222222),
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
