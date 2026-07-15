import '../config/market/dublin_macro_areas.dart';
import '../config/market/market_config.dart';
import 'city_area_match.dart';
import 'listing_data.dart';
import 'profile_data.dart';

/// Seeker target areas — macro regions + optional postcode refinements.
abstract final class TargetSearchAreas {
  static const allDublinToken = 'ALL_DUBLIN';
  static const allDublinLabel = 'All Dublin';

  /// Primary area-first options (Dublin v2).
  static List<(String, String)> get primaryFilterOptions {
    final market = MarketConfig.current;
    if (market.id.name == 'dublin' && market.profileUseAreaPicker) {
      return [
        (allDublinToken, allDublinLabel),
        ...DublinMacroAreas.primaryOptions,
      ];
    }
    return [(allDublinToken, allDublinLabel), ...market.areaOptions];
  }

  /// Postcode / district refinement options (More Filters → Refine Area).
  ///
  /// Dublin: same keys as [MarketConfig.areaOptions] / `dublin_districts.dart`,
  /// short labels via [DublinMacroAreas.districtRefinementOptions].
  static List<(String, String)> get postcodeRefinementOptions {
    final market = MarketConfig.current;
    if (market.id.name == 'dublin') {
      return DublinMacroAreas.districtRefinementOptions;
    }
    return market.areaOptions;
  }

  /// Legacy profile multi-select — macro + districts (profile onboarding).
  static List<(String, String)> get selectableOptions => primaryFilterOptions;

  static bool isMacroToken(String key) =>
      key == allDublinToken || DublinMacroAreas.isMacroToken(key);

  static bool isDistrictKey(String key) => DublinMacroAreas.isDistrictKey(key);

  static String labelForKey(String key) {
    if (key == allDublinToken) return allDublinLabel;
    if (DublinMacroAreas.isMacroToken(key)) {
      return DublinMacroAreas.labelFor(key);
    }
    for (final (k, _) in MarketConfig.current.areaOptions) {
      if (k == key) return DublinMacroAreas.labelFor(key);
    }
    return key;
  }

