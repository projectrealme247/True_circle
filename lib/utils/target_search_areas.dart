import '../config/market/market_config.dart';
import 'city_area_match.dart';
import 'listing_data.dart';
import 'profile_data.dart';

/// Seeker target postal areas — separate from [detected_city] (current location).
abstract final class TargetSearchAreas {
  static const allDublinToken = 'ALL_DUBLIN';
  static const allDublinLabel = 'All of Dublin';

  /// `(key, label)` for multi-select UI; Dublin injects macro at index 0.
  static List<(String, String)> get selectableOptions {
    final market = MarketConfig.current;
    if (market.id.name == 'dublin' && market.profileUseAreaPicker) {
      return [
        (allDublinToken, allDublinLabel),
        ...market.areaOptions,
      ];
    }
    return market.areaOptions;
  }

  static String labelForKey(String key) {
    if (key == allDublinToken) return allDublinLabel;
    for (final (k, label) in MarketConfig.current.areaOptions) {
      if (k == key) return label;
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

  /// Normalizes storage: macro token is exclusive.
  static List<String> normalizeTokens(List<String> tokens) {
    final cleaned = tokens
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (cleaned.contains(allDublinToken)) return [allDublinToken];
    return cleaned;
  }

  /// Reads explicit targets, else legacy [detected_city] for backward compatibility.
  static List<String> hydrateFromSession(Map<String, dynamic>? session) {
    final explicit = normalizeTokens(tokenList(session?['target_search_areas']));
    if (explicit.isNotEmpty) return explicit;

    final legacy = ProfileData.text(session?['detected_city']);
    final key = CityAreaMatch.profileAreaKey(legacy);
    if (key != null) return [key];
    return [];
  }

  /// Explicit user-selected targets only (for completion denominators).
  static bool hasExplicitSelection(Map<String, dynamic>? session) =>
      normalizeTokens(tokenList(session?['target_search_areas'])).isNotEmpty;

  /// Includes legacy [detected_city] fallback for matching until migrated.
  static bool hasSelection(Map<String, dynamic>? session) =>
      hydrateFromSession(session).isNotEmpty;

  static bool hasAllDublin(List<String> tokens) =>
      tokens.contains(allDublinToken);

  static String displaySummary(List<String> tokens) {
    if (tokens.isEmpty) return ProfileData.notProvided;
    if (hasAllDublin(tokens)) return allDublinLabel;
    return tokens.map(labelForKey).join(', ');
  }

  /// Short preview for form tap-targets (e.g. "Dublin 1, Dublin 2...").
  static String compactSummary(List<String> tokens, {int maxLabels = 2}) {
    if (tokens.isEmpty) return '';
    if (hasAllDublin(tokens)) return allDublinLabel;
    final labels = tokens.map(labelForKey).toList();
    if (labels.length <= maxLabels) return labels.join(', ');
    return '${labels.take(maxLabels).join(', ')}...';
  }

  /// UI toggle respecting [allDublinToken] exclusivity.
  static List<String> toggleSelection(List<String> current, String key) {
    if (key == allDublinToken) {
      if (current.contains(allDublinToken)) return [];
      return [allDublinToken];
    }
    final next = List<String>.from(current);
    if (next.contains(allDublinToken)) next.clear();
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    return normalizeTokens(next);
  }

  /// Wildcard: [allDublinToken] skips postal constraints.
  static bool listingMatchesTargets(
    List<String> targetTokens,
    Map<String, dynamic> listing,
  ) {
    if (targetTokens.isEmpty) return false;
    if (hasAllDublin(targetTokens)) return true;

    final blob =
        '${ListingData.location(listing)} ${ListingData.hostCity(listing)}';
    for (final token in targetTokens) {
      if (CityAreaMatch.blobMatchesFilter(blob, token)) return true;
      final label = labelForKey(token);
      final fromLabel = CityAreaMatch.profileAreaKey(label);
      if (fromLabel != null &&
          CityAreaMatch.blobMatchesFilter(blob, fromLabel)) {
        return true;
      }
    }
    return false;
  }

  /// Preferred-area scoring key — first explicit target, or null when macro.
  static String? primaryAreaKey(List<String> tokens) {
    if (tokens.isEmpty || hasAllDublin(tokens)) return null;
    return tokens.first;
  }

  /// Wildcard filter token for marketplace search + profile target areas.
  static List<String> get allDublinFilterTokens => const [allDublinToken];
}
