import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/market/market_config.dart';
import '../core/theme/app_theme.dart' as core;
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/listing_search_intent.dart';
import '../utils/rental_date_format.dart';
import '../utils/target_search_areas.dart';
import '../models/seeker_onboarding_enums.dart';
import 'area_macro_filter_sheet.dart';
import 'listing_creation/listing_creation_primitives.dart';
import 'onboarding/onboarding_choice_chip.dart';

const double _kFiltersSidebarWidth = 420;

/// Tower-specific filter chips + applied filter pills for the marketplace home.
class MarketplaceFilterBar extends StatelessWidget {
  const MarketplaceFilterBar({
    super.key,
    required this.towerPropertyType,
    required this.activeFilters,
    required this.onFiltersChanged,
    required this.onClearAll,
    this.showAdvancedChips = false,
    this.horizontalChips = false,
    this.onMoreFiltersTap,
    this.moreFiltersActiveCount = 0,
  });

  final String towerPropertyType;
  final ListingSearchFilters activeFilters;
  final ValueChanged<ListingSearchFilters> onFiltersChanged;
  final VoidCallback onClearAll;

  /// When false, only the applied-pills row is shown (default home view).
  final bool showAdvancedChips;

  /// Lays chip dropdowns in a single horizontal scroll row (home hero).
  final bool horizontalChips;

  /// Opens the full More Filters drawer (homepage chip row).
  final VoidCallback? onMoreFiltersTap;

  /// Badge count for filters applied beyond Area + Budget.
  final int moreFiltersActiveCount;

  /// Opens a full-height right-hand filter sidebar (Daft-style drawer).
  static Future<void> showAdvancedFiltersDrawer(
    BuildContext context, {
    required String towerPropertyType,
    required ListingSearchFilters activeFilters,
    required ValueChanged<ListingSearchFilters> onFiltersChanged,
    required VoidCallback onClearAll,
    required int resultCount,
    int Function()? resultCountProvider,
    required List<Map<String, dynamic>> allListings,
    Map<String, dynamic>? userSession,
    String searchQuery = '',
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      barrierLabel: 'Dismiss filters',
      transitionDuration: const Duration(milliseconds: 150),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        );
        return SlideTransition(position: slide, child: child);
      },
      pageBuilder: (ctx, animation, secondaryAnimation) {
        final screenHeight = MediaQuery.sizeOf(ctx).height;
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: _kFiltersSidebarWidth,
              height: screenHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(-4, 0),
                  ),
                ],
              ),
              child: _MarketplaceFiltersSidebar(
                towerPropertyType: towerPropertyType,
                activeFilters: activeFilters,
                onFiltersChanged: onFiltersChanged,
                onClearAll: onClearAll,
                resultCount: resultCount,
                resultCountProvider: resultCountProvider,
                allListings: allListings,
                userSession: userSession,
                searchQuery: searchQuery,
              ),
            ),
          ),
        );
      },
    );
  }

  static int activeFilterCount(ListingSearchFilters filters) =>
      filters.appliedPills().length;

  /// Filters applied beyond the homepage Area + Budget chips.
  static int drawerOnlyActiveCount(
    ListingSearchFilters filters, {
    required String towerPropertyType,
  }) {
    const homepagePillIds = {'city', 'budget'};
    return filters
        .appliedPills(towerPropertyType: towerPropertyType)
        .where((pill) => !homepagePillIds.contains(pill.id))
        .length;
  }

  /// Rent sidebar home-type filter — apartment and house only.
  static const _homeTypeFilterOptions = [
    ('apartment', 'Apartment'),
    ('house', 'House'),
  ];

  static const _foodOptions = [
    ('veg', 'Veg'),
    ('non-veg', 'Non-veg'),
  ];

  /// Shared Living household type — no Family (tab-level exclusion handles that).
  static const _householdTypeOptions = [
    ('Students', '🎓 Students'),
    ('Working Professionals', '💼 Professionals'),
    ('Mixed Household', '🌍 Mixed Household'),
  ];

  static String? householdTypeDisplayLabel(String? occupantType) {
    if (occupantType == null) return null;
    for (final entry in _householdTypeOptions) {
      if (entry.$1 == occupantType) return entry.$2;
    }
    return occupantType;
  }

  @Deprecated('Use householdTypeDisplayLabel')
  static String? suitableForDisplayLabel(String? occupantType) =>
      householdTypeDisplayLabel(occupantType);

  static const _genderOptions = [
    ('mixed', 'Any / Mixed'),
    ('girls', 'Girls only'),
    ('boys', 'Boys only'),
  ];

  static const _genderChoiceLabels = {
    'mixed': '🌍 Any / Mixed',
    'girls': '🙋‍♀️ Girls only',
    'boys': '🙋‍♂️ Boys only',
  };

  /// Shared Living room-type filter — filter-drawer emoji primitives (no 👥 on shared room).
  static const _shareRoomFilterOptions = [
    ('private_bath', '🛌 Private + shared bath'),
    ('ensuite', '🚿 Private ensuite'),
    ('bed_shared', '🛏️ Shared room'),
  ];

  static TextStyle get _sectionSubheaderStyle => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Colors.grey[600],
        fontFamily: core.AppTypography.fontFamily,
        fontFamilyFallback: core.AppTypography.emojiFontFallback,
      );

  static const _smokingKeywords = [
    ('smoking', 'Smoking allowed'),
    ('no-smoking', 'No smoking'),
  ];

  static const _petKeywords = [
    ('pets', 'Pets allowed'),
    ('no-pets', 'No pets'),
  ];

  static List<(int?, int?, String)> get _rentBudgetOptions {
    return MarketConfig.current.rentBudgetBands
        .map((b) => (b.$1, b.$2, b.$3))
        .toList();
  }

  static List<(int?, int?, String)> get _buyBudgetOptions {
    return MarketConfig.current.buyBudgetBands
        .map((b) => (b.$1, b.$2, b.$3))
        .toList();
  }

  static List<(int?, int?, String)> get _shareBudgetOptions {
    return MarketConfig.current.shareBudgetBands
        .map((b) => (b.$1, b.$2, b.$3))
        .toList();
  }

  static const _propertyTypeKeywords = [
    ('apartment', 'Apartment'),
    ('villa', 'Villa'),
    ('plot', 'Plot'),
  ];

  static const _possessionKeywords = [
    ('ready', 'Ready to move'),
    ('construction', 'Under construction'),
  ];

  @override
  Widget build(BuildContext context) {
    final pills = activeFilters.appliedPills(towerPropertyType: towerPropertyType);
    if (!showAdvancedChips && pills.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showAdvancedChips)
          horizontalChips
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0;
                          i < _chipsForTower(towerPropertyType).length;
                          i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _FilterChipDropdown(
                          chip: _chipsForTower(towerPropertyType)[i],
                          towerPropertyType: towerPropertyType,
                          activeFilters: activeFilters,
                          onFiltersChanged: onFiltersChanged,
                        ),
                      ],
                      if (onMoreFiltersTap != null) ...[
                        const SizedBox(width: 8),
                        _MoreFiltersChipButton(
                          onTap: onMoreFiltersTap!,
                          activeCount: moreFiltersActiveCount,
                        ),
                      ],
                    ],
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: [
                    for (final chip in _chipsForTower(towerPropertyType))
                      _FilterChipDropdown(
                        chip: chip,
                        towerPropertyType: towerPropertyType,
                        activeFilters: activeFilters,
                        onFiltersChanged: onFiltersChanged,
                      ),
                    if (onMoreFiltersTap != null)
                      _MoreFiltersChipButton(
                        onTap: onMoreFiltersTap!,
                        activeCount: moreFiltersActiveCount,
                      ),
                  ],
                ),
        if (pills.isNotEmpty) ...[
          if (showAdvancedChips) const SizedBox(height: 12),
          _AppliedFilterPillsRow(
            pills: pills,
            onRemove: (id) => onFiltersChanged(activeFilters.withoutPill(id)),
            onClearAll: onClearAll,
          ),
        ],
      ],
    );
  }

  static List<_FilterChipConfig> _chipsForTower(String towerPropertyType) {
    return switch (towerPropertyType) {
      'Buy' => [
        _FilterChipConfig.city(),
        if (MarketConfig.current.buyBudgetBands.isNotEmpty)
          _FilterChipConfig.budget(),
        _FilterChipConfig.propertyType(),
        _FilterChipConfig.bedroom(),
        _FilterChipConfig.possession(),
      ],
      'Share' => [
        _FilterChipConfig.city(),
        _FilterChipConfig.budget(),
      ],
      _ => [
        _FilterChipConfig.city(),
        _FilterChipConfig.budget(),
      ],
    };
  }
}

