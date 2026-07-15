/// Common languages spoken across modern Ireland — mother tongue & spoken pickers.
abstract final class IrelandLanguageCatalog {
  static const all = <String>[
    'English',
    'Gaeilge',
    'Polish',
    'Portuguese',
    'Romanian',
    'Lithuanian',
    'Latvian',
    'Spanish',
    'French',
    'German',
    'Italian',
    'Arabic',
    'Urdu',
    'Hindi',
    'Telugu',
    'Tamil',
    'Malayalam',
    'Bengali',
    'Assamese',
    'Punjabi',
    'Gujarati',
    'Kannada',
    'Marathi',
    'Chinese (Mandarin)',
    'Chinese (Cantonese)',
    'Russian',
    'Ukrainian',
    'Bulgarian',
    'Hungarian',
    'Czech',
    'Slovak',
    'Dutch',
    'Turkish',
    'Filipino',
    'Vietnamese',
    'Thai',
    'Japanese',
    'Korean',
    'Somali',
    'Swahili',
    'Yoruba',
    'Igbo',
    'Amharic',
    'Persian',
    'Pashto',
    'Bosnian',
    'Croatian',
    'Serbian',
    'Albanian',
    'Greek',
    'Hebrew',
    'Nepali',
    'Sinhala',
    'Other',
  ];

  static List<String> filterByQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List<String>.from(all);
    return all
        .where((language) => language.toLowerCase().contains(q))
        .toList(growable: false);
  }
}
