import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart' as core;
import '../models/applicant_trust_tier.dart';
import '../models/landlord_applicant_card_model.dart';
import '../theme/trust_tier_design.dart';

/// Sleek single-line trust scale — micro-toggle filters on dashboard.
class TrustTierLegendScale extends StatelessWidget {
  const TrustTierLegendScale({
    super.key,
    this.selectedFilter = LandlordTrustFilter.all,
    this.onFilterChanged,
    this.interactive = true,
    this.compact = false,
    this.mutedTextColor = const Color(0xFF6B7280),
  });

  final LandlordTrustFilter selectedFilter;
  final ValueChanged<LandlordTrustFilter>? onFilterChanged;
  final bool interactive;
  final bool compact;
  final Color mutedTextColor;

  static const _items = [
    (
      filter: LandlordTrustFilter.sound,
      tier: ApplicantTrustTier.sound,
    ),
    (
      filter: LandlordTrustFilter.grand,
      tier: ApplicantTrustTier.grand,
    ),
    (
      filter: LandlordTrustFilter.justLanded,
      tier: ApplicantTrustTier.justLanded,
    ),
  ];

  void _onTap(LandlordTrustFilter filter) {
    if (!interactive || onFilterChanged == null) return;
    if (selectedFilter == filter) {
      onFilterChanged!(LandlordTrustFilter.all);
    } else {
      onFilterChanged!(filter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 640;

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _prefixLabel(),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final item in _items)
                    _MicroToggle(
                      label: TrustTierDesign.trustScaleLegendLabel(item.tier),
                      selected: selectedFilter == item.filter,
                      interactive: interactive,
                      mutedTextColor: mutedTextColor,
                      compact: compact,
                      onTap: () => _onTap(item.filter),
                    ),
                ],
              ),
            ],
          );
        }

        return Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _prefixLabel(),
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0)
                Text(
                  '·',
                  style: TextStyle(
                    fontSize: compact ? 15 : 16,
                    color: mutedTextColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              _MicroToggle(
                label: TrustTierDesign.trustScaleLegendLabel(_items[i].tier),
                selected: selectedFilter == _items[i].filter,
                interactive: interactive,
                mutedTextColor: mutedTextColor,
                compact: compact,
                onTap: () => _onTap(_items[i].filter),
              ),
            ],
          ],
        );
      },
    );

    if (compact) {
      return Align(
        alignment: Alignment.centerLeft,
        child: content,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: content,
    );
  }

  Widget _prefixLabel() {
    return Text(
      'Trust Scale:',
      style: TextStyle(
        fontSize: compact ? 15 : 16,
        fontWeight: FontWeight.w700,
        color: mutedTextColor,
        height: 1.25,
      ),
    );
  }
}

class _MicroToggle extends StatelessWidget {
  const _MicroToggle({
    required this.label,
    required this.selected,
    required this.interactive,
    required this.mutedTextColor,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool interactive;
  final Color mutedTextColor;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor = core.AppColors.secondaryText;
    final child = Text(
      label,
      style: TextStyle(
        fontSize: compact ? 15 : 16,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        color: selected ? selectedColor : mutedTextColor,
        decoration: selected ? TextDecoration.underline : null,
        decorationColor: selectedColor,
        height: 1.25,
        fontFamily: core.AppTypography.fontFamily,
        fontFamilyFallback: core.AppTypography.emojiFontFallback,
      ),
    );

    if (!interactive) {
      return MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: child,
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: child,
          ),
        ),
      ),
    );
  }
}
