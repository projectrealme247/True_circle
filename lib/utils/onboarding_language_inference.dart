import 'language_proximity_db.dart';

/// Predictive spoken-language companions when a mother tongue is chosen.
abstract final class OnboardingLanguageInference {
  /// Suggested secondary-language chips for seeker onboarding (unselected by default).
  static const Map<String, List<String>> _companionLanguages = {
    'Tamil': ['English', 'Malayalam', 'Telugu', 'Kannada', 'Hindi'],
    'Hindi': ['English', 'Punjabi', 'Bengali', 'Marathi'],
    'Malayalam': ['English', 'Tamil', 'Hindi'],
    'Telugu': ['English', 'Tamil', 'Hindi', 'Kannada'],
    'Kannada': ['English', 'Tamil', 'Telugu', 'Hindi'],
    'Bengali': ['English', 'Hindi', 'Assamese'],
    'Punjabi': ['English', 'Hindi', 'Urdu'],
    'Gujarati': ['English', 'Hindi', 'Marathi'],
    'Marathi': ['English', 'Hindi', 'Gujarati'],
    'Urdu': ['English', 'Hindi', 'Punjabi'],
    'Polish': ['English', 'Ukrainian', 'Russian'],
    'Ukrainian': ['English', 'Russian', 'Polish'],
    'Portuguese': ['English', 'Spanish'],
    'Spanish': ['English', 'Portuguese'],
    'French': ['English', 'Spanish', 'German'],
    'German': ['English', 'French'],
    'Italian': ['English', 'Spanish', 'French'],
    'Arabic': ['English', 'Urdu'],
    'Chinese (Mandarin)': ['English', 'Chinese (Cantonese)'],
    'Chinese (Cantonese)': ['English', 'Chinese (Mandarin)'],
    'Russian': ['English', 'Ukrainian', 'Polish'],
    'Gaeilge': ['English'],
    'English': ['English'],
  };

  /// Chip-row suggestions for "Other languages you speak" — never auto-selected.
  static List<String> suggestedLanguagesFor(String primary) {
    final trimmed = primary.trim();
    if (trimmed.isEmpty) return const ['English'];

    for (final entry in _companionLanguages.entries) {
      if (entry.key.toLowerCase() == trimmed.toLowerCase()) {
        return List<String>.from(entry.value);
      }
    }
    return const ['English'];
  }

  /// Fluent secondary languages inferred from a seeker primary language pick.
  static List<String> fluentCompanionsFor(String primaryLanguage) =>
      buildFluentLanguagesForPrimary(primaryLanguage);

  /// Builds the fluent chip list — English is always the baseline entry.
  static List<String> buildFluentLanguagesForPrimary(String selectedLang) {
    final cleanPrimary = _normalizePrimaryKey(selectedLang);
    if (cleanPrimary.isEmpty) return const [];

    final modernFluentList = <String>['English'];

    if (languageProximityDb.containsKey(cleanPrimary)) {
      final relatedLanguages = languageProximityDb[cleanPrimary]!;
      for (final lang in relatedLanguages) {
        if (!_containsLanguage(modernFluentList, lang)) {
          modernFluentList.add(lang);
        }
      }
    }

    if (cleanPrimary != 'english') {
      modernFluentList.removeWhere(
        (lang) => lang.toLowerCase().trim() == cleanPrimary,
      );
    }

    return List<String>.from(modernFluentList);
  }

  /// Ensures English is always present in the spoken-language session list.
  static List<String> withEnglishFoundation(List<String> spoken) {
    const english = 'English';
    if (spoken.any((l) => l.toLowerCase() == english.toLowerCase())) {
      return _dedupe(spoken);
    }
    return _dedupe([...spoken, english]);
  }

  static List<String> companionsFor(String motherTongue) {
    final key = motherTongue.trim().toLowerCase();
    const english = 'English';

    final inferred = switch (key) {
      'telugu' => ['Telugu', english, 'Hindi'],
      'hindi' => ['Hindi', english],
      'malayalam' => ['Malayalam', english, 'Hindi'],
      'tamil' => ['Tamil', english, 'Hindi'],
      'bengali' => ['Bengali', english, 'Hindi'],
      'punjabi' => ['Punjabi', english, 'Hindi'],
      'gujarati' => ['Gujarati', english, 'Hindi'],
      'kannada' => ['Kannada', english, 'Hindi'],
      'marathi' => ['Marathi', english, 'Hindi'],
      'polish' => ['Polish', english],
      'portuguese' => ['Portuguese', english],
      'romanian' => ['Romanian', english],
      'lithuanian' => ['Lithuanian', english],
      'latvian' => ['Latvian', english],
      'spanish' => ['Spanish', english],
      'french' => ['French', english],
      'german' => ['German', english],
      'italian' => ['Italian', english],
      'gaeilge' => ['Gaeilge', english],
      'arabic' => ['Arabic', english],
      'urdu' => ['Urdu', english, 'Hindi'],
      'chinese (mandarin)' => ['Chinese (Mandarin)', english],
      'chinese (cantonese)' => ['Chinese (Cantonese)', english],
      'russian' => ['Russian', english],
      'ukrainian' => ['Ukrainian', english],
      _ => [motherTongue.trim(), english],
    };

    return _dedupe(inferred);
  }

  static String _normalizePrimaryKey(String primaryLanguage) {
    final key = primaryLanguage.trim().toLowerCase();
    if (key.isEmpty) return key;
    return languageProximityAliases[key] ?? key;
  }

  static bool _containsLanguage(List<String> languages, String candidate) {
    final key = candidate.toLowerCase().trim();
    return languages.any((lang) => lang.toLowerCase().trim() == key);
  }

  static List<String> _dedupe(List<String> languages) {
    final seen = <String>{};
    final result = <String>[];
    for (final language in languages) {
      final trimmed = language.trim();
      if (trimmed.isEmpty) continue;
      final token = trimmed.toLowerCase();
      if (seen.add(token)) result.add(trimmed);
    }
    return result;
  }
}
