import '../../config/market/dublin_districts.dart';

/// Dublin macro area tokens for area-first marketplace filtering (v2).
abstract final class DublinMacroAreas {
  static const cityCentre = 'MACRO_CITY_CENTRE';
  static const northDublin = 'MACRO_NORTH_DUBLIN';
  static const southDublin = 'MACRO_SOUTH_DUBLIN';
  static const westDublin = 'MACRO_WEST_DUBLIN';

  static const allMacroTokens = {
    cityCentre,
    northDublin,
    southDublin,
    westDublin,
  };

  /// Homepage + primary filter macros in canonical order.
  ///
  /// City Centre membership is defined solely by [districtKeysFor] for
  /// [cityCentre] — the same set everywhere (D1, D2, D7, D8).
  static const primaryOptions = <(String, String)>[
    (cityCentre, 'City Centre'),
    (northDublin, 'North Dublin'),
    (southDublin, 'South Dublin'),
    (westDublin, 'West Dublin'),
  ];

  /// Refine-filter district chips: short labels from [dublinAreaOptions].
  /// Keys match listing-creation / catalog storage keys.
  static List<(String, String)> get districtRefinementOptions => [
        for (final (key, _) in dublinAreaOptions) (key, labelFor(key)),
      ];

  static bool isMacroToken(String token) =>
      allMacroTokens.contains(token.trim());

  static bool isDistrictKey(String token) {
    final key = token.trim().toLowerCase();
    if (key.isEmpty) return false;
    for (final (districtKey, _) in dublinAreaOptions) {
      if (districtKey == key) return true;
    }
    return false;
  }

  static String labelFor(String token) {
    for (final (key, label) in primaryOptions) {
      if (key == token) return label;
    }
    for (final (key, label) in dublinAreaOptions) {
      if (key == token) return _shortDistrictLabel(label);
    }
    return token;
  }

  static String _shortDistrictLabel(String full) {
    final numbered = RegExp(r'^(Dublin \d+[W]?)').firstMatch(full);
    if (numbered != null) return numbered.group(1)!;
    if (full.startsWith('Co. Dublin (North')) return 'Co. Dublin North';
    if (full.startsWith('Co. Dublin (South')) return 'Co. Dublin South';
    return full;
  }

  static List<String> districtKeysFor(String macroToken) {
    return switch (macroToken) {
      cityCentre => const [
          'dublin1',
          'dublin2',
          'dublin7',
          'dublin8',
        ],
      northDublin => const [
          'dublin3',
          'dublin5',
          'dublin9',
          'dublin11',
          'dublin13',
          'dublin17',
          'co_dublin_north',
        ],
      southDublin => const [
          'dublin4',
          'dublin6',
          'dublin6w',
          'dublin12',
          'dublin14',
          'dublin16',
          'dublin18',
          'co_dublin_south',
        ],
      westDublin => const [
          'dublin10',
          'dublin15',
          'dublin20',
          'dublin22',
          'dublin24',
        ],
      _ => const [],
    };
  }

  /// Named localities matched on listing location text when no postcode is present.
  static List<String> localityTermsFor(String macroToken) {
    return switch (macroToken) {
      northDublin => const [
          'swords',
          'malahide',
          'portmarnock',
          'howth',
        ],
      southDublin => const [
          'blackrock',
          'dún laoghaire',
          'dun laoghaire',
          'monkstown',
          'stillorgan',
          'booterstown',
          'foxrock',
          'sandyford',
          'dalkey',
          'killiney',
        ],
      westDublin => const [
          'lucan',
          'clondalkin',
          'tallaght',
          'blanchardstown',
        ],
      _ => const [],
    };
  }

  static List<String> expandMacros(Iterable<String> macroTokens) {
    final keys = <String>{};
    final localities = <String>{};
    for (final macro in macroTokens) {
      if (!isMacroToken(macro)) continue;
      keys.addAll(districtKeysFor(macro));
      localities.addAll(localityTermsFor(macro));
    }
    return [...keys, ...localities];
  }

  static ({List<String> districtKeys, List<String> localityTerms}) resolveMacros(
    Iterable<String> macroTokens,
  ) {
    final keys = <String>{};
    final localities = <String>{};
    for (final macro in macroTokens) {
      if (!isMacroToken(macro)) continue;
      keys.addAll(districtKeysFor(macro));
      localities.addAll(localityTermsFor(macro));
    }
    return (
      districtKeys: keys.toList(),
      localityTerms: localities.toList(),
    );
  }
}
