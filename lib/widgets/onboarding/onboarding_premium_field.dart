import 'package:flutter/material.dart';

import 'onboarding_design_tokens.dart';

/// Refined onboarding text field — filled 0xFFF8FAFC, border 0xFFE2E8F0.
class OnboardingPremiumField extends StatelessWidget {
  const OnboardingPremiumField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: OnboardingTokens.sectionLabelStyle),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged == null ? null : (_) => onChanged!(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F172A),
          ),
          decoration: OnboardingTokens.inputDecoration(hint: hint),
        ),
      ],
    );
  }
}
