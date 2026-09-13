import 'market_config.dart';

final class IndiaMarketConfig implements MarketConfig {
  IndiaMarketConfig._();
  static final instance = IndiaMarketConfig._();

  @override
  MarketId get id => MarketId.india;

  @override
  String get appTitle => 'TrueCircle';

  @override
  String get tagline => 'Where trust meets home — India';

  @override
  int get seedVersion => 5;

  @override
  List<String> get enabledTowers => const ['Rent', 'Buy', 'Share'];

  @override
  TrustVerificationKind get trustVerificationKind =>
      TrustVerificationKind.aadhaar;

  @override
  String get currencySymbol => '₹';

  @override
  String get defaultAreaKey => 'hyderabad';

  @override
  String get defaultAreaDisplayName => 'Hyderabad';

  @override
  List<(String, String)> get areaOptions => const [
        ('hyderabad', 'Hyderabad'),
        ('bangalore', 'Bangalore'),
        ('chennai', 'Chennai'),
        ('mumbai', 'Mumbai'),
        ('delhi', 'Delhi'),
      ];

  @override
  Map<String, List<String>> get cityAliases => const {
        'hyderabad': [
          'hyderabad',
          'hyd',
          'secunderabad',
          'hitech',
          'hitec',
          'gachibowli',
        ],
        'bangalore': [
          'bangalore',
          'bengaluru',
          'blr',
          'bang',
          'koramangala',
          'whitefield',
        ],
        'chennai': ['chennai', 'madras', 'chn', 'omr', 'velachery'],
        'mumbai': ['mumbai', 'bombay', 'andheri', 'bandra', 'powai', 'navi mumbai'],
        'delhi': ['delhi', 'ncr', 'dwarka', 'noida', 'gurgaon', 'gurugram'],
      };

  @override
  Map<String, List<String>> get parseCityAliases => const {
        'hyderabad': ['hyderabad', 'hyd', 'secunderabad'],
        'bangalore': ['bangalore', 'bengaluru', 'blr'],
        'chennai': ['chennai', 'madras', 'chn'],
        'mumbai': ['mumbai', 'bombay'],
        'delhi': ['delhi', 'ncr', 'noida', 'gurgaon', 'gurugram'],
      };

  @override
  Map<String, String> get cityDisplayNames => const {
        'hyderabad': 'Hyderabad',
        'bangalore': 'Bangalore',
        'chennai': 'Chennai',
        'mumbai': 'Mumbai',
        'delhi': 'Delhi',
      };

  @override
  List<String> get localityKeywords => const [
        'hitec',
        'hitech',
        'gachibowli',
        'koramangala',
        'whitefield',
        'indiranagar',
        'jubilee hills',
        'jubilee',
        'velachery',
        'omr',
        'andheri',
        'bandra',
        'powai',
        'dwarka',
        'banjara',
        'madhapur',
        'kondapur',
      ];

  @override
  Map<String, String> get localityDisplayNames => const {
        'hitec': 'HITEC',
        'hitech': 'HITEC',
        'gachibowli': 'Gachibowli',
        'koramangala': 'Koramangala',
        'whitefield': 'Whitefield',
        'indiranagar': 'Indiranagar',
        'jubilee': 'Jubilee Hills',
        'jubilee hills': 'Jubilee Hills',
        'velachery': 'Velachery',
        'omr': 'OMR',
        'andheri': 'Andheri',
        'bandra': 'Bandra',
        'powai': 'Powai',
        'dwarka': 'Dwarka',
        'banjara': 'Banjara Hills',
        'madhapur': 'Madhapur',
        'kondapur': 'Kondapur',
      };

  @override
  String layoutFilterLabelFor(String towerPropertyType) => bedroomFilterLabel;

  @override
  List<(String, String)> layoutFilterOptionsFor(String towerPropertyType) =>
      bedroomFilterOptions;

  @override
  List<(String, String)> get dwellingFilterOptions => const [];

  @override
  String get bedroomFilterLabel => 'BHK';

  @override
  List<(String, String)> get bedroomFilterOptions => const [
        ('1bhk', '1 BHK'),
        ('2bhk', '2 BHK'),
        ('3bhk', '3 BHK'),
        ('4bhk', '4 BHK'),
      ];

  @override
  List<BudgetBand> get rentBudgetBands => const [
        (null, 10000, 'Under ₹10k'),
        (10000, 20000, '₹10k – ₹20k'),
        (20000, 40000, '₹20k – ₹40k'),
        (40000, null, 'Above ₹40k'),
      ];

  @override
  List<BudgetBand> get shareBudgetBands => const [
        (null, 8000, 'Under ₹8k'),
        (8000, 15000, '₹8k – ₹15k'),
        (15000, 25000, '₹15k – ₹25k'),
        (25000, null, 'Above ₹25k'),
      ];

  @override
  List<BudgetBand> get buyBudgetBands => const [
        (null, 5000000, 'Under ₹50L'),
        (5000000, 10000000, '₹50L – ₹1Cr'),
        (10000000, 20000000, '₹1Cr – ₹2Cr'),
        (20000000, null, 'Above ₹2Cr'),
      ];

  @override
  String formatBudgetAmount(int value) {
    if (value >= 10000000) {
      return '${(value / 10000000).toStringAsFixed(1)}Cr';
    }
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).round()}k';
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
      'Try Veg in Hyderabad, Family in Bangalore…';

  @override
  List<(String label, String query)> get fallbackSearchSuggestions => const [
        ('Veg', 'veg'),
        ('Family', 'family'),
        ('Students', 'students'),
      ];

  @override
  String get defaultProfileLocation => 'Hyderabad, Telangana';

  @override
  List<String> get profileLanguageOptions => const [
        'Telugu',
        'English',
        'Hindi',
        'Tamil',
        'Kannada',
      ];

  @override
  List<String> get profileFoodOptions => const ['Pure Veg', 'Non-Veg'];

  @override
  List<String> get profileOccupantOptions =>
      const ['Family', 'Working Professionals', 'Students'];

  @override
  List<String> get profileGenderPrefOptions =>
      const ['Boys and Girls', 'Boys only', 'Girls only'];

  @override
  List<String> get profileStudentFundingOptions => const [
        'Family supported',
        'Education loan',
      ];

  @override
  String get profileBudgetSubtitle => 'Monthly rent or purchase budget (INR).';

  @override
  String get profileBudgetMinHint => 'e.g. 8000';

  @override
  String get profileBudgetMaxHint => 'e.g. 25000';

  @override
  String get profileCityLabel => 'Current city';

  @override
  bool get profileUseAreaPicker => false;

  @override
  String get defaultMotherTongue => 'Telugu';

  @override
  String get defaultFoodPreference => 'Pure Veg';

  @override
  String? get defaultOccupantType => null;

  @override
  bool get profileExpandOptionalOnSignup => false;
}