  static List<String> tokenList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => ProfileData.text(e))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final single = ProfileData.text(raw);
    if (single.isEmpty) return [];
    return [single];
  }

  /// Normalizes macro storage: [allDublinToken] is exclusive.
  static List<String> normalizeMacroTokens(List<String> tokens) {
    final cleaned =
        tokens.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (cleaned.contains(allDublinToken)) return [allDublinToken];
    return cleaned.where(isMacroToken).toList();
  }

  static List<String> normalizeRefinementTokens(List<String> tokens) {
    return tokens
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && isDistrictKey(t))
        .toSet()
        .toList();
  }

  /// Backward-compatible normalize for legacy district keys in [target_search_areas].
  static List<String> normalizeTokens(List<String> tokens) {
    return normalizeMacroTokens(_splitLegacyStorage(tokens).macros);
  }

  static ({List<String> macros, List<String> refinements}) _splitLegacyStorage(
    List<String> tokens,
  ) {
    final macros = <String>[];
    final refinements = <String>[];
    for (final token in tokens) {
      if (isMacroToken(token)) {
        macros.add(token);
      } else if (isDistrictKey(token)) {
        refinements.add(token);
      }
    }
    return (macros: macros, refinements: refinements);
  }

  /// Reads explicit macro targets, else legacy [detected_city] as All Dublin.
  static List<String> hydrateFromSession(Map<String, dynamic>? session) {
    final raw = tokenList(session?['target_search_areas']);
    final split = _splitLegacyStorage(raw);
    if (split.macros.isNotEmpty) {
      return normalizeMacroTokens(split.macros);
    }
    if (split.refinements.isNotEmpty) return [allDublinToken];

    final legacy = ProfileData.text(session?['detected_city']);
    final key = CityAreaMatch.profileAreaKey(legacy);
    if (key != null) return [allDublinToken];

    return [];
  }

  static List<String> hydrateRefinementsFromSession(
    Map<String, dynamic>? session,
  ) {
    final explicit = normalizeRefinementTokens(
      tokenList(session?['target_search_area_refinements']),
    );
    if (explicit.isNotEmpty) return explicit;

    final split = _splitLegacyStorage(tokenList(session?['target_search_areas']));
    if (split.refinements.isNotEmpty) return split.refinements;

    final legacy = ProfileData.text(session?['detected_city']);
    final key = CityAreaMatch.profileAreaKey(legacy);
    if (key != null) return [key];

    return [];
  }

  static bool hasExplicitSelection(Map<String, dynamic>? session) =>
      normalizeMacroTokens(tokenList(session?['target_search_areas']))
          .isNotEmpty;

  static bool hasSelection(Map<String, dynamic>? session) =>
      hydrateFromSession(session).isNotEmpty ||
      hydrateRefinementsFromSession(session).isNotEmpty;

  static bool hasAllDublin(List<String> macroTokens) =>
      macroTokens.isEmpty || macroTokens.contains(allDublinToken);

  static String displaySummary(List<String> macroTokens) {
    if (macroTokens.isEmpty || hasAllDublin(macroTokens)) {
      return allDublinLabel;
    }
    return macroTokens.map(labelForKey).join(', ');
  }

  static String compactSummary(List<String> macroTokens, {int maxLabels = 2}) {
    if (macroTokens.isEmpty || hasAllDublin(macroTokens)) return allDublinLabel;
    final labels = macroTokens.map(labelForKey).toList();
    if (labels.length <= maxLabels) return labels.join(', ');
    return '${labels.take(maxLabels).join(', ')}...';
  }

  static String refinementSummary(List<String> refinements) {
    if (refinements.isEmpty) return '';
    return refinements.map(labelForKey).join(', ');
  }

  /// Macro toggle — [allDublinToken] exclusive with macro regions.
  static List<String> toggleMacroSelection(List<String> current, String key) {
    if (key == allDublinToken) {
      return [allDublinToken];
    }

    var next = List<String>.from(current);
    if (next.isEmpty || next.contains(allDublinToken)) {
      next = [key];
    } else if (next.contains(key)) {
      next.remove(key);
      if (next.isEmpty) next = [allDublinToken];
    } else {
      next.add(key);
    }
    return normalizeMacroTokens(next);
  }

  /// Postcode refinement toggle (multi-select).
  static List<String> toggleRefinementSelection(
    List<String> current,
    String districtKey,
  ) {
    final next = List<String>.from(current);
    if (next.contains(districtKey)) {
      next.remove(districtKey);
    } else {
      next.add(districtKey);
    }
    return normalizeRefinementTokens(next);
  }

  /// UI toggle (profile field — macros + districts).
  static List<String> toggleSelection(List<String> current, String key) {
    if (isDistrictKey(key)) {
      return toggleRefinementSelection(current, key);
    }
    return toggleMacroSelection(current, key);
  }

  static List<String> get allDublinFilterTokens => const [allDublinToken];

  static ResolvedAreaSearch resolveSearch({
    required List<String> macroTokens,
    required List<String> refinementTokens,
  }) {
    final macros = normalizeMacroTokens(macroTokens);
    final refinements = normalizeRefinementTokens(refinementTokens);

    if (hasAllDublin(macros) && refinements.isEmpty) {
      return const ResolvedAreaSearch.allDublin();
    }

    final expanded = DublinMacroAreas.resolveMacros(
      macros.where(DublinMacroAreas.isMacroToken),
    );

    var districtKeys = expanded.districtKeys;
    var localityTerms = expanded.localityTerms;

    if (refinements.isNotEmpty) {
      if (districtKeys.isEmpty && localityTerms.isEmpty) {
        districtKeys = refinements;
      } else {
        districtKeys =
            districtKeys.where(refinements.contains).toList(growable: false);
        if (districtKeys.isEmpty) {
          districtKeys = refinements;
        }
      }
    }

    return ResolvedAreaSearch(
      districtKeys: districtKeys,
      localityTerms: localityTerms,
    );
  }

  /// Wildcard + macro expansion + postcode refinement matching.
  static bool listingMatchesTargets(
    List<String> targetTokens,
    Map<String, dynamic> listing, {
    List<String> refinementTokens = const [],
  }) {
    final split = _splitLegacyStorage(targetTokens);
    final macros =
        split.macros.isNotEmpty ? split.macros : normalizeMacroTokens(targetTokens);
    final refinements = refinementTokens.isNotEmpty
        ? refinementTokens
        : split.refinements;

    return listingMatchesResolved(
      resolveSearch(macroTokens: macros, refinementTokens: refinements),
      listing,
    );
  }

  static bool listingMatchesResolved(
    ResolvedAreaSearch resolution,
    Map<String, dynamic> listing,
  ) {
    if (resolution.isAllDublin) return true;

    for (final token in resolution.districtKeys) {
      if (_listingMatchesDistrictToken(token, listing)) return true;
    }

    final blob =
        '${ListingData.location(listing)} ${ListingData.hostCity(listing)}';
    for (final locality in resolution.localityTerms) {
      if (_blobMatchesLocality(blob, locality)) return true;
    }

    return false;
  }

  static bool _listingMatchesDistrictToken(
    String token,
    Map<String, dynamic> listing,
  ) {
    final explicitAreaKey =
        ProfileData.text(listing['listing_area_key']).trim();
    if (explicitAreaKey.isNotEmpty && explicitAreaKey == token) {
      return true;
    }

    final blob =
        '${ListingData.location(listing)} ${ListingData.hostCity(listing)}';
    if (CityAreaMatch.blobMatchesFilter(blob, token)) return true;

    final label = labelForKey(token);
    final fromLabel = CityAreaMatch.profileAreaKey(label);
    if (fromLabel != null &&
        CityAreaMatch.blobMatchesFilter(blob, fromLabel)) {
      return true;
    }
    return false;
  }

  static bool _blobMatchesLocality(String blob, String locality) {
    final term = locality.trim().toLowerCase();
    if (term.isEmpty) return false;
    return CityAreaMatch.aliasPattern(term).hasMatch(blob.toLowerCase());
  }

  static String? primaryAreaKey(List<String> tokens) {
    if (tokens.isEmpty || hasAllDublin(tokens)) return null;
    for (final token in tokens) {
      if (isDistrictKey(token)) return token;
    }
    return null;
  }
}

/// Expanded area search tokens used by the listing pipeline.
class ResolvedAreaSearch {
  const ResolvedAreaSearch({
    required this.districtKeys,
    required this.localityTerms,
  }) : isAllDublin = false;

  const ResolvedAreaSearch.allDublin()
      : districtKeys = const [],
        localityTerms = const [],
        isAllDublin = true;

  final bool isAllDublin;
  final List<String> districtKeys;
  final List<String> localityTerms;
}
