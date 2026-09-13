import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../config/market/dublin_commuter_hubs.dart';
import '../config/market/dublin_districts.dart';
import '../config/market/market_config.dart';
import '../core/theme/app_theme.dart';
import '../debug/agent_log.dart';
import '../services/auth_service.dart';
import '../services/profile_state_notifier.dart';
import '../services/commute_scoring_service.dart';
import '../utils/applicant_session_sync.dart';
import '../utils/commute_profile.dart';
import '../utils/target_search_areas.dart';
import '../utils/dublin_hap_contribution_validator.dart';
import '../services/profile_storage_service.dart';
import '../services/listings_storage_service.dart';
import '../services/trust_service.dart';
import '../services/view_preference_service.dart';
import '../models/move_in_timing.dart';
import '../models/onboarding_user_intent.dart';
import '../models/onboarding_user_role.dart';
import '../models/profile_onboarding_models.dart';
import '../models/seeker_onboarding_enums.dart';
import '../models/financial_support_type.dart';
import '../models/spoken_language_entry.dart';
import '../services/eircode_geocoding_service.dart';
import '../services/eircode_lookup_service.dart';
import '../services/fast_location_service.dart';
import '../models/irish_address_suggestion.dart';
import '../utils/address_privacy.dart';
import '../services/profile_onboarding_repository.dart';
import '../services/marketplace_context_notifier.dart';
import '../utils/phone_e164.dart';
import '../utils/onboarding_language_inference.dart';
import '../utils/ireland_language_catalog.dart';
import '../utils/profile_data.dart';
import '../utils/seeker_primary_language_locale.dart';
import '../utils/seeker_destination_validity.dart';
import '../utils/spoken_language_profile_codec.dart';
import '../widgets/commute_destination_field.dart';
import '../widgets/gamified_form_wizard.dart';
import '../widgets/language_pill_chips.dart';
import '../widgets/onboarding/onboarding_design_tokens.dart';
import '../widgets/onboarding/onboarding_content_shell.dart';
import '../widgets/onboarding/seeker/seeker_onboarding_basics_screen.dart';
import '../widgets/onboarding/seeker/seeker_onboarding_preferences_screen.dart';
import '../widgets/onboarding/seeker/seeker_onboarding_destination_screen.dart';
import '../widgets/onboarding/seeker/seeker_onboarding_step_tracker.dart';
import '../widgets/onboarding/seeker/seeker_onboarding_shell.dart';
import '../widgets/onboarding/seeker/seeker_preferred_areas_selector.dart';
import '../widgets/onboarding/seeker/seeker_shared_choice_chips.dart';
import '../widgets/onboarding/onboarding_premium_field.dart';
import '../utils/rental_date_format.dart';
import '../widgets/onboarding/onboarding_field_block.dart';
import '../widgets/onboarding/onboarding_move_in_window_field.dart';
import '../widgets/onboarding/onboarding_grid_shell.dart';
import '../utils/contextual_passport_snapshot.dart';
import '../widgets/onboarding/contextual_passport_card.dart';
import '../widgets/shadcn_select.dart';
import '../widgets/truecircle_logo.dart';
import '../services/verification_gateway_recommendation.dart';
import '../widgets/verification_gateway_bottom_sheet.dart';
import 'auth_screen.dart';

/// Seeker tower preferences: entire place vs room in shared flat (no buy path).
abstract final class ProfileSeekerPreferences {
  static const entirePlaceLabel = 'Entire Place (Independent Flat/House)';
  static const sharedRoomLabel = 'Room in a Shared Flat / House';

  static const arrangementOptions = [
    entirePlaceLabel,
    sharedRoomLabel,
  ];

  static const arrangementToBackend = {
    entirePlaceLabel: 'full_rent',
    sharedRoomLabel: 'shared',
  };

  static const shareRoomLayoutOptions = [
    'Single / Private Room',
    'Ensuite Room',
    'Twin / Shared Room',
  ];

  static const rentPropertyLayoutOptions = [
    'Studio',
    '1 Bed',
    '2 Bed',
    '3 Bed',
    '4+ Bed',
  ];

  static bool isSharedRoom(String preferredArrangement) =>
      preferredArrangement == sharedRoomLabel;

  static bool isEntirePlace(String preferredArrangement) =>
      preferredArrangement == entirePlaceLabel;

  static String hydrateArrangement(Map<String, dynamic> profile) {
    final arrangementRaw = ProfileData.text(profile['preferred_arrangement']);
    if (arrangementRaw == 'shared') {
      return sharedRoomLabel;
    }
    if (arrangementRaw == 'full_rent') {
      return entirePlaceLabel;
    }
    final legacyTower = ProfileData.text(profile['preferred_property_type']);
    if (legacyTower == 'Share') {
      return sharedRoomLabel;
    }
    return arrangementOptions.first;
  }

  static String? hydrateLayout(
    Map<String, dynamic> profile,
    String preferredArrangement,
  ) {
    final layout = _normalizeLayoutLabel(ProfileData.text(profile['preferred_layout']));
    if (layout.isEmpty) return null;
    final options = activeLayoutOptions(preferredArrangement);
    return options.contains(layout) ? layout : null;
  }

  static String _normalizeLayoutLabel(String layout) {
    switch (layout) {
      case 'Single Room':
      case 'Double Room':
        return 'Single / Private Room';
      default:
        return layout;
    }
  }

  static List<String> activeLayoutOptions(String preferredArrangement) {
    return isSharedRoom(preferredArrangement)
        ? shareRoomLayoutOptions
        : rentPropertyLayoutOptions;
  }

  static String resolveLayout(
    String preferredArrangement,
    String? preferredLayout,
  ) {
    final options = activeLayoutOptions(preferredArrangement);
    if (preferredLayout != null && options.contains(preferredLayout)) {
      return preferredLayout;
    }
    return options.first;
  }

  static Map<String, dynamic> persistFields({
    required String preferredArrangement,
    required String preferredLayout,
  }) {
    return {
      'preferred_arrangement': arrangementToBackend[preferredArrangement]!,
      'preferred_layout': preferredLayout,
      'preferred_property_type':
          isSharedRoom(preferredArrangement) ? 'Share' : 'Rent',
    };
  }

  static String sharedFoodToBackend(String chip) =>
      chip == 'Veg' ? 'Pure Veg' : 'Non-Veg';

  static String sharedFoodFromBackend(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.contains('non')) return 'Non-Veg';
    return 'Veg';
  }
}

abstract final class ProfileCommuteOptions {
  static const methodLabels = [
    'Public Transport & Walking',
    'Driving',
  ];

  static const methodToBackend = {
    'Public Transport & Walking': 'public_transport_walking',
    'Driving': 'driving',
  };

  static const backendToMethod = {
    'public_transport_walking': 'Public Transport & Walking',
    'driving': 'Driving',
  };

  static String hydrateMethod(Map<String, dynamic> profile) {
    return CommuteMethod.fromBackend(ProfileData.text(profile['commute_method']))
        .toDisplayLabel();
  }
}

/// "I am looking for" arrangement + conditional layout dropdowns.
class ProfileLookingForFields extends StatelessWidget {
  const ProfileLookingForFields({
    super.key,
    required this.preferredArrangement,
    required this.preferredLayout,
    required this.onArrangementChanged,
    required this.onLayoutChanged,
  });

  final String preferredArrangement;
  final String? preferredLayout;
  final ValueChanged<String> onArrangementChanged;
  final ValueChanged<String> onLayoutChanged;

