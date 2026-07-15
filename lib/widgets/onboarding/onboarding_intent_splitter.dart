import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/onboarding_user_intent.dart';
import 'onboarding_design_tokens.dart';

/// Interactive role fork at the top of the master onboarding gateway.
class OnboardingIntentSplitter extends StatelessWidget {
  const OnboardingIntentSplitter({
    super.key,
    required this.selected,
    required this.onChanged,
    this.allowUnselected = false,
  });

  final OnboardingUserIntent selected;
  final ValueChanged<OnboardingUserIntent> onChanged;

  /// When true, neither segment shows a selected border until the user taps.
  final bool allowUnselected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What brings you to True Circle?',
          style: OnboardingTokens.sectionLabelStyle.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final intent in OnboardingUserIntent.values) ...[
              Expanded(
                child: _IntentSegment(
                  label: intent.segmentLabel,
                  icon: intent.segmentIcon,
                  selected: !allowUnselected && intent == selected,
                  onTap: () => onChanged(intent),
                ),
              ),
              if (intent != OnboardingUserIntent.values.last)
                const SizedBox(width: 10),
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
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  static const _labelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Color(0xFF111827),
    height: 1.35,
    fontFamily: AppTypography.fontFamily,
  );

  static const _iconColor = Color(0xFF6B7280);
  static const _restFill = Color(0xFFF3F4F6);
  static const _selectedBorder = Color(0xFF374151);

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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: _restFill,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: _selectedBorder, width: 1)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: _iconColor),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _labelStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
