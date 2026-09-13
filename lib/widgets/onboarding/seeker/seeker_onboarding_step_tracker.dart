import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Interactive seeker wizard step indicator — width follows the shell content band.
class SeekerOnboardingStepTracker extends StatelessWidget {
  const SeekerOnboardingStepTracker({
    super.key,
    required this.current,
    this.onStepTap,
    this.isSharedTrack = false,
  });

  final int current;
  final ValueChanged<int>? onStepTap;
  final bool isSharedTrack;

  static const _ipSteps = ['Basics', 'Rental Plan', 'Destination'];
  static const _sharedSteps = [
    'Basics',
    'Profile',
    'Search',
    'Location',
  ];

  @override
  Widget build(BuildContext context) {
    final steps = isSharedTrack ? _sharedSteps : _ipSteps;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const Expanded(child: _SeekerStepConnector()),
          _SeekerStepLabel(
            index: i,
            label: steps[i],
            state: _stepState(i),
            onTap: _tapFor(i),
          ),
        ],
      ],
    );
  }

  _SeekerStepVisual _stepState(int index) {
    if (index == current) return _SeekerStepVisual.active;
    if (index < current) return _SeekerStepVisual.complete;
    return _SeekerStepVisual.upcoming;
  }

  VoidCallback? _tapFor(int index) {
    if (index >= current || onStepTap == null) return null;
    return () => onStepTap!(index);
  }
}

enum _SeekerStepVisual { upcoming, active, complete }

class _SeekerStepLabel extends StatelessWidget {
  const _SeekerStepLabel({
    required this.index,
    required this.label,
    required this.state,
    this.onTap,
  });

  final int index;
  final String label;
  final _SeekerStepVisual state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = state == _SeekerStepVisual.active;
    final complete = state == _SeekerStepVisual.complete;
    final tappable = onTap != null;

    final textColor = active
        ? const Color(0xFF111827)
        : complete
            ? const Color(0xFF4B5563)
            : const Color(0xFF9CA3AF);
    final opacity = active ? 1.0 : 0.5;

    final content = Opacity(
      opacity: opacity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            '${index + 1} $label',
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
              height: 1.4,
              letterSpacing: -0.1,
              decoration:
                  tappable ? TextDecoration.underline : TextDecoration.none,
              decorationColor: const Color(0xFF9CA3AF),
              fontFamily: AppTypography.fontFamily,
              fontFamilyFallback: AppTypography.emojiFontFallback,
            ),
          ),
        ],
      ),
    );

    if (!tappable) return content;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: content,
        ),
      ),
    );
  }
}

/// Razor-thin geometric accent between step labels.
class _SeekerStepConnector extends StatelessWidget {
  const _SeekerStepConnector();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFFD1D5DB),
      ),
    );
  }
}
