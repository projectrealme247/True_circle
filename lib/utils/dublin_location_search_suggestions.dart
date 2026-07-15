import '../config/market/dublin_districts.dart';
import '../services/nominatim_forward.dart';
import 'nominatim_label_sanitizer.dart';

/// Source tier for blended location autocomplete ranking.
enum LocationSuggestionTier {
  localAlias(2000),
  localDistrict(1200),
  nominatim(0);

  const LocationSuggestionTier(this.boost);
  final int boost;
}

/// Ranked map-search row with primary place name + secondary district.
class LocationSearchSuggestion {
  const LocationSearchSuggestion({
    required this.primaryTitle,
    required this.secondaryTitle,
    required this.result,
    required this.score,
    required this.tier,
    this.matchedToken,
  });

  final String primaryTitle;
  final String secondaryTitle;
  final NominatimAddressResult result;
  final int score;
  final LocationSuggestionTier tier;
  final String? matchedToken;
}

/// Local Dublin area/alias matches for map search autocomplete.
List<LocationSearchSuggestion> searchLocalDublinAreaSuggestions(String rawQuery) {
  final query = rawQuery.trim().toLowerCase();
  if (query.length < 3) return const [];

  final matches = <LocationSearchSuggestion>[];
  final seen = <String>{};

  for (final (key, label) in dublinAreaOptions) {
    final centroid = dublinDistrictCentroidFromLabel(label);
    if (centroid == null) continue;

    final secondary = _districtSecondaryLabel(label);
    final aliases = dublinCityAliases[key] ?? const <String>[];

    for (final alias in aliases) {
      final normalized = alias.trim().toLowerCase();
      if (normalized.isEmpty) continue;

      final aliasScore = _scoreTextMatch(query, normalized);
      if (aliasScore < 0) continue;

      final primary = _titleCase(normalized);
      final dedupeKey = '${primary.toLowerCase()}|$secondary';
      if (seen.contains(dedupeKey)) continue;
      seen.add(dedupeKey);

      matches.add(
        LocationSearchSuggestion(
          primaryTitle: primary,
          secondaryTitle: secondary,
          result: NominatimAddressResult(
            displayLabel: '$primary, $secondary',
            lat: centroid.lat,
            lon: centroid.lon,
            streetLine: primary,
            area: primary,
            county: 'Dublin',
          ),
          score: LocationSuggestionTier.localAlias.boost + aliasScore,
          tier: LocationSuggestionTier.localAlias,
          matchedToken: normalized,
        ),
      );
    }

    final districtTokens = _districtSearchTokens(label);
    for (final token in districtTokens) {
      final districtScore = _scoreTextMatch(query, token);
      if (districtScore < 0) continue;

      final primary = _titleCase(token);
      final dedupeKey = '${primary.toLowerCase()}|$secondary';
      if (seen.contains(dedupeKey)) continue;
      seen.add(dedupeKey);

      matches.add(
        LocationSearchSuggestion(
          primaryTitle: primary,
          secondaryTitle: secondary,
          result: NominatimAddressResult(
            displayLabel: '$primary, $secondary',
            lat: centroid.lat,
            lon: centroid.lon,
            streetLine: primary,
            area: primary,
            county: 'Dublin',
          ),
          score: LocationSuggestionTier.localDistrict.boost + districtScore,
          tier: LocationSuggestionTier.localDistrict,
          matchedToken: token,
        ),
      );
    }
  }

  matches.sort((a, b) => b.score.compareTo(a.score));
  return matches.take(8).toList();
}

/// Blends local + Nominatim rows with weighted ranking (higher score first).
List<LocationSearchSuggestion> rankLocationSearchSuggestions(
  String rawQuery,
  List<LocationSearchSuggestion> local,
  List<NominatimAddressResult> remote,
) {
  final query = rawQuery.trim().toLowerCase();
  final ranked = <LocationSearchSuggestion>[...local];

  for (final item in remote) {
    ranked.add(_nominatimToSuggestion(query, item));
  }

  ranked.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.primaryTitle.compareTo(b.primaryTitle);
  });

  final seen = <String>{};
  final deduped = <LocationSearchSuggestion>[];
  for (final item in ranked) {
    final key =
        '${item.primaryTitle.toLowerCase()}|${item.secondaryTitle.toLowerCase()}|'
        '${item.result.lat.toStringAsFixed(4)}|${item.result.lon.toStringAsFixed(4)}';
    if (seen.contains(key)) continue;
    seen.add(key);
    deduped.add(item);
    if (deduped.length >= 8) break;
  }
  return deduped;
}

