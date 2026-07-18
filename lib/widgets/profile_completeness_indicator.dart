import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'onboarding/onboarding_design_tokens.dart';

/// Profile completeness indicator (presentation only).
///
/// Scoring / percent must be supplied by the caller — this widget does not
/// compute completion.
class ProfileCompletenessIndicator extends StatelessWidget {
  const ProfileCompletenessIndicator({
    super.key,
    required this.percent,
    required this.levelLabel,
  });

  final int percent;
  final String levelLabel;

  static String bandCaptionFor(int percent) {
    final p = percent.clamp(0, 100);
    if (p >= 100) return 'Profile Complete';
    if (p >= 80) return 'Almost Complete';
    if (p >= 60) return 'Profile In Progress';
    return 'Just started';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _progressColor(percent);
    final progress = (percent.clamp(0, 100)) / 100.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OnboardingTokens.space12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'PROFILE COMPLETENESS',
            style: SeekerOnboardingLayout.passportSectionHeader,
          ),
          const SizedBox(height: OnboardingTokens.space8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: const Color(0xFFF0F0F0),
              color: accent,
            ),
          ),
          const SizedBox(height: OnboardingTokens.space8),
          Row(
            children: [
              Expanded(
                child: Text(
                  levelLabel,
                  style: SeekerOnboardingLayout.passportValueProminent.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: SeekerOnboardingLayout.passportValueProminent.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// LinkedIn-style strength tones — accent only on bar + labels, not the card.
  static Color _progressColor(int percent) {
    final p = percent.clamp(0, 100);
    if (p >= 90) return const Color(0xFF057642);
    if (p >= 70) return const Color(0xFF0A66C2);
    if (p >= 40) return const Color(0xFF915907);
    return AppColors.secondaryText;
  }
}
