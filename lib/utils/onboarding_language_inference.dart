/// Predictive spoken-language companions when a mother tongue is chosen.
abstract final class OnboardingLanguageInference {
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
