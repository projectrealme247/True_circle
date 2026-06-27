import 'package:flutter/material.dart';

import '../theme/home_marketplace_theme.dart';

/// Selectable language pills — primary when active, accent on hover.
class LanguagePillChips extends StatelessWidget {
  const LanguagePillChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.nativeByLanguage = const {},
    this.onToggleNative,
    this.spacing = 10,
    this.runSpacing = 10,
    this.unselectedBackgroundColor,
  });

  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final Map<String, bool> nativeByLanguage;
  final ValueChanged<String>? onToggleNative;
  final double spacing;
  final double runSpacing;
  final Color? unselectedBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: options
          .map(
            (label) => _LanguagePill(
              label: label,
              selected: selected.contains(label),
              isNative: nativeByLanguage[label] ?? false,
              onTap: () => onToggle(label),
              onToggleNative: onToggleNative == null
                  ? null
                  : () => onToggleNative!(label),
              unselectedBackgroundColor: unselectedBackgroundColor,
            ),
          )
          .toList(),
    );
  }
}

class _LanguagePill extends StatefulWidget {
  const _LanguagePill({
    required this.label,
    required this.selected,
    required this.isNative,
    required this.onTap,
    this.onToggleNative,
    this.unselectedBackgroundColor,
  });

  final String label;
  final bool selected;
  final bool isNative;
  final VoidCallback onTap;
  final VoidCallback? onToggleNative;
  final Color? unselectedBackgroundColor;

  @override
  State<_LanguagePill> createState() => _LanguagePillState();
}

class _LanguagePillState extends State<_LanguagePill> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.selected
        ? HomeMarketplaceTheme.primary
        : _hovering
            ? HomeMarketplaceTheme.accent.withValues(alpha: 0.55)
            : HomeMarketplaceTheme.border;

    final bgColor = widget.selected
        ? HomeMarketplaceTheme.primary
        : _hovering
            ? HomeMarketplaceTheme.accentSurface
            : (widget.unselectedBackgroundColor ?? HomeMarketplaceTheme.surface);

    return Material(
      color: Colors.transparent,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(999),
          splashColor: HomeMarketplaceTheme.accent.withValues(alpha: 0.12),
          highlightColor: HomeMarketplaceTheme.accentSurface,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: widget.selected
                  ? HomeMarketplaceTheme.cardShadowRest
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: widget.selected
                        ? Colors.white
                        : HomeMarketplaceTheme.textPrimary,
                  ),
                ),
                if (widget.selected && widget.onToggleNative != null) ...[
                  const SizedBox(width: 8),
                  _NativeToggle(
                    active: widget.isNative,
                    onTap: widget.onToggleNative!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NativeToggle extends StatelessWidget {
  const _NativeToggle({
    required this.active,
    required this.onTap,
  });

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 12,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              const Text(
                'Native',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
