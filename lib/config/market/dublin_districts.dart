/// Canonical Dublin postal districts for TrueCircle area pickers and search.
const List<String> dublinDistricts = [
  'Dublin 1 (City Centre North)',
  'Dublin 2 (City Centre South)',
  'Dublin 3 (Clontarf, Fairview)',
  'Dublin 4 (Ballsbridge, Donnybrook)',
  'Dublin 5 (Artane, Raheny)',
  'Dublin 6 (Rathmines, Ranelagh)',
  'Dublin 6W (Terenure)',
  'Dublin 7 (Phibsborough, Smithfield)',
  'Dublin 8 (The Liberties, Portobello)',
  'Dublin 9 (Drumcondra, Santry)',
  'Dublin 10 (Ballyfermot)',
  'Dublin 11 (Finglas, Ballymun)',
  'Dublin 12 (Crumlin, Walkinstown)',
  'Dublin 13 (Howth, Baldoyle)',
  'Dublin 14 (Dundrum, Rathfarnham)',
  'Dublin 15 (Blanchardstown, Castleknock)',
  'Dublin 16 (Ballinteer, Knocklyon)',
  'Dublin 17 (Coolock, Darndale)',
  'Dublin 18 (Sandyford, Leopardstown)',
  'Dublin 20 (Chapelizod, Palmerstown)',
  'Dublin 22 (Clondalkin, Liffey Valley)',
  'Dublin 24 (Tallaght, Firhouse)',
  'Co. Dublin (North - Malahide, Swords, Skerries)',
  'Co. Dublin (South - Dún Laoghaire, Dalkey)',
];

/// Stable storage key for a [dublinDistricts] label.
String dublinDistrictKey(String district) {
  final numbered = RegExp(r'^Dublin (\d+[W]?)').firstMatch(district);
  if (numbered != null) {
    return 'dublin${numbered.group(1)!.toLowerCase()}';
  }
  if (district.startsWith('Co. Dublin (North')) return 'co_dublin_north';
  if (district.startsWith('Co. Dublin (South')) return 'co_dublin_south';
  return district.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
}

/// `(key, label)` pairs for profile pickers and filter chips.
List<(String, String)> get dublinAreaOptions => [
      for (final district in dublinDistricts) (dublinDistrictKey(district), district),
    ];

/// Search + listing alias tokens keyed by [dublinDistrictKey].
Map<String, List<String>> get dublinCityAliases {
  final map = <String, List<String>>{};
  for (final district in dublinDistricts) {
    map[dublinDistrictKey(district)] = _aliasesForDistrict(district);
  }
  _mergeLegacyAliases(map);
  return map;
}

Map<String, String> get dublinCityDisplayNames => {
      for (final district in dublinDistricts)
        dublinDistrictKey(district): district,
    };

List<String> _aliasesForDistrict(String district) {
  final aliases = <String>{district.toLowerCase()};

  final numbered = RegExp(r'Dublin (\d+[W]?)').firstMatch(district);
  if (numbered != null) {
    final code = numbered.group(1)!.toLowerCase();
    aliases
      ..add('dublin $code')
      ..add('d$code')
      ..add('dublin$code');
  }

  final paren = RegExp(r'\(([^)]+)\)').firstMatch(district);
  if (paren != null) {
    for (final segment in paren.group(1)!.split(RegExp(r'[-,]'))) {
      final token = segment.trim().toLowerCase();
      if (token.isNotEmpty) aliases.add(token);
    }
  }

  if (district.startsWith('Co. Dublin (North')) {
    aliases.addAll(['co dublin north', 'north county dublin']);
  }
  if (district.startsWith('Co. Dublin (South')) {
    aliases.addAll(['co dublin south', 'south county dublin', 'dun laoghaire', 'dún laoghaire']);
  }

  return aliases.toList();
}

/// Keeps sample-listing and search tokens working after the district refresh.
void _mergeLegacyAliases(Map<String, List<String>> map) {
  void add(String key, List<String> extra) {
    map.putIfAbsent(key, () => <String>[]);
    map[key] = {...map[key]!, ...extra}.toList();
  }

  add('dublin2', ['docklands', 'grand canal dock', 'temple bar']);
  add('dublin4', ['sandymount', 'ringsend', 'glass bottle']);
  add('dublin6', ['harolds cross']);
  add('dublin7', ['phibsboro']);
  add('dublin8', ['liberties']);
  add('dublin12', ['rialto', "dolphin's barn"]);
  add('dublin14', ['kilmacud', 'windy arbour']);
  add('dublin15', ['blanchardstown', 'hollystown', 'hollywoodrath', 'hollywood rath', 'castaheany', 'hansfield', 'corduff', 'huntstown', 'diswellstown']);
  add('dublin16', ['two oaks']);
  add('dublin18', ['cherrywood', 'business park']);
  add('dublin22', ['lucan', 'liffey valley']);
  add('dublin24', ['citywest']);
  add('co_dublin_north', ['dundalk', 'dkit']);
}

/// Subset of aliases used when parsing free-text search queries.
Map<String, List<String>> get dublinParseCityAliases {
  final parsed = <String, List<String>>{};
  for (final entry in dublinCityAliases.entries) {
    parsed[entry.key] = entry.value.take(6).toList();
  }
  return parsed;
}

