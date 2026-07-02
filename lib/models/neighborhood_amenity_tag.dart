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
}
