import 'india_market_config.dart';
import 'dublin_market_config.dart';

enum MarketId { india, dublin }

enum TrustVerificationKind { aadhaar, lightTrust }

/// Budget band: min (inclusive), max (inclusive), display label.
typedef BudgetBand = (int? min, int? max, String label);

/// Active marketplace preset selected via `--dart-define=MARKET=dublin|india`.
abstract class MarketConfig {
  static const _marketRaw = String.fromEnvironment('MARKET', defaultValue: 'dublin');

  static MarketConfig get current => switch (_marketRaw.toLowerCase()) {
        'india' => IndiaMarketConfig.instance,
        _ => DublinMarketConfig.instance,
      };

  MarketId get id;
  String get appTitle;
  String get tagline;
  int get seedVersion;

  /// Rent, Buy, Share — Dublin hides Buy at launch.
  List<String> get enabledTowers;

  TrustVerificationKind get trustVerificationKind;

  String get currencySymbol;

  /// Default area key for search fallbacks.
  String get defaultAreaKey;

  String get defaultAreaDisplayName;

  /// Filter chip area options: (canonical key, label).
  List<(String, String)> get areaOptions;

  /// Search + listing city aliases (broad).
  Map<String, List<String>> get cityAliases;

  /// City tokens used when parsing search queries.
  Map<String, List<String>> get parseCityAliases;

  Map<String, String> get cityDisplayNames;

  List<String> get localityKeywords;

  Map<String, String> get localityDisplayNames;

  /// BHK (India) or bed/bath / room type (Dublin) filter chip label for [tower].
  String layoutFilterLabelFor(String towerPropertyType);

  /// Filter chip options for Rent/Share layout filters: (keyword id, label).
  List<(String, String)> layoutFilterOptionsFor(String towerPropertyType);

  /// Rent-only dwelling filter (House / Apartment). Empty when not used.
  List<(String, String)> get dwellingFilterOptions;

  /// @deprecated Use [layoutFilterOptionsFor] — kept for India BHK default.
  String get bedroomFilterLabel;

  /// @deprecated Use [layoutFilterOptionsFor].
  List<(String, String)> get bedroomFilterOptions;

  List<BudgetBand> get rentBudgetBands;
  List<BudgetBand> get shareBudgetBands;
  List<BudgetBand> get buyBudgetBands;

  String formatBudgetAmount(int value);

  String formatBudgetRange(int? min, int? max);

  /// Placeholder text in the home search bar.
  String get searchBarHint;

  /// Idle / no-match suggestion chips: (display label, query).
  List<(String label, String query)> get fallbackSearchSuggestions;

  /// Profile location hint and demo sign-in default (market-specific).
  String get defaultProfileLocation;

  /// Language options in signup / profile edit.
  List<String> get profileLanguageOptions;

  List<String> get profileFoodOptions;

  List<String> get profileOccupantOptions;

  List<String> get profileGenderPrefOptions;

  List<String> get profileStudentFundingOptions;

  String get profileBudgetSubtitle;

  String get profileBudgetMinHint;

  String get profileBudgetMaxHint;

  /// Label for city / area field on the profile form.
  String get profileCityLabel;

  /// When true, show area dropdown from [areaOptions] instead of free text.
  bool get profileUseAreaPicker;

  String get defaultMotherTongue;

  String get defaultFoodPreference;

  /// Pre-selected occupant type on new profiles (null = none).
  String? get defaultOccupantType;

  /// Expand optional profile fields by default on signup step 2.
  bool get profileExpandOptionalOnSignup;
}
