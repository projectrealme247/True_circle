import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/onboarding_user_intent.dart';
import 'onboarding_design_tokens.dart';

/// Low-profile horizontal intent track at the top of onboarding profile.
class OnboardingIntentSplitter extends StatelessWidget {
  const OnboardingIntentSplitter({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final OnboardingUserIntent selected;
  final ValueChanged<OnboardingUserIntent> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What brings you to True Circle?',
          style: OnboardingTokens.sectionLabelStyle,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final intent in OnboardingUserIntent.values) ...[
              Expanded(
                child: _IntentSegment(
                  label: intent.segmentLabel,
                  selected: intent == selected,
                  onTap: () => onChanged(intent),
                ),
              ),
              if (intent != OnboardingUserIntent.values.last)
                const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _IntentSegment extends StatelessWidget {
  const _IntentSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _unselectedBorder = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.accent : _unselectedBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: selected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}
