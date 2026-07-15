import 'package:flutter/material.dart';

/// Distributes [sections] evenly when [minViewportHeight] is set (page 2–3 rhythm).
class OnboardingSpreadPage extends StatelessWidget {
  const OnboardingSpreadPage({
    super.key,
    required this.sections,
    this.minViewportHeight,
  });

  final List<Widget> sections;
  final double? minViewportHeight;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();
    if (sections.length == 1) return sections.first;

    final spread = minViewportHeight != null && minViewportHeight! > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment:
          spread ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
      children: spread
          ? sections
          : [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) const SizedBox(height: 28),
                sections[i],
              ],
            ],
    );
  }
}
