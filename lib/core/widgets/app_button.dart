import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, outline, ghost }

enum AppButtonSize { small, medium, large }

enum IconPosition { leading, trailing }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.iconPosition = IconPosition.leading,
    this.isLoading = false,
    this.isFullWidth = false,
    this.isDisabled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final IconPosition iconPosition;
  final bool isLoading;
  final bool isFullWidth;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isDisabled || isLoading ? null : onPressed;

    final buttonChild = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: _iconSize,
            height: _iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_foregroundColor),
            ),
          )
        else if (icon != null && iconPosition == IconPosition.leading)
          Icon(icon, size: _iconSize),
        if ((icon != null || isLoading) && iconPosition == IconPosition.leading)
          SizedBox(width: _spacing),
        Text(label, style: _labelStyle),
        if (icon != null && iconPosition == IconPosition.trailing) ...[
          SizedBox(width: _spacing),
          Icon(icon, size: _iconSize),
        ],
      ],
    );

    final Widget button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: _primaryStyle,
          child: buttonChild,
        ),
      AppButtonVariant.secondary => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: _secondaryStyle,
          child: buttonChild,
        ),
      AppButtonVariant.outline => OutlinedButton(
          onPressed: effectiveOnPressed,
          style: _outlineStyle,
          child: buttonChild,
        ),
      AppButtonVariant.ghost => TextButton(
          onPressed: effectiveOnPressed,
          style: _ghostStyle,
          child: buttonChild,
        ),
    };

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  TextStyle get _labelStyle => AppTypography.button.copyWith(
        fontSize: _fontSize,
        color: _foregroundColor,
      );

  double get _iconSize {
    switch (size) {
      case AppButtonSize.small:
        return 16;
      case AppButtonSize.medium:
        return 18;
      case AppButtonSize.large:
        return 20;
    }
  }

  double get _spacing {
    switch (size) {
      case AppButtonSize.small:
        return 6;
      case AppButtonSize.medium:
        return 8;
      case AppButtonSize.large:
        return 10;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 18);
    }
  }

  double get _fontSize {
    switch (size) {
      case AppButtonSize.small:
        return 13;
      case AppButtonSize.medium:
        return 15;
      case AppButtonSize.large:
        return 17;
    }
  }

  Color get _foregroundColor {
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.surface;
      case AppButtonVariant.secondary:
        return AppColors.surface;
      case AppButtonVariant.outline:
      case AppButtonVariant.ghost:
        return variant == AppButtonVariant.ghost
            ? AppColors.accent
            : AppColors.primaryText;
    }
  }

  ButtonStyle get _primaryStyle => ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.surface,
        disabledBackgroundColor: AppColors.disabled,
        disabledForegroundColor: AppColors.secondaryText,
        elevation: 0,
        padding: _padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: _fontSize,
          fontWeight: FontWeight.w600,
        ),
      );

  ButtonStyle get _secondaryStyle => ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryText,
        foregroundColor: AppColors.surface,
        disabledBackgroundColor: AppColors.disabled,
        disabledForegroundColor: AppColors.secondaryText,
        elevation: 0,
        padding: _padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: _fontSize,
          fontWeight: FontWeight.w600,
        ),
      );

  ButtonStyle get _outlineStyle => OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryText,
        side: BorderSide(
          color: isDisabled ? AppColors.disabled : AppColors.primaryText,
          width: 1.5,
        ),
        padding: _padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: _fontSize,
          fontWeight: FontWeight.w600,
        ),
      );

  ButtonStyle get _ghostStyle => TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        padding: _padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: _fontSize,
          fontWeight: FontWeight.w600,
        ),
      );
}