class _FilterChipDropdown extends StatelessWidget {
  const _FilterChipDropdown({
    required this.chip,
    required this.towerPropertyType,
    required this.activeFilters,
    required this.onFiltersChanged,
  });

  final _FilterChipConfig chip;
  final String towerPropertyType;
  final ListingSearchFilters activeFilters;
  final ValueChanged<ListingSearchFilters> onFiltersChanged;

  bool get _usesAreaMacroSheet =>
      chip.kind == _FilterChipKind.city &&
      MarketConfig.current.profileUseAreaPicker;

  Future<void> _openAreaMacroSheet(BuildContext context) async {
    final initial = activeFilters.effectiveAreaTokens;
    final result = await showAreaMacroFilterSheet(
      context,
      initialSelection: initial.isEmpty
          ? TargetSearchAreas.allDublinFilterTokens
          : initial,
    );
    if (result == null) return;
    onFiltersChanged(
      activeFilters.copyWith(
        city: null,
        targetSearchAreas: result,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_usesAreaMacroSheet) {
      return _FilterChipButton(
        label: chip.label,
        valueLabel: chip.valueLabel(activeFilters, towerPropertyType),
        isActive: chip.isActive(activeFilters, towerPropertyType),
        isOpen: false,
        onTap: () => _openAreaMacroSheet(context),
      );
    }

    final options = chip.optionsFor(towerPropertyType);
    final selectedId = chip.selectedId(activeFilters, towerPropertyType);

    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(HomeMarketplaceTheme.surface),
        elevation: const WidgetStatePropertyAll(6),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
        minimumSize: const WidgetStatePropertyAll(Size(180, 0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: HomeMarketplaceTheme.border),
          ),
        ),
      ),
      menuChildren: [
        if (selectedId != null)
          MenuItemButton(
            onPressed: () => onFiltersChanged(chip.clearFrom(activeFilters)),
            child: Text(
              'Clear filter',
              style: AppTypography.detail().copyWith(
                color: HomeMarketplaceTheme.textSecondary,
              ),
            ),
          ),
        for (final option in options)
          MenuItemButton(
            onPressed: () => onFiltersChanged(
              chip.applyTo(activeFilters, option.id, option.label),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(option.label, style: AppTypography.detail()),
                ),
                if (selectedId == option.id)
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: HomeMarketplaceTheme.primary,
                  ),
              ],
            ),
          ),
      ],
      builder: (context, controller, child) {
        return _FilterChipButton(
          label: chip.label,
          valueLabel: chip.valueLabel(activeFilters, towerPropertyType),
          isActive: chip.isActive(activeFilters, towerPropertyType),
          isOpen: controller.isOpen,
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
      },
    );
  }
}

class _AppliedFilterPillsRow extends StatelessWidget {
  const _AppliedFilterPillsRow({
    required this.pills,
    required this.onRemove,
    required this.onClearAll,
  });

