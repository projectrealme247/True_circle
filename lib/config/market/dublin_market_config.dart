import 'dublin_districts.dart';
import 'market_config.dart';

final class DublinMarketConfig implements MarketConfig {
  DublinMarketConfig._();
  static final instance = DublinMarketConfig._();

  static const _rentLayoutOptions = [
    ('1bed1bath', '1 bed · 1 bath'),
    ('2bed1bath', '2 bed · 1 bath'),
    ('2bed2bath', '2 bed · 2 bath'),
    ('3bed1bath', '3 bed · 1 bath'),
    ('3bed2bath', '3 bed · 2 bath'),
    ('4bed2bath', '4 bed · 2 bath'),
  ];

  static const _shareRoomOptions = [
    ('ensuite', 'Ensuite room'),
    ('private_bath', 'Private room · own bathroom'),
    ('bed_shared', 'Bed in shared room'),
    ('student_room', 'Student room'),
    ('double_ensuite', 'Double ensuite'),
  ];

  @override
  MarketId get id => MarketId.dublin;

  @override
  String get appTitle => 'TrueCircle Dublin';

  @override
  String get tagline => 'Trusted home for Indians in Dublin';

  @override
  int get seedVersion => 5;

  @override
  List<String> get enabledTowers => const ['Rent', 'Share'];

  @override
  TrustVerificationKind get trustVerificationKind =>
      TrustVerificationKind.lightTrust;

  @override
  String get currencySymbol => '€';

  @override
  String get defaultAreaKey => 'dublin18';

  @override
  String get defaultAreaDisplayName =>
      dublinDistrictLabelForKey(defaultAreaKey) ??
      'Dublin 18 (Sandyford, Leopardstown)';

  @override
  List<(String, String)> get areaOptions => dublinAreaOptions;

  @override
  Map<String, List<String>> get cityAliases => dublinCityAliases;

  @override
  Map<String, List<String>> get parseCityAliases => dublinParseCityAliases;

  @override
  Map<String, String> get cityDisplayNames => dublinCityDisplayNames;

  @override
  List<String> get localityKeywords => const [
        'luas',
        'green line',
        'sandymount',
        'glass bottle',
        'lime house',
        'two oaks',
        'green acre',
        'tandys lane',
        'rockfield',
        'grand canal dock',
        'windy arbour',
        'cherrywood',
      ];

  @override
  Map<String, String> get localityDisplayNames => const {
        'luas': 'Luas',
        'green line': 'Luas Green Line',
        'sandymount': 'Sandymount',
        'glass bottle': 'Glass Bottle',
        'lime house': 'Lime House',
        'two oaks': 'Two Oaks',
        'green acre': 'Green Acre Grange',
        'tandys lane': 'Tandy\'s Lane',
        'rockfield': 'Rockfield Manor',
        'grand canal dock': 'Grand Canal Dock',
        'windy arbour': 'Windy Arbour',
        'cherrywood': 'Cherrywood',
      };

  @override
  String layoutFilterLabelFor(String towerPropertyType) =>
      switch (towerPropertyType) {
        'Share' => 'Room type',
        _ => 'Bed & bath',
      };

  @override
  List<(String, String)> layoutFilterOptionsFor(String towerPropertyType) =>
      switch (towerPropertyType) {
        'Share' => _shareRoomOptions,
        'Rent' => _rentLayoutOptions,
        _ => const [],
      };

  @override
  List<(String, String)> get dwellingFilterOptions => const [
        ('apartment', 'Apartment'),
        ('house', 'House'),
        ('duplex', 'Duplex / townhouse'),
      ];

  @override
  String get bedroomFilterLabel => 'Bed & bath';

  @override
  List<(String, String)> get bedroomFilterOptions => _rentLayoutOptions;

  /// Daft.ie Q1 2026 — whole-unit rent (avg 2-bed ~€2,600 Dublin).
  @override
  List<BudgetBand> get rentBudgetBands => const [
        (null, 1500, 'Under €1,500'),
        (1500, 2000, '€1.5k – €2k'),
        (2000, 2500, '€2k – €2.5k'),
        (2500, 3000, '€2.5k – €3k'),
        (3000, null, 'Above €3k'),
      ];

  /// Daft.ie room / share listings (typical €600–€1,200).
  @override
  List<BudgetBand> get shareBudgetBands => const [
        (null, 600, 'Under €600'),
        (600, 800, '€600 – €800'),
        (800, 1000, '€800 – €1k'),
        (1000, 1200, '€1k – €1.2k'),
        (1200, null, 'Above €1.2k'),
      ];

  @override
  List<BudgetBand> get buyBudgetBands => const [];

  @override
  String formatBudgetAmount(int value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toString();
  }

  @override
  String formatBudgetRange(int? min, int? max) {
    if (min != null && max != null) {
      return '$currencySymbol${formatBudgetAmount(min)} – $currencySymbol${formatBudgetAmount(max)}';
    }
    if (max != null) return 'Under $currencySymbol${formatBudgetAmount(max)}';
    if (min != null) return 'Above $currencySymbol${formatBudgetAmount(min)}';
    return 'Budget';
  }

  @override
  String get searchBarHint =>
      "Try 'All of Dublin' or 'Ensuite in Dublin 6'...";

  @override
  List<(String label, String query)> get fallbackSearchSuggestions => const [
        ('2 bed Dundrum', '2 bed dundrum'),
        ('Ensuite room', 'ensuite cherrywood'),
        ('Veg', 'veg'),
      ];

  @override
  String get defaultProfileLocation => 'Dublin 18 (Sandyford, Leopardstown)';

  @override
  List<String> get profileLanguageOptions => const [
        'English',
        'Gaeilge',
        'Portuguese',
        'Hindi',
        'Telugu',
        'Malayalam',
        'Polish',
        'Romanian',
        'Spanish',
        'French',
        'German',
      ];

  @override
  List<String> get profileFoodOptions => const ['Pure Veg', 'Non-Veg', 'Eggetarian'];

  @override
  List<String> get profileOccupantOptions =>
      const ['Students', 'Working Professionals', 'Family'];

  @override
  List<String> get profileGenderPrefOptions =>
      const ['Boys and Girls', 'Boys only', 'Girls only'];

  @override
  List<String> get profileStudentFundingOptions => const [
        'Family supported',
        'Education loan (bank financed)',
        'Self funded',
      ];

  @override
  String get profileNativePlaceHint => 'e.g. Hyderabad, Chennai';

  @override
  String get profileBudgetSubtitle => 'Monthly rent budget (€).';

  @override
  String get profileBudgetMinHint => 'e.g. 1500';

  @override
  String get profileBudgetMaxHint => 'e.g. 2500';

  @override
  String get profileCityLabel => 'Current area in Dublin';

  @override
  bool get profileUseAreaPicker => true;

  @override
  String get defaultMotherTongue => 'English';

  @override
  String get defaultFoodPreference => 'Pure Veg';

  @override
  String? get defaultOccupantType => 'Students';

  @override
  bool get profileExpandOptionalOnSignup => true;
}
