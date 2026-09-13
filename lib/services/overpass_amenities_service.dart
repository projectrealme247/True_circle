import '../models/neighborhood_amenity_tag.dart';
import 'proximity_resolution_cache.dart';
import 'structured_amenities_fallback_service.dart';
import 'overpass_amenities_stub.dart'
    if (dart.library.js_interop) 'overpass_amenities_web.dart' as impl;

/// Extra transit / hospital lines shown as supplementary proximity chips.
class NearbyExtraTransit {
  const NearbyExtraTransit({required this.line, required this.walkMin});

  final String line;
  final int walkMin;

  Map<String, dynamic> toJson() => {
        'line': line,
        'walk_min': walkMin,
      };

  static NearbyExtraTransit? fromJson(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final line = raw['line']?.toString().trim() ?? '';
    if (line.isEmpty) return null;
    return NearbyExtraTransit(
      line: line,
      walkMin: (raw['walk_min'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A grocery option within walking distance of a listing pin.
class NearbyGroceryOption {
  const NearbyGroceryOption({required this.brand, required this.walkMin});

  final String brand;
  final int walkMin;

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'walk_min': walkMin,
      };

  static NearbyGroceryOption? fromJson(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final brand = raw['brand']?.toString().trim() ?? '';
    if (brand.isEmpty) return null;
    return NearbyGroceryOption(
      brand: brand,
      walkMin: (raw['walk_min'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Snapshot of nearby amenities resolved from OpenStreetMap Overpass API.
class NearbyAmenities {
  const NearbyAmenities({
    this.eircode,
    this.transitLine,
    this.transitWalkMin,
    this.supermarketName,
    this.supermarketWalkMin,
    this.primarySchool,
    this.primarySchoolWalkMin,
    this.secondarySchool,
    this.secondarySchoolWalkMin,
    this.crecheName,
    this.crecheWalkMin,
    this.lifestyleTags = const [],
    this.extraTransit = const [],
    this.groceries = const [],
    this.collegeSchool,
    this.collegeWalkMin,
    this.gpClinic,
    this.gpWalkMin,
  });

  final String? eircode;
  final String? transitLine;
  final int? transitWalkMin;
  final String? supermarketName;
  final int? supermarketWalkMin;
  final String? primarySchool;
  final int? primarySchoolWalkMin;
  final String? secondarySchool;
  final int? secondarySchoolWalkMin;
  final String? crecheName;
  final int? crecheWalkMin;

  /// Lifestyle POI tags resolved from Overpass (pubs, ATMs, pizza, etc.).
  final List<NeighborhoodAmenityTag> lifestyleTags;

  /// Bus / DART / hospital lines beyond the primary transit chip.
  final List<NearbyExtraTransit> extraTransit;

  /// Up to three nearest grocery options, closest first.
  final List<NearbyGroceryOption> groceries;

  final String? collegeSchool;
  final int? collegeWalkMin;
  final String? gpClinic;
  final int? gpWalkMin;

  bool get isEmpty =>
      eircode == null &&
      transitLine == null &&
      supermarketName == null &&
      primarySchool == null &&
      secondarySchool == null &&
      crecheName == null &&
      lifestyleTags.isEmpty &&
      extraTransit.isEmpty &&
      groceries.isEmpty &&
      collegeSchool == null &&
      gpClinic == null;

  /// True when Overpass enrichment includes schools and/or lifestyle POIs.
  /// Thin transport+grocery-only snapshots are not enrichment-complete.
  bool get hasEnrichmentCoverage =>
      lifestyleTags.isNotEmpty ||
      primarySchool != null ||
      secondarySchool != null;

  /// Combines two snapshots, preferring [primary] and filling gaps from [secondary].
  static NearbyAmenities? merge(NearbyAmenities? primary, NearbyAmenities? secondary) {
    if (primary == null) return secondary;
    if (secondary == null) return primary;
    return NearbyAmenities(
      eircode: primary.eircode ?? secondary.eircode,
      transitLine: primary.transitLine ?? secondary.transitLine,
      transitWalkMin: primary.transitWalkMin ?? secondary.transitWalkMin,
      supermarketName: primary.supermarketName ?? secondary.supermarketName,
      supermarketWalkMin:
          primary.supermarketWalkMin ?? secondary.supermarketWalkMin,
      primarySchool: primary.primarySchool ?? secondary.primarySchool,
      primarySchoolWalkMin:
          primary.primarySchoolWalkMin ?? secondary.primarySchoolWalkMin,
      secondarySchool: primary.secondarySchool ?? secondary.secondarySchool,
      secondarySchoolWalkMin:
          primary.secondarySchoolWalkMin ?? secondary.secondarySchoolWalkMin,
      crecheName: primary.crecheName ?? secondary.crecheName,
      crecheWalkMin: primary.crecheWalkMin ?? secondary.crecheWalkMin,
      lifestyleTags: primary.lifestyleTags.isNotEmpty
          ? primary.lifestyleTags
          : secondary.lifestyleTags,
      extraTransit: [
        ...primary.extraTransit,
        ...secondary.extraTransit,
      ],
      groceries: _mergeGroceries(primary.groceries, secondary.groceries),
      collegeSchool: primary.collegeSchool ?? secondary.collegeSchool,
      collegeWalkMin: primary.collegeWalkMin ?? secondary.collegeWalkMin,
      gpClinic: primary.gpClinic ?? secondary.gpClinic,
      gpWalkMin: primary.gpWalkMin ?? secondary.gpWalkMin,
    );
  }

  static List<NearbyGroceryOption> _mergeGroceries(
    List<NearbyGroceryOption> primary,
    List<NearbyGroceryOption> secondary,
  ) {
    final byBrand = <String, NearbyGroceryOption>{};
    for (final item in [...primary, ...secondary]) {
      final key = item.brand.trim().toLowerCase();
      if (key.isEmpty) continue;
      final existing = byBrand[key];
      if (existing == null || item.walkMin < existing.walkMin) {
        byBrand[key] = item;
      }
    }
    final merged = byBrand.values.toList()
      ..sort((a, b) => a.walkMin.compareTo(b.walkMin));
    return merged.take(3).toList();
  }
}

/// Queries OpenStreetMap Overpass API for amenities within walking distance.
/// Falls back to structured local POIs when Overpass is slow or unavailable.
///
/// Phase 2 enrichment: once the OSM-seeded local catalog is confirmed
/// comprehensive, this layer may become optional — keep for now as a secondary
/// check that can surface live OSM POIs not yet in the seeded dataset.
abstract final class OverpassAmenitiesService {
  static Future<NearbyAmenities?> fetchNearby({
    required double latitude,
    required double longitude,
  }) async {
    final cellKey = ProximityResolutionCache.keyFor(latitude, longitude);
    final cached = ProximityResolutionCache.getAmenities(cellKey);
    // Skip thin cached snapshots (transport/grocery only) so lifestyle can refill.
    if (cached != null && cached.hasEnrichmentCoverage) return cached;

    NearbyAmenities? merged;
    final fromOverpass = await impl.fetchNearbyAmenities(latitude, longitude);
    merged = NearbyAmenities.merge(merged, fromOverpass);

    if (merged == null || merged.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final retry = await impl.fetchNearbyAmenities(latitude, longitude);
      merged = NearbyAmenities.merge(merged, retry);
    }

    final fallback = StructuredAmenitiesFallbackService.resolve(
      latitude: latitude,
      longitude: longitude,
    );
    merged = NearbyAmenities.merge(merged, fallback);
    if (merged != null && merged.hasEnrichmentCoverage) {
      ProximityResolutionCache.putAmenities(cellKey, merged);
    }
    return merged?.isEmpty == false ? merged : null;
  }
}
