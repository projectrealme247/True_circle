import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../services/listings_storage_service.dart';
import '../services/profile_storage_service.dart';
import '../utils/listing_data.dart';
import '../utils/listing_match_engine.dart';
import '../utils/listing_search_intent.dart';
import '../utils/listing_search_suggestions.dart';
import '../utils/marketplace_listing_pipeline.dart';
import '../utils/viewer_profile.dart';
import '../widgets/hoverable_listing_card.dart';
import '../widgets/listing_food_badge.dart';
import '../widgets/listing_cover_image.dart';
import '../widgets/listing_match_banner.dart';
import '../widgets/listing_occupant_badges.dart';
import '../widgets/home_tower_tabs.dart';
import '../widgets/listing_property_type_badge.dart';
import '../widgets/circlekey_logo.dart';
import '../theme/app_scroll_behavior.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import 'auth_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _listings = [];
  bool _listingsLoading = true;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  /// Single pipeline result — always the source of truth for the grid.
  MarketplaceListingPipelineResult? _pipelineResult;

  /// Active filters applied to the current pipeline.
  ListingSearchFilters _activeFilters = const ListingSearchFilters();

  String _selectedPropertyType = 'Rent';
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
  /// Guards against [onChanged] firing when text is set programmatically.
  bool _settingTextProgrammatically = false;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  @override
  void dispose() {
    _removeSearchDropdownOverlay();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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

  MarketplaceListingPipelineResult _runDefaultPipeline() {
    return MarketplaceListingPipeline.runWithFilters(
      allListings: _listings,
      towerPropertyType: _selectedPropertyType,
      filters: const ListingSearchFilters(),
      userSession: AuthScreen.currentUserSession,
    );
  }

  List<ScoredListing> get _rankedVisibleListings => _currentPipeline.ranked;

  /// Runs search from the text field (Enter key).
  void _commitSearchFromField() {
    final text = SearchSuggestion.stripCountSuffix(_searchController.text);
    if (text.isEmpty) {
      _clearSearch();
      return;
    }
    final parsed = ListingSearchIntent.parseQuery(text);
    final filters = ListingSearchFilters.fromIntent(parsed);
    _runSearchWithFilters(filters, pipelineQuery: text);
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
      userSession: AuthScreen.currentUserSession,
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
    setState(() {
      _showSuggestions = false;
      _highlightedSuggestionIndex = -1;
      _activeFilters = const ListingSearchFilters();
      _pipelineResult = _runDefaultPipeline();
    });
    _removeSearchDropdownOverlay();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledListingAddedMessage) return;

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

  Future<void> _loadHomeData() async {
    await _hydrateSessionFromStorage();
    await _loadListingsFromStorage();
  }

  Future<void> _hydrateSessionFromStorage() async {
    // Don't auto-restore session from storage — matching features
    // require the user to explicitly sign in each session.
    // Profile data remains in storage for the auth/edit screen.
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadListingsFromStorage() async {
    if (!_listingsLoading) {
      setState(() => _listingsLoading = true);
    }
    try {
      final listings = await ListingsStorageService.load();
      if (!mounted) return;
      _listings = listings;
      _listingsLoading = false;

      if (!_activeFilters.isEmpty) {
        _runSearchWithFilters(
          _activeFilters,
          pipelineQuery: _activeFilters.toPipelineQuery(),
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
    if (AuthScreen.currentUserSession == null) {
      _openSignIn();
      return;
    }
    context.push('/add-listing').then((_) {
      if (mounted) _loadListingsFromStorage();
    });
  }

  Widget _buildAddListingButton({bool compact = false}) {
    if (compact) {
      return FilledButton(
        onPressed: _goAddListing,
        style: FilledButton.styleFrom(
          backgroundColor: HomeMarketplaceTheme.accent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'Add Listing',
              style: AppTypography.button().copyWith(fontSize: AppTypography.textSm),
            ),
          ],
        ),
      );
    }

    return FilledButton.icon(
      onPressed: _goAddListing,
      icon: const Icon(Icons.add_rounded, size: 20),
      label: Text('Add Listing', style: AppTypography.button()),
      style: FilledButton.styleFrom(
        backgroundColor: HomeMarketplaceTheme.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read the public global session variable
    final userSession = AuthScreen.currentUserSession;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final bodyPadding = screenWidth < 600 ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: HomeMarketplaceTheme.canvas,
      appBar: AppBar(
        backgroundColor: HomeMarketplaceTheme.surface,
        foregroundColor: HomeMarketplaceTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            const CircleKeyLogo(size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: 'Circle',
                    style: AppTypography.appBarBrand().copyWith(
                      color: HomeMarketplaceTheme.primary,
                    ),
                  ),
                  TextSpan(
                    text: 'Key',
                    style: AppTypography.appBarBrand().copyWith(
                      color: HomeMarketplaceTheme.accent,
                    ),
                  ),
                ]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(child: _buildAddListingButton(compact: true)),
          ),
          if (userSession == null)
              Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final shouldRefresh = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AuthScreen()),
                    );
                    if (shouldRefresh == true && mounted) {
                      setState(() {
                        _pipelineResult = null;
                      });
                    }
                  },
                  icon: const Icon(Icons.login, size: 16, color: Colors.white),
                  label: Text(
                    'Sign In',
                    style: AppTypography.button().copyWith(fontSize: AppTypography.textSm),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HomeMarketplaceTheme.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: _UserHeaderMenu(
                  fullName: userSession['full_name']?.toString() ?? 'User',
                  onViewProfile: () => context.go('/profile'),
                  onLogout: () async {
                    AuthScreen.currentUserSession = null;
                    await ProfileStorageService.clear();
                    if (mounted) {
                      setState(() {
                        _pipelineResult = null;
                      });
                    }
                  },
                ),
              ),
            ),
        ],
      ),
      body: Padding(
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
    );
  }

  int _gridCrossAxisCount(double width) {
    if (width >= 1100) return 4;
    if (width >= 720) return 3;
    if (width >= 480) return 2;
    return 1;
  }

  static const double _listingGridSpacing = 16;

  double _listingCellWidth(double contentWidth, int crossAxisCount) {
    if (crossAxisCount <= 1) return contentWidth;
    return (contentWidth - _listingGridSpacing * (crossAxisCount - 1)) /
        crossAxisCount;
  }

  Widget _buildListingCardsWrap({
    Key? key,
    required List<ScoredListing> listings,
    required double contentWidth,
    required int crossAxisCount,
  }) {
    if (kDebugMode) {
      debugPrint('UI using listings: ${listings.length}');
    }

    final itemWidth = _listingCellWidth(contentWidth, crossAxisCount);
    final cards = <Widget>[];
    for (var index = 0; index < listings.length; index++) {
      final scored = listings[index];
      final listingId = ListingData.id(scored.listing, fallbackIndex: index);
      cards.add(
        SizedBox(
          width: itemWidth,
          child: _buildListingCard(
            scored,
            index: index,
            key: ValueKey(listingId.isEmpty ? 'listing-$index' : listingId),
          ),
        ),
      );
    }
    return Wrap(
      key: key,
      spacing: _listingGridSpacing,
      runSpacing: _listingGridSpacing,
      children: cards,
    );
  }

  List<Widget> _buildHomePageSlivers({
    required Map<String, dynamic>? userSession,
    required double contentWidth,
  }) {
    final crossAxisCount = _gridCrossAxisCount(contentWidth);

    return [
      SliverToBoxAdapter(child: _buildHeroSection(userSession: userSession)),
      const SliverToBoxAdapter(child: SizedBox(height: 40)),
      SliverToBoxAdapter(
        child: Center(child: _buildSearchSection()),
      ),
      if (_currentPipeline.searchSummary != null &&
          !_showSuggestions) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(child: _buildSearchSummaryBanner()),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 28)),
      SliverToBoxAdapter(child: _buildMarketplaceSectionHeader()),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
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
          _currentPipeline.hasActiveSearch &&
          !_showSuggestions)
        SliverToBoxAdapter(child: _buildSearchNoResultsState())
      else
        SliverToBoxAdapter(
          child: IgnorePointer(
            ignoring: _showSuggestions && _flatSuggestions.isNotEmpty,
            child: _buildListingCardsWrap(
              key: ValueKey(
                'grid-${_activeFilters.foodPreference}-'
                '${_activeFilters.city}-'
                '${_rankedVisibleListings.length}',
              ),
              listings: _rankedVisibleListings,
              contentWidth: contentWidth,
              crossAxisCount: crossAxisCount,
            ),
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

    final pipelineQuery = item.query.trim().isNotEmpty
        ? item.query
        : filters.toPipelineQuery();

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

  Widget _buildSearchSection() {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: HomeMarketplaceTheme.searchBlockMaxWidth,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HomeMarketplaceTheme.surface,
          borderRadius: BorderRadius.circular(
            HomeMarketplaceTheme.searchBlockRadius,
          ),
          border: Border.all(color: HomeMarketplaceTheme.border),
          boxShadow: HomeMarketplaceTheme.searchShadowSm,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              HomeTowerTabs(
                selectedPropertyType: _selectedPropertyType,
                onSelected: (type) {
                  if (_selectedPropertyType == type) return;
                  _selectedPropertyType = type;
                  if (!_activeFilters.isEmpty) {
                    _runSearchWithFilters(
                      _activeFilters,
                      pipelineQuery: _activeFilters.toPipelineQuery(),
                    );
                  } else {
                    setState(() {
                      _pipelineResult = _runDefaultPipeline();
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              _buildSearchBarAnchor(),
            ],
          ),
        ),
      ),
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
    return Material(
      elevation: 0,
      shadowColor: Colors.transparent,
      color: HomeMarketplaceTheme.searchSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: const BorderSide(color: HomeMarketplaceTheme.border),
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
              hintText: 'Try Veg in Hyderabad, Family in Bangalore…',
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
                            ? HomeMarketplaceTheme.canvas
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

  Widget _buildSearchSummaryBanner() {
    final pipeline = _currentPipeline;
    final summary = pipeline.searchSummary!;
    final notice = pipeline.relaxationNotice;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: HomeMarketplaceTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HomeMarketplaceTheme.border),
        boxShadow: HomeMarketplaceTheme.cardShadowRest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.travel_explore_rounded,
                size: 17,
                color: HomeMarketplaceTheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary,
                  style: AppTypography.cardTitle(),
                ),
              ),
            ],
          ),
          if (notice != null) ...[
            const SizedBox(height: 5),
            Text(notice, style: AppTypography.detail()),
          ],
        ],
      ),
    );
  }

  Future<void> _openSignIn() async {
    final shouldRefresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );
    if (shouldRefresh == true && mounted) {
      setState(() {
        _pipelineResult = null;
      });
    }
  }

  Widget _buildHeroSection({
    required Map<String, dynamic>? userSession,
  }) {
    final signedIn = userSession != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 36, 8, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Find homes where you feel understood',
                textAlign: TextAlign.center,
                style: AppTypography.heroTitle(),
              ),
              const SizedBox(height: 16),
              Text(
                'Matched by lifestyle, language, and preferences you can trust',
                textAlign: TextAlign.center,
                style: AppTypography.heroSubtitle(),
              ),
              const SizedBox(height: 28),
              if (!signedIn)
                FilledButton(
                  onPressed: _openSignIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeMarketplaceTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 15,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'See your matches',
                    style: AppTypography.button(),
                  ),
                )
              else
                Text(
                  'Showing matches tailored to your profile',
                  textAlign: TextAlign.center,
                  style: AppTypography.detail(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarketplaceSectionHeader() {
    final count = _rankedVisibleListings.length;
    final subtext = _listingsLoading
        ? 'Finding homes that match you…'
        : count == 0
            ? 'No homes match your preferences and search yet'
            : count == 1
                ? '1 home based on your preferences and search'
                : '$count homes based on your preferences and search';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Homes that truly fit you',
          style: AppTypography.sectionTitle(),
        ),
        const SizedBox(height: 4),
        Text(subtext, style: AppTypography.sectionMeta()),
      ],
    );
  }

  Widget _buildSearchNoResultsState() {
    final summary = _currentPipeline.requestedIntent.displaySummary;
    final towerLabel = HomeTowerTabs.tabs
        .firstWhere((t) => t.type == _selectedPropertyType)
        .label;

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
    final label = HomeTowerTabs.tabs
        .firstWhere((t) => t.type == _selectedPropertyType)
        .label;

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
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _goAddListing,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text('Add your first listing', style: AppTypography.button()),
            style: FilledButton.styleFrom(
              backgroundColor: HomeMarketplaceTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingCard(ScoredListing scored, {required int index, Key? key}) {
    final item = scored.listing;
    final matchResult = scored.match;
    final listingId = ListingData.id(item, fallbackIndex: index);
    final title = ListingData.title(item);
    final price = ListingData.price(item);
    final location = ListingData.location(item);

    return HoverableListingCard(
      key: key,
      match: matchResult,
      onTap: () {
        if (listingId.isEmpty) return;
        context.push('/listing/$listingId', extra: item);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover image (no overlay)
          AspectRatio(
            aspectRatio: HomeMarketplaceTheme.listingCardImageAspectRatio,
            child: ListingCoverImage(
              listing: item,
              fill: true,
              compact: true,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(HomeMarketplaceTheme.cardRadius),
              ),
            ),
          ),
          // Trust row (full width, right below image)
          ListingTrustRow(match: matchResult),
          // Card body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardPrice(),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardTitle(),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.detail(),
                  ),
                ],
                const SizedBox(height: 8),
                _buildCompactBadgeRow(item),
                if (matchResult.reasons.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ListingMatchReasonLine(
                    reasons: matchResult.reasons,
                    highlighted: matchResult.percentage >= 70,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBadgeRow(Map<String, dynamic> item) {
    final bhk = ListingData.bhk(item);
    final furnishing = ListingData.furnishing(item);
    final category = ListingData.propertyCategory(item);
    final roomType = ListingData.roomType(item);
    final occupants = ListingData.currentOccupants(item);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      clipBehavior: Clip.hardEdge,
      children: [
        ListingPropertyTypeBadge(listing: item),
        if (bhk.isNotEmpty) _textChip(bhk, Icons.apartment_rounded),
        if (furnishing.isNotEmpty) _textChip(furnishing, Icons.chair_rounded),
        if (category.isNotEmpty) _textChip(category, Icons.category_rounded),
        if (roomType.isNotEmpty) _textChip(roomType, Icons.meeting_room_rounded),
        if (occupants > 0) _textChip('$occupants living', Icons.group_rounded),
        ListingFoodBadge(listing: item),
        ListingOccupantBadges(listing: item),
      ],
    );
  }

  Widget _textChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeMarketplaceTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: HomeMarketplaceTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: HomeMarketplaceTheme.textSecondary,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
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
    return Material(
      color: _hovering ? HomeMarketplaceTheme.canvas : HomeMarketplaceTheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
                  padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        backgroundColor: HomeMarketplaceTheme.primary,
                        radius: 17,
                        child: Text(
                          _initial,
                          style: AppTypography.button().copyWith(
                            fontSize: AppTypography.textSm,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          widget.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cardTitle(),
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
            offset: const Offset(0, 36),
            color: Colors.white,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 24,
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
    );
  }
}