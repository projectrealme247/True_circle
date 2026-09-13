import 'overpass_config.dart';

/// Shared Overpass QL for batched amenity lookup (web Phase 2 + POI seeding).
///
/// Keep in sync with [lib/services/overpass_amenities_web.dart] live parser radii.
String buildFullOverpassQuery(String latStr, String lonStr) => '''
${OverpassConfig.queryHeader(OverpassQueryType.full)};
(
  node["shop"~"supermarket|convenience"](around:1200,$latStr,$lonStr);
  way["shop"~"supermarket|convenience"](around:1200,$latStr,$lonStr);
  node["amenity"="school"](around:1800,$latStr,$lonStr);
  way["amenity"="school"](around:1800,$latStr,$lonStr);
  node["amenity"~"childcare|kindergarten"](around:1800,$latStr,$lonStr);
  way["amenity"~"childcare|kindergarten"](around:1800,$latStr,$lonStr);
  node["amenity"~"hospital|clinic"](around:3000,$latStr,$lonStr);
  way["amenity"~"hospital|clinic"](around:3000,$latStr,$lonStr);
  node["railway"~"tram_stop|station|halt"](around:2800,$latStr,$lonStr);
  node["highway"="bus_stop"](around:2200,$latStr,$lonStr);
  node["addr:postcode"](around:350,$latStr,$lonStr);
  way["addr:postcode"](around:350,$latStr,$lonStr);
  node["amenity"~"pub|bar|biergarten"](around:1200,$latStr,$lonStr);
  node["amenity"="atm"](around:1000,$latStr,$lonStr);
  node["amenity"="bank"](around:1000,$latStr,$lonStr);
  node["shop"~"pizza"](around:1500,$latStr,$lonStr);
  node["amenity"~"fast_food"](around:1500,$latStr,$lonStr);
  node["shop"~"supermarket"](around:1500,$latStr,$lonStr);
  node["shop"~"asian|asian_supermarket|oriental"](around:2200,$latStr,$lonStr);
  node["leisure"~"fitness_centre|sports_centre"](around:1500,$latStr,$lonStr);
  way["leisure"~"fitness_centre|sports_centre"](around:1500,$latStr,$lonStr);
  node["leisure"="park"](around:1200,$latStr,$lonStr);
  way["leisure"="park"](around:1200,$latStr,$lonStr);
  node["amenity"="pharmacy"](around:1000,$latStr,$lonStr);
  node["amenity"="cafe"](around:800,$latStr,$lonStr);
  node["amenity"~"restaurant"](around:1000,$latStr,$lonStr);
  node["landuse"~"commercial|industrial"](around:2000,$latStr,$lonStr);
  way["landuse"~"commercial|industrial"](around:2000,$latStr,$lonStr);
  node["office"](around:1500,$latStr,$lonStr);
  way["office"](around:1500,$latStr,$lonStr);
  node["tourism"~"attraction|museum|gallery"](around:2000,$latStr,$lonStr);
  way["tourism"~"attraction|museum|gallery"](around:2000,$latStr,$lonStr);
);
out center;
''';

/// Reduced query when the full batch is slow, empty, or lifestyle-thin.
///
/// Lifestyle selectors are copied verbatim from [buildFullOverpassQuery] so the
/// existing parser classifies them without new category logic.
String buildEssentialsOverpassQuery(String latStr, String lonStr) => '''
${OverpassConfig.queryHeader(OverpassQueryType.essentials)};
(
  node["shop"~"supermarket|convenience"](around:1500,$latStr,$lonStr);
  node["amenity"="school"](around:2000,$latStr,$lonStr);
  node["amenity"~"childcare|kindergarten"](around:2000,$latStr,$lonStr);
  node["amenity"~"hospital|clinic"](around:3500,$latStr,$lonStr);
  node["railway"~"tram_stop|station|halt"](around:3000,$latStr,$lonStr);
  node["highway"="bus_stop"](around:2500,$latStr,$lonStr);
  node["shop"~"asian|asian_supermarket|oriental"](around:2500,$latStr,$lonStr);
  node["amenity"~"pub|bar|biergarten"](around:1200,$latStr,$lonStr);
  node["amenity"="atm"](around:1000,$latStr,$lonStr);
  node["amenity"="bank"](around:1000,$latStr,$lonStr);
  node["shop"~"pizza"](around:1500,$latStr,$lonStr);
  node["amenity"~"fast_food"](around:1500,$latStr,$lonStr);
  node["leisure"~"fitness_centre|sports_centre"](around:1500,$latStr,$lonStr);
  way["leisure"~"fitness_centre|sports_centre"](around:1500,$latStr,$lonStr);
  node["leisure"="park"](around:1200,$latStr,$lonStr);
  way["leisure"="park"](around:1200,$latStr,$lonStr);
  node["amenity"="pharmacy"](around:1000,$latStr,$lonStr);
  node["amenity"="cafe"](around:800,$latStr,$lonStr);
  node["amenity"~"restaurant"](around:1000,$latStr,$lonStr);
);
out center;
''';
