import 'package:flutter/material.dart';

/// Placeholder when a listing has no photo uploaded.
class ListingImagePlaceholder extends StatelessWidget {
  const ListingImagePlaceholder({
    super.key,
    this.height = 88,
    this.borderRadius,
    this.label = 'No image available',
    this.fill = false,
    this.compact = false,
  });

  final double? height;
  final BorderRadius? borderRadius;
  final String label;
  final bool fill;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    final resolvedHeight = height ?? 88;

    final content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F0FE),
              Color(0xFFF0F2F5),
              Color(0xFFEEF2FF),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: -12,
              bottom: -16,
              child: Icon(
                Icons.home_work_outlined,
                size: resolvedHeight * 0.55,
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.06),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(compact || resolvedHeight < 120 ? 8 : 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Icon(
                      Icons.photo_outlined,
                      size: compact ? 20 : (resolvedHeight < 120 ? 26 : 36),
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.75),
                    ),
                  ),
                  if (!compact) ...[
                    SizedBox(height: resolvedHeight < 120 ? 6 : 10),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: resolvedHeight < 120 ? 11 : 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
    );

    if (fill) {
      return SizedBox(width: double.infinity, height: double.infinity, child: content);
    }
    return SizedBox(
      height: resolvedHeight,
      width: double.infinity,
      child: content,
    );
  }
}
