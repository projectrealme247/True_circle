import '../config/market/dublin_macro_areas.dart';
import 'city_area_match.dart';
import 'listing_area_resolution.dart';
import 'listing_data.dart';
import 'profile_data.dart';

/// Per-district inventory rollup for recommendation ranking (soft signals only).
///
/// Built from the loaded listing pool in a single pass — not a DB view and not
/// a hard filter on browse.
class DistrictInventoryStats {
  const DistrictInventoryStats({
    required this.districtKey,
    required this.listingCount,
    required this.medianRent,
    required this.averageRent,
    required this.bedroomHistogram,
    required this.unknownBedroomCount,
    required this.sharedLivingCount,
    required this.independentPlaceCount,
    this.parsedRents = const [],
  });

  final String districtKey;

  /// Listings resolved to this district key.
  final int listingCount;

  /// Median of parsed listing rents; null when no rents parsed.
  final double? medianRent;

  /// Mean of parsed listing rents; null when no rents parsed.
  final double? averageRent;

  /// Bed-count → listing count. Studio maps to `0`.
  final Map<int, int> bedroomHistogram;

  /// Listings with no parseable bedroom count.
  final int unknownBedroomCount;

  /// Share / shared-living tower listings.
  final int sharedLivingCount;

  /// Rent / independent-place tower listings.
  final int independentPlaceCount;

  /// Parsed monthly rents used for affordability queries (recommendation soft signals).
  final List<int> parsedRents;

  /// Share of inventory that is shared living (0–1).
  double get sharedLivingShare =>
      listingCount == 0 ? 0 : sharedLivingCount / listingCount;

  /// Share of inventory that is independent place (0–1).
  double get independentPlaceShare =>
      listingCount == 0 ? 0 : independentPlaceCount / listingCount;

  /// Fraction of parsed rents at or below [budget] (0–1). Null when no rents.
  double? shareAtOrBelowBudget(int budget) {
    if (parsedRents.isEmpty || budget <= 0) return null;
    final hits = parsedRents.where((rent) => rent <= budget).length;
    return hits / parsedRents.length;
  }

  /// Listings with [minBeds] or more bedrooms (excludes unknown).
  int listingsWithAtLeastBeds(int minBeds) {
    var total = 0;
    for (final entry in bedroomHistogram.entries) {
      if (entry.key >= minBeds) total += entry.value;
    }
    return total;
  }
}

/// In-memory snapshot of [DistrictInventoryStats] for all resolved districts.
class DistrictInventorySnapshot {
  const DistrictInventorySnapshot({
    required this.byDistrict,
    required this.totalListingsScanned,
    required this.unresolvedListingCount,
    required this.builtAt,
  });

  /// District key → stats (only districts that had ≥1 listing).
  final Map<String, DistrictInventoryStats> byDistrict;

  final int totalListingsScanned;

  /// Listings that could not be mapped to a district key.
  final int unresolvedListingCount;

  final DateTime builtAt;

  DistrictInventoryStats? operator [](String districtKey) =>
      byDistrict[districtKey];

  Iterable<String> get districtKeys => byDistrict.keys;

  bool get isEmpty => byDistrict.isEmpty;

  /// Single-pass groupBy over [listings]. Call again when the pool refreshes.
  static DistrictInventorySnapshot build(
    Iterable<Map<String, dynamic>> listings, {
    DateTime? builtAt,
  }) {
    final buckets = <String, _MutableDistrictBucket>{};
    var scanned = 0;
    var unresolved = 0;

    for (final listing in listings) {
      scanned++;
      final key = resolveDistrictKeyForListing(listing);
      if (key == null) {
        unresolved++;
        continue;
      }
      final bucket = buckets.putIfAbsent(key, _MutableDistrictBucket.new);
      bucket.add(listing);
    }

    final byDistrict = <String, DistrictInventoryStats>{
      for (final entry in buckets.entries)
        entry.key: entry.value.toStats(entry.key),
    };

    return DistrictInventorySnapshot(
      byDistrict: Map.unmodifiable(byDistrict),
      totalListingsScanned: scanned,
      unresolvedListingCount: unresolved,
      builtAt: builtAt ?? DateTime.now(),
    );
  }
}

/// Resolves a listing to a canonical Dublin district key using existing logic.
///
/// Preference order:
/// 1. Explicit `listing_area_key` when it is a known district
/// 2. [resolveListingAreaKey] (eircode → coords → area label)
/// 3. [CityAreaMatch.listingAreaKeyFromBlob] on location + host city
String? resolveDistrictKeyForListing(Map<String, dynamic> listing) {
  final explicit = ProfileData.text(listing['listing_area_key']).trim();
  if (explicit.isNotEmpty && DublinMacroAreas.isDistrictKey(explicit)) {
    return explicit.toLowerCase();
  }

  final coords = ListingData.listingCoordinates(listing);
  final fromResolve = resolveListingAreaKey(
    eircode: ProfileData.text(listing['eircode']),
    lat: coords?.latitude,
    lon: coords?.longitude,
    areaLabel: _areaLabelBlob(listing),
  );
  if (fromResolve != null && DublinMacroAreas.isDistrictKey(fromResolve)) {
    return fromResolve.toLowerCase();
  }

  final fromBlob = CityAreaMatch.listingAreaKeyFromBlob(_areaLabelBlob(listing));
  if (fromBlob != null && DublinMacroAreas.isDistrictKey(fromBlob)) {
    return fromBlob.toLowerCase();
  }

  return null;
}

String _areaLabelBlob(Map<String, dynamic> listing) {
  final parts = <String>[
    ListingData.location(listing),
    ListingData.hostCity(listing),
  ];
  return parts.where((part) => part.trim().isNotEmpty).join(', ');
}

class _MutableDistrictBucket {
  final List<int> _rents = [];
  final Map<int, int> _beds = {};
  var unknownBeds = 0;
  var shared = 0;
  var independent = 0;
  var listingCount = 0;

  void add(Map<String, dynamic> listing) {
    listingCount++;

    final rent = ListingData.listingPriceAmount(listing);
    if (rent != null && rent > 0) {
      _rents.add(rent);
    }

    final beds = _bedBucket(listing);
    if (beds == null) {
      unknownBeds++;
    } else {
      _beds[beds] = (_beds[beds] ?? 0) + 1;
    }

    if (ListingData.isRoomShare(listing)) {
      shared++;
    } else if (ListingData.isIndependentRental(listing)) {
      independent++;
    }
  }

  DistrictInventoryStats toStats(String districtKey) {
    return DistrictInventoryStats(
      districtKey: districtKey,
      listingCount: listingCount,
      medianRent: _median(_rents),
      averageRent: _average(_rents),
      bedroomHistogram: Map.unmodifiable(Map<int, int>.from(_beds)),
      unknownBedroomCount: unknownBeds,
      sharedLivingCount: shared,
      independentPlaceCount: independent,
      parsedRents: List.unmodifiable(List<int>.from(_rents)),
    );
  }
}

int? _bedBucket(Map<String, dynamic> listing) {
  final beds = ListingData.bedCount(listing);
  if (beds != null) return beds;
  final raw = ListingData.bedrooms(listing).toLowerCase();
  if (raw.contains('studio')) return 0;
  return null;
}

double? _median(List<int> values) {
  if (values.isEmpty) return null;
  final sorted = List<int>.from(values)..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid].toDouble();
  return (sorted[mid - 1] + sorted[mid]) / 2.0;
}

double? _average(List<int> values) {
  if (values.isEmpty) return null;
  final sum = values.fold<int>(0, (a, b) => a + b);
  return sum / values.length;
}
