import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/applicant_management_controller.dart';
import '../services/application_lifecycle_service.dart';
import '../core/theme/app_theme.dart' show AppColors;
import '../data/dublin_mock_data.dart';
import '../data/mock_applicant_seeder.dart';
import '../models/applicant_application_status.dart';
import '../models/independent_places_applicant_stream.dart';
import '../models/landlord_applicant_card_model.dart';
import '../models/landlord_recommendation_state.dart';
import '../models/listing_creation_category.dart';
import '../models/shared_living_applicant_stream.dart';
import '../navigation/home_primary_destination.dart';
import '../navigation/navigate_after_identity.dart';
import '../services/active_mode_service.dart';
import '../services/application_service.dart';
import '../services/auth_service.dart';
import '../services/listing_applications_service.dart';
import '../services/listings_storage_service.dart';
import '../services/qa_test_auth_service.dart';
import '../services/local_applicant_stream_service.dart';
import '../services/profile_onboarding_repository.dart';
import '../services/profile_state_notifier.dart';
import '../models/profile_onboarding_models.dart';
import '../screens/auth_screen.dart';
import '../utils/listing_data.dart';
import '../utils/landlord_queue_buckets.dart';
import '../utils/profile_data.dart';
import '../utils/profile_progress.dart';
import '../utils/viewing_invitation.dart';
import '../widgets/landlord_dashboard/invite_viewing_sheet.dart';
import '../utils/seeker_strong_match_aggregator.dart';
import '../utils/landlord_dashboard_helpers.dart';
import '../widgets/active_mode/active_mode_switch.dart';
import '../widgets/home/home_profile_completion_banner.dart';
import '../widgets/landlord_dashboard/landlord_dashboard_theme.dart';
import '../widgets/landlord_dashboard/landlord_dashboard_top_nav.dart';
import '../widgets/landlord_dashboard/landlord_decision_workspace.dart';
import '../widgets/landlord_dashboard/landlord_listings_rail.dart';

/// Premium landlord decision workspace — who to invite next.
class LandlordDashboardScreen extends StatefulWidget {
  const LandlordDashboardScreen({
    super.key,
    this.initialListingId,
  });

  final String? initialListingId;

  @override
  State<LandlordDashboardScreen> createState() => _LandlordDashboardScreenState();
}

class _ListingStreamPayload {
  const _ListingStreamPayload({
    required this.category,
    this.independent,
    this.shared,
    required this.noiseDeflected,
    required this.metrics,
  });

  final ListingCreationCategory category;
  final IndependentPlacesApplicantStream? independent;
  final SharedLivingApplicantStream? shared;
  final int noiseDeflected;
  final LandlordStreamMetrics metrics;
}

class _LandlordDashboardScreenState extends State<LandlordDashboardScreen> {
  final _payloadsByListingId = <String, _ListingStreamPayload>{};
  final _selectedApplicantByListing = <String, String>{};

  List<Map<String, dynamic>> _listings = const [];
  int _selectedIndex = 0;
  bool _loading = true;
  String? _actionLoadingId;
  String? _loadError;
  int _hostApplicantCount = 0;
  int _seekerStrongMatchCount = 0;

