import 'package:flutter/material.dart';

import '../config/market/market_config.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/listing_search_intent.dart';
import '../utils/target_search_areas.dart';

/// Tower-specific filter chips + applied filter pills for the marketplace home.
class MarketplaceFilterBar extends StatelessWidget {
  const MarketplaceFilterBar({
    super.key,
    required this.towerPropertyType,
    required this.activeFilters,
    required this.onFiltersChanged,
    required this.onClearAll,
  });

  final String towerPropertyType;
  final ListingSearchFilters activeFilters;
  final ValueChanged<ListingSearchFilters> onFiltersChanged;
  final VoidCallback onClearAll;

  static List<(String, String)> get _cityOptions =>
      MarketConfig.current.areaOptions;

  static List<(String, String)> get _dwellingOptions =>
      MarketConfig.current.dwellingFilterOptions;

  static const _foodOptions = [
    ('veg', 'Veg'),
    ('non-veg', 'Non-veg'),
  ];

  static const _occupantOptions = [
    ('Family', 'Family'),
    ('Bachelors', 'Bachelors'),
    ('Working Professionals', 'Working Professionals'),
    ('Students', 'Students'),
  ];

  static const _genderOptions = [
    ('girls', 'Girls only'),
    ('boys', 'Boys only'),
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

  static const _smokingKeywords = [
    ('smoking', 'Smoking OK'),
    ('no-smoking', 'No smoking'),
  ];

  @override
  Widget build(BuildContext context) {
    final pills = activeFilters.appliedPills();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final chip in _chipsForTower())
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChipDropdown(
                    chip: chip,
                    towerPropertyType: towerPropertyType,
                    activeFilters: activeFilters,
                    onFiltersChanged: onFiltersChanged,
                  ),
                ),
            ],
          ),
        ),
        if (pills.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AppliedFilterPillsRow(
            pills: pills,
            onRemove: (id) => onFiltersChanged(activeFilters.withoutPill(id)),
            onClearAll: onClearAll,
          ),
        ],
      ],
    );
  }

  List<_FilterChipConfig> _chipsForTower() {
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
        _FilterChipConfig.layout(towerPropertyType),
        _FilterChipConfig.gender(),
        _FilterChipConfig.food(),
        _FilterChipConfig.smoking(),
        _FilterChipConfig.budget(),
      ],
      _ => [
        _FilterChipConfig.city(),
        _FilterChipConfig.layout(towerPropertyType),
        if (MarketConfig.current.dwellingFilterOptions.isNotEmpty)
          _FilterChipConfig.dwelling(),
        _FilterChipConfig.budget(),
        _FilterChipConfig.food(),
        _FilterChipConfig.occupant(),
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

  @override
  Widget build(BuildContext context) {
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
          : HomeMarketplaceTheme.searchSurface,
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
      const _FilterChipConfig(_FilterChipKind.food, 'Food');

  factory _FilterChipConfig.occupant() =>
      const _FilterChipConfig(_FilterChipKind.occupant, 'Occupant');

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
          MarketplaceFilterBar._dwellingOptions,
        ),
      _FilterChipKind.budget => _budgetChipLabel(filters),
      _FilterChipKind.food => filters.foodPreference != null
          ? (filters.foodPreference == 'veg' ? 'Veg' : 'Non-veg')
          : null,
      _FilterChipKind.occupant => filters.occupantType,
      _FilterChipKind.gender => filters.genderPreference != null
          ? (filters.genderPreference == 'girls' ? 'Girls only' : 'Boys only')
          : null,
      _FilterChipKind.propertyType =>
        _activeKeywordLabel(filters.keywords, MarketplaceFilterBar._propertyTypeKeywords),
      _FilterChipKind.possession =>
        _activeKeywordLabel(filters.keywords, MarketplaceFilterBar._possessionKeywords),
      _FilterChipKind.smoking =>
        _activeKeywordLabel(filters.keywords, MarketplaceFilterBar._smokingKeywords),
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
          MarketplaceFilterBar._dwellingOptions,
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
    };
  }

  List<_FilterOption> optionsFor(String tower) {
    return switch (kind) {
      _FilterChipKind.city => [
          _FilterOption(
            id: TargetSearchAreas.allDublinToken,
            label: '✨ All of Dublin',
          ),
          for (final entry in MarketplaceFilterBar._cityOptions)
            _FilterOption(id: entry.$1, label: entry.$2),
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
          for (final entry in MarketplaceFilterBar._dwellingOptions)
            _FilterOption(id: entry.$1, label: entry.$2),
        ],
      _FilterChipKind.food => [
          for (final entry in MarketplaceFilterBar._foodOptions)
            _FilterOption(id: entry.$1, label: entry.$2),
        ],
      _FilterChipKind.occupant => [
          for (final entry in MarketplaceFilterBar._occupantOptions)
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
    };
  }

  ListingSearchFilters applyTo(
    ListingSearchFilters filters,
    String id,
    String label,
  ) {
    return switch (kind) {
      _FilterChipKind.city => id == TargetSearchAreas.allDublinToken
          ? filters.withAllDublinArea()
          : filters.copyWith(
              city: null,
              targetSearchAreas: [id],
            ),
      _FilterChipKind.layout => filters.copyWith(
          keywords: [..._keywordsWithoutLayout(filters.keywords), id],
        ),
      _FilterChipKind.dwelling => filters.copyWith(
          keywords: [
            ..._keywordsWithoutSet(
              filters.keywords,
              MarketplaceFilterBar._dwellingOptions.map((e) => e.$1),
            ),
            id,
          ],
        ),
      _FilterChipKind.budget => _applyBudget(filters, id),
      _FilterChipKind.food => filters.copyWith(foodPreference: id),
      _FilterChipKind.occupant => filters.copyWith(occupantType: id),
      _FilterChipKind.gender => filters.copyWith(genderPreference: id),
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
    };
  }

  ListingSearchFilters clearFrom(ListingSearchFilters filters) {
    return switch (kind) {
      _FilterChipKind.city =>
        filters.copyWith(city: null, targetSearchAreas: const []),
      _FilterChipKind.layout =>
        filters.copyWith(keywords: _keywordsWithoutLayout(filters.keywords)),
      _FilterChipKind.dwelling => filters.copyWith(
          keywords: _keywordsWithoutSet(
            filters.keywords,
            MarketplaceFilterBar._dwellingOptions.map((e) => e.$1),
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
