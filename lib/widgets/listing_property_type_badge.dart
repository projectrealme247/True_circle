import 'package:flutter/material.dart';

import '../theme/home_marketplace_theme.dart';
import '../utils/listing_data.dart';

/// Property type chip with icon (Rent / Buy / Share) for listing cards.
class ListingPropertyTypeBadge extends StatelessWidget {
  const ListingPropertyTypeBadge({
    super.key,
    required this.listing,
    this.compact = false,
  });

  final Map<String, dynamic> listing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final propertyType = ListingData.propertyType(listing);
    final tone = HomeMarketplaceTheme.tagToneFor(propertyType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(propertyType), size: 16, color: tone.text),
          const SizedBox(width: 4),
          Text(
            propertyType,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tone.text,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'Buy' => Icons.vpn_key_rounded,
        'Share' => Icons.bed_rounded,
        _ => Icons.home_rounded,
      };
}
