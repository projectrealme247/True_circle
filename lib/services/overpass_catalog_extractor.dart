import '../data/poi_catalog_kind.dart';

/// Extracts catalog POIs from a batched Overpass response (all matches, not nearest-only).
///
/// Transit stops are excluded — DublinTransitNetwork owns transit locally.
List<PoiCatalogEntry> extractPoiCatalogFromOverpassElements(List<dynamic> elements) {
  final results = <PoiCatalogEntry>[];
  final seen = <String>{};

  for (final el in elements) {
    if (el is! Map) continue;
    final tags = el['tags'];
    if (tags is! Map) continue;

    final lat = _elLat(el);
    final lon = _elLon(el);
    if (lat == null || lon == null) continue;

    final name = _bestName(tags);
    if (name.isEmpty) continue;

    final shop = tags['shop']?.toString() ?? '';
    final amenity = tags['amenity']?.toString() ?? '';
    final railway = tags['railway']?.toString() ?? '';
    final highway = tags['highway']?.toString() ?? '';
    final cuisine = tags['cuisine']?.toString().toLowerCase() ?? '';
    final leisure = tags['leisure']?.toString() ?? '';
    final tourism = tags['tourism']?.toString() ?? '';
    final landuse = tags['landuse']?.toString() ?? '';
    final office = tags['office']?.toString() ?? '';

    if (railway.isNotEmpty || highway == 'bus_stop') continue;
    if (tags.containsKey('addr:postcode')) continue;
    if (amenity == 'hospital' || amenity == 'clinic') continue;

    final kind = _kindForTags(
      shop: shop,
      amenity: amenity,
      cuisine: cuisine,
      leisure: leisure,
      tourism: tourism,
      landuse: landuse,
      office: office,
      name: name,
      tags: tags,
    );
    if (kind == null) continue;

    final key =
        '${kind.name}|${_normalize(name)}|${lat.toStringAsFixed(5)}|${lon.toStringAsFixed(5)}';
    if (!seen.add(key)) continue;

    results.add(
      PoiCatalogEntry(
        name: _displayName(kind, name, tags),
        lat: lat,
        lon: lon,
        kind: kind,
      ),
    );
  }

  return results;
}

PoiCatalogKind? _kindForTags({
  required String shop,
  required String amenity,
  required String cuisine,
  required String leisure,
  required String tourism,
  required String landuse,
  required String office,
  required String name,
  required Map tags,
}) {
  if (shop == 'asian' || shop == 'asian_supermarket' || shop == 'oriental') {
    return PoiCatalogKind.asianStore;
  }
  if (shop == 'supermarket' || shop == 'convenience') {
    return PoiCatalogKind.grocery;
  }
  if (shop == 'pizza' || (amenity == 'fast_food' && cuisine.contains('pizza'))) {
    return PoiCatalogKind.pizzaShop;
  }
  if (amenity == 'pub' || amenity == 'bar' || amenity == 'biergarten') {
    return PoiCatalogKind.pub;
  }
  if (amenity == 'cafe') return PoiCatalogKind.cafe;
  if (amenity == 'restaurant') return PoiCatalogKind.restaurant;
  if (amenity == 'fast_food') return PoiCatalogKind.foodJoint;
  if (amenity == 'pharmacy') return PoiCatalogKind.pharmacy;
  if (amenity == 'atm') return PoiCatalogKind.atm;
  if (amenity == 'bank') return PoiCatalogKind.atm;
  if (leisure == 'fitness_centre' || leisure == 'sports_centre') {
    return PoiCatalogKind.gym;
  }
  if (leisure == 'park') return PoiCatalogKind.park;
  if (tourism == 'attraction' || tourism == 'museum' || tourism == 'gallery') {
    return PoiCatalogKind.attraction;
  }
  if (landuse == 'commercial' || landuse == 'industrial' || office.isNotEmpty) {
    return PoiCatalogKind.businessPark;
  }
  if (amenity == 'school') {
    if (_isSecondarySchool(name, tags)) return PoiCatalogKind.secondarySchool;
    return PoiCatalogKind.primarySchool;
  }
  if (amenity == 'childcare' || amenity == 'kindergarten') {
    return PoiCatalogKind.creche;
  }
  return null;
}

String _displayName(PoiCatalogKind kind, String name, Map tags) {
  if (kind == PoiCatalogKind.grocery) return _normalisedGroceryBrand(name);
  if (kind == PoiCatalogKind.atm && tags['amenity']?.toString() == 'bank') {
    return '$name ATM';
  }
  return name;
}

double? _elLat(Map el) {
  final center = el['center'];
  if (center is Map && center['lat'] is num) {
    return (center['lat'] as num).toDouble();
  }
  if (el['lat'] is num) return (el['lat'] as num).toDouble();
  return null;
}

double? _elLon(Map el) {
  final center = el['center'];
  if (center is Map && center['lon'] is num) {
    return (center['lon'] as num).toDouble();
  }
  if (el['lon'] is num) return (el['lon'] as num).toDouble();
  return null;
}

String _bestName(Map tags) {
  final brand = tags['brand']?.toString().trim() ?? '';
  final operator = tags['operator']?.toString().trim() ?? '';
  final name = tags['name']?.toString().trim() ?? '';
  if (brand.isNotEmpty) return brand;
  if (name.isNotEmpty) return name;
  return operator;
}

String _normalisedGroceryBrand(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('tesco')) return 'Tesco';
  if (lower.contains('dunnes')) return 'Dunnes';
  if (lower.contains('supervalu') || lower.contains('super valu')) {
    return 'SuperValu';
  }
  if (lower.contains('lidl')) return 'Lidl';
  if (lower.contains('aldi')) return 'Aldi';
  if (lower.contains('spar')) return 'Spar';
  if (lower.contains('centra')) return 'Centra';
  return raw;
}

bool _isPrimarySchool(String name, Map tags) {
  final iscedLevel = tags['isced:level']?.toString() ?? '';
  final schoolType = tags['school:type']?.toString().toLowerCase() ?? '';
  final lower = name.toLowerCase();
  if (iscedLevel.contains('1')) return true;
  if (schoolType.contains('primary')) return true;
  if (lower.contains('national school') ||
      lower.contains(' n.s.') ||
      lower.contains(' ns ') ||
      lower.contains('primary')) {
    return true;
  }
  return false;
}

bool _isSecondarySchool(String name, Map tags) {
  final iscedLevel = tags['isced:level']?.toString() ?? '';
  final schoolType = tags['school:type']?.toString().toLowerCase() ?? '';
  final lower = name.toLowerCase();
  if (iscedLevel.contains('2') || iscedLevel.contains('3')) return true;
  if (schoolType.contains('secondary')) return true;
  if (lower.contains('secondary') ||
      lower.contains('community school') ||
      lower.contains('community college') ||
      lower.contains('vocational') ||
      lower.contains(' etss') ||
      lower.contains(' cbs ') ||
      lower.contains(' css ') ||
      lower.contains('college') && !lower.contains('national school')) {
    return true;
  }
  return false;
}

String _normalize(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
