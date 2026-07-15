import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../controllers/applicant_management_controller.dart';
import '../core/theme/app_theme.dart' show AppColors;
import '../data/dublin_mock_data.dart';
import '../data/mock_applicant_seeder.dart';
import '../models/independent_places_applicant_stream.dart';
import '../models/landlord_applicant_card_model.dart';
import '../models/listing_creation_category.dart';
import '../models/shared_living_applicant_stream.dart';
import '../navigation/navigate_after_identity.dart';
import '../services/active_mode_service.dart';
import '../services/application_service.dart';
import '../services/auth_service.dart';
import '../services/listing_applications_service.dart';
import '../services/listings_storage_service.dart';
import '../services/profile_state_notifier.dart';
import '../screens/auth_screen.dart';
import '../utils/listing_data.dart';
import '../utils/profile_data.dart';
import '../utils/profile_progress.dart';
import '../utils/seeker_strong_match_aggregator.dart';
import '../theme/app_typography.dart';
import '../utils/landlord_dashboard_helpers.dart';
import '../widgets/active_mode/active_mode_switch.dart';
import '../widgets/home/home_profile_completion_banner.dart';
import '../widgets/landlord_dashboard/landlord_dashboard_theme.dart';
import '../widgets/landlord_dashboard/landlord_kpi_metrics_row.dart';
import '../widgets/landlord_dashboard/landlord_listing_switcher.dart';
import '../widgets/landlord_dashboard/landlord_noise_filter_banner.dart';
import '../widgets/landlord_dashboard/landlord_pipeline_workspace.dart';

