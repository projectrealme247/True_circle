/// Safe parsing and display helpers for profile fields.
abstract final class ProfileData {
  static const notProvided = 'Not provided';

  static const profileKeys = [
    'full_name',
    'email',
    'detected_city',
    'native_place',
    'mother_tongue',
    'food_preference',
    'spoken_languages',
  ];

  /// Returns null when storage is empty or has no displayable profile fields.
  static Map<String, dynamic>? normalize(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return null;

    final hasProfileContent = profileKeys.any((key) {
      if (!raw.containsKey(key)) return false;
      final value = raw[key];
      if (value is List) return value.isNotEmpty;
      return text(value).isNotEmpty;
    });

    if (!hasProfileContent) return null;

    return Map<String, dynamic>.from(raw);
  }

  static String text(dynamic value) {
    if (value == null) return '';
    final raw = value.toString().trim();
    if (raw.isEmpty || raw == 'null') return '';
    return raw;
  }

  static String display(dynamic value) {
    final parsed = text(value);
    return parsed.isEmpty ? notProvided : parsed;
  }

  static List<String> languageList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.map((e) => text(e)).where((s) => s.isNotEmpty).toList();
    }

    final asString = text(value);
    if (asString.isEmpty) return [];

    return asString
        .split(RegExp(r'[,;]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  static String displayLanguages(dynamic value) {
    final languages = languageList(value);
    if (languages.isEmpty) return notProvided;
    return languages.join(', ');
  }

  static bool isNotProvided(String value) => value == notProvided;
}
