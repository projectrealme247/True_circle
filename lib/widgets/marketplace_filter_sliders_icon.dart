import 'package:flutter/material.dart';

/// Low-noise inline filter glyph — three horizontal adjustment lines (no emoji).
class MarketplaceFilterSlidersIcon extends StatelessWidget {
  const MarketplaceFilterSlidersIcon({
    super.key,
    this.size = 18,
    this.color = const Color(0xFF6B7280),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _FilterSlidersPainter(color: color),
    );
  }
}

class _FilterSlidersPainter extends CustomPainter {
  const _FilterSlidersPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final rows = [0.28, 0.5, 0.72];
    final widths = [0.88, 0.62, 0.78];

    for (var i = 0; i < rows.length; i++) {
      final y = h * rows[i];
      final lineW = w * widths[i];
      final x0 = (w - lineW) / 2;
      canvas.drawLine(Offset(x0, y), Offset(x0 + lineW, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FilterSlidersPainter oldDelegate) =>
      oldDelegate.color != color;
}