  @override
  void initState() {
    super.initState();
    profileStateNotifier.addListener(_onProfileChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    profileStateNotifier.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final session = profileStateNotifier.session;
      var listings =
          await ListingsStorageService.ownedByCurrentUser(session);
      if (listings.isEmpty &&
          DublinMockData.useMockHarness &&
          QaTestAuthService.allowMockHostListings(session)) {
        listings = DublinMockData.ownedListingsForHost();
      }
      final initialId = widget.initialListingId;
      if (DublinMockData.useMockHarness &&
          QaTestAuthService.allowMockHostListings(session) &&
          initialId == DublinMockData.listingId &&
          !listings.any((l) => l['id']?.toString() == DublinMockData.listingId)) {
        listings = [...DublinMockData.ownedListingsForHost(), ...listings];
      }

      final payloads = <String, _ListingStreamPayload>{};
      for (final listing in listings) {
        final id = listing['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        payloads[id] = await _loadPayloadForListing(listing);
      }

      var selected = 0;
      if (initialId != null && initialId.isNotEmpty) {
        final idx = listings.indexWhere((l) => l['id']?.toString() == initialId);
        if (idx >= 0) selected = idx;
      }

      if (!mounted) return;
      setState(() {
        _listings = listings;
        _payloadsByListingId
          ..clear()
          ..addAll(payloads);
        _selectedIndex = selected;
        _loading = false;
      });
      await _refreshCrossModeBadges(listings);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _refreshCrossModeBadges(List<Map<String, dynamic>> listings) async {
    await applicationService.ensureLoaded();
    var applicantCount = 0;
    for (final listing in listings) {
      applicantCount +=
          applicationService.rowsForListing(ListingData.id(listing)).length;
    }
    final strongMatches = await SeekerStrongMatchAggregator.countForSession(
      profileStateNotifier.session,
    );
    if (!mounted) return;
    setState(() {
      _hostApplicantCount = applicantCount;
      _seekerStrongMatchCount = strongMatches;
    });
  }

  Widget? _buildModeSwitch() {
    final session = profileStateNotifier.session;
    final caps = ActiveModeService.capabilitiesFor(session);
    if (!caps.isDualCapable) return null;
    final unread = ActiveModeService.unreadActivityFor(
      session: session,
      activeMode: ActiveModeService.current,
      hostApplicantCount: _hostApplicantCount,
      seekerStrongMatchCount: _seekerStrongMatchCount,
    );
    return ActiveModeSwitch(
      current: ActiveModeService.current,
      unread: unread,
      canSeek: caps.canSeek,
      canHost: caps.canHost,
      compact: true,
      applicationsCount: applicationService
          .getUserApplications(AuthService.identityUserId())
          .where((app) {
        final status = ApplicantApplicationStatus.parseOrDefault(
          applicationService.rowById(app.id)?['status']?.toString(),
        );
        return status != ApplicantApplicationStatus.declined;
      }).length,
      onApplicationsSelected: caps.canSeek
          ? () async {
              await ActiveModeService.setMode(ActiveMode.explore);
              requestHomeApplicationsTab();
              if (!mounted) return;
              context.go('/');
            }
          : null,
      onModeSelected: (mode) async {
        await ActiveModeService.recordUnreadBaselines(
          hostApplicantCount: _hostApplicantCount,
          seekerStrongMatchCount: _seekerStrongMatchCount,
        );
        if (!mounted) return;
        await navigateForActiveMode(context, mode);
      },
    );
  }

  Widget? _buildHostProfileBanner() {
    final session = profileStateNotifier.session;
    final signedIn = AuthService.isSignedIn(session);
    final state = ProfileProgress.hostBannerState(
      session,
      signedIn: signedIn,
      ownedListingCount: _listings.length,
    );
    if (HomeProfileCompletionBannerSession.hostDismissed ||
        state == HomeOnboardingBannerState.hidden ||
        state == HomeOnboardingBannerState.signInRequired) {
      return null;
    }
    final percent = ProfileProgress.hostPercent(session);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1360),
        child: HomeProfileCompletionBanner(
          percent: percent,
          audience: ProfileCompletionAudience.host,
          onContinue: () {
            // Independent Places: host name is collected on Add Listing.
            // Shared Living keeps the dedicated host profile screen.
            final track = session == null
                ? ProfileOnboardingTrack.landlordEntirePlace
                : ProfileOnboardingRepository.resolveHostTrack(session);
            if (track == ProfileOnboardingTrack.landlordSharedSpace) {
              final extra = session;
              if (extra != null && extra.isNotEmpty) {
                context.push('/profile/edit/host', extra: extra);
              } else {
                context.push('/profile/edit/host');
              }
            } else {
              context.push('/add-listing');
            }
          },
          onDismiss: () {
            HomeProfileCompletionBannerSession.hostDismissed = true;
            setState(() {});
          },
        ),
      ),
    );
  }

