import '../config/market/market_config.dart';

/// Boundary-safe Dublin/India area matching for search parse + listing filters.
abstract final class CityAreaMatch {
  static List<(String alias, String cityKey)> get sortedParseAliases {
    final aliases = <(String alias, String cityKey)>[];
    for (final entry in MarketConfig.current.parseCityAliases.entries) {
      for (final alias in entry.value) {
        if (alias.length >= 2) aliases.add((alias, entry.key));
      }
      if (entry.key.length >= 3) {
        aliases.add((entry.key, entry.key));
      }
    }
    aliases.sort((a, b) => b.$1.length.compareTo(a.$1.length));
    return aliases;
  }

  static List<(String alias, String cityKey)> get sortedFilterAliases {
    final aliases = <(String alias, String cityKey)>[];
    for (final entry in MarketConfig.current.cityAliases.entries) {
      for (final alias in entry.value) {
        if (alias.length >= 2) aliases.add((alias, entry.key));
      }
      aliases.add((entry.key, entry.key));
    }
    aliases.sort((a, b) => b.$1.length.compareTo(a.$1.length));
    return aliases;
  }

  /// Regex for an area alias — `dublin 4` won't match `dublin 12` or `dublin 14`.
  static RegExp aliasPattern(String alias) {
    final lower = alias.trim().toLowerCase();
    if (lower.isEmpty) return RegExp(r'$^');

    final dublinSpaced = RegExp(r'^dublin (\d+)$').firstMatch(lower);
    if (dublinSpaced != null) {
      final n = dublinSpaced.group(1)!;
      return RegExp(
        r'(?<![0-9a-z])dublin\s+' + RegExp.escape(n) + r'(?![0-9])',
        caseSensitive: false,
      );
    }

    final dublinCompact = RegExp(r'^dublin(\d+)$').firstMatch(lower);
    if (dublinCompact != null) {
      final n = dublinCompact.group(1)!;
      return RegExp(
        r'(?<![0-9a-z])dublin\s*' + RegExp.escape(n) + r'(?![0-9])',
        caseSensitive: false,
      );
    }

    if (lower.contains(' ')) {
      return RegExp(
        r'(?<![0-9a-z])' +
            RegExp.escape(lower).replaceAll(r'\ ', r'\s+') +
            r'(?![0-9a-z])',
        caseSensitive: false,
      );
    }

    return RegExp(
      r'(?<![0-9a-z])' + RegExp.escape(lower) + r'(?![0-9a-z])',
      caseSensitive: false,
    );
  }

  static bool blobMatchesFilter(String blob, String filterCityKey) {
    final key = filterCityKey.trim().toLowerCase();
    if (key.isEmpty) return true;

    final terms = <String>{key};
    final broad = MarketConfig.current.cityAliases[key];
    if (broad != null) terms.addAll(broad);
    final parse = MarketConfig.current.parseCityAliases[key];
    if (parse != null) terms.addAll(parse);

    for (final term in terms) {
      if (term.isEmpty) continue;
      if (aliasPattern(term).hasMatch(blob)) return true;
    }
    return false;
  }

  /// First non-overlapping city phrase in [query].
  static (String cityKey, int start, int end)? findFirstMatch(
    String query, {
    bool Function(int start, int end)? isAvailable,
  }) {
    for (final (alias, cityKey) in sortedParseAliases) {
      for (final match in aliasPattern(alias).allMatches(query)) {
        if (isAvailable != null && !isAvailable(match.start, match.end)) {
          continue;
        }
        return (cityKey, match.start, match.end);
      }
    }
    return null;
  }

  /// Maps profile [detected_city] (label or key) to a canonical area key.
  static String? profileAreaKey(String profileCity) {
    final trimmed = profileCity.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();

    for (final (key, label) in MarketConfig.current.areaOptions) {
      if (key.toLowerCase() == lower || label.toLowerCase() == lower) {
        return key;
      }
    }

    final match = findFirstMatch(lower);
    return match?.$1;
  }

  /// Resolves listing location + host city text to a canonical area key.
  static String? listingAreaKeyFromBlob(String locationBlob) {
    final blob = locationBlob.trim().toLowerCase();
    if (blob.isEmpty) return null;

    for (final (key, _) in MarketConfig.current.areaOptions) {
      if (blobMatchesFilter(blob, key)) return key;
    }
    return null;
  }
}
