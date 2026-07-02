import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../navigation/home_explore_reset_notifier.dart';
import '../router/app_router.dart';

import '../navigation/space_gateway_navigation.dart';
import '../data/dublin_mock_data.dart';
import '../services/auth_service.dart';
import '../services/application_service.dart';
import '../services/listings_storage_service.dart';
import '../services/marketplace_context_notifier.dart';
import '../services/profile_state_notifier.dart';
import '../services/profile_onboarding_repository.dart';
import '../services/profile_portal_inheritance_service.dart';
import '../models/listing_application.dart';
import '../models/marketplace_space.dart';
import '../utils/listing_data.dart';
import '../utils/listing_match_engine.dart';
import '../utils/listing_search_intent.dart';
import '../utils/listing_search_suggestions.dart';
import '../utils/marketplace_listing_pipeline.dart';
import '../utils/numeric_bounds.dart';
import '../config/market/market_config.dart';
import '../utils/profile_data.dart';
import 'profile_edit_screen.dart';
import '../utils/dublin_macro_search.dart';
import '../utils/viewer_profile.dart';
import '../widgets/property_card.dart';
import '../widgets/space_switcher.dart';
import '../widgets/truecircle_logo.dart';
import '../widgets/trust_tier_legend_scale.dart';
import '../widgets/filter_chip_bar.dart';
import '../theme/app_scroll_behavior.dart';
import '../theme/app_typography.dart';
import '../core/theme/app_theme.dart' show AppButtonStyles, AppColors;
import '../theme/home_marketplace_theme.dart';
import 'auth_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.authRequired = false,
    this.authRedirectPath,
  });

  /// Set when router redirects an unauthenticated user from a protected route.
  final bool authRequired;
  final String? authRedirectPath;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _HomeTab { explore, saved, applications, listings }

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _listings = [];
  bool _listingsLoading = true;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  /// Single pipeline result — always the source of truth for the grid.
  MarketplaceListingPipelineResult? _pipelineResult;

  /// Active filters applied to the current pipeline.
  ListingSearchFilters _activeFilters = const ListingSearchFilters();

  /// Active Dublin space maps to tower property type (Rent / Share).
  MarketplaceSpace get _activeSpace => marketplaceContextNotifier.activeSpace;
  String get _selectedPropertyType => _activeSpace.towerPropertyType;

  bool _showSuggestions = false;
  int _highlightedSuggestionIndex = -1;
  final List<String> _recentSearchQueries = [];

  static final Object _searchTapGroup = Object();
  final GlobalKey _searchBarAnchorKey = GlobalKey();
  OverlayEntry? _searchDropdownOverlayEntry;
  static const double _searchBarHeight = 56;
  static const double _searchDropdownMaxHeight = 300;
  static const double _searchDropdownGap = 8;
  static const double _searchDropdownRadius = 12;

  bool _handledListingAddedMessage = false;
  bool _handledPortalWelcome = false;
  bool _showWelcomeFeedBanner = false;
  bool _showFirstListingPrompt = false;
  bool _applicationsReady = false;
  int _applicationCount = 0;
  double _averageMatchPercent = 0;
  _HomeTab _selectedTab = _HomeTab.explore;
  /// Guards against [onChanged] firing when text is set programmatically.
  bool _settingTextProgrammatically = false;

  @override
  void initState() {
    super.initState();
    authSessionNotifier.addListener(_onAuthSessionChanged);
    profileStateNotifier.addListener(_onProfileStateChanged);
    marketplaceContextNotifier.addListener(_onMarketplaceContextChanged);
    homeExploreResetNotifier.addListener(_onHomeExploreResetRequested);
    _ensureValidTowerSelection();
    _loadHomeData();
    if (widget.authRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openSignIn(authRedirectPath: widget.authRedirectPath);
      });
    }
  }

  void _onHomeExploreResetRequested() {
    if (!mounted) return;
    if (_selectedTab != _HomeTab.explore) {
      setState(() => _selectedTab = _HomeTab.explore);
    }
    _closeSuggestions();
  }

  void _onLogoTap() {
    homeExploreResetNotifier.value = 0;
    if (_selectedTab != _HomeTab.explore) {
      setState(() => _selectedTab = _HomeTab.explore);
    }
    _closeSuggestions();
    Navigator.of(context, rootNavigator: true).popUntil(
      (Route<dynamic> route) => route.isFirst,
    );
    appRouter.pushReplacement('/');
  }

  Future<void> _openProfileEdit({Map<String, dynamic>? initialProfile}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            ProfileEditScreen(initialProfile: initialProfile),
      ),
    );
    if (!mounted) return;
    await AuthService.reloadProfileFromStorage();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openSignIn({String? authRedirectPath}) async {
    final signedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );
    if (!mounted) return;
    if (signedIn == true) {
      await AuthService.reloadProfileFromStorage();
      if (!mounted) return;
      setState(() {
        _pipelineResult = null;
      });
      if (authRedirectPath != null && authRedirectPath.isNotEmpty) {
        context.go(Uri.decodeComponent(authRedirectPath));
      } else {
        await navigateAfterAuth(context);
      }
    }
  }

  void _ensureValidTowerSelection() {
    final enabled = MarketplaceSpace.enabledForMarket();
    if (!enabled.contains(_activeSpace) && enabled.isNotEmpty) {
      unawaited(marketplaceContextNotifier.setActiveSpace(enabled.first));
    }
  }

  @override
  void dispose() {
    authSessionNotifier.removeListener(_onAuthSessionChanged);
    profileStateNotifier.removeListener(_onProfileStateChanged);
    marketplaceContextNotifier.removeListener(_onMarketplaceContextChanged);
    homeExploreResetNotifier.removeListener(_onHomeExploreResetRequested);
    _removeSearchDropdownOverlay();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool _reloadingProfile = false;

  void _onAuthSessionChanged() {
    if (!mounted) return;
    profileStateNotifier.invalidateCache();
    _syncDashboardFromGlobalSession();
  }

  Future<void> _reloadProfileSession() async {
    if (_reloadingProfile) return;
    if (!AuthService.isAuthenticated && AuthScreen.currentUserSession == null) {
      return;
    }
    _reloadingProfile = true;
    try {
      await AuthService.reloadProfileFromStorage();
      if (!mounted) return;
      setState(() {});
    } finally {
      _reloadingProfile = false;
    }
  }

  void _onProfileStateChanged() {
    if (!mounted) return;
    _refreshPipelineFromProfile();
  }

  void _onMarketplaceContextChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _selectActiveSpace(MarketplaceSpace space) async {
    if (space == _activeSpace) return;
    await marketplaceContextNotifier.setActiveSpace(space);
    if (!mounted) return;
    if (!_activeFilters.isEmpty) {
      _runSearchWithFilters(
        _activeFilters,
        pipelineQuery: _activeFilters.pipelineQueryText(),
      );
    } else {
      setState(() => _pipelineResult = _runDefaultPipeline());
    }
  }

  Future<void> _refreshApplicationMetrics() async {
    await applicationService.ensureLoaded();
    final owned = marketplaceContextNotifier.ownedListings;
    var totalScore = 0.0;
    var count = 0;
    for (final listing in owned) {
      final apps = applicationService.rowsForListing(ListingData.id(listing));
      count += apps.length;
      for (final app in apps) {
        final score = app['compatibility_score'];
        if (score is num) totalScore += score;
      }
    }
    if (!mounted) return;
    setState(() {
      _applicationCount = count;
      _averageMatchPercent = count > 0 ? totalScore / count : 0;
      _applicationsReady = true;
    });
  }

  List<ListingApplication> get _userApplicationsForActiveSpace {
    final userId = AuthService.currentUser?.id ?? '';
    return [
      for (final application in applicationService.getUserApplications(userId))
        if (_applicationSpace(application) == _activeSpace) application,
    ];
  }

  MarketplaceSpace? _applicationSpace(ListingApplication application) {
    final fromListing = _listingSpaceForId(application.listingId);
    if (fromListing != null) return fromListing;

    for (final row in applicationService.allRows()) {
      if (row['id']?.toString() != application.id) continue;
      final token = row['space']?.toString();
      if (token == null || token.isEmpty) return null;
      return MarketplaceSpace.fromStorageToken(token);
    }
    return null;
  }

  MarketplaceSpace? _listingSpaceForId(String listingId) {
    if (listingId.isEmpty) return null;
    for (final listing in _listings) {
      if (ListingData.id(listing) == listingId) {
        return MarketplaceSpace.fromTowerPropertyType(
          ListingData.propertyType(listing),
        );
      }
    }
    return null;
  }

  String _listingTitleForApplication(ListingApplication application) {
    for (final listing in _listings) {
      if (ListingData.id(listing) == application.listingId) {
        final title = ListingData.title(listing);
        if (title.isNotEmpty) return title;
      }
    }
    return 'Listing unavailable';
  }

  String _formatAppliedDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[date.month - 1];
    return '$month ${date.day}, ${date.year}';
  }

  /// Mirrors global profile session into home widgets immediately.
  void _syncDashboardFromGlobalSession() {
    if (!mounted) return;
    setState(() {});
    _loadListingsFromStorage();
  }

  // ── Overlay management ────────────────────────────────────────

  void _syncSearchDropdownOverlay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateSearchDropdownOverlay();
    });
  }

  void _removeSearchDropdownOverlay() {
    _searchDropdownOverlayEntry?.remove();
    _searchDropdownOverlayEntry?.dispose();
    _searchDropdownOverlayEntry = null;
  }

  void _markSearchDropdownDirty() {
    _searchDropdownOverlayEntry?.markNeedsBuild();
  }

  void _updateSearchDropdownOverlay() {
    final shouldShow = _showSuggestions && _flatSuggestions.isNotEmpty;
    if (!shouldShow) {
      _removeSearchDropdownOverlay();
      return;
    }
    if (_searchDropdownOverlayEntry != null) {
      _markSearchDropdownDirty();
      return;
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    _searchDropdownOverlayEntry = OverlayEntry(
      builder: (context) => _buildSearchDropdownOverlayLayer(),
    );
    overlay.insert(_searchDropdownOverlayEntry!);
  }

  // ── Search input callbacks (Google model) ─────────────────────
  //
  // onChanged  → show/hide suggestions (NEVER touches pipeline)
  // onSubmitted / Enter → commit search (runs pipeline)
  // suggestion click → commit search (runs pipeline)
  // clear button → clear search (runs default pipeline)
  // focus lost → close suggestions (NEVER touches pipeline)

  /// Called by TextField.onChanged — only controls suggestion visibility.
  void _onSearchTextChanged(String raw) {
    if (_settingTextProgrammatically) return;
    final text = SearchSuggestion.stripCountSuffix(raw);
    setState(() {
      _showSuggestions = text.isNotEmpty;
      _highlightedSuggestionIndex = -1;
    });
    _syncSearchDropdownOverlay();
  }

  // Focus loss is NOT used to close suggestions — TapRegion.onTapOutside
  // handles that. Closing on focus loss would destroy the overlay before a
  // mouse-click on a suggestion completes (pointer-down removes focus,
  // overlay is removed, pointer-up finds no InkWell → onTap never fires).

  // ── Pipeline helpers ──────────────────────────────────────────

  MarketplaceListingPipelineResult get _currentPipeline {
    return _pipelineResult ??= _runDefaultPipeline();
  }

  Map<String, dynamic>? get _activeUserSession =>
      profileStateNotifier.session ?? AuthScreen.currentUserSession;

  MarketplaceListingPipelineResult _runDefaultPipeline() {
    final inheritedFilters = _inheritedFeedFilters(_activeUserSession);
    return MarketplaceListingPipeline.runWithFilters(
      allListings: _listings,
      towerPropertyType: _selectedPropertyType,
      filters: inheritedFilters,
      userSession: _activeUserSession,
    );
  }

  ListingSearchFilters _inheritedFeedFilters(Map<String, dynamic>? session) {
    if (session == null || session.isEmpty) {
      return const ListingSearchFilters();
    }
    final snapshot = ProfileOnboardingRepository.snapshotFromSession(session);
    return ProfilePortalInheritanceService.seekerFeedDefaults(snapshot);
  }

  void _refreshPipelineFromProfile() {
    if (!mounted) return;
    if (_activeFilters.isEmpty) {
      setState(() => _pipelineResult = _runDefaultPipeline());
    } else {
      _runSearchWithFilters(
        _activeFilters,
        pipelineQuery: _activeFilters.pipelineQueryText(),
      );
    }
  }

  List<ScoredListing> get _rankedVisibleListings => _currentPipeline.ranked;

  /// Runs search from the text field (Enter key).
  void _commitSearchFromField() {
    final text = SearchSuggestion.stripCountSuffix(_searchController.text).trim();
    if (text.isEmpty) {
      _clearSearch();
      return;
    }

    if (DublinMacroSearch.isExactMacroPhrase(text)) {
      _applyAllDublinMacroSearch(clearSearchBar: true);
      return;
    }

    final parsed = ListingSearchIntent.parseQuery(text);
    var filters = ListingSearchFilters.fromIntent(parsed);
    if (DublinMacroSearch.hasMicroLocationInQuery(
      text,
      parsedCityKey: parsed.city,
      parsedLocalityKeywords: parsed.remainingKeywords,
    )) {
      filters = filters.withoutAllDublinMacro();
    }

    _runSearchWithFilters(filters, pipelineQuery: text);
  }

  void _applyAllDublinMacroSearch({required bool clearSearchBar}) {
    if (clearSearchBar) {
      _settingTextProgrammatically = true;
      _searchController.clear();
      _settingTextProgrammatically = false;
    }
    _runSearchWithFilters(
      _activeFilters.withAllDublinArea(),
      pipelineQuery: '',
    );
  }

  /// Single pipeline entry point. Runs the pipeline, updates state, done.
  void _runSearchWithFilters(
    ListingSearchFilters filters, {
    required String pipelineQuery,
  }) {
    final result = MarketplaceListingPipeline.runWithFilters(
      allListings: _listings,
      towerPropertyType: _selectedPropertyType,
      filters: filters,
      userSession: _activeUserSession,
      searchQuery: pipelineQuery,
    );

    setState(() {
      _pipelineResult = result;
      _activeFilters = filters;
      _showSuggestions = false;
      _highlightedSuggestionIndex = -1;
    });
    _removeSearchDropdownOverlay();

    if (kDebugMode) {
      MarketplaceListingPipeline.debugLog(
        result,
        pipelineQuery,
        userSession: AuthScreen.currentUserSession,
      );
    }
  }

  /// Clears search and restores the full tower grid.
  void _clearSearch() {
    final inheritedFilters = _inheritedFeedFilters(_activeUserSession);
    setState(() {
      _showSuggestions = false;
      _highlightedSuggestionIndex = -1;
      _activeFilters = inheritedFilters;
      _pipelineResult = MarketplaceListingPipeline.runWithFilters(
        allListings: _listings,
        towerPropertyType: _selectedPropertyType,
        filters: inheritedFilters,
        userSession: _activeUserSession,
      );
    });
    _removeSearchDropdownOverlay();
  }

  void _clearAllFilters() {
    _searchController.clear();
    _clearSearch();
  }

  void _onChipFiltersChanged(ListingSearchFilters filters) {
    if (filters.isAllDublinMacro) {
      _settingTextProgrammatically = true;
      _searchController.clear();
      _settingTextProgrammatically = false;
    } else if (filters.effectiveAreaTokens.isNotEmpty &&
        _activeFilters.isAllDublinMacro) {
      _settingTextProgrammatically = true;
      _searchController.clear();
      _settingTextProgrammatically = false;
    }

    if (filters.isEmpty && _searchController.text.trim().isEmpty) {
      _clearSearch();
      return;
    }
    final searchText = _searchController.text.trim();
    _runSearchWithFilters(
      filters,
      pipelineQuery: filters.pipelineQueryText(searchText: searchText),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_handledListingAddedMessage) {
      final extra = GoRouterState.of(context).extra;
      if (extra is Map && extra['listingAdded'] != null) {
        _handledListingAddedMessage = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                content: Text('Listing added to the marketplace.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
        });
      }
    }

    if (!_handledPortalWelcome) {
      final qp = GoRouterState.of(context).uri.queryParameters;
      if (qp.containsKey('welcomeFeed') || qp.containsKey('promptFirstListing')) {
        _handledPortalWelcome = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (qp['welcomeFeed'] == '1') {
            final inherited = _inheritedFeedFilters(_activeUserSession);
            if (!inherited.isEmpty) {
              _runSearchWithFilters(
                inherited,
                pipelineQuery: inherited.pipelineQueryText(),
              );
            } else {
              setState(() {
                _showWelcomeFeedBanner = true;
                _pipelineResult = _runDefaultPipeline();
              });
              return;
            }
            setState(() => _showWelcomeFeedBanner = true);
          }
          if (qp['promptFirstListing'] == '1') {
            setState(() => _showFirstListingPrompt = true);
          }
        });
      }
    }
  }

  Future<void> _loadHomeData() async {
    await _hydrateSessionFromStorage();
    await _loadListingsFromStorage();
  }

  Future<void> _hydrateSessionFromStorage() async {
    await _reloadProfileSession();
  }

  Future<void> _loadListingsFromStorage() async {
    if (!_listingsLoading) {
      setState(() => _listingsLoading = true);
    }
    try {
      final listings = await ListingsStorageService.load();
      if (!mounted) return;
      await marketplaceContextNotifier.refresh();
      if (!mounted) return;
      _listings = listings;
      _listingsLoading = false;
      await _refreshApplicationMetrics();

      if (!_activeFilters.isEmpty) {
        _runSearchWithFilters(
          _activeFilters,
          pipelineQuery: _activeFilters.pipelineQueryText(),
        );
      } else {
        setState(() {
          _pipelineResult = _runDefaultPipeline();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listings = [];
        _listingsLoading = false;
      });
    }
  }

  void _goAddListing() {
    if (!AuthService.isAuthenticated &&
        AuthScreen.currentUserSession == null) {
      _openSignIn(authRedirectPath: '/add-listing');
      return;
    }
    final session = _activeUserSession;
    final snapshot = ProfileOnboardingRepository.snapshotFromSession(session);
    final prefill = snapshot.track.isLandlord
        ? ProfilePortalInheritanceService.listingPrefill(snapshot).toDraftMap()
        : null;
    context.push('/add-listing', extra: prefill == null ? null : {'listingDraft': prefill}).then((_) {
      if (mounted) _loadListingsFromStorage();
    });
  }

  Widget _buildAddListingButton({bool compact = false}) {
    if (compact) {
      return FilledButton(
        onPressed: _goAddListing,
        style: AppButtonStyles.primaryFilled.copyWith(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'Add Listing',
              style: AppTypography.button().copyWith(
                fontSize: AppTypography.textSm,
                height: 1.1,
              ),
            ),
          ],
        ),
      );
    }

    return FilledButton.icon(
      onPressed: _goAddListing,
      icon: const Icon(Icons.add_rounded, size: 20),
      label: Text('Add Listing', style: AppTypography.button()),
      style: AppButtonStyles.primaryFilled,
    );
  }

  PreferredSizeWidget _buildHomeAppBar({
    required bool signedIn,
    required Map<String, dynamic>? userSession,
  }) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(_HomeNavBar.toolbarHeight),
      child: Material(
        color: HomeMarketplaceTheme.surface,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: HomeMarketplaceTheme.border, width: 0.5),
            ),
          ),
          child: SizedBox(
            height: _HomeNavBar.toolbarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _HomeNavBar.horizontalPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: _onLogoTap,
                    borderRadius: BorderRadius.circular(8),
                    mouseCursor: SystemMouseCursors.click,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          TrueCircleLogo.appBarMark(
                            size: _HomeNavBar.markSize,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'TrueCircle',
                            style: TextStyle(
                              fontSize: _HomeNavBar.wordmarkSize,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF222222),
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildAddListingButton(compact: true),
                  const SizedBox(width: 10),
                  if (!signedIn)
                    FilledButton.icon(
                      onPressed: () => _openSignIn(),
                      icon: const Icon(
                        Icons.login,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Sign In',
                        style: AppTypography.button().copyWith(
                          fontSize: AppTypography.textSm,
                          height: 1.1,
                        ),
                      ),
                      style: AppButtonStyles.primaryFilled.copyWith(
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  else
                    _UserHeaderMenu(
                      fullName: AuthService.displayName(userSession),
                      onViewProfile: () {
                        final session = AuthScreen.currentUserSession;
                        if (ProfileData.isMatchingReady(session)) {
                          context.go('/profile');
                        } else {
                          context.go('/profile/edit', extra: session);
                        }
                      },
                      onLogout: () async {
                        await AuthService.signOut();
                        if (mounted) {
                          setState(() {
                            _pipelineResult = null;
                          });
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        authSessionNotifier,
        profileStateNotifier,
        marketplaceContextNotifier,
      ]),
      builder: (context, _) {
        final userSession = profileStateNotifier.session;
        final signedIn =
            AuthService.isAuthenticated || userSession != null;

        final screenWidth = MediaQuery.sizeOf(context).width;
        final bodyPadding = screenWidth < 600 ? 16.0 : 24.0;

        return Scaffold(
          backgroundColor: HomeMarketplaceTheme.canvas,
          appBar: _buildHomeAppBar(
            signedIn: signedIn,
            userSession: userSession,
          ),
          body: IndexedStack(
            index: _selectedTab.index,
            children: [
              _buildExploreTab(
                userSession: userSession,
                bodyPadding: bodyPadding,
                screenWidth: screenWidth,
              ),
              _HomeDashboardEmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'Saved',
                subtitle: 'Your saved listings will appear here.',
              ),
              _buildApplicationsTab(),
              _buildListingsTab(bodyPadding: bodyPadding),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedTab.index,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.accent,
            unselectedItemColor: const Color(0xFF9CA3AF),
            backgroundColor: HomeMarketplaceTheme.surface,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            selectedLabelStyle: AppTypography.meta().copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
              letterSpacing: 0.1,
              height: 1.1,
            ),
            unselectedLabelStyle: AppTypography.meta().copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF9CA3AF),
              letterSpacing: 0.05,
              height: 1.1,
            ),
            elevation: 0,
            onTap: (index) {
              if (_selectedTab.index == index) return;
              setState(() {
                _selectedTab = _HomeTab.values[index];
              });
              if (_HomeTab.values[index] == _HomeTab.applications) {
                unawaited(_refreshApplicationMetrics());
              }
              _closeSuggestions();
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.explore_outlined),
                activeIcon: Icon(Icons.explore),
                label: 'Explore',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite_border_rounded),
                activeIcon: Icon(Icons.favorite_rounded),
                label: 'Saved',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.description_outlined),
                activeIcon: Icon(Icons.description),
                label: 'Applications',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.home_work_outlined),
                activeIcon: Icon(Icons.home_work),
                label: 'Listings',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExploreTab({
    required Map<String, dynamic>? userSession,
    required double bodyPadding,
    required double screenWidth,
  }) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.all(bodyPadding),
          child: TapRegion(
            groupId: _searchTapGroup,
            onTapOutside: (_) => _closeSuggestions(),
            child: CustomScrollView(
              physics: appPageScrollPhysics,
              cacheExtent: 480,
              slivers: _buildHomePageSlivers(
                userSession: userSession,
                contentWidth: screenWidth - (bodyPadding * 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  int _gridCrossAxisCount(double width) {
    if (width >= 1100) return 4;
    if (width >= 720) return 3;
    if (width >= 480) return 2;
    return 1;
  }

  static const double _listingGridSpacing = 16;

  Widget _buildListingGridSliver({
    Key? key,
    required List<ScoredListing> listings,
    required int crossAxisCount,
  }) {
    return SliverGrid(
      key: key,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: _listingGridSpacing,
        mainAxisSpacing: _listingGridSpacing,
        mainAxisExtent: PropertyCard.gridMainAxisExtent,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final scored = listings[index];
          final listingId = ListingData.id(scored.listing, fallbackIndex: index);
          return _buildListingCard(
            scored,
            index: index,
            key: ValueKey(listingId.isEmpty ? 'listing-$index' : listingId),
          );
        },
        childCount: listings.length,
      ),
    );
  }

  List<Widget> _buildHomePageSlivers({
    required Map<String, dynamic>? userSession,
    required double contentWidth,
  }) {
    final crossAxisCount = _gridCrossAxisCount(contentWidth);

    return [
      SliverToBoxAdapter(
        child: Center(child: _buildExploreCommandBar()),
      ),
      if (userSession != null &&
          ProfileData.calculateProfileCompletionPercentage(userSession) < 100) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverToBoxAdapter(
          child: _buildProfileCompletionBanner(userSession),
        ),
      ],
      if (_showWelcomeFeedBanner) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverToBoxAdapter(child: _buildWelcomeFeedBanner()),
      ],
      if (_showFirstListingPrompt && _ownedListingsForActiveSpace.isEmpty) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverToBoxAdapter(child: _buildFirstListingPromptBanner()),
      ],
      if (_currentPipeline.isCommuteDivergent && !_showSuggestions) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        SliverToBoxAdapter(child: _buildCommuteDivergenceAlert()),
      ],
      if (_currentPipeline.searchSummary != null &&
          !_showSuggestions) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        SliverToBoxAdapter(child: _buildSearchSummaryBanner()),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 10)),
      const SliverToBoxAdapter(
        child: TrustTierLegendScale(
          interactive: false,
          compact: true,
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      SliverToBoxAdapter(child: _buildMarketplaceSectionHeader()),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      if (_listingsLoading)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(
                color: HomeMarketplaceTheme.primary,
              ),
            ),
          ),
        )
      else if (_listings.isEmpty)
        SliverToBoxAdapter(child: _buildListingsEmptyState())
      else if (_currentPipeline.afterTower.isEmpty)
        SliverToBoxAdapter(child: _buildTowerEmptyState())
      else if (_rankedVisibleListings.isEmpty &&
          (_currentPipeline.isCommuteDivergent ||
              (_currentPipeline.hasActiveSearch && !_showSuggestions)))
        SliverToBoxAdapter(
          child: _currentPipeline.isCommuteDivergent
              ? _buildCommuteDivergenceAlert()
              : _buildSearchNoResultsState(),
        )
      else
        SliverIgnorePointer(
          ignoring: _showSuggestions && _flatSuggestions.isNotEmpty,
          sliver: _buildListingGridSliver(
            key: ValueKey(
              'grid-${_activeFilters.foodPreference}-'
              '${_activeFilters.city}-'
              '${_rankedVisibleListings.length}',
            ),
            listings: _rankedVisibleListings,
            crossAxisCount: crossAxisCount,
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }

  List<Map<String, dynamic>> get _towerListings => [
        for (final item in _listings)
          if (ListingData.propertyType(item) == _selectedPropertyType) item,
      ];

  List<SearchSuggestionGroup> get _searchSuggestionGroups {
    if (!_showSuggestions) return const [];
    final seed = _searchController.text.trim();
    if (seed.isEmpty) return const [];
    return ListingSearchSuggestions.suggestGrouped(
      seed,
      listings: _towerListings,
      viewer: ViewerProfile.fromSession(AuthScreen.currentUserSession),
      recentSearchQueries: _recentSearchQueries,
    );
  }

  void _recordRecentSearch(String query) {
    final normalized = ListingSearchIntent.normalizeQuery(query);
    if (normalized.isEmpty) return;
    _recentSearchQueries.remove(normalized);
    _recentSearchQueries.insert(0, normalized);
    if (_recentSearchQueries.length > 8) {
      _recentSearchQueries.removeLast();
    }
  }

  List<SearchSuggestion> get _flatSuggestions => [
        for (final group in _searchSuggestionGroups) ...group.items,
      ];

  void _closeSuggestions() {
    if (!_showSuggestions && _highlightedSuggestionIndex < 0) return;
    setState(() {
      _showSuggestions = false;
      _highlightedSuggestionIndex = -1;
    });
    _syncSearchDropdownOverlay();
  }

  KeyEventResult _handleSearchKeyEvent(KeyEvent event) {
    final items = _flatSuggestions;
    if (event is! KeyDownEvent || items.isEmpty) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _showSuggestions = true;
        _highlightedSuggestionIndex =
            (_highlightedSuggestionIndex + 1) % items.length;
      });
      _markSearchDropdownDirty();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _showSuggestions = true;
        _highlightedSuggestionIndex = _highlightedSuggestionIndex <= 0
            ? items.length - 1
            : _highlightedSuggestionIndex - 1;
      });
      _markSearchDropdownDirty();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_highlightedSuggestionIndex >= 0 &&
          _highlightedSuggestionIndex < items.length) {
        _handleSuggestionSelect(items[_highlightedSuggestionIndex]);
      } else {
        _commitSearchFromField();
        _searchFocusNode.unfocus();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _closeSuggestions();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Handles a suggestion click: builds filters, runs pipeline, updates grid.
  /// No listener management needed — onChanged only controls suggestions,
  /// never touches the pipeline.
  void _handleSuggestionSelect(SearchSuggestion item) {
    final filters = item.toSearchFilters();

    if (filters.isEmpty) {
      if (kDebugMode) {
        debugPrint('SUGGESTION: no filters resolved for "${item.label}"');
      }
      return;
    }

    final pipelineQuery = filters.pipelineQueryText(searchText: item.query);

    final displayText =
        SearchSuggestion.stripCountSuffix(item.label).isNotEmpty
            ? SearchSuggestion.stripCountSuffix(item.label)
            : item.label;

    if (kDebugMode) {
      debugPrint(
        'SUGGESTION CLICKED: ${item.label} → '
        'food=${filters.foodPreference}, city=${filters.city}, '
        'occupant=${filters.occupantType}, gender=${filters.genderPreference}',
      );
    }

    _settingTextProgrammatically = true;
    _searchController.text = displayText;
    _settingTextProgrammatically = false;

    // 2. Run pipeline — this is the ONLY place that sets _pipelineResult.
    _runSearchWithFilters(filters, pipelineQuery: pipelineQuery);

    // 3. Unfocus and record.
    _searchFocusNode.unfocus();
    _recordRecentSearch(pipelineQuery);
  }

  Widget _buildExploreCommandBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: HomeMarketplaceTheme.searchBlockMaxWidth,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildExploreHeroCopy(),
            const SizedBox(height: 24),
            DecoratedBox(
              decoration: BoxDecoration(
                color: HomeMarketplaceTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HomeMarketplaceTheme.border),
                boxShadow: HomeMarketplaceTheme.cardShadowRest,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SpaceSwitcher(
                      activeSpace: _activeSpace,
                      onSelected: (space) => unawaited(_selectActiveSpace(space)),
                    ),
                    const SizedBox(height: 10),
                    _buildSearchBarAnchor(),
                    const SizedBox(height: 10),
                    MarketplaceFilterBar(
                      towerPropertyType: _selectedPropertyType,
                      activeFilters: _activeFilters,
                      onFiltersChanged: _onChipFiltersChanged,
                      onClearAll: _clearAllFilters,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreHeroCopy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Match with spaces and communities that actually fit your story.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: HomeMarketplaceTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          HomeMarketplaceTheme.brandTagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBarAnchor() {
    final showDropdown = _showSuggestions && _flatSuggestions.isNotEmpty;
    final searchFieldRounded = showDropdown ? 16.0 : 999.0;

    return TapRegion(
      groupId: _searchTapGroup,
      child: SizedBox(
        key: _searchBarAnchorKey,
        height: _searchBarHeight,
        width: double.infinity,
        child: _buildSearchInputField(searchFieldRounded),
      ),
    );
  }

  Widget _buildSearchInputField(double borderRadius) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: HomeMarketplaceTheme.border),
        boxShadow: HomeMarketplaceTheme.searchShadowSm,
      ),
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Focus(
          focusNode: _searchFocusNode,
          onKeyEvent: (node, event) => _handleSearchKeyEvent(event),
          child: TextField(
            controller: _searchController,
            style: AppTypography.searchInputProminent(),
            textInputAction: TextInputAction.search,
            onChanged: _onSearchTextChanged,
            onTap: () {
              if (_searchController.text.trim().isEmpty) return;
              setState(() => _showSuggestions = true);
              _syncSearchDropdownOverlay();
            },
            onSubmitted: (_) {
              final items = _flatSuggestions;
              if (_highlightedSuggestionIndex >= 0 &&
                  _highlightedSuggestionIndex < items.length) {
                _handleSuggestionSelect(items[_highlightedSuggestionIndex]);
              } else {
                _commitSearchFromField();
                _searchFocusNode.unfocus();
              }
            },
            decoration: InputDecoration(
              hintText: MarketConfig.current.searchBarHint,
              hintStyle: AppTypography.searchHint(),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: HomeMarketplaceTheme.textMuted,
                size: 24,
              ),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: HomeMarketplaceTheme.textSecondary,
                      onPressed: () {
                        _searchController.clear();
                        _clearSearch();
                      },
                    ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              isDense: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchDropdownOverlayLayer() {
    final anchorContext = _searchBarAnchorKey.currentContext;
    if (anchorContext == null) {
      return const SizedBox.shrink();
    }

    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return const SizedBox.shrink();
    }

    final anchorOrigin = box.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalInset = MediaQuery.paddingOf(context).horizontal + 48;
    final dropdownWidth = (screenWidth - horizontalInset)
        .clamp(0.0, HomeMarketplaceTheme.searchBlockMaxWidth);

    return Positioned(
      left: anchorOrigin.dx,
      top: anchorOrigin.dy + box.size.height + _searchDropdownGap,
      width: dropdownWidth,
      child: TapRegion(
        groupId: _searchTapGroup,
        child: Material(
          elevation: 6,
          color: Colors.white,
          borderRadius: BorderRadius.circular(_searchDropdownRadius),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: HomeMarketplaceTheme.border),
              borderRadius: BorderRadius.circular(_searchDropdownRadius),
            ),
            child: _buildSearchSuggestionsDropdown(_searchSuggestionGroups),
          ),
        ),
      ),
    );
  }

  double _estimateSearchDropdownContentHeight(
      List<SearchSuggestionGroup> groups) {
    const captionHeight = 36.0;
    const groupHeaderHeight = 28.0;
    const dividerHeight = 1.0;
    const suggestionTileHeight = 44.0;
    const listVerticalPadding = 12.0;
    const bottomGap = 4.0;

    var height = captionHeight + listVerticalPadding + bottomGap;
    for (var g = 0; g < groups.length; g++) {
      if (g > 0) height += dividerHeight;
      height += groupHeaderHeight;
      height += groups[g].items.length * suggestionTileHeight;
    }
    return height;
  }

  Widget _buildSearchSuggestionsDropdown(List<SearchSuggestionGroup> groups) {
    var flatIndex = 0;
    final fromListings =
        groups.isNotEmpty && !groups.every((g) => g.isFallback);
    final contentHeight = _estimateSearchDropdownContentHeight(groups);
    final viewportHeight = contentHeight > _searchDropdownMaxHeight
        ? _searchDropdownMaxHeight
        : contentHeight;
    final scrollable = contentHeight > _searchDropdownMaxHeight;

    return ScrollConfiguration(
      behavior: const DropdownScrollBehavior(),
      child: Container(
        constraints: const BoxConstraints(
          maxHeight: _searchDropdownMaxHeight,
        ),
        child: SizedBox(
          height: viewportHeight,
          child: ListView(
            shrinkWrap: !scrollable,
            padding: const EdgeInsets.symmetric(vertical: 6),
            physics: scrollable
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Text(
                  fromListings ? 'Based on your listings' : 'Popular searches',
                  style: AppTypography.suggestionCaption(),
                ),
              ),
              for (var g = 0; g < groups.length; g++) ...[
                if (g > 0)
                  const Divider(height: 1, color: HomeMarketplaceTheme.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                  child: Text(
                    groups[g].title,
                    style: AppTypography.suggestionGroup(),
                  ),
                ),
                for (var i = 0; i < groups[g].items.length; i++)
                  Builder(
                    builder: (context) {
                      final index = flatIndex;
                      flatIndex += 1;
                      final item = groups[g].items[i];
                      final highlighted =
                          index == _highlightedSuggestionIndex;
                      return Material(
                        color: highlighted
                            ? HomeMarketplaceTheme.searchSurface
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => _handleSuggestionSelect(item),
                          onHover: (hovering) {
                            if (!hovering) return;
                            if (_highlightedSuggestionIndex == index) return;
                            setState(
                              () => _highlightedSuggestionIndex = index,
                            );
                            _markSearchDropdownDirty();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            child: Text(
                              item.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.suggestionItem(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommuteDivergenceAlert() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB347), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33FFB347),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.alt_route_rounded, size: 22, color: Color(0xFFFFB347)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              MarketplaceListingPipelineResult.commuteDivergenceNotice,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: Color(0xFFF3F4F6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSummaryBanner() {
    final pipeline = _currentPipeline;
    final summary = pipeline.searchSummary!;
    final notice = pipeline.relaxationNotice;
    final isDivergent = pipeline.isCommuteDivergent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isDivergent ? const Color(0xFF1A2332) : HomeMarketplaceTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDivergent ? const Color(0xFFFFB347) : HomeMarketplaceTheme.border,
        ),
        boxShadow: HomeMarketplaceTheme.cardShadowRest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isDivergent
                    ? Icons.alt_route_rounded
                    : Icons.travel_explore_rounded,
                size: 17,
                color: isDivergent
                    ? const Color(0xFFFFB347)
                    : HomeMarketplaceTheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary,
                  style: AppTypography.cardTitle().copyWith(
                    color: isDivergent ? const Color(0xFFF3F4F6) : null,
                  ),
                ),
              ),
            ],
          ),
          if (notice != null && !isDivergent) ...[
            const SizedBox(height: 5),
            Text(notice, style: AppTypography.detail()),
          ],
        ],
      ),
    );
  }

  void _switchToExploreTab() {
    if (_selectedTab == _HomeTab.explore) return;
    setState(() => _selectedTab = _HomeTab.explore);
    _closeSuggestions();
  }

  Widget _buildApplicationsTab() {
    final applications = _userApplicationsForActiveSpace;

    if (!_applicationsReady) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(color: HomeMarketplaceTheme.primary),
        ),
      );
    }

    if (applications.isEmpty) {
      return _HomeDashboardEmptyState(
        icon: Icons.description_outlined,
        title: "You haven't applied to any places yet",
        subtitle: 'Find places you like and apply in seconds',
        actionLabel: 'Browse homes',
        onAction: _switchToExploreTab,
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Applications', style: AppTypography.sectionTitle()),
          const SizedBox(height: 4),
          Text(
            '${applications.length} pending in ${_activeSpace.label}',
            style: AppTypography.sectionMeta(),
          ),
          const SizedBox(height: 16),
          for (final application in applications)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ApplicationTile(
                title: _listingTitleForApplication(application),
                statusLabel: 'Pending',
                appliedLabel:
                    'Applied ${_formatAppliedDate(application.createdAt)}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListingsTab({required double bodyPadding}) {
    final spaceListings = _ownedListingsForActiveSpace;

    if (spaceListings.isEmpty) {
      return _HomeDashboardEmptyState(
        icon: Icons.home_work_outlined,
        title: 'No listings yet',
        subtitle: 'Post a listing if you have a room or property to fill',
        actionLabel: '+ Add Listing',
        onAction: _goAddListing,
      );
    }

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: EdgeInsets.all(bodyPadding),
            children: [
              Text('Listings', style: AppTypography.sectionTitle()),
              const SizedBox(height: 4),
              Text(
                'Your listings',
                style: AppTypography.sectionMeta(),
              ),
              const SizedBox(height: 20),
              if (_applicationCount > 0) ...[
                _YourListingsSummaryRow(
                  listingCount: spaceListings.length,
                  applicationCount: _applicationCount,
                  averageMatchPercent: _averageMatchPercent,
                ),
                const SizedBox(height: 16),
              ],
              for (var index = 0; index < spaceListings.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _YourListingTile(
                    listing: spaceListings[index],
                    activeSpace: _activeSpace,
                    onManage: () {
                      final id = ListingData.id(spaceListings[index]);
                      if (id.isNotEmpty) context.push('/listing/$id/manage');
                    },
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _goAddListing,
                style: AppButtonStyles.primaryFilled,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('+ Add Listing', style: AppTypography.button()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _ownedListingsForActiveSpace {
    final owned = DublinMockData.useMockHarness &&
            marketplaceContextNotifier.ownedListings.isEmpty
        ? DublinMockData.ownedListingsForHost()
        : marketplaceContextNotifier.ownedListings;
    return [
      for (final listing in owned)
        if (MarketplaceSpace.fromTowerPropertyType(
              ListingData.propertyType(listing),
            ) ==
            _activeSpace)
          listing,
    ];
  }

  Widget _buildProfileCompletionBanner(Map<String, dynamic> userSession) {
    final missing = ProfileData.missingFieldsForCompletion(userSession);
    final percent =
        ProfileData.calculateProfileCompletionPercentage(userSession);
    if (percent >= 100) return const SizedBox.shrink();
    final missingText = missing.take(3).join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.searchSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeMarketplaceTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: HomeMarketplaceTheme.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile $percent% complete',
                  style: AppTypography.cardTitle(),
                ),
                const SizedBox(height: 4),
                Text(
                  missing.isEmpty
                      ? 'Add a few more details for better ranking.'
                      : 'Still needed: $missingText',
                  style: AppTypography.detail(),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _openProfileEdit(initialProfile: userSession),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeFeedBanner() {
    final filterSummary = _activeFilters.isEmpty
        ? 'your onboarding preferences'
        : _activeFilters.pipelineQueryText();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HomeMarketplaceTheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.explore_rounded,
            color: HomeMarketplaceTheme.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to your feed',
                  style: AppTypography.cardTitle(),
                ),
                const SizedBox(height: 4),
                Text(
                  filterSummary.isEmpty
                      ? 'Listings ranked by your commute and profile.'
                      : 'Showing matches for $filterSummary.',
                  style: AppTypography.detail(),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _showWelcomeFeedBanner = false),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstListingPromptBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.searchSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeMarketplaceTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.home_work_outlined,
            color: HomeMarketplaceTheme.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to list your space?',
                  style: AppTypography.cardTitle(),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your host profile is saved. Add your first listing when you are ready.',
                  style: AppTypography.detail(),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _goAddListing,
                  style: AppButtonStyles.primaryFilled,
                  child: Text('+ Add your first listing', style: AppTypography.button()),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _showFirstListingPrompt = false),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceSectionHeader() {
    final isShared = _activeSpace == MarketplaceSpace.sharedSpace;
    final spaceLabel = isShared
        ? 'Shared Living in Dublin'
        : 'Independent Places in Dublin';

    return Text(
      spaceLabel,
      style: AppTypography.sectionTitle().copyWith(
        fontWeight: FontWeight.w800,
        color: const Color(0xFF222222),
      ),
    );
  }

  Widget _buildSearchNoResultsState() {
    final summary = _currentPipeline.requestedIntent.displaySummary;
    final towerLabel = _activeSpace.label;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeMarketplaceTheme.border),
        boxShadow: HomeMarketplaceTheme.cardShadowRest,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 36,
            color: HomeMarketplaceTheme.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            summary.isEmpty
                ? 'No matches for your search'
                : 'No $towerLabel matches for $summary',
            textAlign: TextAlign.center,
            style: AppTypography.sectionTitle()
                .copyWith(fontSize: AppTypography.textMd),
          ),
          const SizedBox(height: 6),
          Text(
            'Try another $towerLabel search, clear filters, or switch tabs',
            textAlign: TextAlign.center,
            style: AppTypography.detail(),
          ),
        ],
      ),
    );
  }

  Widget _buildTowerEmptyState() {
    final label = _activeSpace.label;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeMarketplaceTheme.border),
        boxShadow: HomeMarketplaceTheme.cardShadowRest,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.home_work_outlined,
              size: 36, color: HomeMarketplaceTheme.textMuted),
          const SizedBox(height: 12),
          Text(
            'No $label listings yet',
            style: AppTypography.sectionTitle().copyWith(fontSize: AppTypography.textMd),
          ),
          const SizedBox(height: 6),
          Text(
            'Try another tab or add a new listing',
            textAlign: TextAlign.center,
            style: AppTypography.detail(),
          ),
        ],
      ),
    );
  }

  Widget _buildListingsEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeMarketplaceTheme.border),
        boxShadow: HomeMarketplaceTheme.cardShadowRest,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.home_work_outlined,
              size: 44, color: HomeMarketplaceTheme.textMuted),
          const SizedBox(height: 14),
          Text(
            'No listings yet',
            style: AppTypography.sectionTitle().copyWith(fontSize: AppTypography.textMd),
          ),
          const SizedBox(height: 8),
          Text(
            'Post a listing if you have a room or property to fill',
            textAlign: TextAlign.center,
            style: AppTypography.detail(),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _goAddListing,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text('Add listing', style: AppTypography.button()),
            style: AppButtonStyles.primaryFilled,
          ),
        ],
      ),
    );
  }

  Widget _buildListingCard(ScoredListing scored, {required int index, Key? key}) {
    final item = scored.listing;
    final listingId = ListingData.id(item, fallbackIndex: index);

    return PropertyCard(
      key: key,
      listing: item,
      match: scored.match,
      viewerProfile: AuthScreen.currentUserSession,
      activeSpace: _activeSpace,
      onTap: () {
        if (listingId.isEmpty) return;
        context.push('/listing/$listingId', extra: item);
      },
    );
  }

}

