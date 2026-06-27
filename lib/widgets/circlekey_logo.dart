import 'package:flutter/material.dart';

import '../theme/home_marketplace_theme.dart';

/// The CircleKey brand mark: a sky-blue filled circle with an orange
/// keyhole shape (round top + narrow slot) outlined by a thin white border.
class CircleKeyLogo extends StatelessWidget {
  const CircleKeyLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _KeyholePainter(size: size)),
    );
  }
}

class _KeyholePainter extends CustomPainter {
  _KeyholePainter({required this.size});

  final double size;

  static const _badgeColor = HomeMarketplaceTheme.primary;
  static const _keyholeColor = HomeMarketplaceTheme.accent;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(size / 2, size / 2);
    final radius = size / 2;

    // 1. Blue circle badge
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = _badgeColor,
    );

    // Keyhole proportions relative to badge size
    final holeRadius = size * 0.18;
    final holeCenter = Offset(center.dx, center.dy - size * 0.06);
    final slotWidth = size * 0.14;
    final slotTop = holeCenter.dy + holeRadius * 0.45;
    final slotBottom = center.dy + size * 0.3;
    final borderWidth = size * 0.06;

    // 2. White border around keyhole (drawn slightly larger)
    final borderPath = Path()
      ..addOval(Rect.fromCircle(
        center: holeCenter,
        radius: holeRadius + borderWidth,
      ))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(
          center.dx - slotWidth / 2 - borderWidth,
          slotTop,
          center.dx + slotWidth / 2 + borderWidth,
          slotBottom + borderWidth,
        ),
        Radius.circular(slotWidth * 0.3),
      ));
    canvas.drawPath(borderPath, Paint()..color = Colors.white);

    // 3. Orange keyhole (circle + slot)
    final holePath = Path()
      ..addOval(Rect.fromCircle(center: holeCenter, radius: holeRadius))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(
          center.dx - slotWidth / 2,
          slotTop,
          center.dx + slotWidth / 2,
          slotBottom,
        ),
        Radius.circular(slotWidth * 0.25),
      ));
    canvas.drawPath(holePath, Paint()..color = _keyholeColor);
  }

  @override
  bool shouldRepaint(covariant _KeyholePainter oldDelegate) =>
      oldDelegate.size != size;
}
