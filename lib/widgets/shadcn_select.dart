import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'onboarding/onboarding_design_tokens.dart';

/// shadcn/ui-inspired select trigger + popover menu (Flutter-native).
class ShadcnSelect extends StatefulWidget {
  const ShadcnSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint = 'Select',
    this.seekerTypography = false,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final String hint;
  /// Seeker onboarding: 14px medium label, 16px regular value, 40px control.
  final bool seekerTypography;

  @override
  State<ShadcnSelect> createState() => _ShadcnSelectState();
}

class _ShadcnSelectState extends State<ShadcnSelect> {
  final _menuController = MenuController();
  bool _focused = false;
  bool _hovering = false;

  void _toggleMenu(MenuController controller) {
    if (controller.isOpen) {
      controller.close();
    } else {
      controller.open();
    }
    setState(() => _focused = controller.isOpen);
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = widget.seekerTypography
        ? SeekerOnboardingLayout.fieldLabel
        : ShadcnSelectTheme.fieldLabel;
    final inputStyle = widget.seekerTypography
        ? SeekerOnboardingLayout.inputValue
        : ShadcnSelectTheme.inputText;
    final controlHeight = widget.seekerTypography
        ? 40.0
        : ShadcnSelectTheme.controlHeight;
    final labelGap = widget.seekerTypography
        ? OnboardingTokens.space4
        : ShadcnSelectTheme.labelGap;

    final borderColor = _focused
        ? ShadcnSelectTheme.primary
        : _hovering
            ? ShadcnSelectTheme.primary.withValues(alpha: 0.4)
            : ShadcnSelectTheme.borderSoft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.seekerTypography
              ? 18
              : ShadcnSelectTheme.labelHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(widget.label, style: labelStyle),
          ),
        ),
        SizedBox(height: labelGap),
        MenuAnchor(
          controller: _menuController,
          onOpen: () => setState(() => _focused = true),
          onClose: () => setState(() => _focused = false),
          style: MenuStyle(
            padding: WidgetStateProperty.all(EdgeInsets.zero),
            elevation: WidgetStateProperty.all(4),
            shadowColor: WidgetStateProperty.all(Colors.black12),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(ShadcnSelectTheme.radiusXl),
              ),
            ),
            backgroundColor:
                WidgetStateProperty.all(ShadcnSelectTheme.surface),
          ),
          menuChildren: widget.options.map((option) {
            final selected = option == widget.value;
            return MenuItemButton(
              onPressed: () {
                widget.onChanged(option);
                _menuController.close();
              },
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return const Color(0xFFFDF0ED);
                  }
                  if (selected) {
                    return const Color(0xFFF7F7F7);
                  }
                  return Colors.transparent;
                }),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option,
                      style: inputStyle.copyWith(
                        fontWeight:
                            selected ? FontWeight.w500 : FontWeight.w400,
                        color: selected
                            ? ShadcnSelectTheme.primary
                            : ShadcnSelectTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: ShadcnSelectTheme.primary,
                    ),
                ],
              ),
            );
          }).toList(),
          builder: (context, controller, child) {
            return Material(
              color: Colors.transparent,
              child: MouseRegion(
                onEnter: (_) => setState(() => _hovering = true),
                onExit: (_) => setState(() => _hovering = false),
                child: InkWell(
                  onTap: () => _toggleMenu(controller),
                  borderRadius:
                      BorderRadius.circular(ShadcnSelectTheme.radiusXl),
                  splashColor: const Color(0x33E76F51),
                  highlightColor: const Color(0x1AE76F51),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    height: controlHeight,
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.seekerTypography ? 12 : 16,
                      vertical: widget.seekerTypography ? 8 : 14,
                    ),
                    decoration: BoxDecoration(
                      color: ShadcnSelectTheme.surface,
                      borderRadius:
                          BorderRadius.circular(ShadcnSelectTheme.radiusXl),
                      border: Border.all(
                        color: borderColor,
                        width: _focused ? 1.5 : 1,
                      ),
                      boxShadow: _hovering ? ShadcnSelectTheme.shadowSm : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.value.isEmpty ? widget.hint : widget.value,
                            style: inputStyle.copyWith(
                              color: widget.value.isEmpty
                                  ? ShadcnSelectTheme.gray400
                                  : ShadcnSelectTheme.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          controller.isOpen
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: _hovering || _focused
                              ? ShadcnSelectTheme.primary.withValues(alpha: 0.75)
                              : ShadcnSelectTheme.gray400,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

abstract final class ShadcnSelectTheme {
  static const primary = AppColors.accent;
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111111);
  static const gray400 = Color(0xFF94A3B8);
  static const gray500 = Color(0xFF6B7280);
  static const borderSoft = Color(0xFFE5E7EB);
  static const radiusXl = 12.0;
  static const labelHeight = 18.0;
  static const labelGap = 6.0;
  static const controlHeight = 52.0;

  static const fieldLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: gray500,
    letterSpacing: 0.1,
    height: 1.2,
  );

  static const inputText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    height: 1.2,
  );

  static List<BoxShadow> get shadowSm => const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ];
}
