import 'package:flutter/material.dart';

import '../theme/home_marketplace_theme.dart';
import '../utils/listing_data.dart';

/// Occupant type chip with people icon for listing cards.
class ListingOccupantBadges extends StatelessWidget {
  const ListingOccupantBadges({super.key, required this.listing, this.compact = false});

  final Map<String, dynamic> listing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final occupant = ListingData.occupantType(listing);
    if (occupant.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeMarketplaceTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconFor(occupant),
            size: 16,
            color: HomeMarketplaceTheme.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            occupant,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: HomeMarketplaceTheme.textSecondary,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String occupant) {
    final lower = occupant.toLowerCase();
    if (lower.contains('family')) return Icons.family_restroom_rounded;
    if (lower.contains('student')) return Icons.school_rounded;
    return Icons.people_outline_rounded;
  }
}
