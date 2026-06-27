import 'package:flutter/material.dart';

import '../../services/commute_scoring_service.dart';
import 'onboarding_design_tokens.dart';

/// Bounded 440×380 tactical sidebar — C1 → Transit → C2 + match logic matrix.
class LiveTransitSimulatorPanel extends StatelessWidget {
  const LiveTransitSimulatorPanel({
    super.key,
    required this.headline,
    required this.summary,
    required this.priority,
    required this.primaryMethod,
    this.secondaryMethod,
    required this.primaryHub,
    this.secondaryHub,
    required this.dualCommuter,
  });

  final String headline;
  final String summary;
  final DualCommutePriority priority;
  final String primaryMethod;
  final String? secondaryMethod;
  final String primaryHub;
  final String? secondaryHub;
  final bool dualCommuter;

  bool _primaryEmphasis() =>
      priority == DualCommutePriority.personA ||
      (dualCommuter && priority == DualCommutePriority.balanced) ||
      !dualCommuter;

  bool _secondaryEmphasis() =>
      dualCommuter &&
      (priority == DualCommutePriority.personB ||
          priority == DualCommutePriority.balanced);

  @override
  Widget build(BuildContext context) {
    final linkColor = OnboardingTokens.transitAccentForMethod(primaryMethod);
    final secondaryLinkColor = OnboardingTokens.transitAccentForMethod(
      secondaryMethod ?? primaryMethod,
    );
    final balanced = dualCommuter && priority == DualCommutePriority.balanced;
    final primaryRing =
        priority == DualCommutePriority.personA || balanced || !dualCommuter;
    final secondaryRing =
        priority == DualCommutePriority.personB || balanced;

    return SizedBox(
      width: OnboardingTokens.simulatorWidth,
      height: OnboardingTokens.simulatorHeight,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: OnboardingTokens.terminalBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OnboardingTokens.terminalBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Live Search Strategy',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: OnboardingTokens.terminalMuted,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 20),
            if (dualCommuter)
              Row(
                children: [
                  _Node(
                    label: 'C1',
                    accent: linkColor,
                    ring: primaryRing,
                    scale: priority == DualCommutePriority.personA ? 1.1 : 1.0,
                  ),
                  Expanded(
                    child: _Link(
                      color: Color.lerp(linkColor, secondaryLinkColor, 0.5)!,
                      balanced: balanced,
                    ),
                  ),
                  _Node(
                    label: 'C2',
                    accent: secondaryLinkColor,
                    ring: secondaryRing,
                    scale: priority == DualCommutePriority.personB ? 1.1 : 1.0,
                  ),
                ],
              )
            else
              Row(
                children: [
                  _Node(
                    label: 'C1',
                    accent: linkColor,
                    ring: true,
                    scale: 1.0,
                  ),
                  Expanded(child: _Link(color: linkColor, balanced: false)),
                  const _Node(
                    label: 'Feed',
                    accent: Color(0xFF64748B),
                    ring: false,
                    scale: 1.0,
                  ),
                ],
              ),
            const SizedBox(height: 20),
            Text(
              headline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OnboardingTokens.terminalText,
                letterSpacing: -0.3,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                summary,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFCBD5E1),
                  height: 1.5,
                ),
              ),
            ),
            if (dualCommuter) ...[
              const Divider(color: Color(0xFF334155), height: 1),
              const SizedBox(height: 12),
              _LogicRow(
                label: 'C1 anchor',
                active: _primaryEmphasis(),
                detail: primaryHub,
              ),
              const SizedBox(height: 6),
              _LogicRow(
                label: 'C2 anchor',
                active: _secondaryEmphasis(),
                detail: secondaryHub ?? '—',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({
    required this.label,
    required this.accent,
    required this.ring,
    required this.scale,
  });

  final String label;
  final Color accent;
  final bool ring;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 240),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent.withValues(alpha: 0.15),
          border: Border.all(
            color: ring ? accent : accent.withValues(alpha: 0.4),
            width: ring ? 2.5 : 1,
          ),
          boxShadow: ring
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.color, required this.balanced});

  final Color color;
  final bool balanced;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.3),
                  color,
                  color.withValues(alpha: balanced ? 1.0 : 0.3),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            balanced ? 'Balanced transit link' : 'Dublin transit',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogicRow extends StatelessWidget {
  const _LogicRow({
    required this.label,
    required this.active,
    required this.detail,
  });

  final String label;
  final bool active;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? const Color(0xFF34D399) : const Color(0xFF475569),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active
                ? OnboardingTokens.terminalText
                : OnboardingTokens.terminalMuted,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11,
              color: OnboardingTokens.terminalMuted,
            ),
          ),
        ),
      ],
    );
  }
}
