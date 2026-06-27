import 'package:flutter/material.dart';

import 'landlord_dashboard_theme.dart';

class LandlordNoiseFilterBanner extends StatelessWidget {
  const LandlordNoiseFilterBanner({
    super.key,
    required this.deflectedCount,
  });

  final int deflectedCount;

  String get _message {
    if (deflectedCount <= 0) {
      return 'Noise Filter Active: Smart-screening engine validated all inbound matching tiers with zero anomalies detected today.';
    }
    if (deflectedCount == 1) {
      return 'Noise Filter Active: 1 low-signal profile automatically bounced today';
    }
    return 'Noise Filter Active: $deflectedCount low-signal profiles automatically bounced today';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: LandlordDashboardTheme.canvas,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LandlordDashboardTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: LandlordDashboardTheme.textSecondary,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