String? dublinDistrictLabelForKey(String key) => dublinCityDisplayNames[key];

/// Rough WGS-84 bounds for Dublin postal districts when reverse-geocoding fails.
String? dublinDistrictLabelFromCoordinates(double lat, double lon) {
  const boxes = <({double minLat, double maxLat, double minLon, double maxLon, String key})>[
    (minLat: 53.36, maxLat: 53.43, minLon: -6.49, maxLon: -6.34, key: 'dublin15'),
    (minLat: 53.33, maxLat: 53.37, minLon: -6.44, maxLon: -6.36, key: 'dublin22'),
    (minLat: 53.28, maxLat: 53.33, minLon: -6.40, maxLon: -6.28, key: 'dublin18'),
    (minLat: 53.27, maxLat: 53.33, minLon: -6.43, maxLon: -6.34, key: 'dublin24'),
    (minLat: 53.33, maxLat: 53.37, minLon: -6.30, maxLon: -6.22, key: 'dublin13'),
    (minLat: 53.36, maxLat: 53.40, minLon: -6.28, maxLon: -6.18, key: 'dublin5'),
  ];

  for (final box in boxes) {
    if (lat >= box.minLat &&
        lat <= box.maxLat &&
        lon >= box.minLon &&
        lon <= box.maxLon) {
      return dublinCityDisplayNames[box.key];
    }
  }
  return null;
}

/// Approximate centre for a Dublin district label — used when forward-geocoding fails.
({double lat, double lon})? dublinDistrictCentroidFromLabel(String label) {
  const boxes = <({double minLat, double maxLat, double minLon, double maxLon, String key})>[
    (minLat: 53.36, maxLat: 53.43, minLon: -6.49, maxLon: -6.34, key: 'dublin15'),
    (minLat: 53.33, maxLat: 53.37, minLon: -6.44, maxLon: -6.36, key: 'dublin22'),
    (minLat: 53.28, maxLat: 53.33, minLon: -6.40, maxLon: -6.28, key: 'dublin18'),
    (minLat: 53.27, maxLat: 53.33, minLon: -6.43, maxLon: -6.34, key: 'dublin24'),
    (minLat: 53.33, maxLat: 53.37, minLon: -6.30, maxLon: -6.22, key: 'dublin13'),
    (minLat: 53.36, maxLat: 53.40, minLon: -6.28, maxLon: -6.18, key: 'dublin5'),
    (minLat: 53.27, maxLat: 53.32, minLon: -6.28, maxLon: -6.18, key: 'dublin14'),
    (minLat: 53.34, maxLat: 53.38, minLon: -6.32, maxLon: -6.24, key: 'dublin9'),
    (minLat: 53.35, maxLat: 53.39, minLon: -6.36, maxLon: -6.28, key: 'dublin11'),
    (minLat: 53.32, maxLat: 53.36, minLon: -6.36, maxLon: -6.28, key: 'dublin12'),
    (minLat: 53.34, maxLat: 53.38, minLon: -6.28, maxLon: -6.20, key: 'dublin3'),
    (minLat: 53.33, maxLat: 53.37, minLon: -6.28, maxLon: -6.20, key: 'dublin4'),
    (minLat: 53.34, maxLat: 53.38, minLon: -6.32, maxLon: -6.24, key: 'dublin7'),
    (minLat: 53.33, maxLat: 53.37, minLon: -6.32, maxLon: -6.24, key: 'dublin8'),
    (minLat: 53.34, maxLat: 53.38, minLon: -6.30, maxLon: -6.22, key: 'dublin1'),
    (minLat: 53.33, maxLat: 53.37, minLon: -6.30, maxLon: -6.22, key: 'dublin2'),
    (minLat: 53.33, maxLat: 53.37, minLon: -6.34, maxLon: -6.26, key: 'dublin6'),
    (minLat: 53.32, maxLat: 53.36, minLon: -6.34, maxLon: -6.26, key: 'dublin6w'),
    (minLat: 53.33, maxLat: 53.37, minLon: -6.40, maxLon: -6.32, key: 'dublin10'),
    (minLat: 53.33, maxLat: 53.37, minLon: -6.24, maxLon: -6.16, key: 'dublin17'),
    (minLat: 53.28, maxLat: 53.33, minLon: -6.38, maxLon: -6.30, key: 'dublin16'),
    (minLat: 53.34, maxLat: 53.38, minLon: -6.38, maxLon: -6.30, key: 'dublin20'),
    (minLat: 53.42, maxLat: 53.55, minLon: -6.28, maxLon: -6.05, key: 'co_dublin_north'),
    (minLat: 53.25, maxLat: 53.32, minLon: -6.20, maxLon: -6.05, key: 'co_dublin_south'),
  ];

  final key = dublinDistrictKey(label);
  for (final box in boxes) {
    if (box.key == key) {
      return (
        lat: (box.minLat + box.maxLat) / 2,
        lon: (box.minLon + box.maxLon) / 2,
      );
    }
  }
  return null;
}