  final List<AppliedFilterPill> pills;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Applied:',
          style: AppTypography.detail().copyWith(
            fontWeight: FontWeight.w600,
            color: HomeMarketplaceTheme.textSecondary,
          ),
        ),
        for (final pill in pills)
          InputChip(
            label: Text(pill.label, style: AppTypography.detail()),
            deleteIcon: const Icon(Icons.close_rounded, size: 16),
            onDeleted: () => onRemove(pill.id),
            backgroundColor: HomeMarketplaceTheme.surface,
            side: BorderSide(color: HomeMarketplaceTheme.border),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        TextButton(
          onPressed: onClearAll,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Clear all',
            style: AppTypography.detail().copyWith(
              color: HomeMarketplaceTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.valueLabel,
    required this.isActive,
    required this.isOpen,
    required this.onTap,
  });

  final String label;
  final String? valueLabel;
  final bool isActive;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final display = valueLabel ?? label;

    return Material(
      color: isActive || isOpen
          ? HomeMarketplaceTheme.surface
          : HomeMarketplaceTheme.canvas,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isActive || isOpen
                  ? HomeMarketplaceTheme.primary.withValues(alpha: 0.45)
                  : HomeMarketplaceTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                display,
                style: AppTypography.detail().copyWith(
                  fontWeight: isActive || isOpen ? FontWeight.w600 : FontWeight.w500,
                  color: isActive || isOpen
                      ? HomeMarketplaceTheme.primary
                      : HomeMarketplaceTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: isActive || isOpen
                      ? HomeMarketplaceTheme.primary
                      : HomeMarketplaceTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreFiltersChipButton extends StatelessWidget {
  const _MoreFiltersChipButton({
    required this.onTap,
    this.activeCount = 0,
  });

  final VoidCallback onTap;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final isActive = activeCount > 0;

    return Material(
      color: isActive ? HomeMarketplaceTheme.surface : HomeMarketplaceTheme.canvas,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isActive
                  ? HomeMarketplaceTheme.primary
                  : HomeMarketplaceTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: isActive
                    ? HomeMarketplaceTheme.primary
                    : HomeMarketplaceTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'More Filters',
                style: AppTypography.detail().copyWith(
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? HomeMarketplaceTheme.primary
                      : HomeMarketplaceTheme.textPrimary,
                ),
              ),
              if (activeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: HomeMarketplaceTheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$activeCount',
                    style: AppTypography.detail().copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _FilterChipKind {
  city,
  layout,
  dwelling,
  budget,
  food,
  occupant,
  gender,
  propertyType,
  possession,
  smoking,
  pets,
  moveIn,
  householdLanguage,
}

class _FilterOption {
  const _FilterOption({required this.id, required this.label});

  final String id;
  final String label;
}

class _FilterChipConfig {
  const _FilterChipConfig(this.kind, this.label);

  final _FilterChipKind kind;
  final String label;

  factory _FilterChipConfig.city() =>
      const _FilterChipConfig(_FilterChipKind.city, 'Area');

  factory _FilterChipConfig.layout(String tower) => _FilterChipConfig(
        _FilterChipKind.layout,
        MarketConfig.current.layoutFilterLabelFor(tower),
      );

  factory _FilterChipConfig.dwelling() =>
      const _FilterChipConfig(_FilterChipKind.dwelling, 'Home type');

  factory _FilterChipConfig.bedroom() => _FilterChipConfig(
        _FilterChipKind.layout,
        MarketConfig.current.bedroomFilterLabel,
      );

  factory _FilterChipConfig.budget() =>
      const _FilterChipConfig(_FilterChipKind.budget, 'Budget');

  factory _FilterChipConfig.food() =>
      const _FilterChipConfig(_FilterChipKind.food, 'Food pref.');

  factory _FilterChipConfig.occupant() =>
      const _FilterChipConfig(_FilterChipKind.occupant, 'Occupant');

  factory _FilterChipConfig.householdType() =>
      const _FilterChipConfig(_FilterChipKind.occupant, 'Household pref.');

  factory _FilterChipConfig.householdLanguage() =>
      const _FilterChipConfig(_FilterChipKind.householdLanguage, 'Language pref.');

  factory _FilterChipConfig.pets() =>
      const _FilterChipConfig(_FilterChipKind.pets, 'Pets');

  factory _FilterChipConfig.moveIn() =>
      const _FilterChipConfig(_FilterChipKind.moveIn, 'Move-in');

  factory _FilterChipConfig.gender() =>
      const _FilterChipConfig(_FilterChipKind.gender, 'Gender');

  factory _FilterChipConfig.propertyType() =>
      const _FilterChipConfig(_FilterChipKind.propertyType, 'Property type');

  factory _FilterChipConfig.possession() =>
      const _FilterChipConfig(_FilterChipKind.possession, 'Possession');

  factory _FilterChipConfig.smoking() =>
      const _FilterChipConfig(_FilterChipKind.smoking, 'Smoking');

  bool isActive(ListingSearchFilters filters, String tower) =>
      valueLabel(filters, tower) != null;

  String? valueLabel(ListingSearchFilters filters, String tower) {
    return switch (kind) {
      _FilterChipKind.city => filters.effectiveAreaTokens.isNotEmpty
          ? ListingSearchFilters.areaChipLabel(filters.effectiveAreaTokens)
          : null,
      _FilterChipKind.layout => _activeLayoutLabel(filters.keywords, tower),
      _FilterChipKind.dwelling => _activeKeywordLabel(
          filters.keywords,
          MarketplaceFilterBar._homeTypeFilterOptions,
        ),
      _FilterChipKind.budget => _budgetChipLabel(filters),
      _FilterChipKind.food => filters.foodPreference != null
          ? (filters.foodPreference == 'veg' ? 'Veg' : 'Non-veg')
          : null,
      _FilterChipKind.occupant =>
        MarketplaceFilterBar.householdTypeDisplayLabel(filters.occupantType),
      _FilterChipKind.gender => filters.genderPreference != null
          ? (filters.genderPreference == 'girls' ? 'Girls only' : 'Boys only')
          : null,
      _FilterChipKind.propertyType =>
        _activeKeywordLabel(filters.keywords, MarketplaceFilterBar._propertyTypeKeywords),
      _FilterChipKind.possession =>
        _activeKeywordLabel(filters.keywords, MarketplaceFilterBar._possessionKeywords),
      _FilterChipKind.smoking =>
        _activeKeywordLabel(filters.keywords, MarketplaceFilterBar._smokingKeywords),
      _FilterChipKind.pets =>
        _activeKeywordLabel(filters.keywords, MarketplaceFilterBar._petKeywords),
      _FilterChipKind.moveIn => filters.moveInWindow != null &&
              filters.moveInWindow!.isNotEmpty
          ? RentalDateFormat.formatMoveInWindowDisplay(filters.moveInWindow!)
          : null,
      _FilterChipKind.householdLanguage =>
        filters.householdLanguages.isEmpty
            ? null
            : filters.householdLanguages.join(', '),
    };
  }

  String? selectedId(ListingSearchFilters filters, String tower) {
    return switch (kind) {
      _FilterChipKind.city => filters.effectiveAreaTokens.isNotEmpty
          ? filters.effectiveAreaTokens.first
          : null,
      _FilterChipKind.layout => _activeLayoutKeyword(filters.keywords, tower),
      _FilterChipKind.dwelling => _activeKeywordId(
          filters.keywords,
          MarketplaceFilterBar._homeTypeFilterOptions,
        ),
      _FilterChipKind.budget => _budgetSelectionId(filters),
      _FilterChipKind.food => filters.foodPreference,
      _FilterChipKind.occupant => filters.occupantType,
      _FilterChipKind.gender => filters.genderPreference,
      _FilterChipKind.propertyType =>
        _activeKeywordId(filters.keywords, MarketplaceFilterBar._propertyTypeKeywords),
      _FilterChipKind.possession =>
        _activeKeywordId(filters.keywords, MarketplaceFilterBar._possessionKeywords),
      _FilterChipKind.smoking =>
        _activeKeywordId(filters.keywords, MarketplaceFilterBar._smokingKeywords),
      _FilterChipKind.pets =>
        _activeKeywordId(filters.keywords, MarketplaceFilterBar._petKeywords),
      _FilterChipKind.moveIn => filters.moveInWindow,
      _FilterChipKind.householdLanguage => filters.householdLanguages.isEmpty
          ? null
          : filters.householdLanguages.first,
    };
  }

  List<_FilterOption> optionsFor(String tower) {
    return switch (kind) {
      _FilterChipKind.city => [
          for (final entry in TargetSearchAreas.primaryFilterOptions)
            _FilterOption(
              id: entry.$1,
              label: entry.$1 == TargetSearchAreas.allDublinToken
                  ? '✨ ${entry.$2}'
                  : entry.$2,
            ),
        ],
      _FilterChipKind.layout => _layoutOptionsForTower(tower),
      _FilterChipKind.budget => [
          for (final entry in _budgetOptionsForTower(tower))
            _FilterOption(
              id: '${entry.$1 ?? ''}-${entry.$2 ?? ''}',
              label: entry.$3,
            ),
        ],
      _FilterChipKind.dwelling => [
          for (final entry in MarketplaceFilterBar._homeTypeFilterOptions)
            _FilterOption(id: entry.$1, label: entry.$2),
        ],
      _FilterChipKind.food => [
          for (final entry in MarketplaceFilterBar._foodOptions)
            _FilterOption(id: entry.$1, label: entry.$2),
        ],
      _FilterChipKind.occupant => [
          for (final entry in MarketplaceFilterBar._householdTypeOptions)
            _FilterOption(id: entry.$1, label: entry.$2),
        ],
      _FilterChipKind.gender => [
          for (final entry in MarketplaceFilterBar._genderOptions)
            _FilterOption(id: entry.$1, label: entry.$2),
        ],
      _FilterChipKind.propertyType => [
          for (final entry in MarketplaceFilterBar._propertyTypeKeywords)
            _FilterOption(id: entry.$1, label: entry.$2),
        ],
      _FilterChipKind.possession => [
          for (final entry in MarketplaceFilterBar._possessionKeywords)
            _FilterOption(id: entry.$1, label: entry.$2),
        ],
      _FilterChipKind.smoking => [
          for (final entry in MarketplaceFilterBar._smokingKeywords)
            _FilterOption(id: entry.$1, label: entry.$2),
        ],
      _FilterChipKind.pets => [
          for (final entry in MarketplaceFilterBar._petKeywords)
            _FilterOption(id: entry.$1, label: entry.$2),
        ],
      _FilterChipKind.moveIn => [
          for (final bucket in MoveInBucket.values)
            _FilterOption(id: bucket.storageToken, label: bucket.label),
        ],
      _FilterChipKind.householdLanguage => [
          for (final language in MarketConfig.current.profileLanguageOptions)
            _FilterOption(id: language, label: language),
        ],
    };
  }

  ListingSearchFilters applyTo(
    ListingSearchFilters filters,
    String id,
    String label,
  ) {
    return switch (kind) {
      _FilterChipKind.city => id == TargetSearchAreas.allDublinToken
          ? filters.withAllDublinArea().copyWith(
              targetSearchAreaRefinements: const [],
            )
          : filters.copyWith(
              city: null,
              targetSearchAreas: TargetSearchAreas.isMacroToken(id)
                  ? TargetSearchAreas.toggleMacroSelection(
                      filters.effectiveAreaTokens,
                      id,
                    )
                  : [id],
            ),
      _FilterChipKind.layout => filters.copyWith(
          keywords: [..._keywordsWithoutLayout(filters.keywords), id],
        ),
      _FilterChipKind.dwelling => filters.copyWith(
          keywords: [
            ..._keywordsWithoutSet(
              filters.keywords,
              MarketplaceFilterBar._homeTypeFilterOptions.map((e) => e.$1),
            ),
            id,
          ],
        ),
      _FilterChipKind.budget => _applyBudget(filters, id),
      _FilterChipKind.food => filters.copyWith(foodPreference: id),
      _FilterChipKind.occupant => filters.copyWith(occupantType: id),
      _FilterChipKind.gender => id == 'mixed'
          ? filters.copyWith(genderPreference: null)
          : filters.copyWith(genderPreference: id),
      _FilterChipKind.propertyType => filters.copyWith(
          keywords: [
            ..._keywordsWithoutSet(
              filters.keywords,
              MarketplaceFilterBar._propertyTypeKeywords.map((e) => e.$1),
            ),
            id,
          ],
        ),
      _FilterChipKind.possession => filters.copyWith(
          keywords: [
            ..._keywordsWithoutSet(
              filters.keywords,
              MarketplaceFilterBar._possessionKeywords.map((e) => e.$1),
            ),
            id,
          ],
        ),
      _FilterChipKind.smoking => filters.copyWith(
          keywords: [
            ..._keywordsWithoutSet(
              filters.keywords,
              MarketplaceFilterBar._smokingKeywords.map((e) => e.$1),
            ),
            id,
          ],
        ),
      _FilterChipKind.pets => filters.copyWith(
          keywords: [
            ..._keywordsWithoutSet(
              filters.keywords,
              MarketplaceFilterBar._petKeywords.map((e) => e.$1),
            ),
            id,
          ],
        ),
      _FilterChipKind.moveIn => filters.copyWith(moveInWindow: id),
      _FilterChipKind.householdLanguage => filters.copyWith(
          householdLanguages: filters.householdLanguages.contains(id)
              ? filters.householdLanguages
                    .where((lang) => lang != id)
                    .toList()
              : [...filters.householdLanguages, id],
        ),
    };
  }

  ListingSearchFilters clearFrom(ListingSearchFilters filters) {
    return switch (kind) {
      _FilterChipKind.city => filters.copyWith(
          city: null,
          targetSearchAreas: const [],
          targetSearchAreaRefinements: const [],
        ),
      _FilterChipKind.layout =>
        filters.copyWith(keywords: _keywordsWithoutLayout(filters.keywords)),
      _FilterChipKind.dwelling => filters.copyWith(
          keywords: _keywordsWithoutSet(
            filters.keywords,
            MarketplaceFilterBar._homeTypeFilterOptions.map((e) => e.$1),
          ),
        ),
      _FilterChipKind.budget => filters.copyWith(budgetMin: null, budgetMax: null),
      _FilterChipKind.food => filters.copyWith(foodPreference: null),
      _FilterChipKind.occupant => filters.copyWith(occupantType: null),
      _FilterChipKind.gender => filters.copyWith(genderPreference: null),
      _FilterChipKind.propertyType => filters.copyWith(
          keywords: _keywordsWithoutSet(
            filters.keywords,
            MarketplaceFilterBar._propertyTypeKeywords.map((e) => e.$1),
          ),
        ),
      _FilterChipKind.possession => filters.copyWith(
          keywords: _keywordsWithoutSet(
            filters.keywords,
            MarketplaceFilterBar._possessionKeywords.map((e) => e.$1),
          ),
        ),
      _FilterChipKind.smoking => filters.copyWith(
          keywords: _keywordsWithoutSet(
            filters.keywords,
            MarketplaceFilterBar._smokingKeywords.map((e) => e.$1),
          ),
        ),
      _FilterChipKind.pets => filters.copyWith(
          keywords: _keywordsWithoutSet(
            filters.keywords,
            MarketplaceFilterBar._petKeywords.map((e) => e.$1),
          ),
        ),
      _FilterChipKind.moveIn => filters.copyWith(moveInWindow: null),
      _FilterChipKind.householdLanguage =>
        filters.copyWith(householdLanguages: const []),
    };
  }

  static List<(int?, int?, String)> _budgetOptionsForTower(String tower) {
    return switch (tower) {
      'Buy' => MarketplaceFilterBar._buyBudgetOptions,
      'Share' => MarketplaceFilterBar._shareBudgetOptions,
      _ => MarketplaceFilterBar._rentBudgetOptions,
    };
  }

  static ListingSearchFilters _applyBudget(
    ListingSearchFilters filters,
    String id,
  ) {
    final parts = id.split('-');
    if (parts.length != 2) return filters;
    final min = parts[0].isEmpty ? null : int.tryParse(parts[0]);
    final max = parts[1].isEmpty ? null : int.tryParse(parts[1]);
    return filters.copyWith(budgetMin: min, budgetMax: max);
  }

  static String? _budgetSelectionId(ListingSearchFilters filters) {
    if (filters.budgetMin == null && filters.budgetMax == null) return null;
    return '${filters.budgetMin ?? ''}-${filters.budgetMax ?? ''}';
  }

  static String? _budgetChipLabel(ListingSearchFilters filters) {
    if (filters.budgetMin == null && filters.budgetMax == null) return null;
    for (final pill in filters.appliedPills()) {
      if (pill.id == 'budget') return pill.label;
    }
    return 'Budget';
  }

  static List<_FilterOption> _layoutOptionsForTower(String tower) {
    if (tower == 'Share') {
      return [
        for (final entry in MarketplaceFilterBar._shareRoomFilterOptions)
          _FilterOption(id: entry.$1, label: entry.$2),
      ];
    }
    final layout = MarketConfig.current.layoutFilterOptionsFor(tower);
    final entries = layout.isNotEmpty
        ? layout
        : MarketConfig.current.bedroomFilterOptions;
    return [
      for (final entry in entries)
        _FilterOption(id: entry.$1, label: entry.$2),
    ];
  }

  static Set<String> _layoutKeywordIds(String tower) {
    if (tower == 'Share') {
      return MarketplaceFilterBar._shareRoomFilterOptions.map((e) => e.$1).toSet();
    }
    final ids = MarketConfig.current.layoutFilterOptionsFor(tower)
        .map((e) => e.$1)
        .toSet();
    if (ids.isEmpty) {
      for (final entry in MarketConfig.current.bedroomFilterOptions) {
        ids.add(entry.$1);
      }
    }
    return ids;
  }

  static String? _activeLayoutKeyword(List<String> keywords, String tower) {
    final layoutIds = _layoutKeywordIds(tower);
    for (final k in keywords) {
      if (layoutIds.contains(k)) return k;
      if (RegExp(r'^\d+bhk$').hasMatch(k)) return k;
      if (RegExp(r'^\d+bed\d+bath$').hasMatch(k)) return k;
    }
    return null;
  }

  static String? _activeLayoutLabel(List<String> keywords, String tower) {
    final token = _activeLayoutKeyword(keywords, tower);
    if (token == null) return null;
    for (final entry in MarketConfig.current.layoutFilterOptionsFor(tower)) {
      if (entry.$1 == token) return entry.$2;
    }
    for (final entry in MarketConfig.current.bedroomFilterOptions) {
      if (entry.$1 == token) return entry.$2;
    }
    final bhk = RegExp(r'^(\d+)bhk$').firstMatch(token);
    if (bhk != null) return '${bhk.group(1)} BHK';
    return token;
  }

  static List<String> _keywordsWithoutLayout(List<String> keywords) {
    return keywords
        .where(
          (k) =>
              !RegExp(r'^\d+bhk$').hasMatch(k) &&
              !RegExp(r'^\d+bed\d+bath$').hasMatch(k) &&
              !const {
                'ensuite',
                'private_bath',
                'bed_shared',
                'student_room',
                'double_ensuite',
              }.contains(k),
        )
        .toList();
  }

  static String? _activeKeywordId(
    List<String> keywords,
    List<(String, String)> options,
  ) {
    final ids = options.map((e) => e.$1).toSet();
    for (final k in keywords) {
      if (ids.contains(k)) return k;
    }
    return null;
  }

  static String? _activeKeywordLabel(
    List<String> keywords,
    List<(String, String)> options,
  ) {
    final id = _activeKeywordId(keywords, options);
    if (id == null) return null;
    for (final entry in options) {
      if (entry.$1 == id) return entry.$2;
    }
    return id;
  }

  static List<String> _keywordsWithoutSet(
    List<String> keywords,
    Iterable<String> remove,
  ) {
    final block = remove.toSet();
    return keywords.where((k) => !block.contains(k)).toList();
  }
}

class _MarketplaceFiltersSidebar extends StatefulWidget {
  const _MarketplaceFiltersSidebar({
    required this.towerPropertyType,
    required this.activeFilters,
    required this.onFiltersChanged,
    required this.onClearAll,
    required this.resultCount,
    this.resultCountProvider,
    required this.allListings,
    this.userSession,
    this.searchQuery = '',
  });

  final String towerPropertyType;
  final ListingSearchFilters activeFilters;
  final ValueChanged<ListingSearchFilters> onFiltersChanged;
  final VoidCallback onClearAll;
  final int resultCount;
  final int Function()? resultCountProvider;
  final List<Map<String, dynamic>> allListings;
  final Map<String, dynamic>? userSession;
  final String searchQuery;

  @override
  State<_MarketplaceFiltersSidebar> createState() =>
      _MarketplaceFiltersSidebarState();
}

class _MarketplaceFiltersSidebarState extends State<_MarketplaceFiltersSidebar> {
  late ListingSearchFilters _filters;
  late TextEditingController _budgetMaxController;
  late int _viewCount;

  @override
  void initState() {
    super.initState();
    _filters = widget.activeFilters;
    _viewCount = widget.resultCount;
    _budgetMaxController = TextEditingController(
      text: _filters.budgetMax?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _budgetMaxController.dispose();
    super.dispose();
  }

  void _updateFilters(ListingSearchFilters next) {
    setState(() => _filters = next);
    widget.onFiltersChanged(next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _viewCount = widget.resultCountProvider?.call() ?? widget.resultCount;
      });
    });
  }

  void _handleClearAll() {
    widget.onClearAll();
    setState(() {
      _filters = const ListingSearchFilters();
    });
    _budgetMaxController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _viewCount = widget.resultCountProvider?.call() ?? 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStickyHeader(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _sidebarSections().length; i++) ...[
                  if (i > 0) const SizedBox(height: 24),
                  _sidebarSections()[i],
                ],
              ],
            ),
          ),
        ),
        _buildStickyFooter(context),
      ],
    );
  }

  Widget _buildStickyHeader(BuildContext context) {
    final hasFilters = !_filters.isEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: HomeMarketplaceTheme.border),
        ),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: hasFilters ? _handleClearAll : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: HomeMarketplaceTheme.primary,
            ),
            child: Text(
              'Clear all',
              style: AppTypography.detail().copyWith(
                fontWeight: FontWeight.w600,
                color: hasFilters
                    ? HomeMarketplaceTheme.primary
                    : HomeMarketplaceTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Filters',
              textAlign: TextAlign.center,
              style: AppTypography.sectionTitle().copyWith(
                fontFamily: core.AppTypography.fontFamily,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 22),
            color: HomeMarketplaceTheme.textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildStickyFooter(BuildContext context) {
    final matchLabel = _viewCount == 1 ? 'match' : 'matches';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: HomeMarketplaceTheme.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: HomeMarketplaceTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'View $_viewCount $matchLabel',
                style: AppTypography.detail().copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sidebarSections() {
    return switch (widget.towerPropertyType) {
      'Buy' => [
          _buildRefineAreaSection(),
          _buildBudgetSection(),
          _buildHomeTypeSection(
            label: '🏠 Property type',
            options: MarketplaceFilterBar._propertyTypeKeywords,
            chip: _FilterChipConfig.propertyType(),
          ),
          _buildLayoutPillSection(
            label: '🛏️ ${MarketConfig.current.bedroomFilterLabel}',
          ),
          _buildPossessionSection(),
        ],
      'Share' => [
          _buildRefineAreaSection(),
          _buildBudgetSection(),
          _buildShareRoomTypeSection(),
          _buildHouseholdTypeSection(),
          _buildHouseholdLanguageSection(),
          _buildFoodPreferenceSection(),
          _buildGenderPreferenceSection(),
          _buildSmokingSection(),
          _buildPetsSection(),
          _buildMoveInSection(),
        ],
      _ => [
          _buildRefineAreaSection(),
          _buildBudgetSection(),
          _buildBedBathDropdownSection(),
          _buildHomeTypeSection(
            label: '🏠 Property type',
            options: MarketplaceFilterBar._homeTypeFilterOptions,
            chip: _FilterChipConfig.dwelling(),
          ),
          _buildMoveInSection(),
        ],
    };
  }

  Widget _buildSidebarFieldBlock({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: listingFieldLabelStyle),
        const SizedBox(height: listingLabelSpacing),
        child,
      ],
    );
  }

  Widget _buildRefineAreaSection() {
    if (!MarketConfig.current.profileUseAreaPicker) {
      return _buildLegacyAreaDropdownSection();
    }

    final refinements = _filters.effectiveAreaRefinements;
    final summary = refinements.isEmpty
        ? null
        : TargetSearchAreas.refinementSummary(refinements);

    return _buildSidebarFieldBlock(
      label: '📍 Refine Area',
      child: _SidebarTapField(
        value: summary,
        hint: 'Optional postcode refinement',
        onTap: () async {
          final result = await showAreaRefinementFilterSheet(
            context,
            initialSelection: refinements,
          );
          if (result == null || !mounted) return;
          _updateFilters(
            _filters.copyWith(targetSearchAreaRefinements: result),
          );
        },
      ),
    );
  }

  Widget _buildLegacyAreaDropdownSection() {
    final chip = _FilterChipConfig.city();
    final selectedId = chip.selectedId(_filters, widget.towerPropertyType);
    final options = chip.optionsFor(widget.towerPropertyType);

    return _buildSidebarFieldBlock(
      label: '📍 Area',
      child: _SidebarDropdownField(
        value: selectedId,
        hint: TargetSearchAreas.allDublinLabel,
        options: options.map((o) => (o.id, o.label)).toList(),
        onChanged: (id) {
          if (id == null) {
            _updateFilters(chip.clearFrom(_filters));
          } else {
            final label = options.firstWhere((o) => o.id == id).label;
            _updateFilters(chip.applyTo(_filters, id, label));
          }
        },
      ),
    );
  }

  Widget _buildBedBathDropdownSection() {
    final chip = _FilterChipConfig.layout(widget.towerPropertyType);
    final token = chip.selectedId(_filters, widget.towerPropertyType);
    final (minBeds, minBaths) = _parseBedBathToken(token);

    const bedOptions = ['1', '2', '3', '4'];
    const bathOptions = ['1', '2'];

    return _buildSidebarFieldBlock(
      label: '🛏️ Bed & bath',
      child: Row(
        children: [
          Expanded(
            child: _SidebarDropdownField(
              value: minBeds?.toString(),
              hint: 'Min beds',
              options: [
                for (final n in bedOptions) (n, n),
              ],
              onChanged: (beds) => _applyBedBathFilter(
                minBeds: beds != null ? int.tryParse(beds) : null,
                minBaths: minBaths,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SidebarDropdownField(
              value: minBaths?.toString(),
              hint: 'Min baths',
              options: [
                for (final n in bathOptions) (n, n),
              ],
              onChanged: (baths) => _applyBedBathFilter(
                minBeds: minBeds,
                minBaths: baths != null ? int.tryParse(baths) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyBedBathFilter({int? minBeds, int? minBaths}) {
    final chip = _FilterChipConfig.layout(widget.towerPropertyType);
    final cleared = chip.clearFrom(_filters);

    if (minBeds == null && minBaths == null) {
      _updateFilters(cleared);
      return;
    }

    String? token;
    if (minBeds != null && minBaths != null) {
      token = '${minBeds}bed${minBaths}bath';
    } else if (minBeds != null) {
      token = '${minBeds}bed';
    }

    if (token == null) {
      _updateFilters(cleared);
      return;
    }

    final options = chip.optionsFor(widget.towerPropertyType);
    final match = options.where((o) => o.id == token).toList();
    if (match.isNotEmpty) {
      _updateFilters(chip.applyTo(cleared, token, match.first.label));
    } else {
      _updateFilters(cleared.copyWith(
        keywords: [...cleared.keywords, token],
      ));
    }
  }

  (int? beds, int? baths) _parseBedBathToken(String? token) {
    if (token == null) return (null, null);
    final combined = RegExp(r'^(\d+)bed(\d+)bath$').firstMatch(token);
    if (combined != null) {
      return (int.parse(combined.group(1)!), int.parse(combined.group(2)!));
    }
    final bedsOnly = RegExp(r'^(\d+)bed$').firstMatch(token);
    if (bedsOnly != null) {
      return (int.parse(bedsOnly.group(1)!), null);
    }
    final bhk = RegExp(r'^(\d+)bhk$').firstMatch(token);
    if (bhk != null) {
      return (int.parse(bhk.group(1)!), null);
    }
    return (null, null);
  }

  Widget _buildLayoutPillSection({required String label}) {
    final chip = _FilterChipConfig.layout(widget.towerPropertyType);
    final selectedId = chip.selectedId(_filters, widget.towerPropertyType);
    final options = chip.optionsFor(widget.towerPropertyType);

    return _buildSidebarFieldBlock(
      label: label,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            OnboardingChoiceChip(
              label: option.label,
              selected: selectedId == option.id,
              expand: false,
              onTap: () {
                if (selectedId == option.id) {
                  _updateFilters(chip.clearFrom(_filters));
                } else {
                  _updateFilters(
                    chip.applyTo(_filters, option.id, option.label),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHomeTypeSection({
    required String label,
    required List<(String, String)> options,
    required _FilterChipConfig chip,
  }) {
    final selectedId = chip.selectedId(_filters, widget.towerPropertyType);

    return _buildSidebarFieldBlock(
      label: label,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in options)
            OnboardingChoiceChip(
              label: entry.$2,
              selected: selectedId == entry.$1,
              expand: false,
              onTap: () {
                if (selectedId == entry.$1) {
                  _updateFilters(chip.clearFrom(_filters));
                } else {
                  _updateFilters(
                    chip.applyTo(_filters, entry.$1, entry.$2),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPossessionSection() {
    final chip = _FilterChipConfig.possession();
    final selectedId = chip.selectedId(_filters, widget.towerPropertyType);
    final options = chip.optionsFor(widget.towerPropertyType);

    return _buildSidebarFieldBlock(
      label: '📋 Possession',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            OnboardingChoiceChip(
              label: option.label,
              selected: selectedId == option.id,
              expand: false,
              onTap: () {
                if (selectedId == option.id) {
                  _updateFilters(chip.clearFrom(_filters));
                } else {
                  _updateFilters(
                    chip.applyTo(_filters, option.id, option.label),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBudgetSection() {
    final symbol = MarketConfig.current.currencySymbol;

    return _buildSidebarFieldBlock(
      label: 'Max budget ($symbol)',
      child: TextField(
        controller: _budgetMaxController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: listingFieldValueStyle,
        decoration: _budgetInputDecoration(
          hint: 'e.g. 2500',
          prefix: symbol,
        ),
        onChanged: (value) {
          final max = value.isEmpty ? null : int.tryParse(value);
          _updateFilters(
            _filters.copyWith(budgetMin: null, budgetMax: max),
          );
        },
      ),
    );
  }

  InputDecoration _budgetInputDecoration({
    required String hint,
    required String prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: listingFieldLabelStyle.copyWith(
        color: const Color(0xFF9CA3AF),
      ),
      prefixText: prefix,
      prefixStyle: listingFieldValueStyle.copyWith(
        color: HomeMarketplaceTheme.textSecondary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: listingChoiceBorderUnselected),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: listingChoiceBorderUnselected),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: listingChoiceBorderSelected,
          width: 1.5,
        ),
      ),
    );
  }

  List<String> _keywordsWithoutTokens(Set<String> remove) {
    final block = remove;
    return _filters.keywords.where((k) => !block.contains(k)).toList();
  }

  bool get _smokingAllowedActive => _filters.keywords.contains('smoking');

  bool get _petsAllowedActive => _filters.keywords.contains('pets');

  void _setLifestyleKeyword({
    required Set<String> tokens,
    required bool active,
    required String positiveToken,
    required String negativeToken,
  }) {
    final cleared = _keywordsWithoutTokens(tokens);
    _updateFilters(
      _filters.copyWith(
        keywords: [...cleared, active ? positiveToken : negativeToken],
      ),
    );
  }

  void _toggleSmokingAllowed() {
    _setLifestyleKeyword(
      tokens: const {'smoking', 'no-smoking'},
      active: !_smokingAllowedActive,
      positiveToken: 'smoking',
      negativeToken: 'no-smoking',
    );
  }

  void _togglePetsAllowed() {
    _setLifestyleKeyword(
      tokens: const {'pets', 'no-pets'},
      active: !_petsAllowedActive,
      positiveToken: 'pets',
      negativeToken: 'no-pets',
    );
  }

  Widget _buildShareRoomTypeSection() {
    final chip = _FilterChipConfig.layout(widget.towerPropertyType);
    final selectedId = chip.selectedId(_filters, widget.towerPropertyType);

    return _buildSidebarFieldBlock(
      label: 'Room type',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in MarketplaceFilterBar._shareRoomFilterOptions) ...[
            if (entry != MarketplaceFilterBar._shareRoomFilterOptions.first)
              const SizedBox(height: 8),
            OnboardingChoiceChip(
              label: entry.$2,
              selected: selectedId == entry.$1,
              onTap: () {
                if (selectedId == entry.$1) {
                  _updateFilters(chip.clearFrom(_filters));
                } else {
                  _updateFilters(
                    chip.applyTo(_filters, entry.$1, entry.$2),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHouseholdTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Household preference', style: MarketplaceFilterBar._sectionSubheaderStyle),
        const SizedBox(height: 10),
        ..._buildHouseholdTypeChoices(),
      ],
    );
  }

  List<Widget> _buildHouseholdTypeChoices() {
    final chip = _FilterChipConfig.householdType();
    final selected = _filters.occupantType;

    return [
      for (final entry in MarketplaceFilterBar._householdTypeOptions) ...[
        if (entry != MarketplaceFilterBar._householdTypeOptions.first)
          const SizedBox(height: 8),
        OnboardingChoiceChip(
          label: entry.$2,
          selected: selected == entry.$1,
          onTap: () {
            if (selected == entry.$1) {
              _updateFilters(chip.clearFrom(_filters));
            } else {
              _updateFilters(
                chip.applyTo(_filters, entry.$1, entry.$2),
              );
            }
          },
        ),
      ],
    ];
  }

  Widget _buildHouseholdLanguageSection() {
    final selected = _filters.householdLanguages.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Household language preference',
          style: MarketplaceFilterBar._sectionSubheaderStyle,
        ),
        const SizedBox(height: 4),
        Text(
          'Boosts listings where the household speaks at least one selected language.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final language in MarketConfig.current.profileLanguageOptions)
              FilterChip(
                label: Text(language),
                selected: selected.contains(language),
                onSelected: (_) {
                  final chip = _FilterChipConfig.householdLanguage();
                  _updateFilters(chip.applyTo(_filters, language, language));
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFoodPreferenceSection() {
    return _buildSidebarFieldBlock(
      label: '🥗 Food preference',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in MarketplaceFilterBar._foodOptions) ...[
            if (entry != MarketplaceFilterBar._foodOptions.first)
              const SizedBox(width: 8),
            Expanded(
              child: OnboardingChoiceChip(
                label: entry.$2 == 'Veg' ? '🥦 Veg' : '🍗 Non-veg',
                selected: _filters.foodPreference == entry.$1,
                onTap: () {
                  final chip = _FilterChipConfig.food();
                  if (_filters.foodPreference == entry.$1) {
                    _updateFilters(chip.clearFrom(_filters));
                  } else {
                    _updateFilters(
                      chip.applyTo(_filters, entry.$1, entry.$2),
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenderPreferenceSection() {
    return _buildSidebarFieldBlock(
      label: 'Gender preference',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in MarketplaceFilterBar._genderOptions) ...[
            if (entry != MarketplaceFilterBar._genderOptions.first)
              const SizedBox(width: 8),
            Expanded(
              child: _LifestyleFilterChip(
                label: MarketplaceFilterBar._genderChoiceLabels[entry.$1]!,
                selected: entry.$1 == 'mixed'
                    ? _filters.genderPreference == null
                    : _filters.genderPreference == entry.$1,
                compactLabel: true,
                centerLabel: true,
                fixedHeight: 72,
                onTap: () {
                  final chip = _FilterChipConfig.gender();
                  if (entry.$1 == 'mixed') {
                    _updateFilters(chip.clearFrom(_filters));
                  } else if (_filters.genderPreference == entry.$1) {
                    _updateFilters(chip.clearFrom(_filters));
                  } else {
                    _updateFilters(
                      chip.applyTo(_filters, entry.$1, entry.$2),
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmokingSection() {
    return _buildSidebarFieldBlock(
      label: 'Smoking',
      child: _LifestyleFilterChip(
        label: _smokingAllowedActive
            ? '💨 Smoking Allowed'
            : '🚭 No Smoking',
        selected: _smokingAllowedActive,
        onTap: _toggleSmokingAllowed,
      ),
    );
  }

  Widget _buildPetsSection() {
    return _buildSidebarFieldBlock(
      label: 'Pets',
      child: _LifestyleFilterChip(
        label: _petsAllowedActive
            ? '🐶🐾 Pets Allowed'
            : '🙅‍♂️🐾 No Pets',
        selected: _petsAllowedActive,
        onTap: _togglePetsAllowed,
      ),
    );
  }

  Widget _buildMoveInSection() {
    final moveIn = _filters.moveInWindow;
    return _buildSidebarFieldBlock(
      label: '📅 Move-in timing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final bucket in MoveInBucket.values) ...[
            if (bucket != MoveInBucket.values.first) const SizedBox(height: 8),
            OnboardingChoiceChip(
              label: bucket.label,
              selected: moveIn == bucket.storageToken,
              onTap: () {
                if (moveIn == bucket.storageToken) {
                  _updateFilters(_filters.copyWith(moveInWindow: null));
                } else {
                  _updateFilters(
                    _filters.copyWith(moveInWindow: bucket.storageToken),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _LifestyleFilterChip extends StatelessWidget {
  const _LifestyleFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.centerLabel = false,
    this.compactLabel = false,
    this.fixedHeight,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool centerLabel;
  final bool compactLabel;

  /// Bounded height for equal-size chips inside scroll views (e.g. gender row).
  final double? fixedHeight;

  static const _restCanvas = Color(0xFFF5F5F5);
  static const _radius = 12.0;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.symmetric(
      horizontal: compactLabel ? 8 : 12,
      vertical: compactLabel ? 12 : 14,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: fixedHeight,
          padding: padding,
          decoration: BoxDecoration(
            color: selected
                ? HomeMarketplaceTheme.primary.withValues(alpha: 0.08)
                : _restCanvas,
            borderRadius: BorderRadius.circular(_radius),
            border: selected
                ? Border.all(
                    color: HomeMarketplaceTheme.primary,
                    width: 1.5,
                  )
                : null,
          ),
          alignment: centerLabel ? Alignment.center : null,
          child: Text(
            label,
            textAlign: centerLabel ? TextAlign.center : TextAlign.center,
            style: listingFieldLabelStyle.copyWith(
              fontSize: compactLabel ? 12 : 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4B5563),
              fontFamily: core.AppTypography.fontFamily,
              fontFamilyFallback: core.AppTypography.emojiFontFallback,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarTapField extends StatelessWidget {
  const _SidebarTapField({
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final String? value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final display = value ?? hint;
    final hasValue = value != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: listingChoiceBorderUnselected),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: listingChoiceBorderUnselected),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: listingChoiceBorderSelected,
                width: 1.5,
              ),
            ),
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ),
          child: Text(
            display,
            style: hasValue
                ? listingFieldValueStyle
                : listingFieldLabelStyle.copyWith(
                    color: const Color(0xFF9CA3AF),
                  ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _SidebarDropdownField extends StatelessWidget {
  const _SidebarDropdownField({
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
  });

  static const _anySentinel = '__any__';

  final String? value;
  final String hint;
  final List<(String, String)> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final optionIds = options.map((e) => e.$1).toSet();
    final resolvedValue =
        value != null && optionIds.contains(value) ? value : _anySentinel;

    return DropdownButtonFormField<String>(
      key: ValueKey('$hint-$resolvedValue'),
      initialValue: resolvedValue,
      isExpanded: true,
      hint: Text(
        hint,
        style: listingFieldLabelStyle.copyWith(color: const Color(0xFF9CA3AF)),
        overflow: TextOverflow.ellipsis,
      ),
      style: listingFieldValueStyle,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: listingChoiceBorderUnselected),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: listingChoiceBorderUnselected),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: listingChoiceBorderSelected,
            width: 1.5,
          ),
        ),
      ),
      items: [
        DropdownMenuItem<String>(
          value: _anySentinel,
          child: Text(
            'Any',
            style: listingFieldLabelStyle.copyWith(
              color: HomeMarketplaceTheme.textSecondary,
            ),
          ),
        ),
        for (final entry in options)
          DropdownMenuItem<String>(
            value: entry.$1,
            child: Text(entry.$2, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (next) => onChanged(
        next == null || next == _anySentinel ? null : next,
      ),
    );
  }
}
