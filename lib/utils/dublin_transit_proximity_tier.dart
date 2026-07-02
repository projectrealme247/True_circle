import '../services/transit_extraction_service.dart';
import 'listing_data.dart';
import 'numeric_bounds.dart';

class DublinTransitProximityTier {
  const DublinTransitProximityTier({required this.tier, required this.shortLabel, required this.tooltip});
  final int tier;
  final String shortLabel;
  final String tooltip;
  static const tier1Tooltip = 'Within a 10-minute walk of Luas or DART — strong daily commute option without a car.';
  static const tier2Tooltip = 'On a high-frequency Dublin Bus corridor — reliable connections across the city.';
  static const tier3Tooltip = 'Close to public transport, but expect a longer walk to the stop.';
  static DublinTransitProximityTier? fromListing(Map<String, dynamic> listing) {
    int? walkMinutesRaw;
    var transitType = '';

    final coords = ListingData.listingCoordinates(listing);
    if (coords != null) {
      final extracted = TransitExtractionService.extractLocally(
        latitude: coords.latitude,
        longitude: coords.longitude,
      );
      if (extracted != null) {
        final walk = extracted['walk_minutes'];
        if (walk is num) walkMinutesRaw = walk.round();
        transitType = extracted['transit_type']?.toString().toLowerCase() ?? '';
      }
    } else {
      walkMinutesRaw = ListingData.transitWalkMinutes(listing);
      transitType = ListingData.transitTypeLabel(listing).toLowerCase();
    }

    if (walkMinutesRaw == null || transitType.isEmpty) return null;
    final walkMinutes = NumericBounds.clampWalkMinutes(walkMinutesRaw);
    final isRapidTransit = transitType.contains('luas') || transitType.contains('dart');
    final isBusHf = transitType.contains('dublin bus');
    if (walkMinutes <= 10 && isRapidTransit) {
      return const DublinTransitProximityTier(tier: 1, shortLabel: 'Luas/DART ≤10 min', tooltip: tier1Tooltip);
    }
    if (walkMinutes <= 12 && isBusHf) {
      return const DublinTransitProximityTier(tier: 2, shortLabel: 'Dublin Bus ≤12 min', tooltip: tier2Tooltip);
    }
    if (walkMinutes <= 15) {
      return const DublinTransitProximityTier(tier: 3, shortLabel: 'Transit-adjacent', tooltip: tier3Tooltip);
    }
    return null;
  }
}
