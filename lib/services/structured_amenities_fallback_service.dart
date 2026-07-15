import '../models/neighborhood_amenity_tag.dart';
import '../data/poi_catalog_kind.dart';
import '../data/poi_catalog_repository.dart';
import '../utils/geo_math.dart';
import '../utils/transit_ranking.dart';
import 'overpass_amenities_service.dart';

/// Curated Dublin suburban POIs used when Overpass OSM is slow or incomplete.
/// Fills structured proximity fields (grocery, schools, hospital, extra transit).
abstract final class StructuredAmenitiesFallbackService {
  static const _radiusKm = 2.5;

  static NearbyAmenities? resolve({
    required double latitude,
    required double longitude,
  }) {
    final origin = LatLng(latitude, longitude);
    final lifestyle = <NeighborhoodAmenityTag>[];
    final extras = <NearbyExtraTransit>[];

    final grocery = _nearest(origin, _groceries);
    final primary = _nearest(origin, _primarySchools);
    final secondary = _nearest(origin, _secondarySchools);
    final creche = _nearest(origin, _creches);
    final hospital = _nearest(origin, _hospitals);
    final asian = _nearest(origin, _asianStores);
    final bus = _nearest(origin, _busStops);
    final dart = _nearest(origin, _dartStops);
    final luas = _nearest(origin, _luasStops);

    if (asian != null) {
      lifestyle.add(
        NeighborhoodAmenityTag(
          category: NeighborhoodAmenityCategory.asianStores,
          name: asian.name,
          distanceKm: asian.km,
          emoji: '🛍️',
        ),
      );
    }

    String? transitLine;
    int? transitWalkMin;
    final transitCandidates = <({String line, int walk, double km})>[];
    if (luas != null) {
      transitCandidates.add((
        line: 'Luas Red Line · ${luas.name}',
        walk: _walkMin(luas.km),
        km: luas.km,
      ));
    }
    if (dart != null) {
      transitCandidates.add((
        line: 'DART · ${dart.name}',
        walk: _walkMin(dart.km),
        km: dart.km,
      ));
    }
    if (bus != null) {
      transitCandidates.add((
        line: 'Dublin Bus · ${bus.name}',
        walk: _walkMin(bus.km),
        km: bus.km,
      ));
    }
    transitCandidates.sort((a, b) => TransitRanking.compare(
          walkMinA: a.walk,
          walkMinB: b.walk,
          distanceMetersA: a.km * 1000,
          distanceMetersB: b.km * 1000,
          lineA: a.line,
          lineB: b.line,
        ));
    if (transitCandidates.isNotEmpty) {
      transitLine = transitCandidates.first.line;
      transitWalkMin = transitCandidates.first.walk;
      for (final candidate in transitCandidates.skip(1).take(2)) {
        extras.add(
          NearbyExtraTransit(line: candidate.line, walkMin: candidate.walk),
        );
      }
    }

    if (hospital != null) {
      extras.add(
        NearbyExtraTransit(
          line: 'Hospital · ${hospital.name}',
          walkMin: _walkMin(hospital.km),
        ),
      );
    }

    final result = NearbyAmenities(
      transitLine: transitLine,
      transitWalkMin: transitWalkMin,
      supermarketName: grocery?.name,
      supermarketWalkMin: grocery != null ? _walkMin(grocery.km) : null,
      primarySchool: primary?.name,
      primarySchoolWalkMin: primary != null ? _walkMin(primary.km) : null,
      secondarySchool: secondary?.name,
      secondarySchoolWalkMin:
          secondary != null ? _walkMin(secondary.km) : null,
      crecheName: creche?.name,
      crecheWalkMin: creche != null ? _walkMin(creche.km) : null,
      lifestyleTags: lifestyle,
      extraTransit: extras,
    );
    return result.isEmpty ? null : result;
  }

  static ({String name, double km})? _nearest(
    LatLng origin,
    List<_Poi> catalog,
  ) {
    ({String name, double km})? best;
    for (final poi in catalog) {
      final km = GeoMath.haversineKm(origin, LatLng(poi.lat, poi.lon));
      if (km > _radiusKm) continue;
      if (best == null || km < best.km) {
        best = (name: poi.name, km: km);
      }
    }
    return best;
  }

  static int _walkMin(double km) => GeoMath.walkingMinutes(km);

  static List<_Poi> _seededOrLegacy(PoiCatalogKind kind, List<_Poi> legacy) {
    if (!PoiCatalogRepository.hasSeededDublinCatalog) return legacy;
    final seeded = PoiCatalogRepository.structuredEntries(kind);
    if (seeded.isEmpty) return legacy;
    return [
      for (final entry in seeded)
        _Poi(entry.name, entry.lat, entry.lon),
    ];
  }

  static List<_Poi> get _groceries => _seededOrLegacy(
        PoiCatalogKind.grocery,
        _legacyGroceries,
      );

