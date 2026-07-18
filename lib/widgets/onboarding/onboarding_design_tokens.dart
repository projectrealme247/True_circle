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

  /// Spacing scale (use only these values in seeker onboarding UI).
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space24 = 24.0;

  /// Field groups / related controls.
  static const fieldSpacing = space12;
  static const chipSpacing = space8;

  /// Grouped seeker onboarding sections (Steps 1–2).
  static const stepCardGap = space24;
  static const stepCardRadius = 12.0;
  static const stepCardPaddingH = space16;
  static const stepCardPaddingV = space12;

  /// Canonical onboarding type scale (Plus Jakarta / AppTypography).
  static const pageTitleStyle = TextStyle(
    fontSize: 40,
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
    height: 1.35,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  static const sectionLabelStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Color(0xFF1A1A1A),
    letterSpacing: -0.1,
    height: 1.25,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  static const fieldLabelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Color(0xFF64748B),
    height: 1.3,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  static const optionCardTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Color(0xFF1A1A1A),
    height: 1.25,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  static const inputTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Color(0xFF1A1A1A),
    height: 1.3,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  static const helperTextStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: subtitleColor,
    height: 1.35,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  /// Bundled font + emoji fallbacks so chip labels paint on first frame (web).
  static const emojiFontFallback = AppTypography.emojiFontFallback;

  static TextStyle chipLabelStyle({required bool selected}) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.25,
        color: selected ? const Color(0xFF1A1A1A) : const Color(0xFF64748B),
        fontFamily: AppTypography.fontFamily,
        fontFamilyFallback: emojiFontFallback,
      );

  static InputDecoration inputDecoration({required String hint}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: helperTextStyle.copyWith(color: const Color(0xFF94A3B8)),
        filled: true,
        fillColor: inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
        ),
      );

  static Color transitAccentForMethod(String method) {
    final lower = method.toLowerCase();
    if (lower.contains('driving')) return const Color(0xFF38BDF8);
    return const Color(0xFF34D399);
  }
}

/// Seeker onboarding Pass-1 layout + typography system.
abstract final class SeekerOnboardingLayout {
  static const leftFlex = 52;
  static const rightFlex = 48;
  /// Centered content band as a fraction of the scaffold body width.
  static const contentBandWidthFactor = 0.70;
  static const columnPadding = OnboardingTokens.space16;
  /// Left form column: top + horizontal inset; bottom flush so Continue
  /// shares the column bottom edge with the passport card border.
  static const leftColumnInsets = EdgeInsets.fromLTRB(
    OnboardingTokens.space16,
    OnboardingTokens.space16,
    OnboardingTokens.space16,
    0,
  );
  /// @Deprecated — prefer [leftColumnInsets]; kept for call sites.
  static const columnInsets = leftColumnInsets;
  static const bottomBarHeight = 56.0;
  /// Card-like option rows (persona / track).
  static const optionRowHeight = 40.0;
  /// Intentional option cluster width (not full column stretch).
  static const optionClusterMaxWidth = 560.0;
  /// @deprecated Prefer [optionClusterMaxWidth]; kept for legacy FractionallySizedBox.
  static const compactControlWidthFactor = 1.0;
  static const rightBg = Color(0xFFF7F6F3);
  static const ink = Color(0xFF1A1A1A);
  static const muted = Color(0xFF888888);
  static const labelMuted = Color(0xFFAAAAAA);
  static const optionBorder = Color(0xFFE8E8E8);
  static const optionSelectedFill = Color(0xFFF5F5F5);
  static const optionSelectedBorder = Color(0xFFD8D8D8);
  static const chipBorder = Color(0xFFEEEEEE);
  static const chipSelectedFill = Color(0xFFF7F7F7);
  static const avatarFill = Color(0xFFF0EEF8);
  static const divider = Color(0xFFEBEBEB);
  static const passportPanelRadius = 12.0;

  /// Aliases onto the canonical [OnboardingTokens] scale.
  static const pageHeading = OnboardingTokens.pageTitleStyle;
  static const pageSubheading = OnboardingTokens.pageSubtitleStyle;
  static const sectionLabel = OnboardingTokens.sectionLabelStyle;
  static const fieldLabel = OnboardingTokens.fieldLabelStyle;
  static const optionCardText = OnboardingTokens.optionCardTextStyle;
  static const inputLabel = OnboardingTokens.fieldLabelStyle;
  static const inputValue = OnboardingTokens.inputTextStyle;
  static const helperText = OnboardingTokens.helperTextStyle;
  static TextStyle get chipText =>
      OnboardingTokens.chipLabelStyle(selected: true).copyWith(color: ink);

  static TextStyle optionRow({required bool selected}) =>
      OnboardingTokens.optionCardTextStyle.copyWith(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: ink,
      );

  static const passportSectionHeader = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: muted,
    letterSpacing: 0.8,
    height: 1.3,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  static const passportLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: labelMuted,
    height: 1.25,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  static const passportValue = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: ink,
    height: 1.3,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  /// Primary scannable values under section headers (public passport).
  static const passportValueProminent = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: ink,
    height: 1.3,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  /// Strongest scannable value on the public passport (slightly above body).
  static const passportBudgetValue = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: ink,
    height: 1.25,
    letterSpacing: -0.2,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  /// Display name in the passport identity row.
  static const passportIdentityName = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: ink,
    height: 1.25,
    letterSpacing: -0.2,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  static const passportValueSecondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: muted,
    height: 1.3,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.emojiFontFallback,
  );

  /// Soft trait chips — hairline border, text-first.
  static BoxDecoration passportTraitChipDecoration() => BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      );

  /// Flat passport vertical rhythm.
  static const passportLabelValueGap = OnboardingTokens.space4;
  static const passportRelatedGap = OnboardingTokens.space8;
  static const passportSectionGap = OnboardingTokens.space16;

  /// Centers a control cluster at [optionClusterMaxWidth], left-aligned content.
  static Widget constrainOptionCluster({required Widget child}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: optionClusterMaxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }

  static BoxDecoration optionDecoration({required bool selected}) =>
      BoxDecoration(
        color: selected ? optionSelectedFill : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? optionSelectedBorder : optionBorder,
          width: 1.0,
        ),
      );

  static BoxDecoration passportPanelDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(passportPanelRadius),
        border: Border.all(color: OnboardingTokens.inputBorder),
        boxShadow: [
          BoxShadow(
            color: ink.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration areaChipDecoration({required bool selected}) =>
      BoxDecoration(
        color: selected ? chipSelectedFill : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? ink : chipBorder,
          width: selected ? 1.5 : 1.0,
        ),
      );

  static BoxDecoration hubChipDecoration({required bool selected}) =>
      BoxDecoration(
        color: selected ? chipSelectedFill : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? ink : chipBorder,
          width: selected ? 1.5 : 1.0,
        ),
      );
}