/// Premium landlord command center — pipeline workspace per listing.
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
  final _listingPageController = PageController();
  final _archivedByListing = <String, Set<String>>{};
  final _payloadsByListingId = <String, _ListingStreamPayload>{};
  final _trustFilterByListing = <String, LandlordTrustFilter>{};
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
    _listingPageController.dispose();
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
      if (listings.isEmpty && DublinMockData.useMockHarness) {
        listings = DublinMockData.ownedListingsForHost();
      }
      final initialId = widget.initialListingId;
      if (DublinMockData.useMockHarness &&
          initialId == DublinMockData.listingId &&
          !listings.any((l) => l['id']?.toString() == DublinMockData.listingId)) {
        listings = [...DublinMockData.ownedListingsForHost(), ...listings];
      }

      final payloads = <String, _ListingStreamPayload>{};
      for (final listing in listings) {
        final id = listing['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        payloads[id] = await _loadPayloadForListing(listing);
        _archivedByListing.putIfAbsent(id, () => <String>{});
        _trustFilterByListing.putIfAbsent(id, () => LandlordTrustFilter.all);
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_listingPageController.hasClients && selected > 0) {
          _listingPageController.jumpToPage(selected);
        }
      });
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
    final state = ProfileProgress.hostBannerState(session, signedIn: signedIn);
    if (HomeProfileCompletionBannerSession.hostDismissed ||
        state == HomeOnboardingBannerState.hidden ||
        state == HomeOnboardingBannerState.signInRequired) {
      return null;
    }
    final percent = ProfileProgress.hostPercent(session);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: HomeProfileCompletionBanner(
        percent: percent,
        audience: ProfileCompletionAudience.host,
        onContinue: () {
          final extra = session;
          if (extra != null && extra.isNotEmpty) {
            context.push('/profile/edit/host', extra: extra);
          } else {
            context.push('/profile/edit/host');
          }
        },
        onDismiss: () {
          HomeProfileCompletionBannerSession.hostDismissed = true;
          setState(() {});
        },
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
    final archived = _archivedByListing[listingId] ?? <String>{};
    final useMock = LandlordDashboardHelpers.isMockListing(listingId);

    if (category.isShared) {
      var stream = useMock
          ? (DublinMockData.isHarnessListing(listingId)
              ? DublinMockData.resolveApplicantStream()
              : MockApplicantSeeder.sharedLivingStream(
                  listingId: listingId,
                  dense: true,
                ))
          : await ApplicantManagementController.getSharedLivingApplicants(
              listingId,
            );
      if (stream.totalCount == 0 &&
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
          archivedIds: archived,
        ),
      );
    }

    final stream = useMock
        ? MockApplicantSeeder.independentPlacesStream(
            listingId: listingId,
            dense: true,
          )
        : await ApplicantManagementController.getIndependentPlaceApplicants(
            listingId,
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
        archivedIds: archived,
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
    final archived = _archivedByListing[listingId] ?? {};
    final filter = _trustFilterByListing[listingId] ?? LandlordTrustFilter.all;

    final List<LandlordApplicantCardModel> all;
    if (payload.category.isShared && payload.shared != null) {
      all = LandlordApplicantCardModel.fromSharedStream(payload.shared!);
    } else if (payload.independent != null) {
      all = LandlordApplicantCardModel.fromIndependentStream(payload.independent!);
    } else {
      all = const [];
    }

    var filtered = all
        .where((a) => !archived.contains(a.applicationId))
        .where((a) => filter.matches(a.trustTier))
        .toList();

    if (filtered.isEmpty &&
        all.isEmpty &&
        DublinMockData.useMockHarness &&
        DublinMockData.isHarnessListing(listingId)) {
      final injected =
          LandlordApplicantCardModel.fromSharedStream(
            DublinMockData.fallbackApplicantStream(),
          );
      filtered = injected
          .where((a) => !archived.contains(a.applicationId))
          .where((a) => filter.matches(a.trustTier))
          .toList();
    }

    return filtered;
  }

  void _refreshMetricsForCurrentListing() {
    final listing = _listings[_selectedIndex];
    final id = listing['id']?.toString() ?? '';
    final payload = _payloadsByListingId[id];
    if (payload == null) return;

    final archived = _archivedByListing[id] ?? {};
    final metrics = payload.category.isShared
        ? LandlordDashboardHelpers.metricsFromShared(
            stream: payload.shared!,
            noiseDeflected: payload.noiseDeflected,
            archivedIds: archived,
          )
        : LandlordDashboardHelpers.metricsFromIndependent(
            stream: payload.independent!,
            noiseDeflected: payload.noiseDeflected,
            archivedIds: archived,
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

  void _setTrustFilter(String listingId, LandlordTrustFilter filter) {
    setState(() {
      _trustFilterByListing[listingId] = filter;
      _selectedApplicantByListing.remove(listingId);
    });
  }

  void _selectApplicant(String listingId, LandlordApplicantCardModel applicant) {
    setState(() {
      _selectedApplicantByListing[listingId] = applicant.applicationId;
    });
  }

  void _archiveApplicant(LandlordApplicantCardModel applicant) {
    final id = _currentListingId;
    setState(() {
      _archivedByListing.putIfAbsent(id, () => <String>{}).add(applicant.applicationId);
      _selectedApplicantByListing.remove(id);
    });
    _refreshMetricsForCurrentListing();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Seeker moved to your archive lane'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _inviteApplicant(LandlordApplicantCardModel applicant) async {
    setState(() => _actionLoadingId = applicant.applicationId);
    try {
      await ApplicantManagementController.scheduleViewing(
        applicationId: applicant.applicationId,
        currentStatus: applicant.status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Match invitation sent to ${applicant.seekerName}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LandlordDashboardTheme.canvas,
      appBar: AppBar(
        backgroundColor: LandlordDashboardTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: LandlordDashboardTheme.textPrimary,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(
          'Landlord Dashboard',
          style: AppTypography.sectionTitle().copyWith(
            fontSize: 18,
            color: LandlordDashboardTheme.textPrimary,
          ),
        ),
        actions: [
          if (_buildModeSwitch() != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildModeSwitch(),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            tooltip: 'Refresh streams',
            onPressed: _loading ? null : _bootstrap,
            icon: const Icon(Icons.refresh_rounded),
            color: LandlordDashboardTheme.textSecondary,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: LandlordDashboardTheme.border,
          ),
        ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hostBanner != null) hostBanner,
        LandlordListingSwitcher(
          listings: _listings,
          selectedIndex: _selectedIndex,
          pageController: _listingPageController,
          onSelected: (index) => setState(() => _selectedIndex = index),
        ),
        if (payload != null)
          LandlordNoiseFilterBanner(
            deflectedCount: payload.noiseDeflected,
          ),
        Expanded(
          child: PageView.builder(
            controller: _listingPageController,
            itemCount: _listings.length,
            onPageChanged: (index) => setState(() => _selectedIndex = index),
            itemBuilder: (context, index) {
              final pageListing = _listings[index];
              final pageId = pageListing['id']?.toString() ?? '';
              final pagePayload = _payloadsByListingId[pageId];
              if (pagePayload == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final applicants = _applicantsForListing(pageId, pagePayload);
              final selectedId = _selectedApplicantByListing[pageId];

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LandlordKpiMetricsRow(
                      metrics: pagePayload.metrics,
                      selectedFilter:
                          _trustFilterByListing[pageId] ??
                              LandlordTrustFilter.all,
                      onFilterChanged: (filter) =>
                          _setTrustFilter(pageId, filter),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: LandlordPipelineWorkspace(
                        applicants: applicants,
                        selectedId: selectedId,
                        onSelect: (a) => _selectApplicant(pageId, a),
                        onInvite: _inviteApplicant,
                        onArchive: _archiveApplicant,
                        actionLoadingId: _actionLoadingId,
                        onOptimizeListing: () =>
                            context.push('/listing/$pageId'),
                        hostPhoneE164: ProfileData.text(
                          AuthScreen.currentUserSession?['contact_phone_e164'],
                        ),
                        hostPrefersWhatsapp:
                            AuthScreen.currentUserSession?['prefers_whatsapp'] ==
                                true,
                        listingTitle: ListingData.title(pageListing),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
