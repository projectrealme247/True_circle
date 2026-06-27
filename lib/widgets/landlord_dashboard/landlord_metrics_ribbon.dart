import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart' show AppColors, AppShadows;
import '../../theme/app_typography.dart';
import '../../utils/landlord_dashboard_helpers.dart';

class LandlordMetricsRibbon extends StatelessWidget {
  const LandlordMetricsRibbon({
    super.key,
    required this.metrics,
  });

  final LandlordStreamMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        children: [
          _MetricCard(
            label: 'Active Matches Waiting',
            value: '${metrics.activeMatches}',
            subtitle: 'In your live stream',
            icon: Icons.people_alt_outlined,
            accent: AppColors.accent,
          ),
          const SizedBox(width: 10),
          _MetricCard(
            label: 'Trust Tier Spectrum',
            value: '${metrics.soundCount}·${metrics.grandCount}·${metrics.justLandedCount}',
            subtitle: 'Sound · Grand · Just Landed',
            icon: Icons.verified_outlined,
            accent: const Color(LandlordDashboardTokens.emeraldHighlight),
          ),
          const SizedBox(width: 10),
          _SiftingHoursCard(hours: metrics.siftingHoursSaved),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta().copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(LandlordDashboardTokens.unselectedGrey),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: AppTypography.sectionTitle().copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            subtitle,
            style: AppTypography.meta().copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SiftingHoursCard extends StatelessWidget {
  const _SiftingHoursCard({required this.hours});

  final double hours;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_bottom_rounded,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Sifting Hours Saved',
                  style: AppTypography.meta().copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(LandlordDashboardTokens.unselectedGrey),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '${hours.toStringAsFixed(1)}h',
            style: AppTypography.sectionTitle().copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            '≈ ${(hours * 47).round()} awkward viewings dodged',
            style: AppTypography.meta().copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
