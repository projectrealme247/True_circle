import '../config/market/dublin_commuter_hubs.dart';
import '../models/seeker_onboarding_enums.dart';
import '../models/spoken_language_entry.dart';
import '../services/commute_scoring_service.dart';
import 'commute_profile.dart';
import 'spoken_language_profile_codec.dart';

/// Safe parsing and display helpers for profile fields.
abstract final class ProfileData {
  static const notProvided = 'Not provided';

  static const profileKeys = [
    'full_name',
    'email',
    'detected_city',
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

  static List<SpokenLanguageEntry> spokenLanguageEntries(
    Map<String, dynamic> session,
  ) =>
      SpokenLanguageProfileCodec.fromSession(session);

  static bool isProfileIncomplete(Map<String, dynamic>? session) =>
      !isMatchingReady(session);

  /// True when the session has any identity / onboarding content worth showing
  /// on `/profile`. Distinct from [isMatchingReady] (five essentials).
  static bool hasRenderableProfileContent(Map<String, dynamic>? session) {
    if (session == null || session.isEmpty) return false;
    if (normalize(session) != null) return true;
    if (text(session['full_name']).isNotEmpty) return true;
    if (text(session['email']).isNotEmpty) return true;
    return hasListingTypeSelected(session) ||
        hasPersonaSelected(session) ||
        hasBudgetSet(session) ||
        hasDestinationSet(session) ||
        hasMoveInWindowSet(session);
  }

  /// Ready when the five seeker onboarding essentials are present.
  /// English is assumed — mother tongue / primary language is never required.
  static bool isMatchingReady(Map<String, dynamic>? session) {
    if (session == null || session.isEmpty) return false;
    return _modernCompletionChecks(session).every((check) => check);
  }

  static int calculateProfileCompletionPercentage(Map<String, dynamic>? session) {
    if (session == null) return 0;
    final checks = _modernCompletionChecks(session);
    if (checks.isEmpty) return 0;
    final filled = checks.where((check) => check).length;
    return ((filled / checks.length) * 100).round().clamp(0, 100);
  }

  static int profileCompletenessPercent(Map<String, dynamic>? session) =>
      calculateProfileCompletionPercentage(session);

  /// Seeker completion essentials (order matches [missingFieldsForCompletion]).
  static List<bool> _modernCompletionChecks(Map<String, dynamic> session) => [
        hasListingTypeSelected(session),
        hasPersonaSelected(session),
        hasBudgetSet(session),
        hasDestinationSet(session),
        hasMoveInWindowSet(session),
      ];

  static bool hasListingTypeSelected(Map<String, dynamic>? session) {
    if (session == null) return false;
    final propType = text(session['preferred_property_type']);
    if (propType == 'Share' || propType == 'Rent') return true;
    final arrangement = text(session['preferred_arrangement']).toLowerCase();
    if (arrangement.contains('shared') ||
        arrangement.contains('room') ||
        arrangement.contains('entire') ||
        arrangement.contains('place') ||
        arrangement.contains('apartment')) {
      return true;
    }
    return text(session['active_marketplace_space']).isNotEmpty;
  }

  static bool hasPersonaSelected(Map<String, dynamic>? session) =>
      SeekerPersona.fromSession(session) != null;

  static bool hasBudgetSet(Map<String, dynamic>? session) {
    if (session == null) return false;
    return text(session['budget_min']).isNotEmpty &&
        text(session['budget_max']).isNotEmpty;
  }

  static bool hasDestinationSet(Map<String, dynamic>? session) =>
      hasCommutePreferences(session);

  static bool hasMoveInWindowSet(Map<String, dynamic>? session) =>
      MoveInBucket.fromSession(session) != null;

  static List<String> missingMatchingFields(Map<String, dynamic>? session) =>
      missingFieldsForCompletion(session);

  static List<String> missingFieldsForCompletion(Map<String, dynamic>? session) {
    if (session == null) {
      return const [
        'Listing type',
        'Persona',
        'Budget',
        'Destination',
        'Move-in window',
      ];
    }
    final missing = <String>[];
    if (!hasListingTypeSelected(session)) missing.add('Listing type');
    if (!hasPersonaSelected(session)) missing.add('Persona');
    if (!hasBudgetSet(session)) missing.add('Budget');
    if (!hasDestinationSet(session)) missing.add('Destination');
    if (!hasMoveInWindowSet(session)) missing.add('Move-in window');
    return missing;
  }

  static CommuteMethod commuteMethod(Map<String, dynamic>? session) =>
      CommuteMethod.fromBackend(text(session?['commute_method']));

  static int? maximumCommuteBudgetMinutes(Map<String, dynamic>? session) {
    final raw = session?['maximum_commute_budget_minutes'];
    if (raw is int) return raw;
    return int.tryParse(text(raw));
  }

  static bool identityAnchorMatches(
    String profileFullName,
    String bankHolderName,
  ) {
    String normalize(String name) => name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final tokens = normalize(profileFullName)
        .split(' ')
        .where((token) => token.length > 1)
        .toList();
    if (tokens.isEmpty) return false;

    final haystack = normalize(bankHolderName);
    final required = tokens.length >= 2
        ? [tokens.first, tokens.last]
        : tokens;
    return required.every(haystack.contains);
  }

  static bool isSharedRoomSeeker(Map<String, dynamic>? session) {
    if (session == null) return false;
    final arrangement = text(session['preferred_arrangement']).toLowerCase();
    if (arrangement.contains('shared') || arrangement.contains('room')) {
      return true;
    }
    return text(session['preferred_property_type']) == 'Share';
  }

  static List<String> displayOtherLanguages(Map<String, dynamic>? session) {
    if (session == null) return const [];
    final mother = text(session['mother_tongue']).toLowerCase();
    return languageList(session['spoken_languages'])
        .where((language) => language.toLowerCase() != mother)
        .toList();
  }

  static DublinCommuterHub? commuteHub(Map<String, dynamic>? session) {
    if (session == null) return null;
    return DublinCommuterHubs.byId(
          session['commute_destination_hub_id']?.toString(),
        ) ??
        DublinCommuterHubs.resolveFromProfile(session);
  }

  static bool hasCommutePreferences(Map<String, dynamic>? session) =>
      !commuteDestinationUnknown(session) &&
      commuteProfiles(session).isNotEmpty;

  static bool commuteDestinationUnknown(Map<String, dynamic>? session) =>
      session?['commute_destination_unknown'] == true;

  static List<CommuteProfileEntry> commuteProfiles(
    Map<String, dynamic>? session,
  ) =>
      CommuteProfileRegistry.fromSession(session);

  static int? commuteMinutesFromListing(
    Map<String, dynamic>? session,
    LatLng property,
  ) {
    final profiles = commuteProfiles(session);
    if (profiles.isEmpty) return null;

    var worst = 0;
    for (final profile in profiles) {
      final minutes = CommuteScoringService.calculateCommuteMinutesToHub(
        property,
        profile.hub,
        profile.method,
      );
      if (minutes > worst) worst = minutes;
    }
    return worst;
  }
}
