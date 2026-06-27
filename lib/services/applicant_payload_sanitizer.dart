import '../models/listing_creation_field_keys.dart';
import 'listing_creation_validation_service.dart';
import '../utils/profile_data.dart';
import '../utils/spoken_language_profile_codec.dart';

/// Sanitizes applicant/listing payloads before stream ranking calculations.
abstract final class ApplicantPayloadSanitizer {
  static const moveInWindowDays = 14;

  /// Strips deprecated kitchen utility keys and returns a defensive copy.
  static Map<String, dynamic> sanitizeSession(Map<String, dynamic> raw) {
    return ListingCreationValidationService.stripForbiddenKeys(
      Map<String, dynamic>.from(raw),
    );
  }

  /// Runs seeker/listing language arrays through [sanitizeLanguages].
  static List<String> sanitizeLanguageList(dynamic raw) {
    return ListingCreationValidationService.sanitizeLanguages(
      ProfileData.languageList(raw),
    );
  }

  static List<String> seekerLanguagesFromSession(Map<String, dynamic> session) {
    final sanitized = SpokenLanguageProfileCodec.fromSession(session);
    return SpokenLanguageProfileCodec.sanitizeLanguageLabels(sanitized);
  }

  static List<String> listingLanguagesFromRow(Map<String, dynamic> listing) {
    final fromColumn = listing[ListingCreationFieldKeys.languagesSpoken];
    if (fromColumn is List) {
      return sanitizeLanguageList(fromColumn);
    }

    final legacy = listing['languages_spoken'];
    if (legacy is List) {
      return sanitizeLanguageList(legacy);
    }

    return const [];
  }

  static List<String> languageIntersection(
    List<String> seekerLanguages,
    List<String> listingLanguages,
  ) {
    if (seekerLanguages.isEmpty || listingLanguages.isEmpty) return const [];

    final listingLower = listingLanguages.map((l) => l.toLowerCase()).toSet();
    return [
      for (final lang in seekerLanguages)
        if (listingLower.contains(lang.toLowerCase())) lang,
    ];
  }
}
