import 'package:flutter/foundation.dart';

import '../data/dublin_mock_data.dart';
import '../models/marketplace_space.dart';
import '../models/profile_onboarding_models.dart';
import '../services/listings_storage_service.dart';
import '../services/replacement_workflow_service.dart';
import '../utils/numeric_bounds.dart';
import 'profile_storage_service.dart';
import 'user_session_store.dart';

/// Unified marketplace viewport state: active space + derived workflows.
class MarketplaceContextNotifier extends ChangeNotifier {
  MarketplaceSpace _activeSpace = MarketplaceSpace.fullRental;
  Map<String, dynamic>? _session;
  List<Map<String, dynamic>> _ownedListings = const [];
  Set<MarketplaceWorkflow> _activeWorkflows = {MarketplaceWorkflow.browsing};
  ReplacementWorkflow? _replacementProgress;

  MarketplaceSpace get activeSpace => _activeSpace;

  /// Explicit user choice from [active_marketplace_space]; null until gateway pick.
  MarketplaceSpace? get lastActiveSpace =>
      _readStoredSpace(_session ?? UserSessionStore.current);

  Map<String, dynamic>? get session => _session;
  List<Map<String, dynamic>> get ownedListings => _ownedListings;
  Set<MarketplaceWorkflow> get activeWorkflows => _activeWorkflows;
  ReplacementWorkflow? get replacementProgress => _replacementProgress;

  bool get isManaging => _activeWorkflows.contains(MarketplaceWorkflow.managing);
  bool get isReplacing =>
      _activeWorkflows.contains(MarketplaceWorkflow.replacing);
  int get ownedListingCount => _ownedListings.length;

  Future<void> refresh() async {
    _session = UserSessionStore.current == null
        ? null
        : Map<String, dynamic>.from(UserSessionStore.current!);
    _activeSpace = _readStoredSpace(_session) ??
        MarketplaceSpace.fromSession(_session);

    _ownedListings = await ListingsStorageService.ownedByCurrentUser(_session);
    if (DublinMockData.useMockHarness && _ownedListings.isEmpty) {
      _ownedListings = DublinMockData.ownedListingsForHost();
    }
    _replacementProgress =
        await ReplacementWorkflowService.activeForUser(_session);

    _activeWorkflows = {MarketplaceWorkflow.browsing};
    if (_ownedListings.isNotEmpty) {
      _activeWorkflows.add(MarketplaceWorkflow.managing);
    }
    if (_replacementProgress != null) {
      _activeWorkflows.add(MarketplaceWorkflow.replacing);
    }
    notifyListeners();
  }

  Future<void> setActiveSpace(MarketplaceSpace space) async {
    _activeSpace = space;
    final current = Map<String, dynamic>.from(
      _session ?? UserSessionStore.current ?? {},
    );
    current['active_marketplace_space'] = space.storageToken;
    current['preferred_arrangement'] = space.arrangementBackend;
    current['preferred_property_type'] = space.towerPropertyType;
    _session = current;
    UserSessionStore.current = current;
    await ProfileStorageService.save(current);
    notifyListeners();
  }

  MarketplaceSpace? _readStoredSpace(Map<String, dynamic>? session) {
    if (session == null) return null;
    final token = session['active_marketplace_space']?.toString();
    if (token == null || token.isEmpty) return null;
    return MarketplaceSpace.fromStorageToken(token);
  }

  static MarketplaceSpace spaceFromOnboardingTrack(ProfileOnboardingTrack track) {
    return track.isSharedSpace
        ? MarketplaceSpace.sharedSpace
        : MarketplaceSpace.fullRental;
  }

  Future<void> syncSpaceFromOnboardingTrack(ProfileOnboardingTrack track) =>
      setActiveSpace(spaceFromOnboardingTrack(track));

  double clampedMatchPercent(num value) => NumericBounds.clampPercent(value);
}

final marketplaceContextNotifier = MarketplaceContextNotifier();
