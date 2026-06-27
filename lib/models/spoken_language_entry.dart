/// A spoken language with optional native-speaker flag (Dublin demographics).
class SpokenLanguageEntry {
  const SpokenLanguageEntry({
    required this.language,
    this.isNative = false,
  });

  final String language;
  final bool isNative;

  Map<String, dynamic> toMap() => {
        'language': language,
        'is_native': isNative,
      };

  factory SpokenLanguageEntry.fromMap(Map<dynamic, dynamic> raw) {
    return SpokenLanguageEntry(
      language: raw['language']?.toString() ?? '',
      isNative: raw['is_native'] == true,
    );
  }
}