/// Avatar + name control with hover, tooltip, and account menu.
class _UserHeaderMenu extends StatefulWidget {
  const _UserHeaderMenu({
    required this.fullName,
    required this.onViewProfile,
    required this.onLogout,
  });

  final String fullName;
  final VoidCallback onViewProfile;
  final VoidCallback onLogout;

  @override
  State<_UserHeaderMenu> createState() => _UserHeaderMenuState();
}

class _UserHeaderMenuState extends State<_UserHeaderMenu> {
  bool _hovering = false;

  String get _initial {
    final trimmed = widget.fullName.trim();
    if (trimmed.isEmpty) return 'U';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _HomeNavBar.actionHeight,
      child: Material(
        color: _hovering ? HomeMarketplaceTheme.canvas : HomeMarketplaceTheme.surface,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Tooltip(
              message: 'View Profile',
              waitDuration: const Duration(milliseconds: 350),
              child: InkWell(
                onTap: widget.onViewProfile,
                onHover: (hovering) => setState(() => _hovering = hovering),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 2, 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: HomeMarketplaceTheme.primary,
                          radius: _HomeNavBar.avatarRadius,
                          child: Text(
                            _initial,
                            style: AppTypography.button().copyWith(
                              fontSize: 13,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            widget.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cardTitle().copyWith(
                              fontSize: 14,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              splashRadius: 18,
              tooltip: 'Account menu',
              offset: const Offset(0, 40),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              color: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: Color(0xFF606770),
              ),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  widget.onViewProfile();
                case 'logout':
                  widget.onLogout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 18, color: HomeMarketplaceTheme.textSecondary),
                    const SizedBox(width: 10),
                    Text('View Profile', style: AppTypography.cardTitle()),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded,
                        size: 18, color: HomeMarketplaceTheme.textSecondary),
                    const SizedBox(width: 10),
                    Text('Log out', style: AppTypography.cardTitle()),
                  ],
                ),
              ),
            ],
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({
    required this.title,
    required this.statusLabel,
    required this.appliedLabel,
  });

