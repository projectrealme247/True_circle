import '../models/spoken_language_entry.dart';
import '../services/listing_creation_validation_service.dart';
import 'profile_data.dart';

/// Encodes/decodes spoken language selections for profile + applicant pipelines.
abstract final class SpokenLanguageProfileCodec {
  SpokenLanguageProfileCodec._();

  static const sessionKey = 'spoken_language_entries';

  static List<SpokenLanguageEntry> fromSession(Map<String, dynamic> session) {
    final raw = session[sessionKey];
    if (raw is List) {
      final parsed = <SpokenLanguageEntry>[
        for (final item in raw)
          if (item is Map) SpokenLanguageEntry.fromMap(item),
      ].where((entry) => entry.language.trim().isNotEmpty).toList();

      if (parsed.isNotEmpty) {
        return sanitizeEntries(parsed);
      }
    }

    final mother = ProfileData.text(session['mother_tongue']);
    final legacy = ProfileData.languageList(session['spoken_languages']);
    return sanitizeEntries([
      for (final language in legacy)
        SpokenLanguageEntry(
          language: language,
          isNative: mother.isNotEmpty &&
              language.toLowerCase() == mother.toLowerCase(),
        ),
    ]);
  }

  static Map<String, dynamic> toSessionFields({
    required List<SpokenLanguageEntry> entries,
    required String motherTongue,
  }) {
    final sanitized = sanitizeEntries(entries);
    final labels = sanitizeLanguageLabels(sanitized);

    return {
      sessionKey: sanitized.map((entry) => entry.toMap()).toList(),
      'spoken_languages': labels,
      'mother_tongue': motherTongue,
    };
  }

  static List<SpokenLanguageEntry> sanitizeEntries(
    List<SpokenLanguageEntry> entries,
  ) {
    final seen = <String>{};
    final out = <SpokenLanguageEntry>[];

    for (final entry in entries) {
      final labels = ListingCreationValidationService.sanitizeLanguages(
        [entry.language],
      );
      if (labels.isEmpty) continue;

      final label = labels.first;
      final key = label.toLowerCase();
      final existingIndex = out.indexWhere(
        (item) => item.language.toLowerCase() == key,
      );
      if (existingIndex >= 0) {
        if (entry.isNative) {
          out[existingIndex] = SpokenLanguageEntry(
            language: out[existingIndex].language,
            isNative: true,
          );
        }
        continue;
      }

      seen.add(key);
      out.add(
        SpokenLanguageEntry(
          language: label,
          isNative: entry.isNative,
        ),
      );
    }

    return out;
  }

  static List<String> sanitizeLanguageLabels(List<SpokenLanguageEntry> entries) {
    return ListingCreationValidationService.sanitizeLanguages(
      entries.map((entry) => entry.language).toList(),
    );
  }
}
