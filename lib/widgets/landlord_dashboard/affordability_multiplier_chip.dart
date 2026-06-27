import 'package:flutter/material.dart';

import 'landlord_dashboard_theme.dart';

/// Soft grey capsule showing gross-income rent coverage for landlords.
class AffordabilityMultiplierChip extends StatelessWidget {
  const AffordabilityMultiplierChip({
    super.key,
    required this.multiplier,
    this.fullWidth = false,
    this.compact = false,
  });

  final double multiplier;
  final bool fullWidth;
  final bool compact;

  String get _label =>
      '${multiplier.toStringAsFixed(1)}x Affordability Multiplier';

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      width: fullWidth ? double.infinity : null,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 10,
        vertical: compact ? 6 : 6,
      ),
      decoration: BoxDecoration(
        color: LandlordDashboardTheme.commuteTint,
        borderRadius: BorderRadius.circular(compact ? 8 : 999),
        border: Border.all(color: LandlordDashboardTheme.border),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(
            Icons.euro_rounded,
            size: compact ? 14 : 15,
            color: LandlordDashboardTheme.textSecondary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _label,
              style: TextStyle(
                fontSize: compact ? 11 : 11,
                fontWeight: FontWeight.w600,
                color: LandlordDashboardTheme.textSecondary,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (fullWidth) return chip;

    return Tooltip(
      message: _label,
      waitDuration: const Duration(milliseconds: 400),
      child: chip,
    );
  }
}
