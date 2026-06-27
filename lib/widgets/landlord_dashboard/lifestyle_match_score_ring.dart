import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' show AppColors;
import '../../utils/transit_duration_formatter.dart';
import 'affordability_multiplier_chip.dart';
import 'landlord_dashboard_theme.dart';

class LifestyleMatchScoreRing extends StatefulWidget {
  const LifestyleMatchScoreRing({
    super.key,
    required this.percent,
    this.size = 64,
  });

  final int percent;
  final double size;

  @override
  State<LifestyleMatchScoreRing> createState() => _LifestyleMatchScoreRingState();
}

class _LifestyleMatchScoreRingState extends State<LifestyleMatchScoreRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.percent > 85) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant LifestyleMatchScoreRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.percent > 85 && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (widget.percent <= 85 && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulse = widget.percent > 85
        ? Tween<double>(begin: 1, end: 1.07).animate(
            CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
          )
        : const AlwaysStoppedAnimation(1.0);

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        return Transform.scale(
          scale: pulse.value,
          child: child,
        );
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _RingPainter(
            percent: widget.percent.clamp(0, 100),
            pulseActive: widget.percent > 85,
          ),
          child: Center(
            child: Text(
              '${widget.percent}%',
              style: TextStyle(
                fontSize: widget.size * 0.22,
                fontWeight: FontWeight.w800,
                color: widget.percent > 85
                    ? AppColors.accent
                    : AppColors.primaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.percent, required this.pulseActive});

  final int percent;
  final bool pulseActive;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - stroke;

    final trackPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: pulseActive
            ? [AppColors.accent, AppColors.accentDark]
            : [const Color(0xFF6B7280), AppColors.primaryText],
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final sweep = 2 * math.pi * (percent / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.percent != percent || oldDelegate.pulseActive != pulseActive;
}

/// Match gauge with affordability multiplier chip (landlord operational view).
class MatchScoreWithAffordabilityChip extends StatelessWidget {
  const MatchScoreWithAffordabilityChip({
    super.key,
    required this.percent,
    required this.affordabilityMultiplier,
    this.ringSize = 48,
    this.stackChip = false,
  });

  final int percent;
  final double affordabilityMultiplier;
  final double ringSize;
  final bool stackChip;

  @override
  Widget build(BuildContext context) {
    final chipWidget = AffordabilityMultiplierChip(
      multiplier: affordabilityMultiplier,
    );

    if (stackChip) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LifestyleMatchScoreRing(percent: percent, size: ringSize),
          const SizedBox(height: 8),
          chipWidget,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LifestyleMatchScoreRing(percent: percent, size: ringSize),
        const SizedBox(width: 10),
        Flexible(child: chipWidget),
      ],
    );
  }
}

/// Match gauge with optional verified-transit commute chip.
class MatchScoreWithCommuteChip extends StatelessWidget {
  const MatchScoreWithCommuteChip({
    super.key,
    required this.percent,
    this.transitDurationSeconds,
    this.commuteChipLabel,
    this.ringSize = 48,
    this.stackChip = false,
  });

  final int percent;
  final int? transitDurationSeconds;
  final String? commuteChipLabel;
  final double ringSize;
  final bool stackChip;

  String? get _chipLabel =>
      commuteChipLabel ??
      TransitDurationFormatter.commuteChipLabel(transitDurationSeconds);

  @override
  Widget build(BuildContext context) {
    final chip = _chipLabel;
    if (chip == null) {
      return LifestyleMatchScoreRing(percent: percent, size: ringSize);
    }

    final chipWidget = _TransitCommuteChip(label: chip);

    if (stackChip) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LifestyleMatchScoreRing(percent: percent, size: ringSize),
          const SizedBox(height: 8),
          chipWidget,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LifestyleMatchScoreRing(percent: percent, size: ringSize),
        const SizedBox(width: 10),
        Flexible(child: chipWidget),
      ],
    );
  }
}

class _TransitCommuteChip extends StatelessWidget {
  const _TransitCommuteChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: LandlordDashboardTheme.commuteTint,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: LandlordDashboardTheme.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: LandlordDashboardTheme.textSecondary,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
