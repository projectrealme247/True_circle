import 'package:flutter/material.dart';

import '../theme/home_marketplace_theme.dart';
import '../utils/listing_data.dart';

/// Household culture chips for shared listings (Veg, No Pets, etc.).
class ListingCultureChips extends StatelessWidget {
  const ListingCultureChips({super.key, required this.listing});

  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context) {
    final labels = ListingData.cultureChipLabels(listing);
    if (labels.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      clipBehavior: Clip.hardEdge,
      children: labels.map(_chip).toList(),
    );
  }

  Widget _chip(String label) {
    final isVeg = label == 'Veg';
    final isNonVeg = label == 'Non-veg';

    final Color bg;
    final Color border;
    final Color iconColor;
    final Color textColor;
    final IconData icon;

    if (isVeg) {
      bg = const Color(0xFFF0F9F2);
      border = const Color(0xFFD4E8D8);
      iconColor = const Color(0xFF2E7D32);
      textColor = const Color(0xFF2E7D32);
      icon = Icons.eco_rounded;
    } else if (isNonVeg) {
      bg = const Color(0xFFFAF7F4);
      border = const Color(0xFFE8E2DC);
      iconColor = const Color(0xFF8D6E63);
      textColor = const Color(0xFF7A6F66);
      icon = Icons.restaurant_rounded;
    } else {
      bg = const Color(0xFFF5F5F5);
      border = HomeMarketplaceTheme.border;
      iconColor = HomeMarketplaceTheme.textSecondary;
      textColor = HomeMarketplaceTheme.textSecondary;
      icon = Icons.home_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
