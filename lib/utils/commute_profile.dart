import '../config/market/dublin_commuter_hubs.dart';
import '../services/commute_scoring_service.dart';
import 'geo_math.dart';
import 'profile_data.dart';

/// One commuter anchor in a household (primary seeker or partner).
class CommuteProfileEntry {
  const CommuteProfileEntry({
    required this.id,
    required this.label,
    required this.method,
    required this.hub,
    this.maxCommuteMinutes,
  });

  final String id;
  final String label;
  final CommuteMethod method;
  final DublinCommuterHub hub;
  final int? maxCommuteMinutes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'commute_method': method.toBackend(),
        'commute_destination_hub_id': hub.id,
        'commute_destination': hub.label,
        'destination_latitude': hub.latitude,
        'destination_longitude': hub.longitude,
        if (maxCommuteMinutes != null) 'max_commute_minutes': maxCommuteMinutes,
      };
}

/// Parses single- and multi-commute profile rows from session storage.
abstract final class CommuteProfileRegistry {
  static const primaryId = 'primary';
  static const partnerId = 'partner';

  /// Hubs farther apart than this are treated as opposite sides of Dublin.
  static const divergentHubDistanceKm = 6.0;

  static List<CommuteProfileEntry> fromSession(Map<String, dynamic>? session) {
    if (session == null || session.isEmpty) return const [];

    final fromArray = _fromProfilesArray(session['commute_profiles']);
    if (fromArray.isNotEmpty) return fromArray;

    final legacy = _fromLegacyPrimary(session);
    if (legacy == null) return const [];

    final partner = _fromLegacyPartner(session);
    if (partner != null) {
      return [legacy, partner];
    }
    return [legacy];
  }

  static bool hasMultiCommute(Map<String, dynamic>? session) =>
      fromSession(session).length >= 2;

  static bool hubsAreDivergent(List<CommuteProfileEntry> profiles) {
    if (profiles.length < 2) return false;
    for (var i = 0; i < profiles.length; i++) {
      for (var j = i + 1; j < profiles.length; j++) {
        final km = GeoMath.haversineKm(
          profiles[i].hub.location,
          profiles[j].hub.location,
        );
        if (km >= divergentHubDistanceKm) return true;
      }
    }
    return false;
  }

  static List<CommuteProfileEntry> _fromProfilesArray(dynamic raw) {
    if (raw is! List) return const [];

    final profiles = <CommuteProfileEntry>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final hub = DublinCommuterHubs.byId(
            map['commute_destination_hub_id']?.toString(),
          ) ??
          DublinCommuterHubs.resolveFromProfile(map);
      if (hub == null) continue;

      profiles.add(
        CommuteProfileEntry(
          id: ProfileData.text(map['id']).isEmpty
              ? 'commuter_${profiles.length + 1}'
              : ProfileData.text(map['id']),
          label: ProfileData.text(map['label']).isEmpty
              ? 'Commuter ${profiles.length + 1}'
              : ProfileData.text(map['label']),
          method: CommuteMethod.fromBackend(
            ProfileData.text(map['commute_method']),
          ),
          hub: hub,
        ),
      );
    }
    return profiles;
  }

  static CommuteProfileEntry? _fromLegacyPrimary(Map<String, dynamic> session) {
    final hub = ProfileData.commuteHub(session);
    if (hub == null) return null;
    return CommuteProfileEntry(
      id: primaryId,
      label: 'You',
      method: ProfileData.commuteMethod(session),
      hub: hub,
    );
  }

  static CommuteProfileEntry? _fromLegacyPartner(Map<String, dynamic> session) {
    final methodRaw = ProfileData.text(session['partner_commute_method']);
    if (methodRaw.isEmpty) return null;

    final hub = DublinCommuterHubs.byId(
          session['partner_commute_destination_hub_id']?.toString(),
        ) ??
        DublinCommuterHubs.resolveFromProfile({
          'commute_destination_hub_id':
              session['partner_commute_destination_hub_id'],
          'commute_destination': session['partner_commute_destination'],
          'destination_latitude': session['partner_destination_latitude'],
          'destination_longitude': session['partner_destination_longitude'],
        });
    if (hub == null) return null;

    return CommuteProfileEntry(
      id: partnerId,
      label: 'Partner',
      method: CommuteMethod.fromBackend(methodRaw),
      hub: hub,
    );
  }

  static List<Map<String, dynamic>> persistProfiles(
    List<CommuteProfileEntry> profiles,
  ) =>
      profiles.map((profile) => profile.toMap()).toList(growable: false);
}
