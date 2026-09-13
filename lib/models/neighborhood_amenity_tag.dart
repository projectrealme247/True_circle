/// Lifestyle amenity surfaced near a listing address (within ~1.5 km).
enum NeighborhoodAmenityCategory {
  asianStores,
  pubs,
  pizzaShops,
  atms,
  foodJoints,
  gym,
  park,
  pharmacy,
  cafe,
  restaurant,
  businessPark,
  attraction,
}

class NeighborhoodAmenityTag {
  const NeighborhoodAmenityTag({
    required this.category,
    required this.name,
    required this.distanceKm,
    required this.emoji,
  });

  final NeighborhoodAmenityCategory category;
  final String name;
  final double distanceKm;
  final String emoji;

  String get displayLabel {
    final distance = distanceKm < 1
        ? '${(distanceKm * 1000).round()}m'
        : '${distanceKm.toStringAsFixed(1)} km';
    return '$emoji $name ($distance)';
  }

  Map<String, dynamic> toJson() => {
        'category': category.name,
        'name': name,
        'distance_km': distanceKm,
        'emoji': emoji,
      };

  static NeighborhoodAmenityTag? fromJson(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final name = raw['name']?.toString().trim() ?? '';
    if (name.isEmpty) return null;
    final categoryName = raw['category']?.toString() ?? '';
    final category = NeighborhoodAmenityCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => NeighborhoodAmenityCategory.attraction,
    );
    final distance = (raw['distance_km'] as num?)?.toDouble() ?? 0;
    final emoji = raw['emoji']?.toString().trim() ?? '📍';
    return NeighborhoodAmenityTag(
      category: category,
      name: name,
      distanceKm: distance,
      emoji: emoji.isEmpty ? '📍' : emoji,
    );
  }
}
