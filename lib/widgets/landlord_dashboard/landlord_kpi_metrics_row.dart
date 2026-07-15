import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/landlord_applicant_card_model.dart';
import '../../utils/landlord_dashboard_helpers.dart';
import 'landlord_dashboard_theme.dart';

/// Four uniform KPI metric cards — pool cards toggle trust-tier filters.
class LandlordKpiMetricsRow extends StatelessWidget {
  const LandlordKpiMetricsRow({
    super.key,
    required this.metrics,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final LandlordStreamMetrics metrics;
  final LandlordTrustFilter selectedFilter;
  final ValueChanged<LandlordTrustFilter> onFilterChanged;

  static const _maxContentWidth = 1200.0;

  void _toggleFilter(LandlordTrustFilter filter) {
    if (selectedFilter == filter) {
      onFilterChanged(LandlordTrustFilter.all);
    } else {
      onFilterChanged(filter);
    }
  }

  String _candidateLabel(int count) =>
      count == 1 ? '1 Candidate' : '$count Candidates';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final cards = [
              _MetricCard(
                label: 'Active Responses',
                value: '${metrics.activeMatches}',
                subtext: 'Current high-signal candidates in pipeline',
              ),
              _PoolMetricCard(
                label: 'Sound',
                value: _candidateLabel(metrics.soundCount),
                subtext: 'Vouched & Secured',
                selected: selectedFilter == LandlordTrustFilter.sound,
                onTap: () => _toggleFilter(LandlordTrustFilter.sound),
              ),
              _PoolMetricCard(
                label: 'Grand',
                value: _candidateLabel(metrics.grandCount),
                subtext: 'Verified Intent',
                selected: selectedFilter == LandlordTrustFilter.grand,
                onTap: () => _toggleFilter(LandlordTrustFilter.grand),
              ),
              _PoolMetricCard(
                label: 'Just Landed',
                value: _candidateLabel(metrics.justLandedCount),
                subtext: 'Casual / Inbound',
                selected: selectedFilter == LandlordTrustFilter.justLanded,
                onTap: () => _toggleFilter(LandlordTrustFilter.justLanded),
              ),
            ];

            final maxWidth = constraints.maxWidth;
            if (maxWidth >= 960) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Expanded(child: cards[i]),
                  ],
                ],
              );
            }

            if (maxWidth >= 520) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: gap),
                      Expanded(child: cards[1]),
                    ],
                  ),
                  const SizedBox(height: gap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[2]),
                      const SizedBox(width: gap),
                      Expanded(child: cards[3]),
                    ],
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: gap),
                  cards[i],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtext,
  });

  final String label;
  final String value;
  final String subtext;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: LandlordDashboardTheme.cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: LandlordDashboardTheme.cardLabel(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: LandlordDashboardTheme.cardValue(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              subtext,
              style: LandlordDashboardTheme.cardSubtext(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PoolMetricCard extends StatefulWidget {
  const _PoolMetricCard({
    required this.label,
    required this.value,
    required this.subtext,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final String subtext;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PoolMetricCard> createState() => _PoolMetricCardState();
}

class _PoolMetricCardState extends State<_PoolMetricCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hovered;
    final neutralAccent = AppColors.secondaryText;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          hoverColor: AppColors.surface2,
          splashColor: AppColors.divider,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            decoration: LandlordDashboardTheme.cardDecoration(
              selected: widget.selected,
            ).copyWith(
              border: Border.all(
                color: widget.selected
                    ? neutralAccent
                    : active
                        ? AppColors.divider
                        : LandlordDashboardTheme.border,
                width: widget.selected ? 1.5 : 1,
              ),
              color: active ? AppColors.surface2 : LandlordDashboardTheme.surface,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: LandlordDashboardTheme.cardLabel(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.value,
                  style: LandlordDashboardTheme.cardValue(size: 24),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.subtext,
                  style: LandlordDashboardTheme.cardSubtext().copyWith(
                    color: widget.selected
                        ? neutralAccent
                        : LandlordDashboardTheme.textMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