  final String title;
  final String statusLabel;
  final String appliedLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeMarketplaceTheme.border),
        boxShadow: HomeMarketplaceTheme.cardShadowRest,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.cardTitle(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: HomeMarketplaceTheme.searchSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: HomeMarketplaceTheme.border),
                  ),
                  child: Text(
                    statusLabel,
                    style: AppTypography.detail().copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(appliedLabel, style: AppTypography.detail()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _YourListingsSummaryRow extends StatelessWidget {
  const _YourListingsSummaryRow({
    required this.listingCount,
    required this.applicationCount,
    required this.averageMatchPercent,
  });

  final int listingCount;
  final int applicationCount;
  final double averageMatchPercent;

  @override
  Widget build(BuildContext context) {
    final avgLabel =
        '${NumericBounds.clampPercentInt(averageMatchPercent)}%';

    return Row(
      children: [
        _YourListingsMetric(label: 'Listings', value: '$listingCount'),
        const SizedBox(width: 12),
        _YourListingsMetric(label: 'Applications', value: '$applicationCount'),
        const SizedBox(width: 12),
        _YourListingsMetric(label: 'Avg match', value: avgLabel),
      ],
    );
  }
}

class _YourListingsMetric extends StatelessWidget {
  const _YourListingsMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: HomeMarketplaceTheme.searchSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: HomeMarketplaceTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.detail()),
            const SizedBox(height: 4),
            Text(value, style: AppTypography.cardTitle()),
          ],
        ),
      ),
    );
  }
}

