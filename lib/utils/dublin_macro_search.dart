import '../config/market/market_config.dart';
import 'city_area_match.dart';

/// Exact-match macro phrases for broad Dublin search (not postal micro-queries).
abstract final class DublinMacroSearch {
  static const _exactMacroPhrases = {
    'dublin',
    'all of dublin',
    'co. dublin',
    'county dublin',
  };

  static final RegExp _dublinPostalPattern = RegExp(
    r'\bdublin\s*\d',
    caseSensitive: false,
  );

  static final RegExp _dublinCompactPostalPattern = RegExp(
    r'\bdublin\d',
    caseSensitive: false,
  );

  /// True only for whole-string macro phrases — never for "Dublin 18" or "Dundrum".
  static bool isExactMacroPhrase(String raw) {
    final normalized = _normalizePhrase(raw);
    if (normalized.isEmpty) return false;
    if (hasMicroLocationSignal(normalized)) return false;
    return _exactMacroPhrases.contains(normalized);
  }

  static bool hasMicroLocationSignal(String normalized) {
    if (_dublinPostalPattern.hasMatch(normalized)) return true;
    if (_dublinCompactPostalPattern.hasMatch(normalized)) return true;
    if (CityAreaMatch.findFirstMatch(normalized) != null) return true;
    for (final loc in MarketConfig.current.localityKeywords) {
      if (CityAreaMatch.aliasPattern(loc).hasMatch(normalized)) return true;
    }
    return false;
  }

  static bool hasMicroLocationInQuery(
    String raw, {
    String? parsedCityKey,
    List<String> parsedLocalityKeywords = const [],
  }) {
    final normalized = _normalizePhrase(raw);
    if (hasMicroLocationSignal(normalized)) return true;
    if (parsedCityKey != null && parsedCityKey.isNotEmpty) return true;
    return parsedLocalityKeywords.any(
      (k) => MarketConfig.current.localityKeywords.contains(k),
    );
  }

  static String _normalizePhrase(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
