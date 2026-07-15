import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Core TrueCircle design system palette.
///
/// **Tokens**
/// - Primary accent: coral/red only ([accent]).
/// - Neutrals: charcoal text, light grey surfaces.
/// - Rule: never use corporate blues or oranges in custom widgets or
///   social-platform integrations — use [executiveCta] and [neutralBadgeFill].
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFF0F0F0);
  static const Color primaryText = Color(0xFF222222);
  static const Color secondaryText = Color(0xFF717171);
  static const Color accent = Color(0xFFFF5A5F);

  static const Color success = Color(0xFF00A699);
  static const Color warning = Color(0xFFFFB400);
  static const Color error = Color(0xFFC13515);
  static const Color divider = Color(0xFFEBEBEB);
  static const Color disabled = Color(0xFFDDDDDD);

  static const Color accentLight = Color(0xFFFFE8E8);
  static const Color accentDark = Color(0xFFE04E52);

  /// Teal tint for verified / trust-complete surfaces.
  static const Color successSurface = Color(0xFFE6F6F4);

  /// Executive near-black CTA for OAuth / third-party connect actions.
  static const Color executiveCta = Color(0xFF191919);

  /// Neutral icon badge fill (e.g. LinkedIn card header).
  static const Color neutralBadgeFill = Color(0xFFF5F5F5);

  /// Muted emerald for trust progress — not platform brand colors.
  static const Color trustMuted = Color(0xFF1F6F5C);

  /// Soft surface behind trust-complete states.
  static const Color trustMutedSurface = Color(0xFFE8F0EE);

  /// Official LinkedIn brand — social verification OAuth UI only.
  static const Color linkedInBlue = Color(0xFF0077B5);
  static const Color linkedInSurface = Color(0xFFE8F3F9);
}

/// Plus Jakarta Sans type scale — loaded via [GoogleFonts].
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'PlusJakartaSans';

  /// Bundled color emoji font — registered in pubspec.yaml.
  static const String emojiFontFamily = 'Noto Color Emoji';

  /// CanvasKit/web-safe alias (no spaces) for the same bundled TTF.
  static const String emojiFontFamilyAlias = 'NotoColorEmoji';

  /// Fallback chain for mixed Latin + emoji copy (onboarding chips, labels, trust badges).
  static const List<String> emojiFontFallback = <String>[
    emojiFontFamilyAlias,
    emojiFontFamily,
    'Segoe UI Emoji',
    'Apple Color Emoji',
    'Noto Color Emoji',
  ];

  /// Text style for strings that start with emoji + Latin label (e.g. lifestyle chips).
  static TextStyle emojiMixedTextStyle({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.primaryText,
    double height = 1.2,
  }) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        fontFamily: fontFamily,
        fontFamilyFallback: emojiFontFallback,
      );

  /// Applies [emojiFontFallback] to any text style that may render emoji glyphs.
  static TextStyle withEmojiFallback(TextStyle style) => style.copyWith(
        fontFamilyFallback: emojiFontFallback,
      );

  static TextStyle get display => withEmojiFallback(GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.primaryText,
      ));

  static TextStyle get h1 => withEmojiFallback(GoogleFonts.plusJakartaSans(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: AppColors.primaryText,
      ));

  static TextStyle get h2 => withEmojiFallback(GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.primaryText,
      ));

  static TextStyle get h3 => withEmojiFallback(GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: AppColors.primaryText,
      ));

  static TextStyle get body => withEmojiFallback(GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.primaryText,
      ));

  static TextStyle get bodySecondary => withEmojiFallback(GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.secondaryText,
      ));

  static TextStyle get caption => withEmojiFallback(GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.secondaryText,
      ));

  static TextStyle get button => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1,
        color: AppColors.surface,
      );

  static TextStyle get link => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.5,
        color: AppColors.accent,
      );
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 24);
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
}

class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 999;
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get elevated => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.emojiFontFallback,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        onPrimary: AppColors.surface,
        secondary: AppColors.accent,
        onSecondary: AppColors.surface,
        surface: AppColors.surface,
        onSurface: AppColors.primaryText,
        error: AppColors.error,
        onError: AppColors.surface,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryText,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: AppTypography.h2,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: AppButtonStyles.primaryFilled,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.surface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryText,
          side: const BorderSide(color: AppColors.primaryText, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.button.copyWith(color: AppColors.primaryText),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: AppTypography.link,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primaryText, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: AppTypography.body.copyWith(color: AppColors.secondaryText),
        labelStyle: AppTypography.caption,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.background,
        selectedColor: AppColors.accentLight,
        labelStyle: AppTypography.caption.copyWith(color: AppColors.primaryText),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.secondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.display,
        headlineLarge: AppTypography.h1,
        headlineMedium: AppTypography.h2,
        headlineSmall: AppTypography.h3,
        bodyLarge: AppTypography.body,
        bodyMedium: AppTypography.bodySecondary,
        labelLarge: AppTypography.button,
        labelSmall: AppTypography.caption,
      ),
    );
  }

  /// Airbnb-style floating card decoration.
  static BoxDecoration cardDecoration({
    Color color = AppColors.surface,
    double radius = AppRadius.lg,
    bool elevated = true,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: elevated ? AppShadows.card : null,
    );
  }
}

/// Global primary CTA styling — Coral Red, 12px radius, medium weight.
abstract final class AppButtonStyles {
  static const _radius = AppRadius.md;

  static ButtonStyle get primaryFilled => FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.surface,
        disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.45),
        disabledForegroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        textStyle: AppTypography.button.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
      );

  static ButtonStyle primaryFilledWith({double disabledAlpha = 0.45}) =>
      FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.surface,
        disabledBackgroundColor:
            AppColors.accent.withValues(alpha: disabledAlpha),
        disabledForegroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        textStyle: AppTypography.button.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
      );
}

/// Shared form control padding for profile and listing editors.
abstract final class AppFormFields {
  static InputDecoration decoration({
    required String labelText,
    String? hintText,
    Color fillColor = AppColors.surface,
  }) =>
      InputDecoration(
        labelText: labelText,
        hintText: hintText,
        filled: true,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primaryText, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      );
}
