import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../listing_creation/listing_creation_primitives.dart';
import 'onboarding_design_tokens.dart';

final RegExp onboardingEmailRegex = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);

/// Refined onboarding text field — listing wizard label + input parity.
class OnboardingPremiumField extends StatefulWidget {
  const OnboardingPremiumField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.onChanged,
    this.validateEmailOnUnfocus = false,
    this.prefixSymbol,
    this.integerOnly = false,
    this.compact = false,
    this.seekerTypography = false,
    this.hideLabel = false,
    this.inputHeight,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final VoidCallback? onChanged;
  final bool validateEmailOnUnfocus;
  final String? prefixSymbol;
  final bool integerOnly;
  /// Tighter label + input for dense onboarding steps.
  final bool compact;
  /// Pass-1 input label/value typography.
  final bool seekerTypography;
  /// Hide the label row (e.g. when an outer section label is used).
  final bool hideLabel;
  /// Fixed input height (seeker polish: 44 / 48).
  final double? inputHeight;

  @override
  State<OnboardingPremiumField> createState() => _OnboardingPremiumFieldState();
}

class _OnboardingPremiumFieldState extends State<OnboardingPremiumField> {
  static const _errorBorderColor = Color(0xFFDC2626);

  final FocusNode _focusNode = FocusNode();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && widget.validateEmailOnUnfocus) {
      _validateEmail(showWhenEmpty: false);
    }
  }

  void _validateEmail({bool showWhenEmpty = true}) {
    final value = widget.controller.text.trim();
    if (!showWhenEmpty && value.isEmpty) {
      setState(() => _errorText = null);
      return;
    }
    final valid = value.isNotEmpty && onboardingEmailRegex.hasMatch(value);
    setState(() {
      _errorText =
          valid ? null : 'Please enter a valid email address';
    });
  }

  bool get _hasError => _errorText != null;

  OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(widget.seekerTypography ? 8 : 12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseDecoration = OnboardingTokens.inputDecoration(hint: widget.hint);
    final borderColor =
        _hasError ? _errorBorderColor : OnboardingTokens.inputBorder;
    final focusedBorderColor =
        _hasError ? _errorBorderColor : const Color(0xFF0F172A);
    final labelStyle = widget.seekerTypography
        ? SeekerOnboardingLayout.inputLabel
        : widget.compact
            ? const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
                height: 1.3,
              )
            : listingFieldLabelStyle;
    final valueStyle = widget.seekerTypography
        ? SeekerOnboardingLayout.inputValue
        : listingFieldValueStyle.copyWith(
            fontSize: widget.compact ? 14 : listingFieldValueStyle.fontSize,
          );
    final contentPadding = widget.compact || widget.seekerTypography
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
        : baseDecoration.contentPadding;

    final field = TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.integerOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      onChanged: widget.onChanged == null
          ? null
          : (_) {
              if (_hasError && widget.validateEmailOnUnfocus) {
                _validateEmail(showWhenEmpty: false);
              }
              widget.onChanged!();
            },
      style: valueStyle,
      decoration: baseDecoration.copyWith(
        isDense: widget.compact || widget.seekerTypography,
        contentPadding: contentPadding,
        prefixText: widget.prefixSymbol,
        prefixStyle: valueStyle.copyWith(
          color: const Color(0xFF6B7280),
        ),
        border: _fieldBorder(borderColor),
        enabledBorder: _fieldBorder(borderColor),
        focusedBorder: _fieldBorder(focusedBorderColor, width: 1.5),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.hideLabel) ...[
          Text(widget.label, style: labelStyle),
          SizedBox(
            height: widget.compact || widget.seekerTypography
                ? 4
                : listingLabelSpacing,
          ),
        ],
        if (widget.inputHeight != null)
          SizedBox(height: widget.inputHeight, child: field)
        else
          field,
        if (_hasError) ...[
          const SizedBox(height: 6),
          Text(
            _errorText!,
            style: (widget.seekerTypography
                    ? SeekerOnboardingLayout.helperText
                    : listingSubLabelStyle)
                .copyWith(
              color: _errorBorderColor,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }
}
