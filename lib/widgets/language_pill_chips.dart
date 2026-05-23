import 'package:flutter/material.dart';

/// Selectable language pills with primary highlight when active.
class LanguagePillChips extends StatelessWidget {
  const LanguagePillChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.spacing = 10,
    this.runSpacing = 10,
  });

  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: options.map((label) => _LanguagePill(
            label: label,
            selected: selected.contains(label),
            onTap: () => onToggle(label),
          )).toList(),
    );
  }
}

class _LanguagePill extends StatefulWidget {
  const _LanguagePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_LanguagePill> createState() => _LanguagePillState();
}

class _LanguagePillState extends State<_LanguagePill> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.selected
        ? _PillTheme.primary
        : _hovering
            ? _PillTheme.primary.withValues(alpha: 0.4)
            : _PillTheme.borderSoft;

    final bgColor = widget.selected
        ? _PillTheme.primary
        : _hovering
            ? _PillTheme.primary.withValues(alpha: 0.06)
            : _PillTheme.surface;

    final scale = !widget.selected && _hovering ? 1.03 : 1.0;

    return Material(
      color: Colors.transparent,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(_PillTheme.radiusFull),
          splashColor: _PillTheme.primary.withValues(alpha: 0.12),
          highlightColor: _PillTheme.primary.withValues(alpha: 0.06),
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(_PillTheme.radiusFull),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: widget.selected
                    ? [
                        BoxShadow(
                          color: _PillTheme.primary.withValues(alpha: 0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : _hovering
                        ? [
                            BoxShadow(
                              color:
                                  _PillTheme.primary.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.selected) ...[
                    const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.selected
                          ? Colors.white
                          : _PillTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class _PillTheme {
  static const primary = Color(0xFF0EA5E9);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1C1E21);
  static const borderSoft = Color(0xFFE5E7EB);
  static const radiusFull = 999.0;
}
