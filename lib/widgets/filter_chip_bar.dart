import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/listing_search_intent.dart';

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

  static const _cityOptions = [
    ('hyderabad', 'Hyderabad'),
    ('bangalore', 'Bangalore'),
    ('chennai', 'Chennai'),
    ('mumbai', 'Mumbai'),
    ('delhi', 'Delhi'),
  ];

  static const _bhkOptions = [
    ('1bhk', '1 BHK'),
    ('2bhk', '2 BHK'),
    ('3bhk', '3 BHK'),
    ('4bhk', '4 BHK'),
  ];

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

  static const _rentBudgetOptions = [
    (null, 10000, 'Under ₹10k'),
    (10000, 20000, '₹10k – ₹20k'),
    (20000, 40000, '₹20k – ₹40k'),
    (40000, null, 'Above ₹40k'),
  ];

  static const _buyBudgetOptions = [
    (null, 5000000, 'Under ₹50L'),
    (5000000, 10000000, '₹50L – ₹1Cr'),
    (10000000, 20000000, '₹1Cr – ₹2Cr'),
    (20000000, null, 'Above ₹2Cr'),
  ];

  static const _shareBudgetOptions = [
    (null, 8000, 'Under ₹8k'),
    (8000, 15000, '₹8k – ₹15k'),
    (15000, 25000, '₹15k – ₹25k'),
    (25000, null, 'Above ₹25k'),
  ];

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
        _FilterChipConfig.budget(),
        _FilterChipConfig.propertyType(),
        _FilterChipConfig.bhk(),
        _FilterChipConfig.possession(),
      ],
      'Share' => [
        _FilterChipConfig.city(),
        _FilterChipConfig.gender(),
        _FilterChipConfig.food(),
        _FilterChipConfig.smoking(),
        _FilterChipConfig.budget(),
      ],
      _ => [
        _FilterChipConfig.city(),
        _FilterChipConfig.bhk(),
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
    final selectedId = chip.selectedId(activeFilters);

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
          valueLabel: chip.valueLabel(activeFilters),
          isActive: chip.isActive(activeFilters),
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
            backgroundColor: HomeMarketplaceTheme.primarySurface,
            side: BorderSide(color: HomeMarketplaceTheme.primary.withValues(alpha: 0.25)),
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
          ? HomeMarketplaceTheme.primarySurface
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
  bhk,
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
      const _FilterChipConfig(_FilterChipKind.city, 'City');

  factory _FilterChipConfig.bhk() =>
      const _FilterChipConfig(_FilterChipKind.bhk, 'BHK');

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

  bool isActive(ListingSearchFilters filters) => valueLabel(filters) != null;

  String? valueLabel(ListingSearchFilters filters) {
    return switch (kind) {
      _FilterChipKind.city => filters.city != null
          ? ListingSearchIntent.cityDisplayName(filters.city!)
          : null,
      _FilterChipKind.bhk => _activeBhkLabel(filters.keywords),
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

  String? selectedId(ListingSearchFilters filters) {
    return switch (kind) {
      _FilterChipKind.city => filters.city,
      _FilterChipKind.bhk => _activeBhkKeyword(filters.keywords),
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
          for (final entry in MarketplaceFilterBar._cityOptions)
            _FilterOption(id: entry.$1, label: entry.$2),
        ],
      _FilterChipKind.bhk => [
          for (final entry in MarketplaceFilterBar._bhkOptions)
            _FilterOption(id: entry.$1, label: entry.$2),
        ],
      _FilterChipKind.budget => [
          for (final entry in _budgetOptionsForTower(tower))
            _FilterOption(
              id: '${entry.$1 ?? ''}-${entry.$2 ?? ''}',
              label: entry.$3,
            ),
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
      _FilterChipKind.city => filters.copyWith(city: id),
      _FilterChipKind.bhk => filters.copyWith(
          keywords: [..._keywordsWithoutBhk(filters.keywords), id],
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
      _FilterChipKind.city => filters.copyWith(city: null),
      _FilterChipKind.bhk => filters.copyWith(keywords: _keywordsWithoutBhk(filters.keywords)),
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

  static String? _activeBhkKeyword(List<String> keywords) {
    for (final k in keywords) {
      if (RegExp(r'^\d+bhk$').hasMatch(k)) return k;
    }
    return null;
  }

  static String? _activeBhkLabel(List<String> keywords) {
    final token = _activeBhkKeyword(keywords);
    if (token == null) return null;
    final match = RegExp(r'^(\d)bhk$').firstMatch(token);
    if (match == null) return token;
    return '${match.group(1)} BHK';
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

  static List<String> _keywordsWithoutBhk(List<String> keywords) =>
      keywords.where((k) => !RegExp(r'^\d+bhk$').hasMatch(k)).toList();

  static List<String> _keywordsWithoutSet(
    List<String> keywords,
    Iterable<String> remove,
  ) {
    final block = remove.toSet();
    return keywords.where((k) => !block.contains(k)).toList();
  }
}
