import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Airbnb-grade onboarding grid tokens — do not alter without design review.
abstract final class OnboardingTokens {
  static const canvasBg = Color(0xFFF7F7F7);
  /// Centered profile onboarding column (seeker + landlord).
  static const contentMaxWidth = 600.0;
  static const contentPaddingH = 28.0;
  static const gridMaxWidth = 1280.0;
  static const gridPadding = 48.0;
  static const leftFlex = 7;
  static const rightFlex = 5;
  static const leftPaneMaxWidth = 620.0;

  static const panelTint = Color(0xFFF8FAFC);
  static const progressCoral = Color(0xFFFFF1F2);
  static const inputFill = Color(0xFFF8FAFC);
  static const inputBorder = Color(0xFFE2E8F0);
  static const chipUnselected = Color(0xFFF1F5F9);
  static const subtitleColor = Color(0xFF64748B);

  static const passportWidth = 440.0;
  static const passportHeight = 280.0;

  /// Shared outer frame for seeker onboarding form + passport preview panels.
  static const panelRadius = 16.0;
  /// Identical outer padding for left form + right passport panels.
  static const panelCardPadding = EdgeInsets.fromLTRB(20, 18, 20, 18);

  static BoxDecoration panelCardDecoration({Color color = Colors.white}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(panelRadius),
        border: Border.all(color: inputBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      );

  static const terminalBg = Color(0xFF0F172A);
  static const terminalBorder = Color(0xFF1E293B);
  static const terminalText = Color(0xFFF8FAFC);
  static const terminalMuted = Color(0xFF94A3B8);
  static const simulatorWidth = 440.0;
  static const simulatorHeight = 380.0;

  /// Approximate offset so simulator top aligns with Primary Route header.
  static const page2SimulatorTopOffset = 200.0;

  static const fieldSpacing = 24.0;
  static const chipSpacing = 8.0;

  /// Grouped seeker onboarding sections (Steps 1–2).
  static const stepCardGap = 14.0;
  static const stepCardRadius = 12.0;
  static const stepCardPaddingH = 20.0;
  static const stepCardPaddingV = 16.0;

  static const pageTitleStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: Color(0xFF0F172A),
    letterSpacing: -0.8,
    height: 1.15,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  static const pageSubtitleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: subtitleColor,
    height: 1.45,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  static const sectionLabelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Color(0xFF334155),
    letterSpacing: -0.1,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  /// Bundled font + emoji fallbacks so chip labels paint on first frame (web).
  static const emojiFontFallback = AppTypography.emojiFontFallback;

  static TextStyle chipLabelStyle({required bool selected}) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: const Color(0xFF0F172A),
        fontFamily: AppTypography.fontFamily,
        fontFamilyFallback: emojiFontFallback,
      ).copyWith(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
      );

  static InputDecoration inputDecoration({required String hint}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Color(0xFF94A3B8),
          fontFamily: AppTypography.fontFamily,
          fontFamilyFallback: AppTypography.emojiFontFallback,
        ),
        filled: true,
        fillColor: inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
        ),
      );

  static Color transitAccentForMethod(String method) {
    final lower = method.toLowerCase();
    if (lower.contains('driving')) return const Color(0xFF38BDF8);
    return const Color(0xFF34D399);
  }
}
