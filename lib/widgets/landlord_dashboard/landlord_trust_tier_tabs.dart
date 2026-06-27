import 'package:flutter/material.dart';

import '../../models/landlord_applicant_card_model.dart';
import 'landlord_dashboard_theme.dart';

/// Premium segmented tab bar for trust-tier applicant filtering.
class LandlordTrustTierTabs extends StatelessWidget {
  const LandlordTrustTierTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.counts,
  });

  final LandlordTrustFilter selected;
  final ValueChanged<LandlordTrustFilter> onSelected;
  final Map<LandlordTrustFilter, int> counts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LandlordDashboardTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LandlordDashboardTheme.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 640;
          final tabs = LandlordTrustFilter.values;

          if (isNarrow) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tab in tabs) ...[
                    _TabChip(
                      label: tab.label,
                      count: counts[tab] ?? 0,
                      selected: selected == tab,
                      onTap: () => onSelected(tab),
                    ),
                    if (tab != tabs.last) const SizedBox(width: 6),
                  ],
                ],
              ),
            );
          }

          return Row(
            children: [
              for (final tab in tabs)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: tab == tabs.last ? 0 : 4,
                    ),
                    child: _TabChip(
                      label: tab.label,
                      count: counts[tab] ?? 0,
                      selected: selected == tab,
                      onTap: () => onSelected(tab),
                      expanded: true,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.expanded = false,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: selected ? LandlordDashboardTheme.canvas : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.center : MainAxisAlignment.start,
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected
                        ? LandlordDashboardTheme.textPrimary
                        : LandlordDashboardTheme.textSecondary,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: expanded ? TextAlign.center : TextAlign.start,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? LandlordDashboardTheme.accent.withValues(alpha: 0.12)
                        : LandlordDashboardTheme.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? LandlordDashboardTheme.accent
                          : LandlordDashboardTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return expanded ? child : child;
  }
}
