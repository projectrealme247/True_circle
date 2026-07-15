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
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final VoidCallback? onChanged;
  final bool validateEmailOnUnfocus;
  final String? prefixSymbol;
  final bool integerOnly;

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
      borderRadius: BorderRadius.circular(12),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: listingFieldLabelStyle),
        const SizedBox(height: listingLabelSpacing),
        TextFormField(
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
          style: listingFieldValueStyle,
          decoration: baseDecoration.copyWith(
            prefixText: widget.prefixSymbol,
            prefixStyle: listingFieldValueStyle.copyWith(
              color: const Color(0xFF6B7280),
            ),
            border: _fieldBorder(borderColor),
            enabledBorder: _fieldBorder(borderColor),
            focusedBorder: _fieldBorder(focusedBorderColor, width: 1.5),
          ),
        ),
        if (_hasError) ...[
          const SizedBox(height: 6),
          Text(
            _errorText!,
            style: listingSubLabelStyle.copyWith(
              color: _errorBorderColor,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}
