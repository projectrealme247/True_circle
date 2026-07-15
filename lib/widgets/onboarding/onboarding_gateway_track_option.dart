import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Border-only selection track row — optional emoji prefix and premium card styling.
class OnboardingGatewayTrackOption extends StatelessWidget {
  const OnboardingGatewayTrackOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.prefixEmoji,
    this.premium = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? prefixEmoji;

  /// White card, 12px radius, soft shadow — welcome gate and landlord parity.
  final bool premium;

  static const _labelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Color(0xFF111827),
    height: 1.4,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  static const _premiumLabelStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: Color(0xFF111827),
    height: 1.35,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  static const _selectedBorder = Color(0xFF374151);
  static const _restFill = Color(0xFFF3F4F6);

  static const _premiumShadow = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final radius = premium ? 12.0 : 10.0;
    final padding = premium
        ? const EdgeInsets.symmetric(horizontal: 20, vertical: 18)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    final emojiSize = premium ? 22.0 : 18.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: premium ? Colors.white : _restFill,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: premium ? _premiumShadow : null,
            border: selected
                ? Border.all(color: _selectedBorder, width: 1)
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (prefixEmoji != null) ...[
                Text(
                  prefixEmoji!,
                  style: TextStyle(
                    fontSize: emojiSize,
                    height: 1.1,
                    fontFamily: AppTypography.fontFamily,
                    fontFamilyFallback: AppTypography.emojiFontFallback,
                  ),
                ),
                SizedBox(width: premium ? 14 : 10),
              ],
              Expanded(
                child: Text(
                  label,
                  style: premium ? _premiumLabelStyle : _labelStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