LocationSearchSuggestion _nominatimToSuggestion(
  String query,
  NominatimAddressResult item,
) {
  final primary = _nominatimPrimaryLabel(item);
  final secondary = _nominatimSecondaryLabel(item);
  final haystack = [
    primary,
    item.streetLine,
    item.displayLabel,
    item.area,
  ].join(' ').toLowerCase();

  final matchScore = _scoreTextMatch(query, haystack);
  final score = LocationSuggestionTier.nominatim.boost +
      (matchScore >= 0 ? matchScore : 0);

  return LocationSearchSuggestion(
    primaryTitle: primary,
    secondaryTitle: secondary,
    result: item,
    score: score,
    tier: LocationSuggestionTier.nominatim,
  );
}

String _nominatimPrimaryLabel(NominatimAddressResult item) {
  for (final candidate in [
    item.area,
    item.streetLine,
    ...item.displayLabel.split(',').map((part) => part.trim()),
  ]) {
    final cleaned = NominatimLabelSanitizer.cleanPart(candidate);
    if (cleaned.isEmpty) continue;
    if (NominatimLabelSanitizer.isNoisyAdminPart(cleaned)) continue;
    return cleaned;
  }
  return '';
}

/// Weighted text match — higher is better.
int _scoreTextMatch(String query, String candidate) {
  final q = query.trim().toLowerCase();
  final c = candidate.trim().toLowerCase();
  if (q.isEmpty || c.isEmpty) return -1;
  if (c == q) return 900;
  if (c.startsWith(q)) return 700 - (c.length - q.length).clamp(0, 200);
  final index = c.indexOf(q);
  if (index >= 0) return 350 - index.clamp(0, 100);
  return -1;
}

String _districtSecondaryLabel(String districtLabel) {
  final numbered = RegExp(r'^(Dublin \d+[W]?)').firstMatch(districtLabel);
  if (numbered != null) return numbered.group(1)!;
  if (districtLabel.startsWith('Co. Dublin (North')) return 'Co. Dublin North';
  if (districtLabel.startsWith('Co. Dublin (South')) return 'Co. Dublin South';
  return districtLabel;
}

Iterable<String> _districtSearchTokens(String districtLabel) {
  final tokens = <String>{};
  final numbered = RegExp(r'^(Dublin \d+[W]?)').firstMatch(districtLabel);
  if (numbered != null) {
    tokens.add(numbered.group(1)!.toLowerCase());
  }
  final paren = RegExp(r'\(([^)]+)\)').firstMatch(districtLabel);
  if (paren != null) {
    for (final segment in paren.group(1)!.split(RegExp(r'[-,]'))) {
      final token = segment.trim().toLowerCase();
      if (token.isNotEmpty) tokens.add(token);
    }
  }
  return tokens;
}

String _nominatimSecondaryLabel(NominatimAddressResult item) {
  for (final part in item.displayLabel.split(',')) {
    final cleaned = NominatimLabelSanitizer.cleanPart(part);
    if (cleaned.isEmpty) continue;
    if (NominatimLabelSanitizer.isNoisyAdminPart(cleaned)) continue;
    if (RegExp(r'^Dublin \d').hasMatch(cleaned)) return cleaned;
    if (cleaned.toLowerCase().startsWith('co. dublin')) return cleaned;
  }
  return NominatimLabelSanitizer.formatCountyLabel(item.county);
}

String _titleCase(String raw) {
  if (raw.isEmpty) return raw;
  return raw
      .split(RegExp(r'\s+'))
      .map((word) {
        if (word.isEmpty) return word;
        if (word.length == 1) return word.toUpperCase();
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}