  @override
  Widget build(BuildContext context) {
    final resolvedLayout = ProfileSeekerPreferences.resolveLayout(
      preferredArrangement,
      preferredLayout,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadcnSelect(
          label: 'Preferred Arrangement',
          value: preferredArrangement,
          options: ProfileSeekerPreferences.arrangementOptions,
          onChanged: onArrangementChanged,
        ),
        if (ProfileSeekerPreferences.isSharedRoom(preferredArrangement))
          ShadcnSelect(
            key: const ValueKey('seeker_room_type'),
            label: 'Room Type',
            value: resolvedLayout,
            options: ProfileSeekerPreferences.shareRoomLayoutOptions,
            onChanged: onLayoutChanged,
          ),
        if (ProfileSeekerPreferences.isEntirePlace(preferredArrangement))
          ShadcnSelect(
            key: const ValueKey('seeker_property_layout'),
            label: 'Property Layout',
            value: resolvedLayout,
            options: ProfileSeekerPreferences.rentPropertyLayoutOptions,
            onChanged: onLayoutChanged,
          ),
      ],
    );
  }
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, this.initialProfile});

  final Map<String, dynamic>? initialProfile;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  int _currentPage = 0;
  bool _hydrating = true;
  Map<String, dynamic>? _baselineProfile;

  int get _pageCount =>
      ProfileSeekerPreferences.isSharedRoom(preferredArrangement) ? 4 : 3;

  bool get _isSharedTrack =>
      ProfileSeekerPreferences.isSharedRoom(preferredArrangement);

  /// Matching-ready baseline ⇒ edit profile (show signed-in card).
  /// Incomplete ⇒ first-time onboarding (hide signed-in card).
  bool get _showSignedInAsCard => ProfileData.isMatchingReady(
        _baselineProfile ?? AuthScreen.currentUserSession,
      );

  DublinLocationContext? _dublinLocationContext;
  GuarantorStatus? _guarantorStatus;
  SeekerMoveInWindow? _moveInWindow;
  DateTime? _moveInDate;
  SeekerPersona? _seekerPersona;
  String? _lookingWith;
  String? _groupComposition;
  String? _friendCount;
  String? _roomArrangement;
  String? _sharedRoomPreference;
  String? _smokingStatus;
  String? _petType;
  String? _parkingNeed;
  String? _transportMode;
  final List<String> _selectedTargetSearchAreas = [];
  bool _partnerCommuteEnabled = false;
  DualCommutePriority _dualCommutePriority = DualCommutePriority.personA;
  bool _commuteMethodUserOverridden = false;
  int _pageTransitionDirection = 1;

  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  String _phoneCountryCode = PhoneE164.defaultCountryCode;
  bool _prefersWhatsapp = false;
  final _propertyLocationIdentifierController = TextEditingController();
  final _locationController = TextEditingController();
  final _propertyLocationController = TextEditingController();
  final _propertyEircodeController = TextEditingController();
  final _propertyAddressSearchController = TextEditingController();
  IrishAddressSuggestion? _selectedPropertyAddress;
  bool _hidePropertyExactAddress = false;
  bool _fetchingPropertyLocation = false;
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  final _netMonthlyIncomeController = TextEditingController();
  final _partnerNetMonthlyIncomeController = TextEditingController();
  final _hapVoucherContributionController = TextEditingController();
  String _selectedMotherTongue = '';
  final List<String> _selectedLanguages = [];
  final List<String> _suggestedSecondaryLanguages = [];
  final List<String> _extraSecondaryLanguages = [];
  final Set<String> _selectedSecondaryLanguages = {};
  final Map<String, bool> _languageNativeFlags = {};
  final List<_CommuterDraftEntry> _commuterDrafts = [];
  int _householdCommutersCount = 1;
  bool _commuteDestinationUnknown = false;
  /// Bumped when My ↔ Partner owner switches so destination search remounts empty.
  int _destinationFieldResetToken = 0;
  double _maxCommuteBudgetMinutes =
      SeekerCommuteTimeOptions.defaultMinutes.toDouble();
  int? _preferredLeaseMonths;
  bool _hasHapVoucher = false;
  bool _hapUpliftApproved = false;
  bool _hasVerifiedGuarantor = false;
  bool _householdHasPets = false;
  bool _householdSmoker = false;
  final List<String> _preferredSpokenLanguages = [];
  String _sharedFoodPref = 'Veg';
  bool _hasSetFoodPreference = false;
  bool _hasSetMoveInWindow = false;
  String? _familySharedLivingTip;
  String? _selectedAreaKey;
  String? _providerAreaKey;
  OnboardingUserIntent _onboardingIntent = OnboardingUserIntent.seeker;
  bool _providerSharedSpace = false;
  bool _providerIsFurnished = true;
  bool _providerIsOwnerOccupier = false;
  int _providerHousemateCount = 1;
  final Set<String> _providerHouseRules = {'No smoking', 'No pets'};
  String? _selectedOccupantType;
  String? _selectedGenderPref;
  String? _selectedFinancialSupportType;

  String preferredArrangement = ProfileSeekerPreferences.arrangementOptions.first;
  String? preferredLayout;

  int _familyAdults = 2;
  int _familyChildren = 0;
  List<String> _childrenAges = [];
  int _groupSize = 1;
  TenurePreference? _tenurePreference;
  FurnishingPreference? _furnishingPreference;
  PropertyTypePreference? _propertyTypePreference;
  BathroomPreference? _bathroomPreference;
  bool _smokingOk = false;
  bool _drinkingOk = false;
  String? _scheduleType;
  int _ownedListingCount = 0;
  final _agencyController = TextEditingController();

  static const _childrenAgeOptions = ['Below 5', '5 - 12', '13 - 18'];
  static const _familySharedLivingTipMessage =
      "Shared Living isn't typically available for families — try Independent Place instead";

  int get _selectedBudgetTime => _maxCommuteBudgetMinutes.round();

  int get _commuterSlotCount => 1;

  CommuteMethod _defaultCommuteMethodForPersona(SeekerPersona? persona) {
    return switch (persona) {
      SeekerPersona.student || SeekerPersona.relocating =>
        CommuteMethod.publicTransportWalking,
      SeekerPersona.professional || SeekerPersona.family =>
        CommuteMethod.driving,
      null => CommuteMethod.publicTransportWalking,
    };
  }

  /// Residential status overrides persona default when moving to Dublin.
  CommuteMethod _defaultCommuteMethod() {
    if (_dublinLocationContext == DublinLocationContext.arrivingSoon ||
        _dublinLocationContext == DublinLocationContext.relocating) {
      return CommuteMethod.publicTransportWalking;
    }
    return _defaultCommuteMethodForPersona(_seekerPersona);
  }

  void _ensurePrimaryCommuterDraft() {
    if (_commuterDrafts.isEmpty) {
      _commuterDrafts.add(_CommuterDraftEntry());
    }
  }

  void _applyDefaultCommuteMethodIfNeeded() {
    if (_commuteMethodUserOverridden) return;
    _ensurePrimaryCommuterDraft();
    _commuterDrafts.first.methodLabel =
        _defaultCommuteMethod().toDisplayLabel();
  }

  void _setPartnerCommuteEnabled(bool enabled) {
    _partnerCommuteEnabled = enabled;
    _householdCommutersCount = enabled ? 2 : 1;
    // One profile = one destination — never allocate a second hub draft.
    _ensurePrimaryCommuterDraft();
    _syncCommuterDraftSlots();
    if (!enabled) {
      // Labeling only; personA = my destination.
      _dualCommutePriority = DualCommutePriority.personA;
    } else if (_dualCommutePriority == DualCommutePriority.balanced) {
      _dualCommutePriority = DualCommutePriority.personA;
    }
  }

  List<String> get _languageOptions => MarketConfig.current.profileLanguageOptions;

  static const _sharedFoodChipOptions = ['Veg', 'Non-Veg'];
  List<String> get _occupantOptions => MarketConfig.current.profileOccupantOptions;
  List<String> get _occupantOptionsForCurrentTrack {
    if (_selectedTrack == ProfileOnboardingTrack.seekerSharedSpace) {
      return const ['Working Professionals', 'Students'];
    }
    return _occupantOptions;
  }

  String get _resolvedOccupantType =>
      _selectedOccupantType ?? _occupantOptionsForCurrentTrack.first;
  List<String> get _genderPrefOptions =>
      MarketConfig.current.profileGenderPrefOptions;
  List<String> get _financialSupportOptions =>
      MarketConfig.current.profileStudentFundingOptions;

  String get _resolvedPreferredLayout => ProfileSeekerPreferences.resolveLayout(
        preferredArrangement,
        preferredLayout,
      );

  ProfileOnboardingTrack get _selectedTrack {
    if (_onboardingIntent == OnboardingUserIntent.provider) {
      return _providerSharedSpace
          ? ProfileOnboardingTrack.landlordSharedSpace
          : ProfileOnboardingTrack.landlordEntirePlace;
    }
    return ProfileSeekerPreferences.isSharedRoom(preferredArrangement)
        ? ProfileOnboardingTrack.seekerSharedSpace
        : ProfileOnboardingTrack.seekerEntirePlace;
  }

  /// Display label for the area ShadcnSelect (never the raw storage key).
  String get _locationSelectValue {
    if (!MarketConfig.current.profileUseAreaPicker) {
      return _formatLocationDisplay(_locationController.text.trim());
    }
    final key = _selectedAreaKey ?? MarketConfig.current.defaultAreaKey;
    for (final (areaKey, label) in MarketConfig.current.areaOptions) {
      if (areaKey == key) return label;
    }
    return _formatLocationDisplay(
      dublinDistrictLabelForKey(key) ??
          MarketConfig.current.defaultAreaDisplayName,
    );
  }

  @override
  void initState() {
    super.initState();
    _onboardingIntent = OnboardingUserIntent.seeker;
    profileStateNotifier.beginEditing(widget.initialProfile, notify: false);
    _applyMarketDefaults();
    _nameController.addListener(_onPassportFieldChanged);
    _locationController.addListener(_onPassportFieldChanged);
    _propertyLocationController.addListener(_onPassportFieldChanged);
    _propertyEircodeController.addListener(_onPassportFieldChanged);
    _budgetMaxController.addListener(_onPassportFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _enforceSeekerRoleGate();
    });
    _bootstrap();
  }

  void _enforceSeekerRoleGate() {
    final session =
        widget.initialProfile ?? AuthScreen.currentUserSession;
    if (!AuthService.isSignedIn(session)) {
      context.go('/');
      return;
    }
    final role = UserRole.fromSession(session);
    if (role == UserRole.landlord) {
      context.go('/landlord-dashboard');
      return;
    }
    if (role == UserRole.unassigned) {
      context.go('/');
    }
  }

  void _onPassportFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (!_hydrating && mounted) {
      profileStateNotifier.updateEditingSession(
        _draftSession(),
        notify: false,
      );
    }
  }

  void _applyMarketDefaults() {
    final market = MarketConfig.current;
    if (_onboardingIntent == OnboardingUserIntent.provider) {
      _selectedMotherTongue = market.defaultMotherTongue;
      _applyMotherTongueInference(market.defaultMotherTongue);
    }
    if (market.profileUseAreaPicker) {
      _selectedAreaKey = market.defaultAreaKey;
      _providerAreaKey = market.defaultAreaKey;
      _locationController.text = market.defaultAreaDisplayName;
      _propertyLocationController.text = market.defaultAreaDisplayName;
    }
    _selectedOccupantType ??= _occupantOptions.first;
  }

  Future<void> _bootstrap() async {
    final loaded =
        widget.initialProfile ?? await ProfileStorageService.load();
    final session = loaded ?? AuthScreen.currentUserSession;
    final owned = await ListingsStorageService.ownedByCurrentUser(session);
    if (!mounted) return;
    if (session != null) {
      _baselineProfile = Map<String, dynamic>.from(session);
      _hydrateFromProfile(session);
    }
    if (_commuterDrafts.isEmpty) {
      _commuterDrafts.add(_CommuterDraftEntry());
      _syncCommuterDraftSlots();
    }
    _seedSeekerPrimaryLanguageFromLocale();
    setState(() {
      _ownedListingCount = owned.length;
      _hydrating = false;
    });
    profileStateNotifier.updateEditingSession(_draftSession(), notify: false);
  }

  void _hydrateFromProfile(Map<String, dynamic> profile) {
    _emailController.text = ProfileData.text(profile['email']);
    _nameController.text = ProfileData.text(profile['full_name']);
    _contactPhoneController.text = ProfileData.text(
      profile['contact_phone'] ?? profile['phone'],
    );
    final phoneSplit = PhoneE164.split(
      ProfileData.text(profile['contact_phone_e164']),
    );
    if (phoneSplit != null) {
      _phoneCountryCode = phoneSplit.countryCode;
      _contactPhoneController.text = phoneSplit.national;
    }
    _prefersWhatsapp = profile['prefers_whatsapp'] == true;
    _propertyLocationIdentifierController.text = ProfileData.text(
      profile['property_location_identifier'] ??
          profile['pending_listing_location'],
    );

    final city = ProfileData.text(profile['detected_city']);
    if (MarketConfig.current.profileUseAreaPicker) {
      var matched = false;
      for (final (key, label) in MarketConfig.current.areaOptions) {
        if (label.toLowerCase() == city.toLowerCase() || key == city) {
          _selectedAreaKey = key;
          _locationController.text = label;
          matched = true;
          break;
        }
      }
      if (!matched) {
        _selectedAreaKey = MarketConfig.current.defaultAreaKey;
        _locationController.text = _formatLocationDisplay(
          city.isNotEmpty ? city : MarketConfig.current.defaultAreaDisplayName,
        );
      }
    } else {
      _locationController.text = city;
    }

    _agencyController.text = ProfileData.text(profile['agency_name']);

    final mother = ProfileData.text(profile['mother_tongue']);
    if (mother.isNotEmpty) {
      _selectedMotherTongue = mother;
    }

    _hydrateCommutersFromProfile(profile);
    _commuteDestinationUnknown =
        ProfileData.commuteDestinationUnknown(profile);

    final householdCommuters = profile['household_commuters_count'];
    if (householdCommuters is int && householdCommuters > 0) {
      _householdCommutersCount = householdCommuters;
    } else {
      _householdCommutersCount = _commuterDrafts.length.clamp(1, 2);
    }
    _partnerCommuteEnabled = _householdCommutersCount >= 2 ||
        _commuterDrafts.length >= 2 ||
        ProfileData.text(profile['partner_commute_method']).isNotEmpty;
    if (_partnerCommuteEnabled && _householdCommutersCount < 2) {
      _householdCommutersCount = 2;
    }
    _syncCommuterDraftSlots();
    _commuteMethodUserOverridden =
        ProfileData.text(profile['commute_method']).isNotEmpty;
    _applyDefaultCommuteMethodIfNeeded();

    final maxCommute = profile['maximum_commute_budget_minutes'];
    if (maxCommute is num && maxCommute > 0) {
      _maxCommuteBudgetMinutes =
          SeekerCommuteTimeOptions.snap(maxCommute).toDouble();
    }

    final preferredLangs = profile['preferred_spoken_languages'];
    if (preferredLangs is List) {
      _preferredSpokenLanguages
        ..clear()
        ..addAll(
          preferredLangs
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty),
        );
    }
    _ensurePreferredSpokenLanguagesSeeded();

    final food = ProfileData.text(profile['food_preference']);
    if (food.isNotEmpty) {
      _sharedFoodPref = ProfileSeekerPreferences.sharedFoodFromBackend(food);
    }

    _selectedLanguages
      ..clear()
      ..addAll(ProfileData.languageList(profile['spoken_languages']));

    _hydrateSeekerSecondaryLanguageState();

    _languageNativeFlags
      ..clear()
      ..addEntries(
        ProfileData.spokenLanguageEntries(profile).map(
          (entry) => MapEntry(entry.language, entry.isNative),
        ),
      );
    if (_selectedMotherTongue.trim().isNotEmpty) {
      _languageNativeFlags[_selectedMotherTongue] = true;
    }

    final occupant = ProfileData.text(profile['occupant_type']);
    if (occupant.isNotEmpty && _occupantOptions.contains(occupant)) {
      _selectedOccupantType = occupant;
    }

    preferredArrangement = ProfileSeekerPreferences.hydrateArrangement(profile);
    preferredLayout = ProfileSeekerPreferences.hydrateLayout(
      profile,
      preferredArrangement,
    );
    final layoutRaw = ProfileData.text(profile['preferred_layout']).toLowerCase();
    if (layoutRaw == 'private' || layoutRaw == 'shared') {
      _sharedRoomPreference = layoutRaw;
    } else if (layoutRaw.contains('shared') || layoutRaw.contains('twin')) {
      _sharedRoomPreference = 'shared';
    } else if (layoutRaw.contains('private') || layoutRaw.contains('single')) {
      _sharedRoomPreference = 'private';
    }
    _lookingWith = _hydrateToken(profile['looking_with'], const {
      'just_me',
      'partner',
      'friends',
    });
    _groupComposition = _hydrateToken(profile['group_composition'], const {
      'male',
      'female',
      'mixed',
      'prefer_not',
    });
    _friendCount = _hydrateToken(profile['friend_count'], const {
      'one',
      'two_plus',
    });
    _roomArrangement = _hydrateToken(profile['room_arrangement'], const {
      'separate',
      'sharing',
    });
    _smokingStatus = _hydrateToken(profile['smoking_status'], const {
      'non_smoker',
      'vaper',
      'smoker',
    });
    if (_smokingStatus != null) {
      _smokingOk = _smokingStatus != 'non_smoker';
      _householdSmoker = _smokingStatus == 'smoker';
    }
    _petType = _hydrateToken(profile['pet_type'], const {
      'none',
      'dog',
      'cat',
      'other',
    });
    if (_petType != null) {
      _householdHasPets = _petType != 'none';
    }
    _parkingNeed = _hydrateToken(profile['parking_need'], const {
      'required',
      'nice_to_have',
      'not_needed',
    });
    _transportMode = _hydrateToken(profile['transport_mode'], const {
      'public_transport',
      'walking',
      'cycling',
      'driving',
    });
    if (_transportMode == null) {
      final method = ProfileData.text(profile['commute_method']);
      if (method == CommuteMethod.backendDriving) {
        _transportMode = 'driving';
      } else if (method == CommuteMethod.backendPublicTransportWalking) {
        _transportMode = 'public_transport';
      }
    }
    if (!ProfileSeekerPreferences.isSharedRoom(preferredArrangement)) {
      _partnerCommuteEnabled = false;
      _householdCommutersCount = 1;
      _dualCommutePriority = DualCommutePriority.personA;
    }

    final genderPref = ProfileData.text(profile['gender_preference']);
    if (genderPref.isNotEmpty && _genderPrefOptions.contains(genderPref)) {
      _selectedGenderPref = genderPref;
    }

    final support = FinancialSupportType.fromSession(profile);
    if (support != null && _financialSupportOptions.contains(support)) {
      _selectedFinancialSupportType = support;
    } else {
      _selectedFinancialSupportType = null;
    }

    final adults = profile['adults_count'] ?? profile['family_adults'];
    if (adults is int) _familyAdults = adults;
    final children = profile['children_count'] ?? profile['family_children'];
    if (children is int) _familyChildren = children;

    _tenurePreference = TenurePreference.fromSession(profile);
    TenurePreference.migrateIndependentPlaceSession(profile);
    _furnishingPreference = FurnishingPreference.fromSession(profile);
    _propertyTypePreference = PropertyTypePreference.fromSession(profile);
    _bathroomPreference = BathroomPreference.fromSession(profile);

    final rawAges = profile['children_ages'];
    if (rawAges is List) {
      _childrenAges = rawAges.map((e) => e.toString()).toList();
    } else {
      final legacyAge = ProfileData.text(profile['children_age_range']);
      _childrenAges = List.generate(
        _familyChildren,
        (_) => legacyAge.isNotEmpty ? legacyAge : _childrenAgeOptions.first,
      );
    }

    final group = profile['group_size'];
    if (group is int) _groupSize = group;

    _smokingOk = profile['smoking_ok'] == true;
    _drinkingOk = profile['drinking_ok'] == true;
    final schedule = ProfileData.text(profile['schedule_type']);
    if (schedule.isNotEmpty) _scheduleType = schedule;

    final budgetMin = profile['budget_min'];
    if (budgetMin != null) _budgetMinController.text = budgetMin.toString();
    final budgetMax = profile['budget_max'];
    if (budgetMax != null) _budgetMaxController.text = budgetMax.toString();

    final netIncome = profile['net_monthly_income'];
    if (netIncome != null) {
      _netMonthlyIncomeController.text = netIncome.toString();
    }
    final partnerIncome = profile['partner_net_monthly_income'];
    if (partnerIncome != null) {
      _partnerNetMonthlyIncomeController.text = partnerIncome.toString();
    }
    final hapContribution = profile['hap_voucher_contribution'];
    if (hapContribution != null) {
      _hapVoucherContributionController.text = hapContribution.toString();
    }
    _hasHapVoucher = profile['has_hap_voucher'] == true;
    _hapUpliftApproved = profile['hap_uplift_approved'] == true;
    _hasVerifiedGuarantor = profile['has_verified_guarantor'] == true ||
        profile['verified_guarantor'] == true;
    _householdHasPets = profile['household_has_pets'] == true;
    _householdSmoker = profile['household_smoker'] == true ||
        profile['smoking_ok'] == true;
    _preferredLeaseMonths = profile['preferred_lease_months'] is int
        ? profile['preferred_lease_months'] as int
        : int.tryParse(ProfileData.text(profile['preferred_lease_months']));
    final leaseDuration = profile['lease_duration'];
    if (leaseDuration is int && const {1, 2, 3, 6}.contains(leaseDuration)) {
      _preferredLeaseMonths = leaseDuration;
    }
    _moveInWindow = SeekerMoveInWindow.fromSession(profile);
    _hasSetMoveInWindow = _moveInWindow != null;
    final moveInDateRaw = ProfileData.text(profile['move_in_date']);
    final parsedMoveIn = RentalDateFormat.parseIsoDate(moveInDateRaw);
    if (parsedMoveIn != null) {
      _moveInDate = parsedMoveIn;
      _hasSetMoveInWindow = true;
      _moveInWindow = _deriveMoveInWindowFromDate(parsedMoveIn);
    }
    final leasePref = ProfileData.text(profile['lease_preference']);
    if (leasePref == 'temporary') {
      _tenurePreference = TenurePreference.temporary;
    } else if (leasePref == 'long_term') {
      _tenurePreference = TenurePreference.longTerm;
    }

    _onboardingIntent = OnboardingUserIntent.seeker;
    final snapshot = ProfileOnboardingRepository.snapshotFromSession(profile);
    _providerSharedSpace = snapshot.track == ProfileOnboardingTrack.landlordSharedSpace;
    _providerIsFurnished = snapshot.listingSeed.isFurnished;
    _providerIsOwnerOccupier = snapshot.hostProfile.isOwnerOccupier;
    final hostHousehold =
        snapshot.hostProfile.currentHouseholdMakeup['group_size'] ??
            snapshot.hostProfile.currentHouseholdMakeup['current_occupants'];
    if (hostHousehold is int && hostHousehold > 0) {
      _providerHousemateCount = hostHousehold;
    }
    _providerHouseRules
      ..clear()
      ..addAll(snapshot.hostProfile.houseRules);
    if (_providerHouseRules.isEmpty) {
      _providerHouseRules.addAll({'No smoking', 'No pets'});
    }

    final pendingLocation = ProfileData.text(profile['pending_listing_location']);
    final pendingEircode = ProfileData.text(profile['pending_listing_eircode']);
    if (pendingLocation.isNotEmpty) {
      if (MarketConfig.current.profileUseAreaPicker) {
        var matched = false;
        for (final (key, label) in MarketConfig.current.areaOptions) {
          if (label.toLowerCase() == pendingLocation.toLowerCase() ||
              key == pendingLocation) {
            _providerAreaKey = key;
            _propertyLocationController.text = label;
            matched = true;
            break;
          }
        }
        if (!matched) {
          _propertyLocationController.text = pendingLocation;
        }
      } else {
        _propertyLocationController.text = pendingLocation;
      }
    }
    if (pendingEircode.isNotEmpty) {
      _propertyEircodeController.text =
          EircodeGeocodingService.normalize(pendingEircode);
    }
    _hidePropertyExactAddress =
        profile[AddressPrivacy.hideExactAddressKey] == true;
    if (pendingEircode.isNotEmpty) {
      _propertyAddressSearchController.text = pendingEircode;
    } else if (pendingLocation.isNotEmpty) {
      _propertyAddressSearchController.text = pendingLocation;
    }
    final identifier =
        ProfileData.text(profile['property_location_identifier']);
    if (identifier.isNotEmpty &&
        _propertyAddressSearchController.text.isNotEmpty) {
      _propertyAddressSearchController.text =
          '$identifier, ${_propertyAddressSearchController.text}';
      _propertyLocationIdentifierController.text = identifier;
    } else if (identifier.isNotEmpty) {
      _propertyLocationIdentifierController.text = identifier;
      _propertyAddressSearchController.text = identifier;
    }

    _dublinLocationContext = DublinLocationContext.fromSession(profile);
    _guarantorStatus = GuarantorStatus.fromSession(profile);
    _seekerPersona = SeekerPersona.fromSession(profile);
    if (_seekerPersona == SeekerPersona.relocating) {
      _seekerPersona = SeekerPersona.professional;
    }
    if (_seekerPersona?.requiresGuarantorQuestion == true &&
        _guarantorStatus == null) {
      _guarantorStatus = GuarantorStatus.notSureYet;
    }
    if (_seekerPersona != null) {
      _selectedOccupantType = _seekerPersona!.occupantType;
    }

    _selectedTargetSearchAreas
      ..clear()
      ..addAll(
        TargetSearchAreas.normalizeMacroTokens(
          TargetSearchAreas.tokenList(profile['target_search_areas']),
        ).where((token) => token != TargetSearchAreas.allDublinToken),
      );

    final priorityRaw =
        ProfileData.text(profile['dual_commute_priority']).toLowerCase();
    _dualCommutePriority = switch (priorityRaw) {
      'person_b' || 'personb' => DualCommutePriority.personB,
      // Balanced is not offered in onboarding — map to my destination.
      'balanced' => DualCommutePriority.personA,
      'person_a' || 'persona' => DualCommutePriority.personA,
      _ => DualCommutePriority.personA,
    };
  }

  void _seedSeekerPrimaryLanguageFromLocale() {
    if (_onboardingIntent != OnboardingUserIntent.seeker) return;
    if (_selectedMotherTongue.trim().isNotEmpty) return;
    final inferred = SeekerPrimaryLanguageLocale.fromLocale(
      WidgetsBinding.instance.platformDispatcher.locale,
    );
    if (inferred == null) return;
    _selectedMotherTongue = inferred;
    _languageNativeFlags[inferred] = true;
    _refreshSuggestedSecondaryLanguages(inferred);
    _syncSelectedLanguagesFromSeekerTiers();
  }

  void _hydrateSeekerSecondaryLanguageState() {
    _suggestedSecondaryLanguages.clear();
    _extraSecondaryLanguages.clear();
    _selectedSecondaryLanguages.clear();

    if (_selectedMotherTongue.isEmpty && _selectedLanguages.isNotEmpty) {
      // Prefer first non-English spoken language as primary when restoring.
      final fallback = _selectedLanguages.firstWhere(
        (lang) => lang.toLowerCase() != 'english',
        orElse: () => _selectedLanguages.first,
      );
      _selectedMotherTongue = fallback;
    }

    if (_selectedMotherTongue.isNotEmpty) {
      _suggestedSecondaryLanguages.addAll(
        OnboardingLanguageInference.suggestedLanguagesFor(_selectedMotherTongue),
      );
      for (final lang in _selectedLanguages) {
        if (lang.toLowerCase() == 'english') continue;
        if (lang.toLowerCase() == _selectedMotherTongue.toLowerCase()) {
          continue;
        }
        _selectedSecondaryLanguages.add(lang);
        if (!_suggestedSecondaryLanguages.any(
          (suggested) => suggested.toLowerCase() == lang.toLowerCase(),
        )) {
          _extraSecondaryLanguages.add(lang);
        }
      }
    }
  }

  List<String> _secondaryDisplayLanguages() {
    final seen = <String>{};
    final display = <String>[];
    void addLanguage(String language) {
      if (language.toLowerCase() == 'english') return;
      if (_selectedMotherTongue.isNotEmpty &&
          language.toLowerCase() == _selectedMotherTongue.toLowerCase()) {
        return;
      }
      final key = language.toLowerCase();
      if (seen.add(key)) display.add(language);
    }

    for (final language in _suggestedSecondaryLanguages) {
      addLanguage(language);
    }
    for (final language in _extraSecondaryLanguages) {
      addLanguage(language);
    }
    return display;
  }

  void _refreshSuggestedSecondaryLanguages(String primaryLanguage) {
    _suggestedSecondaryLanguages
      ..clear()
      ..addAll(
        OnboardingLanguageInference.suggestedLanguagesFor(primaryLanguage),
      );

    _extraSecondaryLanguages.removeWhere(
      (language) => _suggestedSecondaryLanguages.any(
        (suggested) => suggested.toLowerCase() == language.toLowerCase(),
      ),
    );

    final display = _secondaryDisplayLanguages();
    _selectedSecondaryLanguages.removeWhere(
      (language) =>
          language.toLowerCase() == primaryLanguage.toLowerCase() ||
          !display.any(
            (candidate) => candidate.toLowerCase() == language.toLowerCase(),
          ),
    );
  }

  List<String> _seekerSpokenLanguagesForPayload() {
    final ordered = <String>[];
    for (final language in _secondaryDisplayLanguages()) {
      if (_selectedSecondaryLanguages.any(
        (selected) => selected.toLowerCase() == language.toLowerCase(),
      )) {
        ordered.add(language);
      }
    }
    return [
      if (_selectedMotherTongue.trim().isNotEmpty) _selectedMotherTongue.trim(),
      ...ordered,
    ];
  }

  void _syncSelectedLanguagesFromSeekerTiers() {
    if (_onboardingIntent != OnboardingUserIntent.seeker) return;
    _selectedLanguages
      ..clear()
      ..addAll(
        OnboardingLanguageInference.withEnglishFoundation(
          _seekerSpokenLanguagesForPayload(),
        ),
      );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      profileStateNotifier.endEditing();
    });
    _nameController.removeListener(_onPassportFieldChanged);
    _locationController.removeListener(_onPassportFieldChanged);
    _propertyLocationController.removeListener(_onPassportFieldChanged);
    _propertyEircodeController.removeListener(_onPassportFieldChanged);
    _budgetMaxController.removeListener(_onPassportFieldChanged);
    _emailController.dispose();
    _nameController.dispose();
    _contactPhoneController.dispose();
    _propertyLocationIdentifierController.dispose();
    _locationController.dispose();
    _propertyLocationController.dispose();
    _propertyEircodeController.dispose();
    _propertyAddressSearchController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _agencyController.dispose();
    super.dispose();
  }

  bool get _showEnterpriseFields {
    final session = _baselineProfile ?? AuthScreen.currentUserSession;
    return ViewPreferenceService.resolve(
          session: session,
          ownedListingCount: _ownedListingCount,
        ) ==
            DashboardViewMode.host ||
        ViewPreferenceService.isMultiListingHost(_ownedListingCount);
  }

  Map<String, dynamic> _draftSession() {
    final baseline = Map<String, dynamic>.from(
      _baselineProfile ?? AuthScreen.currentUserSession ?? {},
    );
    baseline.remove('native_place');
    return {
      ...baseline,
      'email': _emailController.text.trim(),
      'full_name': _nameController.text.trim(),
      'detected_city': _resolvedCity(),
      ..._spokenLanguageSessionFields(),
      ..._commutePayloadFields(),
      if (_budgetMinController.text.trim().isNotEmpty)
        'budget_min': int.tryParse(_budgetMinController.text.trim()),
      if (_budgetMaxController.text.trim().isNotEmpty)
        'budget_max': int.tryParse(_budgetMaxController.text.trim()),
      'occupant_type': _seekerPersona?.occupantType ?? _resolvedOccupantType,
      if (_agencyController.text.trim().isNotEmpty)
        'agency_name': _agencyController.text.trim(),
      if (_selectedOccupantType == 'Family' ||
          _seekerPersona == SeekerPersona.family) ...{
        'adults_count': _familyAdults,
        'children_count': _familyChildren,
        // Legacy aliases — existing passport / HAP consumers.
        'family_adults': _familyAdults,
        'family_children': _familyChildren,
      },
      if (_selectedOccupantType == 'Working Professionals' ||
          _selectedOccupantType == 'Students')
        'group_size': _groupSize,
      if (_partnerNetMonthlyIncomeController.text.trim().isNotEmpty)
        'partner_net_monthly_income':
            double.tryParse(_partnerNetMonthlyIncomeController.text.trim()),
      if (!ProfileSeekerPreferences.isSharedRoom(preferredArrangement)) ...{
        if (_tenurePreference != null)
          TenurePreference.sessionKey: TenurePreference.migrateIndependentPlace(
                _tenurePreference,
              )!
              .storageToken,
        if (_furnishingPreference != null)
          FurnishingPreference.sessionKey: _furnishingPreference!.storageToken,
        if (_propertyTypePreference != null)
          PropertyTypePreference.sessionKey:
              _propertyTypePreference!.storageToken,
      },
      if (_bathroomPreference != null)
        BathroomPreference.sessionKey: _bathroomPreference!.storageToken,
    };
  }

  Map<String, dynamic> _passportPreviewSession() {
    final session = {
      ..._draftSession(),
      'onboarding_intent': _onboardingIntent.storageToken,
      'profile_onboarding_track': _selectedTrack.storageToken,
      ...ProfileSeekerPreferences.persistFields(
        preferredArrangement: preferredArrangement,
        preferredLayout: _resolvedPreferredLayout,
      ),
      ..._seekerPersonaPayloadFields(),
      ..._seekerLocationPayloadFields(),
      ..._targetSearchAreasPayloadFields(),
      ..._guarantorPayloadFields(),
      ..._moveInPayloadFields(),
      if (_scheduleType != null) 'schedule_type': _scheduleType,
      if (ProfileSeekerPreferences.isSharedRoom(preferredArrangement)) ...{
        ..._sharedRoomPayloadFields(),
        'smoking_ok': _smokingOk,
        'drinking_ok': _drinkingOk,
        // Display Only — not used in matching or scoring (V1)
        if (_selectedGenderPref != null) 'gender_preference': _selectedGenderPref,
      },
      if (_preferredLeaseMonths != null)
        'preferred_lease_months': _preferredLeaseMonths,
    };
    if (!_hasSetFoodPreference) {
      session.remove('food_preference');
    }
    if (!_hasSetMoveInWindow) {
      session
        ..remove('earliest_move_in_date')
        ..remove('move_in_window')
        ..remove('move_in_timing_version');
    }
    return session;
  }

  String _passportPreviewFingerprint() {
    final session = _passportPreviewSession();
    final languages = ProfileData.languageList(session['spoken_languages']);
    final preferred = ProfileData.languageList(
      session['preferred_spoken_languages'],
    );
    return [
      ProfileData.text(session['full_name']),
      ProfileData.text(session['profile_onboarding_track']),
      ProfileData.text(session['seeker_persona']),
      ProfileData.text(session['dublin_location_context']),
      ProfileData.text(session['guarantor_status']),
      session['budget_max']?.toString() ?? '',
      _moveInWindow?.storageToken ?? '',
      _tenurePreference?.storageToken ?? '',
      _furnishingPreference?.storageToken ?? '',
      _propertyTypePreference?.storageToken ?? '',
      _bathroomPreference?.storageToken ?? '',
      '$_familyAdults',
      '$_familyChildren',
      ProfileData.text(session['food_preference']),
      ProfileData.text(session['schedule_type']),
      ProfileData.text(session['commute_destination']),
      ProfileData.text(session['commute_destination_hub_id']),
      session['commute_destination_unknown']?.toString() ?? '',
      ProfileData.text(session['dual_commute_priority']),
      session['maximum_commute_budget_minutes']?.toString() ?? '',
      ProfileData.text(session['commute_method']),
      ProfileData.text(session['mother_tongue']),
      languages.join(','),
      preferred.join(','),
    ].join('|');
  }

  Widget _buildPassportPreviewPane() {
    // #region agent log
    agentLog(
      'H4',
      'profile_edit_screen.dart:_buildPassportPreviewPane',
      'passport preview pane build',
      {'currentPage': _currentPage},
    );
    // #endregion

    final session = _passportPreviewSession();
    final snapshot = ContextualPassportSnapshot.fromSession(session);
    // Fill the right Row cell completely — border height == left column height.
    return DecoratedBox(
      decoration: SeekerOnboardingLayout.passportPanelDecoration(),
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.all(OnboardingTokens.space16),
          child: ContextualPassportCard(
            key: ValueKey(_passportPreviewFingerprint()),
            snapshot: snapshot,
            omitOuterFrame: true,
            useOnboardingSeekerPreview: true,
            flatOnboardingStyle: true,
            showHeaderCaption: true,
            headerCaption: 'YOUR PUBLIC PASSPORT',
          ),
        ),
      ),
    );
  }

  void _hydrateCommutersFromProfile(Map<String, dynamic> profile) {
    final fallback = profile['maximum_commute_budget_minutes'];
    final fallbackMinutes = fallback is num && fallback > 0
        ? fallback.toDouble()
        : _maxCommuteBudgetMinutes;

    final rawProfiles = profile['commute_profiles'];
    final perProfileMax = profile['commute_profile_max_minutes'];
    _commuterDrafts.clear();

    if (rawProfiles is List && rawProfiles.isNotEmpty) {
      // One destination only — take the first resolvable hub.
      for (final item in rawProfiles) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final hub = DublinCommuterHubs.byId(
              map['commute_destination_hub_id']?.toString(),
            ) ??
            DublinCommuterHubs.resolveFromProfile(map);
        if (hub == null) continue;

        final maxRaw = map['max_commute_minutes'] ??
            (perProfileMax is Map
                ? perProfileMax[ProfileData.text(map['id'])]
                : null) ??
            fallbackMinutes;

        _commuterDrafts.add(
          _CommuterDraftEntry(
            methodLabel: CommuteMethod.fromBackend(
              ProfileData.text(map['commute_method']),
            ).toDisplayLabel(),
            hub: hub,
            maxCommuteMinutes: maxRaw is num
                ? maxRaw.toDouble()
                : double.tryParse(ProfileData.text(maxRaw)) ??
                    fallbackMinutes,
          ),
        );
        break;
      }
    } else {
      final profiles = CommuteProfileRegistry.fromSession(profile);
      if (profiles.isNotEmpty) {
        final entry = profiles.first;
        _commuterDrafts.add(
          _CommuterDraftEntry(
            methodLabel: entry.method.toDisplayLabel(),
            hub: entry.hub,
            maxCommuteMinutes: fallbackMinutes,
          ),
        );
      } else {
        _commuterDrafts.add(
          _CommuterDraftEntry(
            methodLabel: ProfileCommuteOptions.hydrateMethod(profile),
            hub: DublinCommuterHubs.resolveFromProfile(profile),
            maxCommuteMinutes: fallbackMinutes,
          ),
        );
      }
    }
    _syncCommuterDraftSlots();
  }

  void _syncCommuterDraftSlots() {
    final target = _commuterSlotCount;
    while (_commuterDrafts.length < target) {
      _commuterDrafts.add(_CommuterDraftEntry());
    }
    while (_commuterDrafts.length > target) {
      _commuterDrafts.removeLast();
    }
  }

  void _togglePreferredSpokenLanguage(String language) {
    setState(() {
      if (_preferredSpokenLanguages.contains(language)) {
        _preferredSpokenLanguages.remove(language);
      } else {
        _preferredSpokenLanguages.add(language);
      }
    });
  }

  void _ensurePreferredSpokenLanguagesSeeded() {
    if (_preferredSpokenLanguages.isNotEmpty) return;
    for (final language in _dedupedSpokenLanguages()) {
      if (!_preferredSpokenLanguages.contains(language)) {
        _preferredSpokenLanguages.add(language);
      }
    }
  }

  List<String> get _roommateLanguageChipOptions {
    final seen = <String>{};
    final ordered = <String>[];
    for (final language in [
      ..._dedupedSpokenLanguages(),
      ..._preferredSpokenLanguages,
    ]) {
      final token = language.trim();
      if (token.isEmpty) continue;
      if (seen.add(token.toLowerCase())) ordered.add(token);
    }
    return ordered;
  }

  void _syncPreferredRoommateLanguagesFromIdentity() {
    for (final language in _dedupedSpokenLanguages()) {
      final exists = _preferredSpokenLanguages.any(
        (existing) => existing.toLowerCase() == language.toLowerCase(),
      );
      if (!exists) _preferredSpokenLanguages.add(language);
    }
  }

  Future<void> _showAddRoommateLanguageSheet() async {
    final controller = TextEditingController();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        var filtered = IrelandLanguageCatalog.all
            .where(
              (language) => !_roommateLanguageChipOptions.any(
                (existing) =>
                    existing.toLowerCase() == language.toLowerCase(),
              ),
            )
            .toList();

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void applyFilter(String query) {
              setSheetState(() {
                filtered = IrelandLanguageCatalog.filterByQuery(query)
                    .where(
                      (language) => !_roommateLanguageChipOptions.any(
                        (existing) =>
                            existing.toLowerCase() == language.toLowerCase(),
                      ),
                    )
                    .toList();
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Add roommate language',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: OnboardingTokens.inputDecoration(
                      hint: 'Search languages…',
                    ),
                    onChanged: applyFilter,
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final language = filtered[index];
                        return ListTile(
                          title: Text(language),
                          onTap: () => Navigator.pop(ctx, language),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    controller.dispose();
    if (selected == null || selected.trim().isEmpty || !mounted) return;
    setState(() {
      if (!_preferredSpokenLanguages.contains(selected)) {
        _preferredSpokenLanguages.add(selected);
      }
    });
  }

  Map<String, dynamic> _commutePayloadFields() {
    final whoseDestination = _partnerCommuteEnabled &&
            _dualCommutePriority == DualCommutePriority.personB
        ? 'person_b'
        : 'person_a';

    if (_commuteDestinationUnknown) {
      return {
        'commute_destination_unknown': true,
        'commute_destination': '',
        'primary_commute_destination': '',
        'commute_destination_hub_id': '',
        'destination_latitude': null,
        'destination_longitude': null,
        'commute_profiles': <Map<String, dynamic>>[],
        // Labeling only — not dual-commute optimization.
        'dual_commute_priority': whoseDestination,
        'household_commuters_count': _householdCommutersCount,
      };
    }

    final draft =
        _commuterDrafts.isNotEmpty ? _commuterDrafts.first : null;
    final hub = draft?.hub;
    if (hub == null) {
      return {
        'commute_destination_unknown': false,
        'commute_destination': '',
        'primary_commute_destination': '',
        'commute_destination_hub_id': '',
        'destination_latitude': null,
        'destination_longitude': null,
        'commute_profiles': <Map<String, dynamic>>[],
        'dual_commute_priority': whoseDestination,
        'household_commuters_count': _householdCommutersCount,
      };
    }

    final maxMinutes = draft!.maxCommuteMinutes.round();
    final method = CommuteMethod.fromDisplayLabel(draft.methodLabel);
    final entry = CommuteProfileEntry(
      id: CommuteProfileRegistry.primaryId,
      label: 'Commuter 1',
      method: method,
      hub: hub,
    );
    final profileMap = {
      ...entry.toMap(),
      'max_commute_minutes': maxMinutes,
    };

    return {
      'commute_destination_unknown': false,
      'maximum_commute_budget_minutes': maxMinutes,
      // person_a / person_b = whose destination was entered (labeling only).
      'dual_commute_priority': whoseDestination,
      'household_commuters_count': _householdCommutersCount,
      'commute_profile_max_minutes': {
        CommuteProfileRegistry.primaryId: maxMinutes,
      },
      'commute_method': method.toBackend(),
      ...DublinCommuterHubs.persistFields(hub),
      'commute_profiles': [profileMap],
    };
  }

  Map<String, dynamic> _sharedRoomPayloadFields() {
    final leaseToken = switch (_tenurePreference) {
      TenurePreference.temporary => 'temporary',
      TenurePreference.longTerm || TenurePreference.flexible => 'long_term',
      null => null,
    };
    final moveInIso = _moveInDate == null
        ? null
        : '${_moveInDate!.year.toString().padLeft(4, '0')}-'
            '${_moveInDate!.month.toString().padLeft(2, '0')}-'
            '${_moveInDate!.day.toString().padLeft(2, '0')}';
    final derivedWindow = _moveInDate == null
        ? null
        : _deriveMoveInWindowFromDate(_moveInDate!);

    return {
      if (_hasSetFoodPreference)
        'food_preference':
            ProfileSeekerPreferences.sharedFoodToBackend(_sharedFoodPref),
      if (_preferredSpokenLanguages.isNotEmpty) ...{
        'preferred_spoken_languages':
            List<String>.from(_preferredSpokenLanguages),
        'preferred_spoken_languages_csv':
            _preferredSpokenLanguages.join(', '),
      },
      if (_lookingWith != null) 'looking_with': _lookingWith,
      if (_groupComposition != null) 'group_composition': _groupComposition,
      if (_friendCount != null) 'friend_count': _friendCount,
      if (_roomArrangement != null) 'room_arrangement': _roomArrangement,
      if (_smokingStatus != null) 'smoking_status': _smokingStatus,
      if (_petType != null) 'pet_type': _petType,
      if (_parkingNeed != null) 'parking_need': _parkingNeed,
      if (_transportMode != null) 'transport_mode': _transportMode,
      if (moveInIso != null) 'move_in_date': moveInIso,
      if (derivedWindow != null) ...{
        'move_in_window': derivedWindow.storageToken,
        'move_in_timing_version': 2,
      },
      if (_sharedRoomPreference != null)
        'preferred_layout': _sharedRoomPreference,
      if (leaseToken != null) ...{
        'lease_preference': leaseToken,
        TenurePreference.sessionKey: leaseToken,
      },
      if (_preferredLeaseMonths != null) ...{
        'preferred_lease_months': _preferredLeaseMonths,
        'lease_duration': _preferredLeaseMonths,
      },
      if (_bathroomPreference != null)
        BathroomPreference.sessionKey: _bathroomPreference!.storageToken,
    };
  }

  SeekerMoveInWindow _deriveMoveInWindowFromDate(DateTime date) {
    final today = DateTime.now();
    final endThisMonth = DateTime(today.year, today.month + 1, 0);
    final endNextMonth = DateTime(today.year, today.month + 2, 0);
    final day = DateTime(date.year, date.month, date.day);
    if (!day.isAfter(endThisMonth)) return SeekerMoveInWindow.thisMonth;
    if (!day.isAfter(endNextMonth)) return SeekerMoveInWindow.nextMonth;
    return SeekerMoveInWindow.within3Months;
  }

  void _setSharedMoveInDate(DateTime date) {
    setState(() {
      _moveInDate = DateTime(date.year, date.month, date.day);
      _hasSetMoveInWindow = true;
      _moveInWindow = _deriveMoveInWindowFromDate(_moveInDate!);
    });
  }

  void _setLookingWith(String value) {
    setState(() {
      _lookingWith = value;
      if (value == 'just_me') {
        _friendCount = null;
        _roomArrangement = null;
        if (_groupComposition == 'mixed') _groupComposition = null;
        _setPartnerCommuteEnabled(false);
        _groupSize = 1;
      } else if (value == 'partner') {
        _friendCount = null;
        _roomArrangement = null;
        if (_groupComposition == 'prefer_not') _groupComposition = null;
        _setPartnerCommuteEnabled(true);
        _groupSize = 2;
      } else if (value == 'friends') {
        _setPartnerCommuteEnabled(false);
        if (_groupComposition == 'prefer_not') _groupComposition = null;
        if (_friendCount == 'one') {
          _groupSize = 2;
          _roomArrangement = null;
        } else if (_friendCount == 'two_plus') {
          _groupSize = 3;
        }
      }
    });
  }

  void _setSmokingStatus(String value) {
    setState(() {
      _smokingStatus = value;
      _smokingOk = value != 'non_smoker';
      _householdSmoker = value == 'smoker';
    });
  }

  void _setPetType(String value) {
    setState(() {
      _petType = value;
      _householdHasPets = value != 'none';
    });
  }

  void _setTransportMode(String mode) {
    setState(() {
      _transportMode = mode;
      _commuteMethodUserOverridden = true;
      _ensurePrimaryCommuterDraft();
      final method = mode == 'driving'
          ? CommuteMethod.driving
          : CommuteMethod.publicTransportWalking;
      _commuterDrafts.first.methodLabel = method.toDisplayLabel();
      if (mode == 'driving') {
        _parkingNeed = 'required';
      }
    });
  }

  void _toggleTargetSearchArea(String token) {
    setState(() {
      if (_selectedTargetSearchAreas.contains(token)) {
        _selectedTargetSearchAreas.remove(token);
      } else {
        _selectedTargetSearchAreas.add(token);
      }
    });
  }

  String? _hydrateToken(dynamic raw, Set<String> allowed) {
    final token = ProfileData.text(raw).trim().toLowerCase();
    if (token.isEmpty || !allowed.contains(token)) return null;
    return token;
  }

  String _resolvedCity() {
    if (_onboardingIntent == OnboardingUserIntent.provider) {
      return '';
    }
    if (MarketConfig.current.profileUseAreaPicker && _selectedAreaKey != null) {
      for (final (key, label) in MarketConfig.current.areaOptions) {
        if (key == _selectedAreaKey) return label;
      }
    }
    return _formatLocationDisplay(_locationController.text.trim());
  }

  String? get _composedContactPhoneE164 => PhoneE164.compose(
        countryCode: _phoneCountryCode,
        national: _contactPhoneController.text,
      );

  String _resolvedPropertyNeighborhood() {
    if (_hidePropertyExactAddress && _selectedPropertyAddress != null) {
      return _selectedPropertyAddress!.publicLocationLabel;
    }
    final identifier = _propertyLocationIdentifierController.text.trim();
    if (identifier.isNotEmpty) return _formatLocationDisplay(identifier);
    if (_selectedPropertyAddress != null) {
      return _formatLocationDisplay(_selectedPropertyAddress!.area);
    }
    if (MarketConfig.current.profileUseAreaPicker && _providerAreaKey != null) {
      for (final (key, label) in MarketConfig.current.areaOptions) {
        if (key == _providerAreaKey) return label;
      }
    }
    return _formatLocationDisplay(_propertyLocationController.text.trim());
  }

  void _onPropertyAddressSelected(IrishAddressSuggestion suggestion) {
    setState(() {
      _selectedPropertyAddress = suggestion;
      _propertyLocationIdentifierController.text = suggestion.streetLine;
      _propertyLocationController.text = suggestion.area;
      if (suggestion.eircode != null) {
        _propertyEircodeController.text = suggestion.eircode!;
      }
    });
  }

  Future<void> _usePropertyCurrentLocation() async {
    if (_fetchingPropertyLocation) return;
    setState(() => _fetchingPropertyLocation = true);
    try {
      final resolved = await FastLocationService.resolve();
      if (resolved == null || !mounted) return;
      final suggestion = await EircodeLookupService.resolveFromCoordinates(
        resolved.latitude,
        resolved.longitude,
      );
      if (!mounted) return;
      if (suggestion == null) return;
      setState(() {
        _selectedPropertyAddress = suggestion;
        _propertyLocationController.text = suggestion.area;
        if (suggestion.eircode != null) {
          _propertyEircodeController.text =
              EircodeGeocodingService.normalize(suggestion.eircode!);
        }
      });
    } finally {
      if (mounted) setState(() => _fetchingPropertyLocation = false);
    }
  }

  bool _providerLocationIsSet() {
    if (_selectedPropertyAddress != null) return true;
    final eircode = EircodeGeocodingService.normalize(
      _propertyEircodeController.text,
    );
    if (eircode.isNotEmpty) return true;
    if (_propertyLocationIdentifierController.text.trim().length >= 2) {
      return true;
    }
    if (MarketConfig.current.profileUseAreaPicker && _providerAreaKey != null) {
      return true;
    }
    return _resolvedPropertyNeighborhood().length >= 2;
  }

  String get _providerLocationSelectValue {
    if (!MarketConfig.current.profileUseAreaPicker) {
      return _formatLocationDisplay(_propertyLocationController.text.trim());
    }
    final key = _providerAreaKey ?? MarketConfig.current.defaultAreaKey;
    for (final (areaKey, label) in MarketConfig.current.areaOptions) {
      if (areaKey == key) return label;
    }
    return _formatLocationDisplay(
      dublinDistrictLabelForKey(key) ??
          MarketConfig.current.defaultAreaDisplayName,
    );
  }

  String _formatLocationDisplay(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;

    final fromKey = dublinDistrictLabelForKey(trimmed.toLowerCase());
    if (fromKey != null) return fromKey;

    final numbered = RegExp(r'^dublin[\s_-]?(\d+[w]?)$', caseSensitive: false)
        .firstMatch(trimmed);
    if (numbered != null) {
      return 'Dublin ${numbered.group(1)!.toUpperCase()}';
    }

    return trimmed
        .split(RegExp(r'[\s_-]+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  void _syncChildrenAgesList() {
    if (_childrenAges.length < _familyChildren) {
      _childrenAges.addAll(
        List.generate(
          _familyChildren - _childrenAges.length,
          (_) => _childrenAgeOptions.first,
        ),
      );
    } else if (_childrenAges.length > _familyChildren) {
      _childrenAges = _childrenAges.sublist(0, _familyChildren);
    }
  }

  Map<String, dynamic> _spokenLanguageSessionFields() {
    final languages = _onboardingIntent == OnboardingUserIntent.seeker
        ? _seekerSpokenLanguagesForPayload()
        : _selectedLanguages;
    final entries = [
      for (final language in languages)
        SpokenLanguageEntry(
          language: language,
          isNative: _onboardingIntent == OnboardingUserIntent.seeker
              ? false
              : language == _selectedMotherTongue ||
                  (_languageNativeFlags[language] ?? false),
        ),
    ];

    return SpokenLanguageProfileCodec.toSessionFields(
      entries: entries,
      // Seekers: English is assumed communication baseline — not stored.
      motherTongue: _onboardingIntent == OnboardingUserIntent.seeker
          ? ''
          : _selectedMotherTongue,
    );
  }

  ProfileInheritanceSnapshot _buildTrackSnapshot() {
    if (_onboardingIntent == OnboardingUserIntent.provider) {
      return ProfileInheritanceSnapshot(
        track: _selectedTrack,
        identityProfile: IdentityProfile(
          email: _emailController.text.trim(),
          fullName: _nameController.text.trim(),
        ),
        seekerProfile: const SeekerProfile(),
        hostProfile: const HostProfile(),
        listingSeed: ListingSeed(
          listingMode:
              _selectedTrack.isSharedSpace ? 'shared_space' : 'entire_place',
        ),
      );
    }

    final hostLanguages = _dedupedSpokenLanguages();
    final seekerBudget = int.tryParse(_budgetMaxController.text.trim());
    final hostHousehold = <String, dynamic>{
      if (_providerHousemateCount > 0) 'current_occupants': _providerHousemateCount,
      if (_selectedOccupantType != null) 'occupant_type': _selectedOccupantType,
      if (_groupSize > 0) 'group_size': _groupSize,
    };

    return ProfileInheritanceSnapshot(
      track: _selectedTrack,
      identityProfile: IdentityProfile(
        email: _emailController.text.trim(),
        fullName: _nameController.text.trim(),
        companyName: _agencyController.text.trim(),
        contactPhone: _contactPhoneController.text.trim(),
        motherTongue: _selectedMotherTongue,
        languages: hostLanguages,
      ),
      seekerProfile: SeekerProfile(
        maxBudget: _selectedTrack == ProfileOnboardingTrack.seekerEntirePlace
            ? seekerBudget
            : null,
        roomBudget: _selectedTrack == ProfileOnboardingTrack.seekerSharedSpace
            ? seekerBudget
            : null,
        moveInWindow: _moveInWindow?.storageToken ?? '',
        preferredLeaseMonths: _preferredLeaseMonths,
        occupantGroupFit:
            _seekerPersona?.occupantType ?? _resolvedOccupantType,
        // Display Only — not used in matching or scoring (V1)
        genderPreferences: _selectedGenderPref ?? '',
        wfhStatus: _scheduleType == null || _scheduleType == 'Flexible',
        environmentPreferences: [
          if (_householdHasPets) 'Pets in household',
          if (_householdSmoker) 'Smoker in household',
        ],
        primaryCommute: _commuterDrafts.isNotEmpty && _commuterDrafts.first.hub != null
            ? {
                'commute_method': CommuteMethod.fromDisplayLabel(
                  _commuterDrafts.first.methodLabel,
                ).toBackend(),
                'commute_destination_hub_id': _commuterDrafts.first.hub!.id,
                'commute_destination': _commuterDrafts.first.hub!.label,
                'max_commute_minutes':
                    _commuterDrafts.first.maxCommuteMinutes.round(),
              }
            : const {},
        secondaryCommute: const {},
      ),
      hostProfile: HostProfile(
        languages: hostLanguages,
        currentHouseholdMakeup: hostHousehold,
        isOwnerOccupier: _providerIsOwnerOccupier,
        houseRules: _providerHouseRules.toList(),
      ),
      listingSeed: ListingSeed(
        propertyNeighborhood: _resolvedPropertyNeighborhood(),
        propertyEircode:
            EircodeGeocodingService.normalize(_propertyEircodeController.text),
        isFurnished: _providerIsFurnished,
        listingMode: _selectedTrack.isSharedSpace ? 'shared_space' : 'entire_place',
        currentHouseholdMakeup: hostHousehold,
        houseRules: _providerHouseRules.toList(),
      ),
    );
  }

  void _applyMotherTongueInference(String motherTongue) {
    final inferred = OnboardingLanguageInference.companionsFor(motherTongue);
    _selectedLanguages.clear();
    _selectedLanguages.addAll(inferred);
    _languageNativeFlags.clear();
    for (final language in inferred) {
      _languageNativeFlags[language] =
          language.toLowerCase() == motherTongue.toLowerCase();
    }
    _languageNativeFlags[motherTongue] = true;
  }

  void _onMotherTongueChanged(String value) {
    setState(() {
      _selectedMotherTongue = value;
      _applyMotherTongueInference(value);
    });
  }

  void _removeSpokenLanguage(String language) {
    if (_selectedLanguages.length <= 1) return;
    setState(() {
      _selectedLanguages.removeWhere(
        (l) => l.toLowerCase() == language.toLowerCase(),
      );
      _languageNativeFlags.remove(language);
      if (language.toLowerCase() == _selectedMotherTongue.toLowerCase()) {
        _selectedMotherTongue = _selectedLanguages.first;
        _languageNativeFlags[_selectedMotherTongue] = true;
      }
    });
  }

  void _addSpokenLanguage(String language) {
    final token = language.trim();
    if (token.isEmpty) return;
    if (_selectedLanguages
        .any((l) => l.toLowerCase() == token.toLowerCase())) {
      return;
    }
    setState(() => _selectedLanguages.add(token));
  }

  bool _validatePage1() {
    if (_onboardingIntent == OnboardingUserIntent.provider) {
      if (_nameController.text.trim().isEmpty) {
        _showMessage('Please enter your full name.');
        return false;
      }
      return true;
    }
    if (_emailController.text.trim().isEmpty) {
      _showMessage('Please enter your email.');
      return false;
    }
    if (_nameController.text.trim().isEmpty) {
      _showMessage('Please enter your full name.');
      return false;
    }
    return true;
  }

  bool _validateSeekerBasics() {
    if (_emailController.text.trim().isEmpty) {
      _showMessage('Please enter your email.');
      return false;
    }
    if (!onboardingEmailRegex.hasMatch(_emailController.text.trim())) {
      _showMessage('Please enter a valid email address.');
      return false;
    }
    if (_nameController.text.trim().isEmpty) {
      _showMessage('Please enter your full name.');
      return false;
    }
    if (_seekerPersona == null) {
      _showMessage('Select what best describes you.');
      return false;
    }
    if (_isSharedTrack) {
      if (_lookingWith == null) {
        _showMessage('Select who you are looking with.');
        return false;
      }
      if (_groupComposition == null) {
        _showMessage(
          _lookingWith == 'partner'
              ? 'Select who is looking.'
              : _lookingWith == 'friends'
                  ? 'Select group composition.'
                  : 'Select your gender.',
        );
        return false;
      }
      if (_lookingWith == 'friends' && _friendCount == null) {
        _showMessage('Select how many friends.');
        return false;
      }
      if (_lookingWith == 'friends' &&
          _friendCount == 'two_plus' &&
          _roomArrangement == null) {
        _showMessage('Select room arrangement.');
        return false;
      }
      if (_sharedRoomPreference == null) {
        _showMessage('Select room preference.');
        return false;
      }
      if (_tenurePreference == null ||
          _tenurePreference == TenurePreference.flexible) {
        _showMessage('Select lease preference.');
        return false;
      }
      if (_tenurePreference == TenurePreference.temporary &&
          _preferredLeaseMonths == null) {
        _showMessage('Select lease duration.');
        return false;
      }
      return true;
    }
    return true;
  }

  bool _validateSeekerPreferences() {
    if (_isSharedTrack) {
      if (_selectedMotherTongue.trim().isEmpty ||
          _selectedMotherTongue.trim().toLowerCase() == 'english') {
        _showMessage('Select your additional primary language.');
        return false;
      }
      if (_smokingStatus == null) {
        _showMessage('Select smoking status.');
        return false;
      }
      if (_petType == null) {
        _showMessage('Select pets preference.');
        return false;
      }
      if (_bathroomPreference == null) {
        _showMessage('Select your bathroom preference.');
        return false;
      }
      return true;
    }
    final budget = int.tryParse(_budgetMaxController.text.trim());
    if (budget == null || budget <= 0) {
      _showMessage('Enter your maximum monthly budget.');
      return false;
    }
    if (_dublinLocationContext == null) {
      _showMessage(
        'Tell us whether you are already living in Dublin or moving to Dublin.',
      );
      return false;
    }
    if (!_hasSetMoveInWindow || _moveInWindow == null) {
      _showMessage('Select when you want to move in.');
      return false;
    }
    if (_tenurePreference == null) {
      _showMessage('Select how long you plan to stay.');
      return false;
    }
    if (_furnishingPreference == null) {
      _showMessage('Select your furnishing preference.');
      return false;
    }
    if (_propertyTypePreference == null) {
      _showMessage('Select your property type preference.');
      return false;
    }
    if (_bathroomPreference == null) {
      _showMessage('Select your bathroom preference.');
      return false;
    }
    return true;
  }

  bool _validateSeekerSharedSearch() {
    final budget = int.tryParse(_budgetMaxController.text.trim());
    if (budget == null || budget <= 0) {
      _showMessage('Enter your maximum monthly budget.');
      return false;
    }
    if (_moveInDate == null) {
      _showMessage('Select your move-in date.');
      return false;
    }
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (_moveInDate!.isBefore(todayOnly)) {
      _showMessage('Move-in date must be today or later.');
      return false;
    }
    if (!_destinationValid) {
      _showMessage(
        'Choose a destination preset or enter a custom destination.',
      );
      return false;
    }
    _commuteDestinationUnknown = false;
    if (_transportMode == null) {
      _showMessage('Select how you will commute.');
      return false;
    }
    if (_dublinLocationContext == null) {
      _showMessage('Tell us where you are based.');
      return false;
    }
    if (_seekerPersona?.requiresGuarantorQuestion == true &&
        _selectedFinancialSupportType == null) {
      _showMessage('Select how you will fund your rent.');
      return false;
    }
    if (_seekerPersona?.requiresGuarantorQuestion == true &&
        _guarantorStatus == null) {
      _showMessage('Let us know about your guarantor status.');
      return false;
    }
    return true;
  }

  /// My ↔ Partner owner change clears destination; Save stays gated until re-pick.
  void _onDestinationOwnerChanged(bool mine) {
    final next = mine
        ? DualCommutePriority.personA
        : DualCommutePriority.personB;
    if (next == _dualCommutePriority) return;
    setState(() {
      _dualCommutePriority = next;
      _commuteDestinationUnknown = false;
      _ensurePrimaryCommuterDraft();
      _commuterDrafts.first.hub = null;
      _destinationFieldResetToken++;
    });
  }

  /// Preset or resolved custom hub only — not typed text / legacy unknown.
  bool get _destinationValid => isSeekerDestinationValid(
        commuteDestinationUnknown: _commuteDestinationUnknown,
        hub: _commuterDrafts.isNotEmpty ? _commuterDrafts.first.hub : null,
      );

  bool _validateSeekerDestination() {
    if (!_destinationValid) {
      _showMessage(
        'Choose a destination preset or enter a custom destination.',
      );
      return false;
    }
    // Destination is required — clear any legacy "unknown" flag once a hub exists.
    _commuteDestinationUnknown = false;
    if (_seekerPersona?.requiresGuarantorQuestion == true &&
        _selectedFinancialSupportType == null) {
      _showMessage('Select how you will fund your rent.');
      return false;
    }
    if (_seekerPersona?.requiresGuarantorQuestion == true &&
        _guarantorStatus == null) {
      _showMessage('Let us know about your guarantor status.');
      return false;
    }
    return true;
  }

  void _setMoveInWindow(SeekerMoveInWindow window) {
    setState(() {
      _hasSetMoveInWindow = true;
      _moveInWindow = window;
    });
  }

  void _selectSeekerEntirePlace() {
    setState(() {
      preferredArrangement = ProfileSeekerPreferences.entirePlaceLabel;
      _familySharedLivingTip = null;
      _setPartnerCommuteEnabled(false);
      if (_currentPage >= _pageCount) {
        _currentPage = _pageCount - 1;
      }
    });
  }

  void _selectSeekerSharedSpace() {
    setState(() {
      if (_seekerPersona == SeekerPersona.family) {
        preferredArrangement = ProfileSeekerPreferences.entirePlaceLabel;
        _familySharedLivingTip = _familySharedLivingTipMessage;
      } else {
        preferredArrangement = ProfileSeekerPreferences.sharedRoomLabel;
        _familySharedLivingTip = null;
      }
      if (_currentPage >= _pageCount) {
        _currentPage = _pageCount - 1;
      }
    });
  }

  void _onSeekerStepTap(int step) {
    if (step >= _currentPage) return;
    _goToPage(step);
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _pageCount) return;
    setState(() {
      _pageTransitionDirection = page > _currentPage ? 1 : -1;
      _currentPage = page;
      if (page == 2) {
        _ensurePrimaryCommuterDraft();
        _applyDefaultCommuteMethodIfNeeded();
      }
    });
  }

  void _applySeekerPersona(SeekerPersona persona) {
    setState(() {
      _seekerPersona = persona;
      _selectedOccupantType = persona.occupantType;
      if (!persona.requiresGuarantorQuestion) {
        _guarantorStatus = null;
        _selectedFinancialSupportType = null;
      } else {
        _guarantorStatus ??= GuarantorStatus.notSureYet;
        // Financial support must be chosen explicitly — never silent-default.
      }
      if (persona == SeekerPersona.family &&
          ProfileSeekerPreferences.isSharedRoom(preferredArrangement)) {
        preferredArrangement = ProfileSeekerPreferences.entirePlaceLabel;
        _familySharedLivingTip = _familySharedLivingTipMessage;
      } else if (persona != SeekerPersona.family) {
        _familySharedLivingTip = null;
      }
      if (persona != SeekerPersona.professional &&
          persona != SeekerPersona.family) {
        _setPartnerCommuteEnabled(false);
      }
      _applyDefaultCommuteMethodIfNeeded();
    });
  }

  Map<String, dynamic> _seekerPersonaPayloadFields() {
    final persona = _seekerPersona;
    if (persona == null) return {};
    return {
      'seeker_persona': persona.storageToken,
      'occupant_type': persona.occupantType,
      if (persona == SeekerPersona.student &&
          _selectedFinancialSupportType != null)
        FinancialSupportType.storageKey: _selectedFinancialSupportType,
    };
  }

  void _onOnboardingBack() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  String get _onboardingBackTooltip => switch (_currentPage) {
        0 => 'Exit profile setup',
        1 => 'Back to basics',
        2 => _isSharedTrack ? 'Back to profile' : 'Back to preferences',
        3 => 'Back to search',
        _ => 'Back',
      };

  bool _validate() {
    if (_onboardingIntent == OnboardingUserIntent.seeker) {
      if (_isSharedTrack) {
        return _validateSeekerBasics() &&
            _validateSeekerPreferences() &&
            _validateSeekerSharedSearch();
      }
      return _validateSeekerBasics() &&
          _validateSeekerPreferences() &&
          _validateSeekerDestination();
    }
    if (_onboardingIntent == OnboardingUserIntent.provider) {
      if (_nameController.text.trim().isEmpty) {
        _showMessage('Please enter your full name.');
        return false;
      }
      return true;
    }
    if (_emailController.text.trim().isEmpty) {
      _showMessage('Please enter your email.');
      return false;
    }
    if (_nameController.text.trim().isEmpty) {
      _showMessage('Please enter your full name.');
      return false;
    }
    if (_hasHapVoucher) {
      final contribution = double.tryParse(
        _hapVoucherContributionController.text.trim(),
      );
      if (contribution == null) {
        _showMessage('Enter your monthly HAP contribution in EUR.');
        return false;
      }
      final hapError = DublinHapContributionValidator.validateContribution(
        session: _draftSession(),
        contributionEur: contribution,
        upliftApproved: _hapUpliftApproved,
      );
      if (hapError != null) {
        _showMessage(hapError);
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> _seekerLocationPayloadFields() {
    final context = _dublinLocationContext;
    if (context == DublinLocationContext.alreadyInDublin) {
      return {
        'dublin_location_context':
            DublinLocationContext.alreadyInDublin.storageToken,
        'detected_city': 'Dublin',
        'pre_arrival_seeker': false,
      };
    }
    if (context == DublinLocationContext.arrivingSoon) {
      return {
        'dublin_location_context':
            DublinLocationContext.arrivingSoon.storageToken,
        'pre_arrival_seeker': true,
      };
    }
    if (context == DublinLocationContext.relocating) {
      return {
        'dublin_location_context':
            DublinLocationContext.relocating.storageToken,
        'pre_arrival_seeker': true,
      };
    }
    return {};
  }

  Map<String, dynamic> _targetSearchAreasPayloadFields() {
    final macros = TargetSearchAreas.normalizeMacroTokens(
      List<String>.from(_selectedTargetSearchAreas),
    );
    return {
      'target_search_areas': macros.isEmpty
          ? [TargetSearchAreas.allDublinToken]
          : macros,
    };
  }

  Map<String, dynamic> _guarantorPayloadFields() {
    if (_seekerPersona?.requiresGuarantorQuestion != true) {
      return {};
    }
    return switch (_guarantorStatus) {
      GuarantorStatus.yes => {
          'guarantor_status': 'yes',
          'has_guarantor': true,
          'has_verified_guarantor': false,
        },
      GuarantorStatus.no => {
          'guarantor_status': 'no',
          'has_guarantor': false,
        },
      GuarantorStatus.notSureYet => {
          'guarantor_status': 'not_sure_yet',
          'has_guarantor': false,
        },
      null => <String, dynamic>{},
    };
  }

  Map<String, dynamic> _moveInPayloadFields() {
    if (!_hasSetMoveInWindow || _moveInWindow == null) return {};
    return MoveInTimingMigration.seekerPayload(_moveInWindow!);
  }

  void _onSeekerPrimaryLanguageChanged(String value) {
    setState(() {
      _selectedMotherTongue = value;
      _languageNativeFlags[value] = true;
      _refreshSuggestedSecondaryLanguages(value);
      _syncSelectedLanguagesFromSeekerTiers();
    });
  }

  void _toggleSeekerSecondaryLanguage(String language) {
    setState(() {
      if (_selectedMotherTongue.toLowerCase() == language.toLowerCase()) {
        return;
      }
      if (language.toLowerCase() == 'english') return;
      final existing = _selectedSecondaryLanguages.where(
        (selected) => selected.toLowerCase() == language.toLowerCase(),
      );
      if (existing.isNotEmpty) {
        _selectedSecondaryLanguages.remove(existing.first);
      } else {
        _selectedSecondaryLanguages.add(language);
      }
      _syncSelectedLanguagesFromSeekerTiers();
    });
  }

  void _addSeekerSecondaryLanguage(String language) {
    setState(() {
      if (_selectedMotherTongue.toLowerCase() == language.toLowerCase()) {
        return;
      }
      if (language.toLowerCase() == 'english') return;
      final inSuggested = _suggestedSecondaryLanguages.any(
        (suggested) => suggested.toLowerCase() == language.toLowerCase(),
      );
      if (!inSuggested &&
          !_extraSecondaryLanguages.any(
            (extra) => extra.toLowerCase() == language.toLowerCase(),
          )) {
        _extraSecondaryLanguages.add(language);
      }
      _selectedSecondaryLanguages.add(language);
      _syncSelectedLanguagesFromSeekerTiers();
    });
  }

  Map<String, dynamic> _buildProviderOnboardingPayload() {
    final baseline = Map<String, dynamic>.from(
      _baselineProfile ?? AuthScreen.currentUserSession ?? {},
    );
    final listingMode =
        _selectedTrack.isSharedSpace ? 'shared_space' : 'entire_place';
    final fullName = _nameController.text.trim();

    var payload = {
      ...baseline,
      'full_name': fullName,
      'onboarding_intent': OnboardingUserIntent.provider.storageToken,
      'profile_onboarding_track': _selectedTrack.storageToken,
      'active_marketplace_space':
          MarketplaceContextNotifier.spaceFromOnboardingTrack(_selectedTrack)
              .storageToken,
      'host_profile_complete': true,
      'listingSeed_listingMode': listingMode,
      'identityProfile': {
        'email': ProfileData.text(baseline['email']),
        'fullName': fullName,
      },
      'listingSeed': {
        'listingMode': listingMode,
      },
    };
    return ApplicantSessionSync.enrich(payload);
  }

  Map<String, dynamic> _buildPayload() {
    final baseline = _baselineProfile ?? <String, dynamic>{};
    var payload = {
      ...baseline,
      'email': _emailController.text.trim(),
      'full_name': _nameController.text.trim(),
      'contact_phone': _contactPhoneController.text.trim(),
      if (_composedContactPhoneE164 != null)
        'contact_phone_e164': _composedContactPhoneE164,
      'prefers_whatsapp': _prefersWhatsapp,
      'active_marketplace_space':
          MarketplaceContextNotifier.spaceFromOnboardingTrack(_selectedTrack)
              .storageToken,
      if (_agencyController.text.trim().isNotEmpty)
        'agency_name': _agencyController.text.trim(),
      if (_onboardingIntent == OnboardingUserIntent.seeker)
        ..._seekerLocationPayloadFields()
      else
        'detected_city': _resolvedCity(),
      if (_onboardingIntent == OnboardingUserIntent.seeker)
        ..._targetSearchAreasPayloadFields(),
      ..._spokenLanguageSessionFields(),
      ..._commutePayloadFields(),
      if (_onboardingIntent == OnboardingUserIntent.seeker) ...{
        ..._seekerPersonaPayloadFields(),
        ..._guarantorPayloadFields(),
        ..._moveInPayloadFields(),
      },
      ...ProfileSeekerPreferences.persistFields(
        preferredArrangement: preferredArrangement,
        preferredLayout: _resolvedPreferredLayout,
      ),
      if (ProfileSeekerPreferences.isSharedRoom(preferredArrangement))
        ..._sharedRoomPayloadFields(),
      'occupant_type': _seekerPersona?.occupantType ?? _resolvedOccupantType,
      // Display Only — not used in matching or scoring (V1)
      if (_selectedGenderPref != null) 'gender_preference': _selectedGenderPref,
      if (_selectedFinancialSupportType != null)
        FinancialSupportType.storageKey: _selectedFinancialSupportType,
      if (_selectedOccupantType == 'Family' ||
          _seekerPersona == SeekerPersona.family) ...{
        'adults_count': _familyAdults,
        'children_count': _familyChildren,
        'family_adults': _familyAdults,
        'family_children': _familyChildren,
        if (_familyChildren > 0)
          'children_ages': List<String>.from(_childrenAges),
      },
      if (_selectedOccupantType == 'Working Professionals' ||
          _selectedOccupantType == 'Students')
        'group_size': _groupSize,
      if (ProfileSeekerPreferences.isSharedRoom(preferredArrangement)) ...{
        'smoking_ok': _smokingOk,
        'drinking_ok': _drinkingOk,
        if (_scheduleType != null) 'schedule_type': _scheduleType,
      } else ...{
        'smoking_ok': false,
        'drinking_ok': false,
        if (_tenurePreference != null)
          TenurePreference.sessionKey: TenurePreference.migrateIndependentPlace(
                _tenurePreference,
              )!
              .storageToken,
        if (_furnishingPreference != null)
          FurnishingPreference.sessionKey: _furnishingPreference!.storageToken,
        if (_propertyTypePreference != null)
          PropertyTypePreference.sessionKey:
              _propertyTypePreference!.storageToken,
      },
      if (_bathroomPreference != null)
        BathroomPreference.sessionKey: _bathroomPreference!.storageToken,
      if (_budgetMinController.text.trim().isNotEmpty)
        'budget_min': int.tryParse(_budgetMinController.text.trim()),
      if (_budgetMaxController.text.trim().isNotEmpty)
        'budget_max': int.tryParse(_budgetMaxController.text.trim()),
      if (_netMonthlyIncomeController.text.trim().isNotEmpty)
        'net_monthly_income':
            double.tryParse(_netMonthlyIncomeController.text.trim()),
      if (_partnerNetMonthlyIncomeController.text.trim().isNotEmpty)
        'partner_net_monthly_income':
            double.tryParse(_partnerNetMonthlyIncomeController.text.trim()),
      if (_preferredLeaseMonths != null)
        'preferred_lease_months': _preferredLeaseMonths,
      if (_hasSetMoveInWindow && _moveInWindow != null)
        ...MoveInTimingMigration.seekerPayload(_moveInWindow!),
      'has_hap_voucher': _hasHapVoucher,
      'hap_uplift_approved': _hapUpliftApproved,
      if (_hapVoucherContributionController.text.trim().isNotEmpty)
        'hap_voucher_contribution':
            double.tryParse(_hapVoucherContributionController.text.trim()),
      'has_verified_guarantor': _hasVerifiedGuarantor,
      'household_has_pets': _householdHasPets,
      'household_smoker': _householdSmoker,
      'onboarding_intent': _onboardingIntent.storageToken,
      UserRole.sessionKey: _onboardingIntent == OnboardingUserIntent.seeker
          ? UserRole.seeker.storageToken
          : UserRole.landlord.storageToken,
      'profile_onboarding_track': _selectedTrack.storageToken,
      if (_onboardingIntent == OnboardingUserIntent.provider)
        'listingSeed_listingMode':
            _selectedTrack.isSharedSpace ? 'shared_space' : 'entire_place',
    };
    payload.remove('kitchen_utility_preference');
    // Phase 4: persist financial_support_type only; drop legacy student_type.
    payload.remove(FinancialSupportType.legacyStorageKey);
    if (_seekerPersona != SeekerPersona.student) {
      payload.remove(FinancialSupportType.storageKey);
    }
    if (!ProfileSeekerPreferences.isSharedRoom(preferredArrangement)) {
      payload
        ..remove('kitchen_usage_timing')
        ..remove('food_preference')
        ..remove('schedule_type')
        ..remove('preferred_spoken_languages')
        ..remove('preferred_spoken_languages_csv')
        // Shared → Independent Place: strip Shared-only questionnaire keys.
        ..remove('looking_with')
        ..remove('group_composition')
        ..remove('friend_count')
        ..remove('room_arrangement')
        ..remove('smoking_status')
        ..remove('pet_type')
        ..remove('parking_need')
        ..remove('transport_mode')
        ..remove('lease_preference')
        ..remove('lease_duration')
        ..remove('preferred_lease_months')
        ..remove('move_in_date')
        ..remove('room_preference');
      // Independent Place: one profile / one destination.
      payload['household_commuters_count'] = 1;
      payload['dual_commute_priority'] = 'person_a';
      // Reset Shared-derived household signals so they cannot skew IP matching.
      payload['household_has_pets'] = false;
      payload['household_smoker'] = false;
      payload['group_size'] = 1;
    } else {
      // Shared Spaces: tenure is collected again — keep tenure_preference.
      payload
        ..remove(FurnishingPreference.sessionKey)
        ..remove(PropertyTypePreference.sessionKey);
    }
      if (_onboardingIntent == OnboardingUserIntent.seeker) {
      payload
        ..remove('pending_listing_location')
        ..remove('pending_listing_eircode')
        ..remove('partner_commute_method')
        ..remove('partner_commute_destination')
        ..remove('partner_commute_destination_hub_id')
        ..remove('partner_destination_latitude')
        ..remove('partner_destination_longitude');
    }
    payload.remove('native_place');
    payload = ProfileOnboardingRepository.applySnapshotToSession(
      payload,
      _buildTrackSnapshot(),
    );
    return ApplicantSessionSync.enrich(payload);
  }

  Future<void> _save() async {
    if (!_validate()) return;
    final synced = await AuthService.persistProfileSession(_buildPayload());
    if (!mounted) return;
    setState(() {
      _baselineProfile = Map<String, dynamic>.from(synced);
    });
    if (_onboardingIntent == OnboardingUserIntent.seeker) {
      await marketplaceContextNotifier.syncSpaceFromOnboardingTrack(
        _selectedTrack,
      );
      if (!mounted) return;
      _showMessage('Profile saved — welcome to your feed.');
      // Seeker "Save & find matches" always lands on browse — never /add-listing.
      context.go('/');
      return;
    }
    _showMessage('Profile updated.');
    context.go('/profile', extra: synced);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onOnboardingBack();
      },
      child: Scaffold(
      backgroundColor: OnboardingTokens.canvasBg,
      appBar: AppBar(
        backgroundColor: OnboardingTokens.canvasBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: Semantics(
          label: _onboardingBackTooltip,
          button: true,
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF0F172A),
            ),
            tooltip: _onboardingBackTooltip,
            onPressed: _onOnboardingBack,
          ),
        ),
        titleSpacing: 12,
        title: const Align(
          alignment: Alignment.centerLeft,
          child: TrueCircleHomeLogoButton(markSize: 26),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: OnboardingTokens.inputBorder,
          ),
        ),
      ),
      body: _hydrating
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2B4C7E)),
            )
          : SeekerOnboardingShell(
              progress: SeekerOnboardingStepTracker(
                current: _currentPage,
                onStepTap: _onSeekerStepTap,
                isSharedTrack: _isSharedTrack,
              ),
              leftBody: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final begin = _pageTransitionDirection >= 0
                      ? const Offset(0.06, 0)
                      : const Offset(-0.06, 0);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: begin,
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey('seeker-step-$_currentPage'),
                  child: _buildSeekerPage(_currentPage),
                ),
              ),
              leftFooter: _buildSeekerNavBar(),
              rightPane: _buildPassportPreviewPane(),
            ),
      ),
    );
  }

  Widget _buildSeekerNavBar() {
    final onLastStep = _currentPage == _pageCount - 1;
    return GamifiedFormNavBar(
      floating: false,
      compact: true,
      showBack: _currentPage > 0,
      showNext: _currentPage < _pageCount - 1,
      showSubmit: onLastStep,
      submitEnabled:
          !onLastStep || (_isSharedTrack ? true : _destinationValid),
      nextLabel: 'Continue →',
      submitLabel:
          _isSharedTrack ? 'Start Searching 🚀' : 'Save & find matches',
      onBack: () => _goToPage(_currentPage - 1),
      onNext: _handleSeekerNext,
      onSubmit: _save,
    );
  }

  void _handleSeekerNext() {
    if (_isSharedTrack) {
      switch (_currentPage) {
        case 0:
          if (_validateSeekerBasics()) _goToPage(1);
        case 1:
          if (_validateSeekerPreferences()) _goToPage(2);
        case 2:
          if (_validateSeekerSharedSearch()) _goToPage(3);
        default:
          break;
      }
      return;
    }
    switch (_currentPage) {
      case 0:
        if (_validateSeekerBasics()) _goToPage(1);
      case 1:
        if (!_validateSeekerPreferences()) return;
        _goToPage(2);
      default:
        break;
    }
  }

  Widget _buildSeekerPage(int page) {
    // #region agent log
    agentLog(
      page == 0 ? 'H3' : (page == 1 ? 'H2' : 'H5'),
      'profile_edit_screen.dart:_buildSeekerPage',
      'seeker page build',
      {'page': page, 'shared': _isSharedTrack},
    );
    // #endregion

    // Step 1 is one seamless Basics screen for both tracks.
    if (page == 0) {
      return SeekerOnboardingBasicsScreen(
        emailController: _emailController,
        nameController: _nameController,
        isSharedTrack: _isSharedTrack,
        onSelectEntirePlace: _selectSeekerEntirePlace,
        onSelectSharedSpace: _selectSeekerSharedSpace,
        persona: _seekerPersona,
        onPersonaChanged: _applySeekerPersona,
        familySharedLivingTip: _familySharedLivingTip,
        adultsCount: _familyAdults,
        childrenCount: _familyChildren,
        onAdultsCountChanged: (v) => setState(() => _familyAdults = v),
        onChildrenCountChanged: (v) => setState(() {
          _familyChildren = v;
          _syncChildrenAgesList();
        }),
        primaryLanguage: _selectedMotherTongue,
        onPrimaryLanguageChanged: _onSeekerPrimaryLanguageChanged,
        suggestedLanguages: _secondaryDisplayLanguages(),
        selectedSecondaryLanguages: _selectedSecondaryLanguages,
        onToggleSecondaryLanguage: _toggleSeekerSecondaryLanguage,
        onAddSecondaryLanguage: _addSeekerSecondaryLanguage,
        showSignedInAsCard: _showSignedInAsCard,
        lookingWith: _lookingWith,
        onLookingWithChanged: _setLookingWith,
        groupComposition: _groupComposition,
        onGroupCompositionChanged: (v) => setState(() => _groupComposition = v),
        friendCount: _friendCount,
        onFriendCountChanged: (v) => setState(() {
          _friendCount = v;
          if (v == 'one') {
            _roomArrangement = null;
            _groupSize = 2;
          } else {
            _groupSize = 3;
          }
        }),
        roomArrangement: _roomArrangement,
        onRoomArrangementChanged: (v) => setState(() => _roomArrangement = v),
        roomPreference: _sharedRoomPreference,
        onRoomPreferenceChanged: (v) => setState(() {
          _sharedRoomPreference = v;
          preferredLayout = v;
        }),
        leasePreference: _tenurePreference,
        onLeasePreferenceChanged: (v) => setState(() {
          _tenurePreference = v;
          if (v != TenurePreference.temporary) {
            _preferredLeaseMonths = null;
          }
        }),
        leaseDurationMonths: _preferredLeaseMonths,
        onLeaseDurationMonthsChanged: (v) =>
            setState(() => _preferredLeaseMonths = v),
      );
    }

    if (_isSharedTrack) {
      return _buildSharedSeekerPage(page);
    }

    switch (page) {
      case 1:
        return SeekerOnboardingPreferencesScreen(
          budgetController: _budgetMaxController,
          isSharedTrack: false,
          locationContext: _dublinLocationContext,
          onLocationContextChanged: (v) => setState(() {
            _dublinLocationContext = v;
            _applyDefaultCommuteMethodIfNeeded();
          }),
          moveInWindow: _hasSetMoveInWindow ? _moveInWindow : null,
          onMoveInWindowChanged: _setMoveInWindow,
          partnerCommuteEnabled: _partnerCommuteEnabled,
          onPartnerCommuteEnabledChanged: (enabled) => setState(() {
            _setPartnerCommuteEnabled(enabled);
          }),
          tenurePreference: _tenurePreference,
          onTenurePreferenceChanged: (v) =>
              setState(() => _tenurePreference = v),
          furnishingPreference: _furnishingPreference,
          onFurnishingPreferenceChanged: (v) =>
              setState(() => _furnishingPreference = v),
          propertyTypePreference: _propertyTypePreference,
          onPropertyTypePreferenceChanged: (v) =>
              setState(() => _propertyTypePreference = v),
          bathroomPreference: _bathroomPreference,
          onBathroomPreferenceChanged: (v) =>
              setState(() => _bathroomPreference = v),
        );
      case 2:
        final draft = _commuterDrafts.isNotEmpty
            ? _commuterDrafts.first
            : _CommuterDraftEntry(
                methodLabel: _defaultCommuteMethod().toDisplayLabel(),
              );
        final commuteMinutes = SeekerCommuteTimeOptions.snap(
          draft.maxCommuteMinutes,
        );
        return SeekerOnboardingDestinationScreen(
          persona: _seekerPersona,
          isSharedTrack: false,
          commuteMethod: CommuteMethod.fromDisplayLabel(draft.methodLabel),
          onCommuteMethodChanged: (method) => setState(() {
            _commuteMethodUserOverridden = true;
            _ensurePrimaryCommuterDraft();
            _commuterDrafts.first.methodLabel = method.toDisplayLabel();
          }),
          selectedHub: draft.hub,
          maxCommuteMinutes: commuteMinutes,
          onHubSelected: (hub) => setState(() {
            _commuteDestinationUnknown = false;
            _ensurePrimaryCommuterDraft();
            _commuterDrafts.first.hub = hub;
          }),
          onHubCleared: () => setState(() {
            _commuteDestinationUnknown = false;
            if (_commuterDrafts.isNotEmpty) {
              _commuterDrafts.first.hub = null;
            }
          }),
          onCommuteMinutesChanged: (v) => setState(() {
            _ensurePrimaryCommuterDraft();
            _commuterDrafts.first.maxCommuteMinutes = v.toDouble();
            _maxCommuteBudgetMinutes = v.toDouble();
          }),
          partnerCommuteEnabled: _partnerCommuteEnabled,
          destinationEnteredIsMine:
              _dualCommutePriority != DualCommutePriority.personB,
          onDestinationEnteredIsMineChanged: _onDestinationOwnerChanged,
          guarantorStatus: _guarantorStatus,
          onGuarantorChanged: (v) => setState(() => _guarantorStatus = v),
          financialSupportType: _selectedFinancialSupportType,
          onFinancialSupportChanged: (v) =>
              setState(() => _selectedFinancialSupportType = v),
          financialSupportOptions: _financialSupportOptions,
          destinationFieldResetToken: _destinationFieldResetToken,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSharedSeekerPage(int page) {
    switch (page) {
      case 1:
        return SeekerOnboardingPreferencesScreen(
          budgetController: _budgetMaxController,
          isSharedTrack: true,
          locationContext: _dublinLocationContext,
          onLocationContextChanged: (v) => setState(() {
            _dublinLocationContext = v;
            _applyDefaultCommuteMethodIfNeeded();
          }),
          moveInWindow: _hasSetMoveInWindow ? _moveInWindow : null,
          onMoveInWindowChanged: _setMoveInWindow,
          partnerCommuteEnabled: _partnerCommuteEnabled,
          onPartnerCommuteEnabledChanged: (enabled) => setState(() {
            _setPartnerCommuteEnabled(enabled);
          }),
          primaryLanguage: _selectedMotherTongue,
          onPrimaryLanguageChanged: _onSeekerPrimaryLanguageChanged,
          suggestedLanguages: _secondaryDisplayLanguages(),
          selectedSecondaryLanguages: _selectedSecondaryLanguages,
          onToggleSecondaryLanguage: _toggleSeekerSecondaryLanguage,
          onAddSecondaryLanguage: _addSeekerSecondaryLanguage,
          smokingStatus: _smokingStatus,
          onSmokingStatusChanged: _setSmokingStatus,
          petType: _petType,
          onPetTypeChanged: _setPetType,
          bathroomPreference: _bathroomPreference,
          onBathroomPreferenceChanged: (v) =>
              setState(() => _bathroomPreference = v),
        );
      case 2:
        final draft = _commuterDrafts.isNotEmpty
            ? _commuterDrafts.first
            : _CommuterDraftEntry(
                methodLabel: _defaultCommuteMethod().toDisplayLabel(),
              );
        final commuteMinutes = SeekerCommuteTimeOptions.snap(
          draft.maxCommuteMinutes,
        );
        return SeekerOnboardingDestinationScreen(
          persona: _seekerPersona,
          isSharedTrack: true,
          budgetController: _budgetMaxController,
          moveInDate: _moveInDate,
          onMoveInDateChanged: _setSharedMoveInDate,
          transportMode: _transportMode,
          onTransportModeChanged: _setTransportMode,
          parkingNeed: _parkingNeed,
          onParkingNeedChanged: (v) => setState(() => _parkingNeed = v),
          locationContext: _dublinLocationContext,
          onLocationContextChanged: (v) => setState(() {
            _dublinLocationContext = v;
            _applyDefaultCommuteMethodIfNeeded();
          }),
          commuteMethod: CommuteMethod.fromDisplayLabel(draft.methodLabel),
          onCommuteMethodChanged: (method) => setState(() {
            _commuteMethodUserOverridden = true;
            _ensurePrimaryCommuterDraft();
            _commuterDrafts.first.methodLabel = method.toDisplayLabel();
          }),
          selectedHub: draft.hub,
          maxCommuteMinutes: commuteMinutes,
          onHubSelected: (hub) => setState(() {
            _commuteDestinationUnknown = false;
            _ensurePrimaryCommuterDraft();
            _commuterDrafts.first.hub = hub;
          }),
          onHubCleared: () => setState(() {
            _commuteDestinationUnknown = false;
            if (_commuterDrafts.isNotEmpty) {
              _commuterDrafts.first.hub = null;
            }
          }),
          onCommuteMinutesChanged: (v) => setState(() {
            _ensurePrimaryCommuterDraft();
            _commuterDrafts.first.maxCommuteMinutes = v.toDouble();
            _maxCommuteBudgetMinutes = v.toDouble();
          }),
          partnerCommuteEnabled: _partnerCommuteEnabled,
          destinationEnteredIsMine:
              _dualCommutePriority != DualCommutePriority.personB,
          onDestinationEnteredIsMineChanged: _onDestinationOwnerChanged,
          guarantorStatus: _guarantorStatus,
          onGuarantorChanged: (v) => setState(() => _guarantorStatus = v),
          financialSupportType: _selectedFinancialSupportType,
          onFinancialSupportChanged: (v) =>
              setState(() => _selectedFinancialSupportType = v),
          financialSupportOptions: _financialSupportOptions,
          destinationFieldResetToken: _destinationFieldResetToken,
        );
      case 3:
        return _buildSharedLocationPage();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSharedLocationPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GamifiedFormPageHeader(
              title: 'Location',
              subtitle: 'Choose the areas you want to search in Dublin.',
            ),
            const SizedBox(height: OnboardingTokens.space16),
            const SeekerSharedSectionHeader(
              title: '🗺️ Preferred areas',
              subtitle: 'Optional — leave empty to search all of Dublin.',
            ),
            const SizedBox(height: SeekerSharedChipStyle.headerToContent),
            SeekerPreferredAreasSelector(
              selectedTargetSearchAreas: _selectedTargetSearchAreas,
              onToggleTargetSearchArea: _toggleTargetSearchArea,
            ),
          ],
        );
        if (!constraints.maxHeight.isFinite) return content;
        return SizedBox(
          height: constraints.maxHeight,
          child: SingleChildScrollView(child: content),
        );
      },
    );
  }

  Widget _buildSeekerHousingPageStack() {
    final isEntirePlace =
        _selectedTrack == ProfileOnboardingTrack.seekerEntirePlace;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSeekerHousingPageHeader(),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        _buildPage2SectionAHousingBudget(),
        if (!isEntirePlace) ...[
          const SizedBox(height: OnboardingTokens.fieldSpacing),
          ..._buildSeekerHousingBasicsSections(),
          const SizedBox(height: OnboardingTokens.fieldSpacing),
          _buildHouseholdCommutersCard(),
        ],
      ],
    );
  }

  Widget _buildSeekerCommutePageStack() {
    final showDualCommute = _commuterSlotCount > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSeekerCommutePageHeader(),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        if (_householdCommutersCount > 2) ...[
          _groupCard(
            title: 'Pick your two priority routes',
            subtitle:
                '$_householdCommutersCount people commute — choose the two destinations that matter most for matching.',
            children: const [],
          ),
          const SizedBox(height: OnboardingTokens.fieldSpacing),
        ],
        if (_commuterDrafts.isNotEmpty) ...[
          _buildPrimaryRouteCard(),
          if (showDualCommute) ...[
            const SizedBox(height: OnboardingTokens.fieldSpacing),
            _buildSecondaryRouteCard(1),
          ],
          const SizedBox(height: OnboardingTokens.fieldSpacing),
        ],
        ..._buildSeekerFinalizeSections(),
      ],
    );
  }

  Widget _buildPage2LeftStack() {
    final showDualCommute =
        _selectedTrack == ProfileOnboardingTrack.seekerEntirePlace &&
            _commuterDrafts.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPage2Header(),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        _buildPage2SectionAHousingBudget(),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        if (_commuterDrafts.isNotEmpty) ...[
          _buildPrimaryRouteCard(),
          if (showDualCommute) ...[
            const SizedBox(height: OnboardingTokens.fieldSpacing),
            _buildSecondaryRouteCard(1),
          ],
          const SizedBox(height: OnboardingTokens.fieldSpacing),
        ],
        ..._buildPage2LowerSections(),
      ],
    );
  }

  Widget _buildPage2SectionAHousingBudget() {
    final isSharedTrack = _selectedTrack == ProfileOnboardingTrack.seekerSharedSpace;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingPremiumField(
          controller: _budgetMaxController,
          label: isSharedTrack
              ? 'Max room budget (${MarketConfig.current.currencySymbol} / month)'
              : 'Max monthly budget (${MarketConfig.current.currencySymbol})',
          hint: MarketConfig.current.currencySymbol == '€' ? 'e.g. 1800' : 'e.g. 25000',
          keyboardType: TextInputType.number,
          onChanged: () => setState(() {}),
        ),
        if (isSharedTrack)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Room budget used for shared-space matching.',
              style: TextStyle(
                fontSize: 12,
                color: OnboardingTokens.subtitleColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHouseholdCommutersCard() {
    return _groupCard(
      title: 'Household commuters',
      subtitle:
          'How many people in your household need a daily commute from home?',
      children: [
        _counterRow(
          label: 'People who commute',
          value: _householdCommutersCount,
          min: 1,
          max: 6,
          onChanged: (v) => setState(() {
            _householdCommutersCount = v;
            _syncCommuterDraftSlots();
          }),
        ),
        if (_householdCommutersCount > 2)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'On the next step you will set your two most important commute routes.',
              style: TextStyle(
                fontSize: 12,
                color: OnboardingTokens.subtitleColor,
              ),
            ),
          ),
      ],
    );
  }

  List<String> _dedupedSpokenLanguages() {
    final source = _onboardingIntent == OnboardingUserIntent.seeker
        ? _seekerSpokenLanguagesForPayload()
        : [
            _selectedMotherTongue,
            ..._selectedLanguages,
          ];
    final seen = <String>{};
    final result = <String>[];
    for (final language in source) {
      final token = language.trim();
      if (token.isEmpty) continue;
      if (seen.add(token.toLowerCase())) result.add(token);
    }
    return result;
  }

  String _resolvedPassportLocation() {
    if (MarketConfig.current.profileUseAreaPicker) {
      return _locationSelectValue;
    }
    return _formatLocationDisplay(_locationController.text.trim());
  }

  Widget _buildSeekerHousingPageHeader() {
    final title = _selectedTrack == ProfileOnboardingTrack.seekerSharedSpace
        ? 'Shared-space housing preferences'
        : 'Search & match preferences';
    final subtitle = _selectedTrack == ProfileOnboardingTrack.seekerSharedSpace
        ? 'Room budget, who you are, and how many people commute.'
        : 'Your monthly budget — property filters apply on the live feed.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: OnboardingTokens.pageTitleStyle),
        const SizedBox(height: 8),
        Text(subtitle, style: OnboardingTokens.pageSubtitleStyle),
      ],
    );
  }

  Widget _buildSeekerCommutePageHeader() {
    final title = _selectedTrack == ProfileOnboardingTrack.seekerSharedSpace
        ? 'Commute & compatibility'
        : 'Commute & finalize';
    final subtitle = _selectedTrack == ProfileOnboardingTrack.seekerSharedSpace
        ? 'Daily routes and roommate compatibility filters.'
        : 'Commute routes, lease preferences, and move-in readiness.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: OnboardingTokens.pageTitleStyle),
        const SizedBox(height: 8),
        Text(subtitle, style: OnboardingTokens.pageSubtitleStyle),
      ],
    );
  }

  Widget _buildPage2Header() {
    final title = _selectedTrack == ProfileOnboardingTrack.seekerSharedSpace
        ? 'Shared-space match preferences'
        : 'Search & match preferences';
    final subtitle = _selectedTrack == ProfileOnboardingTrack.seekerSharedSpace
        ? 'Room budget, commute, and compatibility filters for shared living.'
        : 'Budget, housing goals, and the filters that power your ideal matches.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: OnboardingTokens.pageTitleStyle,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: OnboardingTokens.pageSubtitleStyle,
        ),
      ],
    );
  }

  List<Widget> _buildSeekerHousingBasicsSections() {
    return switch (_selectedTrack) {
      ProfileOnboardingTrack.seekerEntirePlace =>
        _buildSeekerEntirePlaceHousingSections(),
      ProfileOnboardingTrack.seekerSharedSpace =>
        _buildSeekerSharedSpaceHousingSections(),
      _ => const [],
    };
  }

  List<Widget> _buildSeekerFinalizeSections() {
    return switch (_selectedTrack) {
      ProfileOnboardingTrack.seekerEntirePlace =>
        _buildSeekerEntirePlaceFinalizeSections(),
      ProfileOnboardingTrack.seekerSharedSpace =>
        _buildSeekerSharedSpaceFinalizeSections(),
      _ => const [],
    };
  }

  List<Widget> _buildPage2LowerSections() {
    return switch (_selectedTrack) {
      ProfileOnboardingTrack.seekerEntirePlace => _buildSeekerEntirePlaceSections(),
      ProfileOnboardingTrack.seekerSharedSpace => _buildSeekerSharedSpaceSections(),
      _ => const [],
    };
  }

  List<Widget> _buildSeekerEntirePlaceHousingSections() => const [];

  List<Widget> _buildSeekerEntirePlaceFinalizeSections() {
    return [
      _groupCard(
        title: 'Environment preferences',
        subtitle: 'Quiet household signals and move-in readiness.',
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Household includes pets'),
            value: _householdHasPets,
            onChanged: (v) => setState(() => _householdHasPets = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Smoker in household'),
            value: _householdSmoker,
            onChanged: (v) => setState(() => _householdSmoker = v),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _buildLeaseHouseholdSection(),
    ];
  }

  List<Widget> _buildSeekerEntirePlaceSections() {
    return [
      ..._buildSeekerEntirePlaceHousingSections(),
      const SizedBox(height: 16),
      ..._buildSeekerEntirePlaceFinalizeSections(),
    ];
  }

  List<Widget> _buildSeekerSharedSpaceHousingSections() {
    return [
      _groupCard(
        title: 'Roommate setup',
        subtitle: 'Who you are and the room format you need.',
        children: [
          ShadcnSelect(
            label: 'Occupant group type',
            value: _resolvedOccupantType,
            options: const ['Working Professionals', 'Students'],
            onChanged: (val) => setState(() {
              _selectedOccupantType = val;
              if (val != 'Students') _selectedFinancialSupportType = null;
            }),
          ),
          ShadcnSelect(
            key: const ValueKey('seeker_room_layout'),
            label: 'Room Layout',
            value: ProfileSeekerPreferences.resolveLayout(
              preferredArrangement,
              preferredLayout,
            ),
            options: ProfileSeekerPreferences.shareRoomLayoutOptions,
            onChanged: (val) => setState(() => preferredLayout = val),
          ),
          ShadcnSelect(
            label: 'Gender preference',
            value: _selectedGenderPref ?? _genderPrefOptions.first,
            options: _genderPrefOptions,
            onChanged: (v) => setState(() => _selectedGenderPref = v),
          ),
          _counterRow(
            label: 'How many people',
            value: _groupSize,
            min: 1,
            max: 10,
            onChanged: (v) => setState(() => _groupSize = v),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildSeekerSharedSpaceFinalizeSections() {
    return [
      _groupCard(
        title: 'Shared-space compatibility',
        subtitle: 'Language, food, and daily rhythm for room matching.',
        children: [
          const Text(
            'Preferred roommate languages',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Defaults to your languages — add more if you like.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 8),
          LanguagePillChips(
            options: _roommateLanguageChipOptions,
            selected: _preferredSpokenLanguages,
            onToggle: _togglePreferredSpokenLanguage,
            spacing: 8,
            runSpacing: 8,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _showAddRoommateLanguageSheet,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add another language'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Food preference',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sharedFoodChipOptions.map((option) {
              final selected = _sharedFoodPref == option;
              return FilterChip(
                label: Text(option),
                selected: selected,
                onSelected: (_) => setState(() {
                  _sharedFoodPref = option;
                  _hasSetFoodPreference = true;
                }),
                selectedColor: AppColors.accentLight,
                checkmarkColor: AppColors.accent,
                labelStyle: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.accentDark : AppColors.primaryText,
                ),
                side: BorderSide(
                  color: selected ? AppColors.accent : AppColors.divider,
                ),
              );
            }).toList(),
          ),
          SwitchListTile(
            title: const Text('OK with smoking'),
            value: _smokingOk,
            onChanged: (v) => setState(() => _smokingOk = v),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('OK with drinking'),
            value: _drinkingOk,
            onChanged: (v) => setState(() => _drinkingOk = v),
            contentPadding: EdgeInsets.zero,
          ),
          ShadcnSelect(
            label: 'Work schedule',
            value: _scheduleType ?? 'Flexible',
            options: const ['Flexible', 'Day shift', 'Night shift'],
            onChanged: (val) => setState(() {
              _scheduleType = val == 'Flexible' ? null : val;
            }),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _buildRootsAndTrustSection(),
    ];
  }

  List<Widget> _buildSeekerSharedSpaceSections() {
    return [
      ..._buildSeekerSharedSpaceHousingSections(),
      const SizedBox(height: 16),
      ..._buildSeekerSharedSpaceFinalizeSections(),
    ];
  }

  Widget _buildRootsAndTrustSection() {
    return _groupCard(
      title: 'Roots & trust',
      subtitle: 'Optional extras that boost credibility and matching quality.',
      children: [
        _VerificationGatewayEntry(
          linkedInVerified: _baselineProfile?['linkedin_verified'] == true,
          company: ProfileData.text(_baselineProfile?['company']),
          session: _baselineProfile ?? AuthScreen.currentUserSession,
          onTap: () => VerificationGatewayBottomSheet.show(
            context,
            session: _baselineProfile ?? AuthScreen.currentUserSession,
          ),
        ),
        if (_showEnterpriseFields)
          _textField(
            _agencyController,
            label: 'Agency / company name (optional)',
            hint: 'For multi-listing hosts',
          ),
      ],
    );
  }

  Widget _buildPrimaryRouteCard() {
    final title = _householdCommutersCount > 2
        ? 'Priority commute 1'
        : 'Primary commuter route';
    return _condensedRouteCard(
      title: title,
      draft: _commuterDrafts.first,
      onMethodChanged: (v) => setState(() => _commuterDrafts.first.methodLabel = v),
      onHubSelected: (hub) => setState(() => _commuterDrafts.first.hub = hub),
      onHubCleared: () => setState(() => _commuterDrafts.first.hub = null),
      onMinutesChanged: (v) => setState(() {
        _commuterDrafts.first.maxCommuteMinutes = v;
      }),
    );
  }

  Widget _buildSecondaryRouteCard(int index) {
    final title = _householdCommutersCount > 2
        ? 'Priority commute 2'
        : 'Secondary commuter route';
    return _condensedRouteCard(
      title: title,
      draft: _commuterDrafts[index],
      onMethodChanged: (v) =>
          setState(() => _commuterDrafts[index].methodLabel = v),
      onHubSelected: (hub) => setState(() => _commuterDrafts[index].hub = hub),
      onHubCleared: () => setState(() => _commuterDrafts[index].hub = null),
      onMinutesChanged: (v) => setState(() {
        _commuterDrafts[index].maxCommuteMinutes = v;
      }),
    );
  }

  Widget _condensedRouteCard({
    required String title,
    required _CommuterDraftEntry draft,
    required ValueChanged<String> onMethodChanged,
    required ValueChanged<DublinCommuterHub> onHubSelected,
    required VoidCallback onHubCleared,
    required ValueChanged<double> onMinutesChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnboardingTokens.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OnboardingTokens.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          ShadcnSelect(
            label: 'Commute method',
            value: draft.methodLabel,
            options: ProfileCommuteOptions.methodLabels,
            onChanged: onMethodChanged,
          ),
          const SizedBox(height: 12),
          CommuteDestinationField(
            label: 'Destination',
            selectedHub: draft.hub,
            occupantType: _resolvedOccupantType,
            onHubSelected: onHubSelected,
            onCleared: onHubCleared,
          ),
          const SizedBox(height: 12),
          Text(
            'Max travel time: ${draft.maxCommuteMinutes.round()} min',
            style: OnboardingTokens.sectionLabelStyle,
          ),
          Slider(
            value: draft.maxCommuteMinutes,
            min: 15,
            max: 90,
            divisions: 15,
            label: '${draft.maxCommuteMinutes.round()} min',
            onChanged: onMinutesChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaseHouseholdSection() {
    final leaseLabels = ApplicantSessionSync.leaseTermLabels;
    final selectedLeaseLabel =
        ApplicantSessionSync.leaseLabelForMonths(_preferredLeaseMonths);

    return _groupCard(
      title: 'Lease & household (entire place)',
      subtitle:
          'Used for landlord checklist scoring — income, move-in, and household policy.',
      children: [
        _textField(
          _netMonthlyIncomeController,
          label: 'Your net monthly income (EUR)',
          hint: 'e.g. 4200',
          keyboardType: TextInputType.number,
          onChanged: () => setState(() {}),
        ),
        if (_commuterSlotCount > 1)
          _textField(
            _partnerNetMonthlyIncomeController,
            label: 'Co-applicant net monthly income (EUR)',
            hint: 'Optional — partner or second earner',
            keyboardType: TextInputType.number,
            onChanged: () => setState(() {}),
          ),
        ShadcnSelect(
          label: 'Preferred lease length',
          value: selectedLeaseLabel,
          hint: 'Select',
          options: leaseLabels,
          onChanged: (v) => setState(() {
            _preferredLeaseMonths = ApplicantSessionSync.leaseMonthsFromLabel(v);
          }),
        ),
        OnboardingFieldBlock(
          label: 'Move-in window',
          child: OnboardingMoveInWindowField(
            selected: _moveInWindow,
            onChanged: (window) => setState(() {
              _hasSetMoveInWindow = true;
              _moveInWindow = window;
            }),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('HAP / municipal rent support'),
          subtitle: const Text('Include verified voucher in household income'),
          value: _hasHapVoucher,
          onChanged: (v) => setState(() => _hasHapVoucher = v),
        ),
        if (_hasHapVoucher) ...[
          _textField(
            _hapVoucherContributionController,
            label: 'Monthly HAP contribution (EUR)',
            hint: 'e.g. 650',
            keyboardType: TextInputType.number,
            onChanged: () => setState(() {}),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enhanced HAP uplift approved'),
            subtitle: Text(
              'Local authority approved 35–50% above the standard cap '
              '(€${DublinHapContributionValidator.standardCapForSession(_draftSession()).toStringAsFixed(0)} for your household).',
            ),
            value: _hapUpliftApproved,
            onChanged: (v) => setState(() => _hapUpliftApproved = v),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Verified guarantor on file'),
          value: _hasVerifiedGuarantor,
          onChanged: (v) => setState(() => _hasVerifiedGuarantor = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Household includes pets'),
          value: _householdHasPets,
          onChanged: (v) => setState(() => _householdHasPets = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Smoker in household'),
          value: _householdSmoker,
          onChanged: (v) => setState(() => _householdSmoker = v),
        ),
      ],
    );
  }

  Widget _groupCard({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
          const SizedBox(height: 12),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _premiumTextField(
    TextEditingController controller, {
    required String label,
    required String hint,
    TextInputType? keyboardType,
    VoidCallback? onChanged,
  }) {
    return OnboardingPremiumField(
      controller: controller,
      label: label,
      hint: hint,
      keyboardType: keyboardType,
      onChanged: onChanged,
    );
  }

  Widget _textField(
    TextEditingController controller, {
    required String label,
    required String hint,
    TextInputType? keyboardType,
    VoidCallback? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged == null ? null : (_) => onChanged(),
      decoration: AppFormFields.decoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }

  Widget _counterRow({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class _CommuterDraftEntry {
  _CommuterDraftEntry({
    String? methodLabel,
    this.hub,
    double? maxCommuteMinutes,
  })  : methodLabel =
            methodLabel ?? ProfileCommuteOptions.methodLabels.first,
        maxCommuteMinutes = SeekerCommuteTimeOptions.snap(
          maxCommuteMinutes ?? SeekerCommuteTimeOptions.defaultMinutes,
        ).toDouble();

  String methodLabel;
  DublinCommuterHub? hub;
  double maxCommuteMinutes;
}

class _VerificationGatewayEntry extends StatelessWidget {
  const _VerificationGatewayEntry({
    required this.linkedInVerified,
    required this.company,
    required this.onTap,
    this.session,
  });

  final bool linkedInVerified;
  final String company;
  final VoidCallback onTap;
  final Map<String, dynamic>? session;

  @override
  Widget build(BuildContext context) {
    final recommendation = getVerificationLabel(session);
    final contactVerified = TrustService.meetsContactVerification(session);
    final subtitle = linkedInVerified
        ? 'Connected — $company · ${recommendation.suffixTag}'
        : '${recommendation.suffixTag} · ${recommendation.pathTitle}';

    return Material(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accentLight,
                AppColors.surface,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Verification Gateway',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (contactVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '✅ Verified User',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentDark,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTypography.fontFamily,
                          fontFamilyFallback: AppTypography.emojiFontFallback,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recommendation.description,
                        style: AppTypography.caption.copyWith(
                          height: 1.45,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.accentDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
