import 'package:flutter/material.dart';

/// shadcn/ui-inspired select trigger + popover menu (Flutter-native).
class ShadcnSelect extends StatefulWidget {
  const ShadcnSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint = 'Select',
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final String hint;

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
    final borderColor = _focused
        ? ShadcnSelectTheme.primary
        : _hovering
            ? ShadcnSelectTheme.primary.withValues(alpha: 0.4)
            : ShadcnSelectTheme.borderSoft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: ShadcnSelectTheme.labelHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(widget.label, style: ShadcnSelectTheme.fieldLabel),
          ),
        ),
        const SizedBox(height: ShadcnSelectTheme.labelGap),
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
                    return ShadcnSelectTheme.primary.withValues(alpha: 0.06);
                  }
                  if (selected) {
                    return ShadcnSelectTheme.primary.withValues(alpha: 0.1);
                  }
                  return Colors.transparent;
                }),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option,
                      style: ShadcnSelectTheme.inputText.copyWith(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
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
                  splashColor:
                      ShadcnSelectTheme.primary.withValues(alpha: 0.08),
                  highlightColor:
                      ShadcnSelectTheme.primary.withValues(alpha: 0.04),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    height: ShadcnSelectTheme.controlHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: ShadcnSelectTheme.surface,
                      borderRadius:
                          BorderRadius.circular(ShadcnSelectTheme.radiusXl),
                      border: Border.all(
                        color: borderColor,
                        width: _focused ? 1.5 : 1,
                      ),
                      boxShadow: _focused
                          ? [
                              BoxShadow(
                                color: ShadcnSelectTheme.primary
                                    .withValues(alpha: 0.2),
                                blurRadius: 0,
                                spreadRadius: 3,
                              ),
                            ]
                          : _hovering
                              ? ShadcnSelectTheme.shadowSm
                              : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.value.isEmpty ? widget.hint : widget.value,
                            style: ShadcnSelectTheme.inputText.copyWith(
                              color: widget.value.isEmpty
                                  ? ShadcnSelectTheme.gray400
                                  : ShadcnSelectTheme.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Icon(
                            controller.isOpen
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: _hovering || _focused
                                ? ShadcnSelectTheme.primary
                                    .withValues(alpha: 0.75)
                                : ShadcnSelectTheme.gray400,
                          ),
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
  static const primary = Color(0xFF0EA5E9);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1C1E21);
  static const gray400 = Color(0xFF9CA3AF);
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