  Future<_ListingStreamPayload> _loadPayloadForListing(
    Map<String, dynamic> listing,
  ) async {
    final listingId = listing['id']?.toString() ?? '';
    final category = LandlordDashboardHelpers.categoryForListing(listing);
    final rawApplications =
        await ListingApplicationsService.forListing(listingId);
    final hasRealApps = rawApplications.isNotEmpty;
    final useSeeded = LocalApplicantStreamService.useSeededFallback(
      listingId: listingId,
      hasRealApplications: hasRealApps,
    );

    if (category.isShared) {
      var stream = hasRealApps
          ? LocalApplicantStreamService.sharedStream(
              listing: listing,
              applicationRows: rawApplications,
            )
          : useSeeded
              ? (DublinMockData.isHarnessListing(listingId)
                  ? DublinMockData.resolveApplicantStream()
                  : MockApplicantSeeder.sharedLivingStream(
                      listingId: listingId,
                      dense: true,
                    ))
              : LocalApplicantStreamService.sharedStream(
                  listing: listing,
                  applicationRows: rawApplications,
                );
      if (stream.totalCount == 0 &&
          useSeeded &&
          DublinMockData.useMockHarness &&
          DublinMockData.isHarnessListing(listingId)) {
        stream = DublinMockData.fallbackApplicantStream();
      }
      final noise = LandlordDashboardHelpers.noiseDeflectedCount(
        listing: listing,
        rawApplications: rawApplications,
        streamCount: stream.totalCount,
      );
      return _ListingStreamPayload(
        category: category,
        shared: stream,
        noiseDeflected: noise,
        metrics: LandlordDashboardHelpers.metricsFromShared(
          stream: stream,
          noiseDeflected: noise,
          archivedIds: const {},
        ),
      );
    }

    final stream = hasRealApps
        ? LocalApplicantStreamService.independentStream(
            listing: listing,
            applicationRows: rawApplications,
          )
        : useSeeded
            ? MockApplicantSeeder.independentPlacesStream(
                listingId: listingId,
                dense: true,
              )
            : LocalApplicantStreamService.independentStream(
                listing: listing,
                applicationRows: rawApplications,
              );
    final noise = LandlordDashboardHelpers.noiseDeflectedCount(
      listing: listing,
      rawApplications: rawApplications,
      streamCount: stream.totalCount,
    );
    return _ListingStreamPayload(
      category: category,
      independent: stream,
      noiseDeflected: noise,
      metrics: LandlordDashboardHelpers.metricsFromIndependent(
        stream: stream,
        noiseDeflected: noise,
        archivedIds: const {},
      ),
    );
  }

  _ListingStreamPayload? get _currentPayload {
    if (_listings.isEmpty) return null;
    final id = _listings[_selectedIndex]['id']?.toString();
    if (id == null) return null;
    return _payloadsByListingId[id];
  }

  String get _currentListingId =>
      _listings.isEmpty ? '' : _listings[_selectedIndex]['id']?.toString() ?? '';

  List<LandlordApplicantCardModel> _applicantsForListing(
    String listingId,
    _ListingStreamPayload payload,
  ) {
    final List<LandlordApplicantCardModel> all;
    if (payload.category.isShared && payload.shared != null) {
      all = LandlordApplicantCardModel.fromSharedStream(payload.shared!);
    } else if (payload.independent != null) {
      all = LandlordApplicantCardModel.fromIndependentStream(payload.independent!);
    } else {
      all = const [];
    }

    var filtered = all.toList();

    if (filtered.isEmpty &&
        all.isEmpty &&
        LocalApplicantStreamService.useSeededFallback(
          listingId: listingId,
          hasRealApplications: false,
        ) &&
        DublinMockData.useMockHarness &&
        DublinMockData.isHarnessListing(listingId)) {
      filtered = LandlordApplicantCardModel.fromSharedStream(
        DublinMockData.fallbackApplicantStream(),
      );
    }

    filtered.sort((a, b) {
      final ra = LandlordRecommendationResolver.resolve(a.decision);
      final rb = LandlordRecommendationResolver.resolve(b.decision);
      final cmp = _recommendationSortKey(ra).compareTo(_recommendationSortKey(rb));
      if (cmp != 0) return cmp;
      return b.matchPercent.compareTo(a.matchPercent);
    });

    return filtered;
  }

  static int _recommendationSortKey(LandlordRecommendationState state) =>
      switch (state) {
        LandlordRecommendationState.inviteReady => 0,
        LandlordRecommendationState.timingConflict => 1,
        LandlordRecommendationState.affordabilityReview => 2,
        LandlordRecommendationState.guarantorReview => 3,
        LandlordRecommendationState.review => 4,
        LandlordRecommendationState.notSuitable => 5,
      };

  List<LandlordListingRailItem> _buildRailItems() {
    return [
      for (final listing in _listings)
        () {
          final id = listing['id']?.toString() ?? '';
          final payload = _payloadsByListingId[id];
          final applicants = payload == null
              ? const <LandlordApplicantCardModel>[]
              : _applicantsForListing(id, payload);
          return LandlordListingRailItem(
            listing: listing,
            applicantCount: applicants.length,
          );
        }(),
    ];
  }

