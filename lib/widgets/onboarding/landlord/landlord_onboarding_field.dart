import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Borderless onboarding text field — white fill, subtle shadow, muted label.
class LandlordOnboardingField extends StatelessWidget {
  const LandlordOnboardingField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback? onChanged;

  static const _labelColor = Color(0xFF757575);
  static const _valueColor = Color(0xFF111827);

  static const _fieldShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '👤 $label',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _labelColor,
            height: 1.35,
            fontFamily: AppTypography.fontFamily,
            fontFamilyFallback: AppTypography.emojiFontFallback,
          ),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _fieldShadow,
          ),
          child: TextFormField(
            controller: controller,
            onChanged: onChanged == null ? null : (_) => onChanged!(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _valueColor,
              fontFamily: AppTypography.fontFamily,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Color(0xFF94A3B8),
                fontFamily: AppTypography.fontFamily,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