  static List<_Poi> get _primarySchools => _seededOrLegacy(
        PoiCatalogKind.primarySchool,
        _legacyPrimarySchools,
      );

  static List<_Poi> get _secondarySchools => _seededOrLegacy(
        PoiCatalogKind.secondarySchool,
        _legacySecondarySchools,
      );

  static List<_Poi> get _creches => _seededOrLegacy(
        PoiCatalogKind.creche,
        _legacyCreches,
      );

  static List<_Poi> get _asianStores => _seededOrLegacy(
        PoiCatalogKind.asianStore,
        _legacyAsianStores,
      );

  static const _legacyGroceries = <_Poi>[
    // Dublin 15 / Hollystown / Hollywoodrath
    _Poi('Tesco Extra Blanchardstown', 53.3915, -6.3938),
    _Poi('Dunnes Stores Blanchardstown', 53.3926, -6.3908),
    _Poi('Lidl Blanchardstown', 53.3902, -6.3955),
    _Poi('SuperValu Castleknock', 53.3688, -6.3642),
    // Dublin 24 / Tallaght
    _Poi('Tesco Extra Tallaght', 53.2885, -6.3575),
    _Poi('Dunnes Stores The Square', 53.2862, -6.3728),
    _Poi('Lidl Belgard', 53.2988, -6.3875),
    _Poi('SuperValu Tallaght', 53.2845, -6.3695),
    _Poi('Aldi Tallaght', 53.2878, -6.3810),
    // Dublin 22 / Newcastle / Clondalkin
    _Poi('Lidl Clondalkin', 53.3220, -6.3975),
    _Poi('Tesco Liffey Valley', 53.3495, -6.3920),
    _Poi('Dunnes Stores Liffey Valley', 53.3488, -6.3905),
  ];

  static const _legacyPrimarySchools = <_Poi>[
    _Poi("St Lorcan's BNS", 53.3925, -6.4055),
    _Poi('Sacred Heart NS Hollystown', 53.3948, -6.4012),
    _Poi('St Thomas\'s NS Jobstown', 53.2835, -6.3925),
    _Poi('St Mark\'s SNS Tallaght', 53.2868, -6.3845),
    _Poi('St Martin de Porres NS', 53.2915, -6.3685),
    _Poi('Scoil Mhuire Clondalkin', 53.3210, -6.3955),
  ];

  static const _legacySecondarySchools = <_Poi>[
    _Poi('Tallaght Community School', 53.2825, -6.3785),
    _Poi('Old Bawn Community School', 53.2795, -6.3685),
    _Poi('Coláiste Bríde Clondalkin', 53.3195, -6.3940),
    _Poi('Hartstown Community School', 53.3965, -6.4185),
  ];

  static const _legacyCreches = <_Poi>[
    _Poi('Giraffe Childcare Blanchardstown', 53.3910, -6.3920),
    _Poi('Bright Horizons Tallaght', 53.2870, -6.3755),
    _Poi('Little Learners Tallaght', 53.2855, -6.3810),
  ];

  static const _hospitals = <_Poi>[
    _Poi('Tallaght University Hospital', 53.2895, -6.3745),
    _Poi('Connolly Hospital Blanchardstown', 53.3885, -6.4025),
  ];

  static const _legacyAsianStores = <_Poi>[
    _Poi('Asia Market Blanchardstown', 53.3918, -6.3924),
    _Poi('Sunflower Asian Market Finglas', 53.3912, -6.2955),
    _Poi('Oriental Pantry Ballyfermot', 53.3485, -6.3555),
  ];

  static const _busStops = <_Poi>[
    _Poi('The Square Bus Stop', 53.2860, -6.3735),
    _Poi('Old Bawn Road Bus Stop', 53.2845, -6.3780),
    _Poi('Newcastle Road Bus Stop', 53.3010, -6.5120),
    _Poi('Clondalkin Village Bus Stop', 53.3215, -6.3965),
    _Poi('Blanchardstown Centre Bus Stop', 53.3920, -6.3915),
  ];

  static const _dartStops = <_Poi>[
    _Poi('Dun Laoghaire', 53.2944, -6.1330),
    _Poi('Blackrock', 53.3015, -6.1785),
    _Poi('Grand Canal Dock', 53.3386, -6.2386),
    _Poi('Pearse', 53.3433, -6.2483),
    _Poi('Tara Street', 53.3471, -6.2561),
  ];

  static const _luasStops = <_Poi>[
    _Poi('The Square', 53.2857, -6.3732),
    _Poi('Cookstown', 53.2910, -6.3830),
    _Poi('Tallaght Hospital', 53.2895, -6.3745),
    _Poi('Cheeverstown', 53.2875, -6.4080),
    _Poi('Red Cow', 53.2960, -6.3705),
    _Poi('Beechwood', 53.3015, -6.2520),
    _Poi('Dundrum', 53.2890, -6.2430),
  ];
}

class _Poi {
  const _Poi(this.name, this.lat, this.lon);

  final String name;
  final double lat;
  final double lon;
}
