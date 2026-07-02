import '../config/market/dublin_commuter_hubs.dart';
import '../models/spoken_language_entry.dart';
import '../services/commute_scoring_service.dart';
import 'commute_profile.dart';
import 'geo_math.dart';
import 'spoken_language_profile_codec.dart';

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

  static List<SpokenLanguageEntry> spokenLanguageEntries(
    Map<String, dynamic> session,
  ) =>
      SpokenLanguageProfileCodec.fromSession(session);

  static bool isProfileIncomplete(Map<String, dynamic>? session) =>
      !isMatchingReady(session);

  static bool isMatchingReady(Map<String, dynamic>? session) {
    if (session == null || session.isEmpty) return false;
    final hasCore = text(session['full_name']).isNotEmpty &&
        text(session['detected_city']).isNotEmpty &&
        text(session['mother_tongue']).isNotEmpty;
    if (!hasCore) return false;
    return languageList(session['spoken_languages']).isNotEmpty;
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

  static List<bool> _modernCompletionChecks(Map<String, dynamic> session) => [
        text(session['full_name']).isNotEmpty,
        text(session['email']).isNotEmpty,
        text(session['detected_city']).isNotEmpty ||
            text(session['current_area']).isNotEmpty,
        text(session['mother_tongue']).isNotEmpty,
        languageList(session['spoken_languages']).isNotEmpty,
        session['linkedin_verified'] == true ||
            (session['trust_stage'] is int &&
                (session['trust_stage'] as int) >= 2),
        maximumCommuteBudgetMinutes(session) != null,
        text(session['budget_min']).isNotEmpty &&
            text(session['budget_max']).isNotEmpty,
        text(session['occupant_type']).isNotEmpty,
        hasCommutePreferences(session),
      ];

  static List<String> missingMatchingFields(Map<String, dynamic>? session) {
    if (session == null) {
      return const [
        'Full name',
        'Mother tongue',
        'Languages spoken',
        'Commuter profiles',
      ];
    }
    final missing = <String>[];
    if (text(session['full_name']).isEmpty) missing.add('Full name');
    if (text(session['mother_tongue']).isEmpty) missing.add('Mother tongue');
    if (languageList(session['spoken_languages']).isEmpty) {
      missing.add('Languages spoken');
    }
    if (!hasCommutePreferences(session)) missing.add('Commuter profiles');
    return missing;
  }

  static List<String> missingFieldsForCompletion(Map<String, dynamic>? session) {
    if (session == null) {
      return const ['Full name', 'Email', 'City', 'Mother tongue', 'Languages spoken'];
    }
    final missing = <String>[];
    if (text(session['full_name']).isEmpty) missing.add('Full name');
    if (text(session['email']).isEmpty) missing.add('Email');
    if (text(session['detected_city']).isEmpty) missing.add('City');
    if (text(session['mother_tongue']).isEmpty) missing.add('Mother tongue');
    if (languageList(session['spoken_languages']).isEmpty) {
      missing.add('Languages spoken');
    }
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
      commuteProfiles(session).isNotEmpty;

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
