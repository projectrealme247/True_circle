import 'package:flutter/material.dart';

import '../theme/home_marketplace_theme.dart';
import '../utils/listing_data.dart';

/// Food preference chip with leading icon for listing cards.
class ListingFoodBadge extends StatelessWidget {
  const ListingFoodBadge({super.key, required this.listing, this.compact = true});

  final Map<String, dynamic> listing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = ListingData.foodPreferenceLabel(listing);
    if (label.isEmpty) {
      return _FoodChip(
        label: 'Food not set',
        icon: Icons.restaurant_rounded,
        compact: compact,
        bg: const Color(0xFFF7F7F7),
        border: HomeMarketplaceTheme.border,
        iconColor: HomeMarketplaceTheme.textMuted,
        textColor: HomeMarketplaceTheme.textMuted,
      );
    }

    final isVeg = label == 'Veg';

    return _FoodChip(
      label: label,
      icon: isVeg ? Icons.eco_rounded : Icons.restaurant_rounded,
      compact: compact,
      bg: isVeg ? const Color(0xFFF0F9F2) : const Color(0xFFFAF7F4),
      border: isVeg ? const Color(0xFFD4E8D8) : const Color(0xFFE8E2DC),
      iconColor: isVeg ? const Color(0xFF2E7D32) : const Color(0xFF8D6E63),
      textColor: isVeg ? const Color(0xFF2E7D32) : const Color(0xFF7A6F66),
    );
  }
}

class _FoodChip extends StatelessWidget {
  const _FoodChip({
    required this.label,
    required this.icon,
    required this.compact,
    required this.bg,
    required this.border,
    required this.iconColor,
    required this.textColor,
  });

  final String label;
  final IconData icon;
  final bool compact;
  final Color bg;
  final Color border;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
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
