import 'package:flutter/material.dart';

/// Polished circular prev/next control for listing photo carousels.
class ListingGalleryNavButton extends StatelessWidget {
  const ListingGalleryNavButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 40.0;
    final iconSize = compact ? 18.0 : 20.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: enabled
            ? const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.white.withValues(alpha: enabled ? 0.96 : 0.72),
        shape: const CircleBorder(
          side: BorderSide(color: Color(0x14000000)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: iconSize,
              color: enabled
                  ? const Color(0xFF111827)
                  : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      ),
    );
  }
}
