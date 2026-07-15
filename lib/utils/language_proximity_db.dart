/// Regional language proximity lookup for seeker fluent-language inference.
const Map<String, List<String>> languageProximityDb = {
  'gujarati': ['Hindi', 'Marathi'],
  'bengali': ['Hindi', 'Assamese'],
  'telugu': ['Tamil', 'Hindi', 'Malayalam'],
  'hindi': ['Urdu', 'Punjabi', 'Gujarati'],
  'punjabi': ['Hindi', 'Urdu'],
  'urdu': ['Hindi', 'Punjabi'],
  'marathi': ['Hindi', 'Gujarati'],
  'tamil': ['Malayalam', 'Telugu', 'Kannada'],
  'malayalam': ['Tamil', 'Kannada', 'Telugu'],
  'kannada': ['Telugu', 'Tamil', 'Malayalam'],
  'portuguese': ['Spanish', 'Italian'],
  'spanish': ['Portuguese', 'Italian', 'French'],
  'french': ['Spanish', 'Italian', 'German'],
  'italian': ['Spanish', 'French', 'Portuguese'],
  'ukrainian': ['Russian', 'Polish'],
  'polish': ['Ukrainian', 'Russian', 'Czech'],
  'chinese (mandarin)': ['Chinese (Cantonese)', 'Japanese'],
  'chinese (cantonese)': ['Chinese (Mandarin)'],
};

/// Spec alias for the proximity lookup table.
const Map<String, List<String>> LANGUAGE_PROXIMITY_DB = languageProximityDb;

/// Aliases that resolve to canonical [languageProximityDb] keys.
const Map<String, String> languageProximityAliases = {
  'mandarin': 'chinese (mandarin)',
  'cantonese': 'chinese (cantonese)',
};
