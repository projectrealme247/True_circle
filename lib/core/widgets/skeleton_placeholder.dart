import 'package:flutter/material.dart';

/// Soft shimmering block used for loading placeholders.
class SkeletonPlaceholder extends StatefulWidget {
  const SkeletonPlaceholder({
    super.key,
    required this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonPlaceholder> createState() => _SkeletonPlaceholderState();
}

class _SkeletonPlaceholderState extends State<SkeletonPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _controller.value, 0),
              end: Alignment(1 + 2 * _controller.value, 0),
              colors: const [
                Color(0xFFE5E7EB),
                Color(0xFFF3F4F6),
                Color(0xFFE5E7EB),
              ],
            ),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
        );
      },
    );
  }
}

/// Capsule chips mimicking variable-length amenity tags.
class SkeletonAmenityChipWrap extends StatelessWidget {
  const SkeletonAmenityChipWrap({super.key});

  static const _widths = <double>[72, 88, 64, 96, 80, 70];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final width in _widths)
          SkeletonPlaceholder(
            width: width,
            height: 32,
            borderRadius: 999,
          ),
      ],
    );
  }
}

/// Subtle pulse shown while Phase 2 (live Overpass) enrichment runs.
class Phase2EnrichmentHint extends StatefulWidget {
  const Phase2EnrichmentHint({
    super.key,
    this.message = 'Checking for more nearby places...',
  });

  final String message;

  @override
  State<Phase2EnrichmentHint> createState() => _Phase2EnrichmentHintState();
}

class _Phase2EnrichmentHintState extends State<Phase2EnrichmentHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.42, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.message,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon + text row mimicking neighborhood proximity readout lines.
class SkeletonProximityRows extends StatelessWidget {
  const SkeletonProximityRows({super.key, this.rowCount = 4});

  final int rowCount;

  static const _lineWidths = <double>[0.92, 0.78, 0.85, 0.7];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rowCount; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final lineWidth =
                  constraints.maxWidth * _lineWidths[i % _lineWidths.length];
              return Row(
                children: [
                  const SkeletonPlaceholder(
                    width: 20,
                    height: 20,
                    borderRadius: 6,
                  ),
                  const SizedBox(width: 10),
                  SkeletonPlaceholder(
                    width: lineWidth,
                    height: 14,
                    borderRadius: 6,
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