  void _refreshMetricsForCurrentListing() {
    final listing = _listings[_selectedIndex];
    final id = listing['id']?.toString() ?? '';
    final payload = _payloadsByListingId[id];
    if (payload == null) return;

    final metrics = payload.category.isShared
        ? LandlordDashboardHelpers.metricsFromShared(
            stream: payload.shared!,
            noiseDeflected: payload.noiseDeflected,
            archivedIds: const {},
          )
        : LandlordDashboardHelpers.metricsFromIndependent(
            stream: payload.independent!,
            noiseDeflected: payload.noiseDeflected,
            archivedIds: const {},
          );

    setState(() {
      _payloadsByListingId[id] = _ListingStreamPayload(
        category: payload.category,
        independent: payload.independent,
        shared: payload.shared,
        noiseDeflected: payload.noiseDeflected,
        metrics: metrics,
      );
    });
  }

  void _selectApplicant(String listingId, LandlordApplicantCardModel applicant) {
    setState(() {
      _selectedApplicantByListing[listingId] = applicant.applicationId;
    });
  }

  Future<void> _rejectApplicant(LandlordApplicantCardModel applicant) async {
    setState(() => _actionLoadingId = applicant.applicationId);
    try {
      await ApplicationLifecycleService.declineApplicant(
        applicationId: applicant.applicationId,
        currentStatus: applicant.status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application declined'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _reloadCurrentListing();
      if (!mounted) return;
      _selectNextAfterReject(applicant.applicationId);
    } on ApplicantManagementException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _actionLoadingId = null);
    }
  }

  void _selectNextAfterReject(String rejectedId) {
    final listingId = _currentListingId;
    final payload = _currentPayload;
    if (payload == null) {
      setState(() => _selectedApplicantByListing.remove(listingId));
      return;
    }
    final applicants = _applicantsForListing(listingId, payload);
    final next = LandlordQueueBuckets.from(applicants).nextAfterReject(rejectedId);
    setState(() {
      if (next == null) {
        _selectedApplicantByListing.remove(listingId);
      } else {
        _selectedApplicantByListing[listingId] = next.applicationId;
      }
    });
  }

  Future<void> _inviteApplicant(LandlordApplicantCardModel applicant) async {
    if (applicant.status != ApplicantApplicationStatus.pending) return;
    final invitation = await InviteViewingSheet.show(context);
    if (invitation == null || !mounted) return;

    setState(() => _actionLoadingId = applicant.applicationId);
    try {
      await ApplicationLifecycleService.sendViewingInvitation(
        applicationId: applicant.applicationId,
        hostUserId: AuthService.identityUserId(),
        invitation: invitation,
        currentStatus: applicant.status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Viewing invitation sent to ${applicant.seekerName}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _reloadCurrentListing();
    } on ApplicantManagementException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _actionLoadingId = null);
    }
  }

  Future<void> _rescheduleApplicant(LandlordApplicantCardModel applicant) async {
    if (applicant.status != ApplicantApplicationStatus.viewingInvitationSent &&
        applicant.status != ApplicantApplicationStatus.viewingScheduled) {
      return;
    }
    final existing = ViewingInvitation.fromRow(
      applicationService.rowById(applicant.applicationId),
    );
    final invitation = await InviteViewingSheet.show(
      context,
      initial: existing,
      updateMode: true,
    );
    if (invitation == null || !mounted) return;

    setState(() => _actionLoadingId = applicant.applicationId);
    try {
      await ApplicationLifecycleService.rescheduleViewing(
        applicationId: applicant.applicationId,
        hostUserId: AuthService.identityUserId(),
        invitation: invitation,
        currentStatus: applicant.status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Viewing updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _reloadCurrentListing();
    } on ApplicantManagementException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _actionLoadingId = null);
    }
  }

  Future<void> _cancelViewingApplicant(
    LandlordApplicantCardModel applicant,
  ) async {
    if (applicant.status != ApplicantApplicationStatus.viewingInvitationSent &&
        applicant.status != ApplicantApplicationStatus.viewingScheduled) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this viewing?'),
        content: Text(
          'Cancel the viewing with ${applicant.seekerName}? '
          'The conversation stays available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Viewing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Viewing'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _actionLoadingId = applicant.applicationId);
    try {
      await ApplicationLifecycleService.cancelViewing(
        applicationId: applicant.applicationId,
        hostUserId: AuthService.identityUserId(),
        currentStatus: applicant.status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Viewing cancelled'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _reloadCurrentListing();
    } on ApplicantManagementException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _actionLoadingId = null);
    }
  }

  Future<void> _reloadCurrentListing() async {
    if (_listings.isEmpty) return;
    final listing = _listings[_selectedIndex];
    final id = listing['id']?.toString() ?? '';
    final payload = await _loadPayloadForListing(listing);
    if (!mounted) return;
    setState(() {
      _payloadsByListingId[id] = payload;
    });
  }

  Future<void> _deleteSelectedListing() async {
    if (_listings.isEmpty) return;
    final index = _selectedIndex.clamp(0, _listings.length - 1);
    final listing = _listings[index];
    final listingId = listing['id']?.toString() ?? '';
    if (listingId.isEmpty) return;

    final title = ListingData.title(listing).trim();
    final label = title.isEmpty ? 'this listing' : '"$title"';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this listing?'),
        content: Text(
          'Delete $label? It will be removed from your dashboard and the '
          'marketplace. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Listing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: LandlordDashboardTheme.declineInk,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Listing'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _actionLoadingId = listingId);
    try {
      await ListingsStorageService.deleteListing(listingId);
      if (!mounted) return;
      setState(() {
        _payloadsByListingId.remove(listingId);
        _selectedApplicantByListing.remove(listingId);
        final next = List<Map<String, dynamic>>.from(_listings)
          ..removeWhere((item) => item['id']?.toString() == listingId);
        _listings = next;
        _selectedIndex = next.isEmpty
            ? 0
            : index.clamp(0, next.length - 1);
        _actionLoadingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionLoadingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete listing: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final modeSwitch = _buildModeSwitch();

    return Scaffold(
      backgroundColor: LandlordDashboardTheme.canvas,
      appBar: LandlordDashboardTopNav(
        onRefresh: _loading ? null : _bootstrap,
        leadingNav: modeSwitch,
        ownedListingIds: {
          for (final listing in _listings)
            if ((listing['id']?.toString() ?? '').isNotEmpty)
              listing['id']!.toString(),
        },
        onAddListing: () => context.push('/add-listing'),
        onEditListing: !_loading && _listings.isNotEmpty
            ? () {
                final listing = _listings[_selectedIndex];
                context.push('/add-listing', extra: listing);
              }
            : null,
        onDeleteListing: !_loading && _listings.isNotEmpty
            ? _deleteSelectedListing
            : null,
        onLogout: () async {
          await AuthService.signOut();
          if (!mounted) return;
          context.go('/');
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _loadError != null
              ? Center(child: Text('Could not load dashboard: $_loadError'))
              : _listings.isEmpty
                  ? const Center(child: Text('No active listings yet'))
                  : _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    final payload = _currentPayload;
    final hostBanner = _buildHostProfileBanner();
    final listingId = _currentListingId;
    final listing = _listings[_selectedIndex];
    final applicants = payload == null
        ? const <LandlordApplicantCardModel>[]
        : _applicantsForListing(listingId, payload);
    final selectedId = _selectedApplicantByListing[listingId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hostBanner != null)
          Align(alignment: Alignment.topCenter, child: hostBanner),
        Expanded(
          child: LandlordDecisionWorkspace(
            railItems: _buildRailItems(),
            selectedListingIndex: _selectedIndex,
            onListingSelected: (index) => setState(() => _selectedIndex = index),
            applicants: applicants,
            selectedApplicantId: selectedId,
            onApplicantSelected: (a) => _selectApplicant(listingId, a),
            onInvite: _inviteApplicant,
            onReschedule: _rescheduleApplicant,
            onCancelViewing: _cancelViewingApplicant,
            onArchive: _rejectApplicant,
            actionLoadingId: _actionLoadingId,
            hostPhoneE164: ProfileData.text(
              AuthScreen.currentUserSession?['contact_phone_e164'],
            ),
            hostPrefersWhatsapp:
                AuthScreen.currentUserSession?['prefers_whatsapp'] == true,
            listingTitle: ListingData.title(listing),
          ),
        ),
      ],
    );
  }
}
