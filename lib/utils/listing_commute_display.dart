import '../config/market/dublin_commuter_hubs.dart';
import '../config/market/market_config.dart';
import '../services/commute_scoring_service.dart';
import '../services/transit_extraction_service.dart';
import 'listing_data.dart';
import 'profile_data.dart';

enum CommuteDisplayKind { personalizedSeeker, propertyTransitFallback }

/// One commuter row on the listing detail card.
class CommuteDisplayRow {
  const CommuteDisplayRow({
    required this.commuterLabel,
    required this.minutes,
    required this.headline,
    this.commuteMethod,
    this.parkingWarning,
    this.exceedsBudget = false,
    this.budgetMinutes,
  });

  final String commuterLabel;
  final int minutes;
  final String headline;
  final CommuteMethod? commuteMethod;
  final String? parkingWarning;
  final bool exceedsBudget;
  final int? budgetMinutes;
}

/// Unified transit presentation for listing detail (1..N commuters).
class MultiCommuteDisplayModel {
  const MultiCommuteDisplayModel({
    required this.rows,
    required this.kind,
    this.subtitle,
    this.metadata,
  });

  final List<CommuteDisplayRow> rows;
  final CommuteDisplayKind kind;
  final String? subtitle;
  final MultiCommuteScorePayload? metadata;

  bool get isPersonalized => kind == CommuteDisplayKind.personalizedSeeker;
  bool get isEmpty => rows.isEmpty;
}

/// Computes on-the-fly commute badges from seeker profile + listing coordinates.
abstract final class ListingCommuteDisplay {
  /// Verbatim over-budget copy for grid cards and listing detail.
  static String overBudgetLabel(int minutes, int budgetMinutes) =>
      '⚠️ $minutes mins door-to-door (Exceeds your ${budgetMinutes}m budget)';

  /// Worst-case door-to-door warning for feed cards (sync, no async lag).
  static String? overBudgetWarningForListing({
    required Map<String, dynamic> listing,
    required Map<String, dynamic>? viewerSession,
  }) {
    if (MarketConfig.current.id != MarketId.dublin) return null;
    if (_isOwnListing(listing, viewerSession)) return null;

    final budget = ProfileData.maximumCommuteBudgetMinutes(viewerSession);
    if (budget == null || !ProfileData.hasCommutePreferences(viewerSession)) {
      return null;
    }

    final property = ListingData.listingCoordinates(listing);
    if (property == null) return null;

    final minutes = ProfileData.commuteMinutesFromListing(viewerSession, property);
    if (minutes == null || minutes <= budget) return null;

    return overBudgetLabel(minutes, budget);
  }

  static Future<MultiCommuteDisplayModel?> resolveAsync({
    required Map<String, dynamic> listing,
    required Map<String, dynamic>? viewerSession,
  }) async {
    if (MarketConfig.current.id != MarketId.dublin) return null;

    final property = ListingData.listingCoordinates(listing);
    final isOwner = _isOwnListing(listing, viewerSession);
    final profiles = ProfileData.commuteProfiles(viewerSession);
    final parkingAvailable = ListingData.parkingAvailable(listing);

    if (!isOwner && profiles.isNotEmpty && property != null) {
      final budget = ProfileData.maximumCommuteBudgetMinutes(viewerSession);
      final payload = await CommuteScoringService.calculateMultiCommuteMinutesAsync(
        propertyLoc: property,
        profiles: profiles,
        parkingAvailable: parkingAvailable,
        dualCommutePriority: ListingData.dualCommutePriority(viewerSession),
        budgetForProfile: (profile, index) =>
            ListingData.commuteBudgetMinutesForProfile(profile, viewerSession),
      );

      if (payload.results.isEmpty) return null;

      final rows = payload.results.map((result) {
        return _personalizedRow(
          commuterLabel: result.profileLabel,
          minutes: result.minutes,
          method: result.method,
          hub: result.hub,
          budgetMinutes: budget,
          parkingWarning: result.parkingConflict
              ? CommuteScoringService.parkingConflictWarning
              : null,
        );
      }).toList(growable: false);

      return MultiCommuteDisplayModel(
        rows: rows,
        kind: CommuteDisplayKind.personalizedSeeker,
        subtitle: rows.length > 1
            ? 'Door-to-door for each commuter in your household'
            : 'Door-to-door from this property',
        metadata: payload,
      );
    }

    final fallback = _propertyTransitFallback(listing, property);
    if (fallback == null) return null;
    return MultiCommuteDisplayModel(
      rows: [fallback],
      kind: CommuteDisplayKind.propertyTransitFallback,
      subtitle: fallback.commuterLabel,
    );
  }