class _YourListingTile extends StatelessWidget {
  const _YourListingTile({
    required this.listing,
    required this.activeSpace,
    required this.onManage,
  });

  final Map<String, dynamic> listing;
  final MarketplaceSpace activeSpace;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final manageLabel = activeSpace == MarketplaceSpace.sharedSpace
        ? 'Review matches'
        : 'Review applicants';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeMarketplaceTheme.border),
        boxShadow: HomeMarketplaceTheme.cardShadowRest,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ListingData.title(listing),
                    style: AppTypography.cardTitle(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ListingData.location(listing),
                    style: AppTypography.detail(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ListingData.price(listing),
                    style: AppTypography.cardPrice(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onManage,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                manageLabel,
                style: AppTypography.button().copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

abstract final class _HomeNavBar {
  static const markSize = 28.0;
  static const wordmarkSize = 20.0;
  static const horizontalPadding = 24.0;
  static const toolbarHeight = 64.0;
  static const actionHeight = 40.0;
  static const avatarRadius = 14.0;
}

class _HomeDashboardEmptyState extends StatelessWidget {
  const _HomeDashboardEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  static const _maxWidth = 480.0;

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: HomeMarketplaceTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: HomeMarketplaceTheme.border),
                boxShadow: HomeMarketplaceTheme.cardShadowRest,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      icon,
                      size: 36,
                      color: HomeMarketplaceTheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTypography.sectionTitle(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.searchHint(),
                    ),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: onAction,
                        style: AppButtonStyles.primaryFilled,
                        child: Text(
                          actionLabel!,
                          style: AppTypography.button(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