  /// Synchronous resolver for lightweight callers (single-profile fast path).
  static MultiCommuteDisplayModel? resolve({
    required Map<String, dynamic> listing,
    required Map<String, dynamic>? viewerSession,
  }) {
    if (MarketConfig.current.id != MarketId.dublin) return null;

    final property = ListingData.listingCoordinates(listing);
    final isOwner = _isOwnListing(listing, viewerSession);
    final profiles = ProfileData.commuteProfiles(viewerSession);
    final parkingAvailable = ListingData.parkingAvailable(listing);

    if (!isOwner && profiles.isNotEmpty && property != null) {
      final budget = ProfileData.maximumCommuteBudgetMinutes(viewerSession);
      final payload = CommuteScoringService.calculateMultiCommuteMinutes(
        propertyLoc: property,
        profiles: profiles,
        parkingAvailable: parkingAvailable,
        dualCommutePriority: ListingData.dualCommutePriority(viewerSession),
        budgetForProfile: (profile, index) =>
            ListingData.commuteBudgetMinutesForProfile(profile, viewerSession),
      );

      if (payload.results.isEmpty) return null;

      final rows = payload.results.map((result) {
        return _personalizedRow(
          commuterLabel: result.profileLabel,
          minutes: result.minutes,
          method: result.method,
          hub: result.hub,
          budgetMinutes: budget,
          parkingWarning: result.parkingConflict
              ? CommuteScoringService.parkingConflictWarning
              : null,
        );
      }).toList(growable: false);

      return MultiCommuteDisplayModel(
        rows: rows,
        kind: CommuteDisplayKind.personalizedSeeker,
        subtitle: rows.length > 1
            ? 'Door-to-door for each commuter in your household'
            : 'Door-to-door from this property',
        metadata: payload,
      );
    }

    final fallback = _propertyTransitFallback(listing, property);
    if (fallback == null) return null;
    return MultiCommuteDisplayModel(
      rows: [fallback],
      kind: CommuteDisplayKind.propertyTransitFallback,
      subtitle: 'Nearest rapid transit from this address',
    );
  }

  static CommuteDisplayRow? _propertyTransitFallback(
    Map<String, dynamic> listing,
    LatLng? property,
  ) {
    var walkMinutes = ListingData.transitWalkMinutes(listing);
    var transitType = ListingData.transitTypeLabel(listing);

    if ((walkMinutes == null || transitType.isEmpty) && property != null) {
      final extracted = TransitExtractionService.extractLocally(
        latitude: property.latitude,
        longitude: property.longitude,
      );
      if (extracted != null) {
        final walk = extracted['walk_minutes'];
        if (walk is num) walkMinutes = walk.round();
        transitType = extracted['transit_type']?.toString() ?? transitType;
      }
    }

    if (walkMinutes == null || transitType.isEmpty) {
      final profile = ListingData.detailTransitWalkProfile(listing);
      if (profile != null) {
        walkMinutes = profile.minutes;
        transitType = profile.destination;
      }
    }

    if (walkMinutes == null || transitType.isEmpty) return null;

    return CommuteDisplayRow(
      commuterLabel: 'Property transit',
      minutes: walkMinutes,
      headline: '$walkMinutes-min walk to $transitType',
    );
  }

  static CommuteDisplayRow _personalizedRow({
    required String commuterLabel,
    required int minutes,
    required CommuteMethod method,
    required DublinCommuterHub hub,
    required int? budgetMinutes,
    String? parkingWarning,
  }) {
    final budget = budgetMinutes;
    final exceeds = budget != null && minutes > budget;
    return CommuteDisplayRow(
      commuterLabel: commuterLabel,
      minutes: minutes,
      headline: exceeds
          ? overBudgetLabel(minutes, budget)
          : _personalizedHeadline(method, minutes, hub),
      commuteMethod: method,
      parkingWarning: parkingWarning,
      exceedsBudget: exceeds,
      budgetMinutes: budgetMinutes,
    );
  }

  static String _personalizedHeadline(
    CommuteMethod method,
    int minutes,
    DublinCommuterHub hub,
  ) {
    switch (method) {
      case CommuteMethod.driving:
        final route = _drivingRouteHint(hub);
        return '$minutes mins to ${_shortHubLabel(hub)} $route';
      case CommuteMethod.publicTransportWalking:
        return '$minutes mins to ${_seekerDestinationPhrase(hub)}';
    }
  }

  static String _seekerDestinationPhrase(DublinCommuterHub hub) {
    switch (hub.id) {
      case 'grand_canal_dock':
      case 'silicon_docks':
        return 'your office (${hub.label})';
      case 'ucd':
        return 'UCD';
      case 'tcd':
        return 'TCD';
      case 'st_stephens_green':
        return 'city centre (${hub.label})';
      case 'cherrywood_business_park':
        return 'Cherrywood Business Park';
      default:
        return hub.label;
    }
  }

  static String _shortHubLabel(DublinCommuterHub hub) {
    switch (hub.id) {
      case 'tcd':
        return 'TCD';
      case 'ucd':
        return 'UCD';
      case 'grand_canal_dock':
        return 'Grand Canal Dock';
      case 'silicon_docks':
        return 'Silicon Docks';
      case 'st_stephens_green':
        return "St. Stephen's Green";
      case 'cherrywood_business_park':
        return 'Cherrywood';
      default:
        return hub.label;
    }
  }

  static String _drivingRouteHint(DublinCommuterHub hub) {
    switch (hub.id) {
      case 'ucd':
      case 'cherrywood_business_park':
        return 'via M50';
      case 'silicon_docks':
      case 'grand_canal_dock':
        return 'via Docklands';
      default:
        return 'via city route';
    }
  }

  static bool _isOwnListing(
    Map<String, dynamic> listing,
    Map<String, dynamic>? session,
  ) {
    if (session == null || session.isEmpty) return false;

    final userId = ProfileData.text(session['supabase_user_id']);
    for (final key in ['owner_user_id', 'user_id']) {
      final ownerId = ProfileData.text(listing[key]);
      if (userId.isNotEmpty && ownerId.isNotEmpty && ownerId == userId) {
        return true;
      }
    }

    final host = ListingData.hostName(listing).trim().toLowerCase();
    final fullName = ProfileData.text(session['full_name']).trim().toLowerCase();
    return fullName.isNotEmpty && host.isNotEmpty && host == fullName;
  }
}
