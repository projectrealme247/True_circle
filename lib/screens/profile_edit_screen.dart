import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../config/market/dublin_commuter_hubs.dart';
import '../config/market/dublin_districts.dart';
import '../config/market/market_config.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/profile_state_notifier.dart';
import '../services/commute_scoring_service.dart';
import '../utils/applicant_session_sync.dart';
import '../utils/commute_profile.dart';
import '../utils/dublin_hap_contribution_validator.dart';
import '../services/profile_storage_service.dart';
import '../services/listings_storage_service.dart';
import '../services/view_preference_service.dart';
import '../models/onboarding_user_intent.dart';
import '../models/profile_onboarding_models.dart';
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
import '../utils/spoken_language_profile_codec.dart';
import '../widgets/commute_destination_field.dart';
import '../debug/agent_log.dart';
import '../widgets/gamified_form_wizard.dart';
import '../widgets/language_pill_chips.dart';
import '../widgets/onboarding/mother_tongue_typeahead_field.dart';
import '../widgets/onboarding/onboarding_design_tokens.dart';
import '../widgets/onboarding/onboarding_grid_shell.dart';
import '../widgets/listing_creation/listing_creation_primitives.dart';
import '../widgets/listing_creation/eircode_address_field.dart';
import '../widgets/onboarding/onboarding_intent_splitter.dart';
import '../widgets/onboarding/onboarding_premium_field.dart';
import '../widgets/onboarding/onboarding_spoken_language_chips.dart';
import '../widgets/onboarding/passport_preview_card.dart';
import '../widgets/shadcn_select.dart';
import '../widgets/truecircle_logo.dart';
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
      _onboardingIntent == OnboardingUserIntent.seeker ? 3 : 2;

  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  String _phoneCountryCode = PhoneE164.defaultCountryCode;
  bool _prefersWhatsapp = false;
  final _propertyLocationIdentifierController = TextEditingController();
  final _nativePlaceController = TextEditingController();
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
  final _earliestMoveInController = TextEditingController();
  String _selectedMotherTongue = 'English';
  final List<String> _selectedLanguages = [];
  final Map<String, bool> _languageNativeFlags = {};
  final List<_CommuterDraftEntry> _commuterDrafts = [];
  int _householdCommutersCount = 1;
  double _maxCommuteBudgetMinutes = 45;
  int? _preferredLeaseMonths;
  bool _hasHapVoucher = false;
  bool _hapUpliftApproved = false;
  bool _hasVerifiedGuarantor = false;
  bool _householdHasPets = false;
  bool _householdSmoker = false;
  final List<String> _preferredSpokenLanguages = [];
  String _sharedFoodPref = 'Veg';
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
  String? _selectedStudentType;

  String preferredArrangement = ProfileSeekerPreferences.arrangementOptions.first;
  String? preferredLayout;

  int _familyAdults = 2;
  int _familyChildren = 0;
  List<String> _childrenAges = [];
  int _groupSize = 1;
  bool _smokingOk = false;
  bool _drinkingOk = false;
  String? _scheduleType;
  int _ownedListingCount = 0;
  final _agencyController = TextEditingController();

  static const _childrenAgeOptions = ['Below 5', '5 - 12', '13 - 18'];

  int get _selectedBudgetTime => _maxCommuteBudgetMinutes.round();

  int get _commuterSlotCount {
    if (_householdCommutersCount <= 1) return 1;
    return 2;
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
  List<String> get _studentFundingOptions =>
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
    profileStateNotifier.beginEditing(widget.initialProfile, notify: false);
    _applyMarketDefaults();
    _nameController.addListener(_onPassportFieldChanged);
    _locationController.addListener(_onPassportFieldChanged);
    _propertyLocationController.addListener(_onPassportFieldChanged);
    _propertyEircodeController.addListener(_onPassportFieldChanged);
    _bootstrap();
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
    _selectedMotherTongue = market.defaultMotherTongue;
    _applyMotherTongueInference(market.defaultMotherTongue);
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

    _nativePlaceController.text = ProfileData.text(profile['native_place']);
    _agencyController.text = ProfileData.text(profile['agency_name']);

    final mother = ProfileData.text(profile['mother_tongue']);
    if (mother.isNotEmpty) {
      _selectedMotherTongue = mother;
    }

    _hydrateCommutersFromProfile(profile);

    final householdCommuters = profile['household_commuters_count'];
    if (householdCommuters is int && householdCommuters > 0) {
      _householdCommutersCount = householdCommuters;
    } else {
      _householdCommutersCount = _commuterDrafts.length.clamp(1, 2);
    }
    _syncCommuterDraftSlots();

    final maxCommute = profile['maximum_commute_budget_minutes'];
    if (maxCommute is num && maxCommute > 0) {
      _maxCommuteBudgetMinutes = maxCommute.toDouble();
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
    if (_selectedLanguages.isEmpty) {
      _selectedLanguages.add(_languageOptions.first);
    }

    _languageNativeFlags
      ..clear()
      ..addEntries(
        ProfileData.spokenLanguageEntries(profile).map(
          (entry) => MapEntry(entry.language, entry.isNative),
        ),
      );
    _languageNativeFlags[_selectedMotherTongue] = true;

    final occupant = ProfileData.text(profile['occupant_type']);
    if (occupant.isNotEmpty && _occupantOptions.contains(occupant)) {
      _selectedOccupantType = occupant;
    }

    preferredArrangement = ProfileSeekerPreferences.hydrateArrangement(profile);
    preferredLayout = ProfileSeekerPreferences.hydrateLayout(
      profile,
      preferredArrangement,
    );

    final genderPref = ProfileData.text(profile['gender_preference']);
    if (genderPref.isNotEmpty && _genderPrefOptions.contains(genderPref)) {
      _selectedGenderPref = genderPref;
    }

    final student = ProfileData.text(profile['student_type']);
    if (student.isNotEmpty && _studentFundingOptions.contains(student)) {
      _selectedStudentType = student;
    }

    final adults = profile['family_adults'];
    if (adults is int) _familyAdults = adults;
    final children = profile['family_children'];
    if (children is int) _familyChildren = children;

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
    _earliestMoveInController.text =
        ProfileData.text(profile['earliest_move_in_date']);

    _onboardingIntent = OnboardingUserIntent.fromSession(profile);
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
  }

  @override
  void dispose() {
    profileStateNotifier.endEditing();
    _nameController.removeListener(_onPassportFieldChanged);
    _locationController.removeListener(_onPassportFieldChanged);
    _propertyLocationController.removeListener(_onPassportFieldChanged);
    _propertyEircodeController.removeListener(_onPassportFieldChanged);
    _emailController.dispose();
    _nameController.dispose();
    _contactPhoneController.dispose();
    _propertyLocationIdentifierController.dispose();
    _nativePlaceController.dispose();
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
    return {
      ...baseline,
      'email': _emailController.text.trim(),
      'full_name': _nameController.text.trim(),
      'detected_city': _resolvedCity(),
      ..._spokenLanguageSessionFields(),
      if (_nativePlaceController.text.trim().isNotEmpty)
        'native_place': _nativePlaceController.text.trim(),
      ..._commutePayloadFields(),
      if (_budgetMinController.text.trim().isNotEmpty)
        'budget_min': int.tryParse(_budgetMinController.text.trim()),
      if (_budgetMaxController.text.trim().isNotEmpty)
        'budget_max': int.tryParse(_budgetMaxController.text.trim()),
      'occupant_type': _resolvedOccupantType,
      if (_agencyController.text.trim().isNotEmpty)
        'agency_name': _agencyController.text.trim(),
      if (_selectedOccupantType == 'Family') ...{
        'family_adults': _familyAdults,
        'family_children': _familyChildren,
      },
      if (_selectedOccupantType == 'Working Professionals' ||
          _selectedOccupantType == 'Students')
        'group_size': _groupSize,
      if (_partnerNetMonthlyIncomeController.text.trim().isNotEmpty)
        'partner_net_monthly_income':
            double.tryParse(_partnerNetMonthlyIncomeController.text.trim()),
    };
  }

  Widget _buildCompletionHeader() {
    final draft = _draftSession();
    final percent = ProfileData.calculateProfileCompletionPercentage(draft);
    final missing = ProfileData.missingFieldsForCompletion(draft);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OnboardingTokens.progressCoral,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile $percent% complete',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Complete identity, commute, and search preferences to reach 100%.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: OnboardingTokens.subtitleColor,
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Still needed: ${missing.take(3).join(', ')}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFBE123C),
              ),
            ),
          ],
        ],
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
      }
    } else {
      final profiles = CommuteProfileRegistry.fromSession(profile);
      if (profiles.isNotEmpty) {
        for (final entry in profiles) {
          _commuterDrafts.add(
            _CommuterDraftEntry(
              methodLabel: entry.method.toDisplayLabel(),
              hub: entry.hub,
              maxCommuteMinutes: fallbackMinutes,
            ),
          );
        }
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
    final profiles = <CommuteProfileEntry>[];
    final profileMaps = <Map<String, dynamic>>[];
    final perProfileMax = <String, int>{};

    for (var i = 0; i < _commuterDrafts.length; i++) {
      final draft = _commuterDrafts[i];
      final hub = draft.hub;
      if (hub == null) continue;

      final id = switch (i) {
        0 => CommuteProfileRegistry.primaryId,
        1 => CommuteProfileRegistry.partnerId,
        _ => 'commuter_${i + 1}',
      };
      final maxMinutes = draft.maxCommuteMinutes.round();
      perProfileMax[id] = maxMinutes;

      profiles.add(
        CommuteProfileEntry(
          id: id,
          label: 'Commuter ${i + 1}',
          method: CommuteMethod.fromDisplayLabel(draft.methodLabel),
          hub: hub,
        ),
      );
      profileMaps.add({
        ...profiles.last.toMap(),
        'max_commute_minutes': maxMinutes,
      });
    }

    final primary = profiles.isNotEmpty ? profiles.first : null;
    final partner = profiles.length > 1 ? profiles[1] : null;
    final worstCaseMax = perProfileMax.values.isEmpty
        ? _selectedBudgetTime
        : perProfileMax.values.reduce((a, b) => a > b ? a : b);

    return {
      'maximum_commute_budget_minutes': worstCaseMax,
      'dual_commute_priority': 'balanced',
      'household_commuters_count': _householdCommutersCount,
      if (perProfileMax.isNotEmpty) 'commute_profile_max_minutes': perProfileMax,
      if (primary != null) ...{
        'commute_method': primary.method.toBackend(),
        ...DublinCommuterHubs.persistFields(primary.hub),
        'commute_profiles': profileMaps,
      },
      if (partner != null) ...{
        'partner_commute_method': partner.method.toBackend(),
        'partner_commute_destination': partner.hub.label,
        'partner_commute_destination_hub_id': partner.hub.id,
        'partner_destination_latitude': partner.hub.latitude,
        'partner_destination_longitude': partner.hub.longitude,
      },
    };
  }

  Map<String, dynamic> _sharedRoomPayloadFields() {
    return {
      'food_preference':
          ProfileSeekerPreferences.sharedFoodToBackend(_sharedFoodPref),
      if (_preferredSpokenLanguages.isNotEmpty) ...{
        'preferred_spoken_languages':
            List<String>.from(_preferredSpokenLanguages),
        'preferred_spoken_languages_csv':
            _preferredSpokenLanguages.join(', '),
      },
    };
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
    final entries = [
      for (final language in _selectedLanguages)
        SpokenLanguageEntry(
          language: language,
          isNative: language == _selectedMotherTongue ||
              (_languageNativeFlags[language] ?? false),
        ),
    ];

    return SpokenLanguageProfileCodec.toSessionFields(
      entries: entries,
      motherTongue: _selectedMotherTongue,
    );
  }

  ProfileInheritanceSnapshot _buildTrackSnapshot() {
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
        nativePlace: _nativePlaceController.text.trim(),
        languages: hostLanguages,
      ),
      seekerProfile: SeekerProfile(
        maxBudget: _selectedTrack == ProfileOnboardingTrack.seekerEntirePlace
            ? seekerBudget
            : null,
        roomBudget: _selectedTrack == ProfileOnboardingTrack.seekerSharedSpace
            ? seekerBudget
            : null,
        moveInWindow: _earliestMoveInController.text.trim(),
        preferredLeaseMonths: _preferredLeaseMonths,
        occupantGroupFit: _resolvedOccupantType,
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
        secondaryCommute:
            _commuterDrafts.length > 1 && _commuterDrafts[1].hub != null
                ? {
                    'commute_method': CommuteMethod.fromDisplayLabel(
                      _commuterDrafts[1].methodLabel,
                    ).toBackend(),
                    'commute_destination_hub_id': _commuterDrafts[1].hub!.id,
                    'commute_destination': _commuterDrafts[1].hub!.label,
                    'max_commute_minutes':
                        _commuterDrafts[1].maxCommuteMinutes.round(),
                  }
                : const {},
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
    if (_emailController.text.trim().isEmpty) {
      _showMessage('Please enter your email.');
      return false;
    }
    if (_nameController.text.trim().isEmpty) {
      _showMessage('Please enter your full name.');
      return false;
    }
    if (_onboardingIntent == OnboardingUserIntent.seeker) {
      if (_resolvedCity().isEmpty) {
        _showMessage('Please set your current location / base.');
        return false;
      }
    } else if (!_providerLocationIsSet()) {
      _showMessage('Enter your property Eircode or a location identifier.');
      return false;
    }
    if (_selectedLanguages.isEmpty) {
      _showMessage('Select at least one language.');
      return false;
    }
    return true;
  }

  bool _validateSeekerHousingPage() {
    final budget = int.tryParse(_budgetMaxController.text.trim());
    if (budget == null || budget <= 0) {
      _showMessage('Enter your maximum monthly budget.');
      return false;
    }
    if (_householdCommutersCount < 1) {
      _showMessage('Tell us how many people in your household commute.');
      return false;
    }
    return true;
  }

  bool _validateSeekerCommutePage() {
    final configured = _commuterDrafts
        .take(_commuterSlotCount)
        .where((draft) => draft.hub != null)
        .length;
    if (configured < _commuterSlotCount) {
      _showMessage(
        _commuterSlotCount == 1
            ? 'Set your commute destination.'
            : 'Set both priority commute destinations.',
      );
      return false;
    }
    return true;
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _pageCount) return;
    setState(() => _currentPage = page);
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
        1 => 'Back to profile details',
        _ => 'Back to housing preferences',
      };

  bool _validate() {
    if (_emailController.text.trim().isEmpty) {
      _showMessage('Please enter your email.');
      return false;
    }
    if (_nameController.text.trim().isEmpty) {
      _showMessage('Please enter your full name.');
      return false;
    }
    if (_onboardingIntent == OnboardingUserIntent.seeker &&
        _resolvedCity().isEmpty) {
      _showMessage('Please set your current location / base.');
      return false;
    }
    if (_onboardingIntent == OnboardingUserIntent.provider &&
        !_providerLocationIsSet()) {
      _showMessage('Enter your property Eircode or a location identifier.');
      return false;
    }
    if (_selectedLanguages.isEmpty) {
      _showMessage('Select at least one language.');
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
      'detected_city': _resolvedCity(),
      'native_place': _nativePlaceController.text.trim(),
      ..._spokenLanguageSessionFields(),
      ..._commutePayloadFields(),
      ...ProfileSeekerPreferences.persistFields(
        preferredArrangement: preferredArrangement,
        preferredLayout: _resolvedPreferredLayout,
      ),
      if (ProfileSeekerPreferences.isSharedRoom(preferredArrangement))
        ..._sharedRoomPayloadFields(),
      'occupant_type': _resolvedOccupantType,
      if (_selectedGenderPref != null) 'gender_preference': _selectedGenderPref,
      if (_selectedStudentType != null) 'student_type': _selectedStudentType,
      if (_selectedOccupantType == 'Family') ...{
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
      },
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
      if (_earliestMoveInController.text.trim().isNotEmpty)
        'earliest_move_in_date': _earliestMoveInController.text.trim(),
      'has_hap_voucher': _hasHapVoucher,
      'hap_uplift_approved': _hapUpliftApproved,
      if (_hapVoucherContributionController.text.trim().isNotEmpty)
        'hap_voucher_contribution':
            double.tryParse(_hapVoucherContributionController.text.trim()),
      'has_verified_guarantor': _hasVerifiedGuarantor,
      'household_has_pets': _householdHasPets,
      'household_smoker': _householdSmoker,
      'onboarding_intent': _onboardingIntent.storageToken,
      'profile_onboarding_track': _selectedTrack.storageToken,
      if (_onboardingIntent == OnboardingUserIntent.provider) ...{
        'pending_listing_location': _resolvedPropertyNeighborhood(),
        'pending_listing_eircode': _hidePropertyExactAddress
            ? ''
            : EircodeGeocodingService.normalize(_propertyEircodeController.text),
        'property_location_identifier':
            _hidePropertyExactAddress
                ? ''
                : _propertyLocationIdentifierController.text.trim(),
        AddressPrivacy.hideExactAddressKey: _hidePropertyExactAddress,
        if (_hidePropertyExactAddress && _selectedPropertyAddress != null)
          AddressPrivacy.publicLocationKey:
              _selectedPropertyAddress!.publicLocationLabel,
        if (_hidePropertyExactAddress &&
            _propertyEircodeController.text.trim().isNotEmpty)
          AddressPrivacy.exactEircodeKey: EircodeGeocodingService.normalize(
            _propertyEircodeController.text,
          ),
        'listingSeed_isFurnished': _providerIsFurnished,
        'is_owner_occupier': _providerIsOwnerOccupier,
      },
      'trust_stage': ProfileData.isMatchingReady(_draftSession()) ? 1 : 0,
      'identity_trust_tier': 'Casual_Browser',
    };
    payload.remove('kitchen_utility_preference');
    if (!ProfileSeekerPreferences.isSharedRoom(preferredArrangement)) {
      payload
        ..remove('kitchen_usage_timing')
        ..remove('food_preference')
        ..remove('schedule_type')
        ..remove('preferred_spoken_languages')
        ..remove('preferred_spoken_languages_csv');
    }
    if (_onboardingIntent == OnboardingUserIntent.seeker) {
      payload
        ..remove('pending_listing_location')
        ..remove('pending_listing_eircode');
    }
    payload = ProfileOnboardingRepository.applySnapshotToSession(
      payload,
      _buildTrackSnapshot(),
    );
    return ApplicantSessionSync.enrich(payload);
  }

  Future<void> _save() async {
    if (!_validate()) return;
    if (_onboardingIntent == OnboardingUserIntent.seeker &&
        !_validateSeekerCommutePage()) {
      return;
    }
    final synced = await AuthService.persistProfileSession(_buildPayload());
    if (!mounted) return;
    setState(() {
      _baselineProfile = Map<String, dynamic>.from(synced);
    });
    if (_onboardingIntent == OnboardingUserIntent.seeker) {
      await ViewPreferenceService.setOverride(DashboardViewMode.seeker);
      await marketplaceContextNotifier.syncSpaceFromOnboardingTrack(
        _selectedTrack,
      );
      if (!mounted) return;
      _showMessage('Profile saved — welcome to your feed.');
      context.go('/?welcomeFeed=1');
      return;
    }
    _showMessage('Profile updated.');
    context.go('/profile', extra: synced);
  }

  Future<void> _completeProviderOnboarding() async {
    if (!_validatePage1()) return;
    final payload = _buildPayload();
    payload['onboarding_intent'] = OnboardingUserIntent.provider.storageToken;
    payload['pending_listing_location'] = _resolvedPropertyNeighborhood();
    payload['pending_listing_eircode'] = _hidePropertyExactAddress
        ? ''
        : EircodeGeocodingService.normalize(_propertyEircodeController.text);
    payload['property_location_identifier'] = _hidePropertyExactAddress
        ? ''
        : _propertyLocationIdentifierController.text.trim();
    payload[AddressPrivacy.hideExactAddressKey] = _hidePropertyExactAddress;
    payload['host_profile_complete'] = true;

    final synced = await AuthService.persistProfileSession(payload);
    await ViewPreferenceService.setOverride(DashboardViewMode.host);
    await marketplaceContextNotifier.syncSpaceFromOnboardingTrack(
      _selectedTrack,
    );
    if (!mounted) return;

    setState(() {
      _baselineProfile = Map<String, dynamic>.from(synced);
    });

    _showMessage('Host profile saved — add your first listing when ready.');
    context.go('/?promptFirstListing=1');
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    // #region agent log
    agentLog(
      location: 'profile_edit_screen.dart:build',
      message: 'scaffold viewport',
      data: {
        'viewportH': MediaQuery.sizeOf(context).height,
        'viewportW': MediaQuery.sizeOf(context).width,
        'currentPage': _currentPage,
        'hydrating': _hydrating,
      },
      hypothesisId: 'B',
    );
    // #endregion

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
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: OnboardingTokens.gridMaxWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(OnboardingTokens.gridPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GamifiedFormProgress(
                        current: _currentPage,
                        total: _pageCount,
                      ),
                      const SizedBox(height: 32),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: switch (_currentPage) {
                            0 => KeyedSubtree(
                                key: const ValueKey('onboarding-step-1'),
                                child: _buildPage1Grid(),
                              ),
                            1 when _onboardingIntent ==
                                OnboardingUserIntent.seeker =>
                              KeyedSubtree(
                                key: const ValueKey('onboarding-step-2'),
                                child: _buildSeekerHousingPageGrid(),
                              ),
                            2 => KeyedSubtree(
                                key: const ValueKey('onboarding-step-3'),
                                child: _buildSeekerCommutePageGrid(),
                              ),
                            _ => KeyedSubtree(
                                key: const ValueKey('onboarding-step-2'),
                                child: _buildPage2Grid(),
                              ),
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildNavBar(),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }

  bool get _showOnboardingIntentSplitter => _currentPage == 0;

  Widget _buildPage1Grid() {
    return OnboardingGridShell(
      stretchRightPane: true,
      leftPane: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: OnboardingTokens.leftPaneMaxWidth,
            ),
            child: _buildPage1FormContent(),
          ),
        ),
      ),
      rightPane: ColoredBox(
        color: OnboardingTokens.panelTint,
        child: Center(child: _buildPassportPreview()),
      ),
    );
  }

  Widget _buildPage2Grid() {
    return OnboardingGridShell(
      leftPane: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: OnboardingTokens.leftPaneMaxWidth,
            ),
            child: _buildPage2LeftStack(),
          ),
        ),
      ),
      rightPane: ColoredBox(
        color: OnboardingTokens.panelTint,
        child: Center(child: _buildPassportPreview()),
      ),
    );
  }

  Widget _buildSeekerHousingPageGrid() {
    return OnboardingGridShell(
      leftPane: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: OnboardingTokens.leftPaneMaxWidth,
            ),
            child: _buildSeekerHousingPageStack(),
          ),
        ),
      ),
      rightPane: ColoredBox(
        color: OnboardingTokens.panelTint,
        child: Center(child: _buildPassportPreview()),
      ),
    );
  }

  Widget _buildSeekerCommutePageGrid() {
    return OnboardingGridShell(
      leftPane: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: OnboardingTokens.leftPaneMaxWidth,
            ),
            child: _buildSeekerCommutePageStack(),
          ),
        ),
      ),
      rightPane: ColoredBox(
        color: OnboardingTokens.panelTint,
        child: Center(child: _buildPassportPreview()),
      ),
    );
  }

  Widget _buildNavBar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: OnboardingTokens.leftPaneMaxWidth,
        ),
        child: Row(
          children: [
            if (_currentPage == 0 &&
                _onboardingIntent == OnboardingUserIntent.seeker)
              FilledButton(
                onPressed: () {
                  if (_validatePage1()) _goToPage(1);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  minimumSize: const Size(220, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Next: Set Match Preferences →',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            if (_currentPage == 0 &&
                _onboardingIntent == OnboardingUserIntent.provider)
              FilledButton(
                onPressed: _completeProviderOnboarding,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  minimumSize: const Size(220, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save host profile →',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            if (_currentPage == 1 &&
                _onboardingIntent == OnboardingUserIntent.seeker)
              FilledButton(
                onPressed: () {
                  if (!_validateSeekerHousingPage()) return;
                  setState(_syncPreferredRoommateLanguagesFromIdentity);
                  _goToPage(2);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  minimumSize: const Size(220, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Next: Commute & finalize →',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            if (_currentPage == 2 &&
                _onboardingIntent == OnboardingUserIntent.seeker)
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  minimumSize: const Size(180, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save changes',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            if (_currentPage == 1 &&
                _onboardingIntent != OnboardingUserIntent.seeker)
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  minimumSize: const Size(180, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save changes',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
          ],
        ),
      ),
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

  Widget _buildPassportPreview() {
    final languages = _dedupedSpokenLanguages();
    final isProvider = _onboardingIntent == OnboardingUserIntent.provider;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _nameController,
      builder: (context, nameValue, _) {
        return PassportPreviewCard(
          displayName: nameValue.text.trim(),
          location: isProvider
              ? ''
              : _resolvedPassportLocation(),
          languages: languages,
          isProvider: isProvider,
        );
      },
    );
  }

  List<String> _dedupedSpokenLanguages() {
    final seen = <String>{};
    final result = <String>[];
    for (final language in [
      _selectedMotherTongue,
      ..._selectedLanguages,
    ]) {
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

  Widget _buildTrackModeSelector() {
    final isProvider = _onboardingIntent == OnboardingUserIntent.provider;
    final isShared = isProvider
        ? _providerSharedSpace
        : ProfileSeekerPreferences.isSharedRoom(preferredArrangement);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Space track',
          style: OnboardingTokens.sectionLabelStyle,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: OnboardingTokens.chipSpacing,
          runSpacing: OnboardingTokens.chipSpacing,
          children: [
            FilterChip(
              label: const Text('🏠 Entire Place'),
              selected: !isShared,
              onSelected: (_) => setState(() {
                if (isProvider) {
                  _providerSharedSpace = false;
                } else {
                  preferredArrangement =
                      ProfileSeekerPreferences.entirePlaceLabel;
                }
              }),
              selectedColor: const Color(0xFF0F172A),
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: !isShared ? Colors.white : const Color(0xFF334155),
                fontWeight: !isShared ? FontWeight.w600 : FontWeight.w500,
              ),
              backgroundColor: OnboardingTokens.chipUnselected,
              side: BorderSide(
                color: !isShared
                    ? const Color(0xFF0F172A)
                    : OnboardingTokens.inputBorder,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            FilterChip(
              label: Text(
                isProvider ? '🛏️ Shared Space' : '🛏️ Shared Space',
              ),
              selected: isShared,
              onSelected: (_) => setState(() {
                if (isProvider) {
                  _providerSharedSpace = true;
                } else {
                  preferredArrangement =
                      ProfileSeekerPreferences.sharedRoomLabel;
                }
              }),
              selectedColor: const Color(0xFF0F172A),
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isShared ? Colors.white : const Color(0xFF334155),
                fontWeight: isShared ? FontWeight.w600 : FontWeight.w500,
              ),
              backgroundColor: OnboardingTokens.chipUnselected,
              side: BorderSide(
                color: isShared
                    ? const Color(0xFF0F172A)
                    : OnboardingTokens.inputBorder,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPage1FormContent() {
    final isSeeker = _onboardingIntent == OnboardingUserIntent.seeker;
    final isProvider = !isSeeker;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Let\'s get to know you',
          style: OnboardingTokens.pageTitleStyle,
        ),
        const SizedBox(height: 8),
        const Text(
          'Set up your core profile details to help find your ideal match.',
          style: OnboardingTokens.pageSubtitleStyle,
        ),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        if (_showOnboardingIntentSplitter) ...[
          OnboardingIntentSplitter(
            selected: _onboardingIntent,
            onChanged: (intent) => setState(() => _onboardingIntent = intent),
          ),
          const SizedBox(height: OnboardingTokens.fieldSpacing),
          _buildTrackModeSelector(),
          const SizedBox(height: OnboardingTokens.fieldSpacing),
        ],
        _buildCompletionHeader(),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        _premiumTextField(
          _emailController,
          label: '✉️ Email',
          hint: 'you@company.com',
        ),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        _premiumTextField(
          _nameController,
          label: '📝 Full name',
          hint: 'As on your ID',
          onChanged: () => setState(() {}),
        ),
        if (isProvider) ...[
          const SizedBox(height: OnboardingTokens.fieldSpacing),
          const Text(
            '📞 Contact phone (optional)',
            style: OnboardingTokens.sectionLabelStyle,
          ),
          const SizedBox(height: 4),
          const Text(
            'Shared with shortlisted applicants only — not shown on listings.',
            style: TextStyle(
              fontSize: 12,
              color: OnboardingTokens.subtitleColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: ShadcnSelect(
                  label: 'Code',
                  value: _phoneCountryCode,
                  options: PhoneE164.commonCountryCodes,
                  onChanged: (v) => setState(() => _phoneCountryCode = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _premiumTextField(
                  _contactPhoneController,
                  label: 'Phone number',
                  hint: '851234567',
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reach me on WhatsApp'),
            subtitle: const Text('Opens WhatsApp after you shortlist an applicant'),
            value: _prefersWhatsapp,
            onChanged: (v) => setState(() => _prefersWhatsapp = v),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'We process contact details under our privacy policy. '
              'Phone numbers are never shown on public listings.',
              style: TextStyle(
                fontSize: 11,
                color: OnboardingTokens.subtitleColor,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: OnboardingTokens.fieldSpacing),
          _premiumTextField(
            _agencyController,
            label: '🏢 Agency or company name (optional)',
            hint: 'Only if you list as a business',
          ),
        ],
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        if (isSeeker) ...[
          if (MarketConfig.current.profileUseAreaPicker)
            ShadcnSelect(
              label: '📍 Current Location / Base',
              value: _locationSelectValue,
              options:
                  MarketConfig.current.areaOptions.map((e) => e.$2).toList(),
              onChanged: (label) {
                setState(() {
                  for (final (key, areaLabel)
                      in MarketConfig.current.areaOptions) {
                    if (areaLabel == label) {
                      _selectedAreaKey = key;
                      _locationController.text = areaLabel;
                      break;
                    }
                  }
                });
              },
            )
          else
            _premiumTextField(
              _locationController,
              label: '📍 Current Location / Base',
              hint: 'e.g. ${MarketConfig.current.defaultProfileLocation}',
              onChanged: () => setState(() {
                _locationController.text = _formatLocationDisplay(
                  _locationController.text,
                );
              }),
            ),
        ],
        if (isProvider) ...[
          const Text(
            'Property address',
            style: OnboardingTokens.sectionLabelStyle,
          ),
          const SizedBox(height: 8),
          EircodeAddressField(
            controller: _propertyAddressSearchController,
            enabled: true,
            selected: _selectedPropertyAddress,
            hideExactAddress: _hidePropertyExactAddress,
            fetchingLocation: _fetchingPropertyLocation,
            showLocationButton: true,
            onSelected: _onPropertyAddressSelected,
            onHideExactAddressChanged: (v) =>
                setState(() => _hidePropertyExactAddress = v),
            onUseCurrentLocation: _usePropertyCurrentLocation,
          ),
          const SizedBox(height: OnboardingTokens.fieldSpacing),
          if (MarketConfig.current.profileUseAreaPicker)
            ShadcnSelect(
              label: 'Property area (fallback)',
              value: _providerLocationSelectValue,
              options:
                  MarketConfig.current.areaOptions.map((e) => e.$2).toList(),
              onChanged: (label) {
                setState(() {
                  for (final (key, areaLabel)
                      in MarketConfig.current.areaOptions) {
                    if (areaLabel == label) {
                      _providerAreaKey = key;
                      _propertyLocationController.text = areaLabel;
                      break;
                    }
                  }
                });
              },
            ),
          const SizedBox(height: OnboardingTokens.fieldSpacing),
          if (_providerSharedSpace) ...[
            _groupCard(
              title: 'Current household composition',
              subtitle: 'Who lives in the home now.',
              children: [
                _counterRow(
                  label: 'Current housemates',
                  value: _providerHousemateCount,
                  min: 1,
                  max: 12,
                  onChanged: (v) => setState(() => _providerHousemateCount = v),
                ),
                SwitchListTile(
                  title: const Text('Owner occupier'),
                  value: _providerIsOwnerOccupier,
                  onChanged: (v) => setState(() => _providerIsOwnerOccupier = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: OnboardingTokens.fieldSpacing),
            _groupCard(
              title: 'House rules',
              subtitle: 'Defaults that will carry into your room listing.',
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in const [
                      ('🚭', 'No smoking'),
                      ('🚫', 'No pets'),
                      ('🥦', 'Veg kitchen'),
                      ('🧑‍💻', 'WFH friendly'),
                    ])
                      GestureDetector(
                        onTap: () => setState(() {
                          if (_providerHouseRules.contains(entry.$2)) {
                            _providerHouseRules.remove(entry.$2);
                          } else {
                            _providerHouseRules.add(entry.$2);
                          }
                        }),
                        child: ListingRuleChip(
                          emoji: entry.$1,
                          label: entry.$2,
                          active: _providerHouseRules.contains(entry.$2),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ] else ...[
            _groupCard(
              title: 'Listing defaults',
              subtitle: 'Seeds your property form without asking twice.',
              children: [
                SwitchListTile(
                  title: const Text('Property is furnished'),
                  value: _providerIsFurnished,
                  onChanged: (v) => setState(() => _providerIsFurnished = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ],
        ],
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        MotherTongueTypeaheadField(
          value: _selectedMotherTongue,
          onChanged: _onMotherTongueChanged,
        ),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        OnboardingSpokenLanguageChips(
          languages: _dedupedSpokenLanguages(),
          motherTongue: _selectedMotherTongue,
          onRemove: _removeSpokenLanguage,
          onAdd: _addSpokenLanguage,
        ),
      ],
    );
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
              if (val != 'Students') _selectedStudentType = null;
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
          if (_selectedOccupantType == 'Students')
            ShadcnSelect(
              label: 'Student funding',
              value: _selectedStudentType ?? _studentFundingOptions.first,
              options: _studentFundingOptions,
              onChanged: (v) => setState(() => _selectedStudentType = v),
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
                onSelected: (_) => setState(() => _sharedFoodPref = option),
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
      _buildRootsAndTrustSection(showNativePlaceField: false),
    ];
  }

  List<Widget> _buildSeekerSharedSpaceSections() {
    return [
      ..._buildSeekerSharedSpaceHousingSections(),
      const SizedBox(height: 16),
      ..._buildSeekerSharedSpaceFinalizeSections(),
    ];
  }

  Widget _buildRootsAndTrustSection({bool showNativePlaceField = true}) {
    return _groupCard(
      title: 'Roots & trust',
      subtitle: 'Optional extras that boost credibility and matching quality.',
      children: [
        if (showNativePlaceField)
          _textField(
            _nativePlaceController,
            label: 'Native place',
            hint: MarketConfig.current.profileNativePlaceHint,
            onChanged: () => setState(() {}),
          ),
        _GrandVerificationGatewayEntry(
          linkedInVerified: _baselineProfile?['linkedin_verified'] == true,
          company: ProfileData.text(_baselineProfile?['company']),
          onTap: () => VerificationGatewayBottomSheet.show(context),
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
        _textField(
          _earliestMoveInController,
          label: 'Earliest move-in date',
          hint: 'YYYY-MM-DD',
          onChanged: () => setState(() {}),
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
        maxCommuteMinutes = maxCommuteMinutes ?? 45;

  String methodLabel;
  DublinCommuterHub? hub;
  double maxCommuteMinutes;
}

class _GrandVerificationGatewayEntry extends StatelessWidget {
  const _GrandVerificationGatewayEntry({
    required this.linkedInVerified,
    required this.company,
    required this.onTap,
  });

  final bool linkedInVerified;
  final String company;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = linkedInVerified
        ? 'Connected — $company · tap to manage verification paths'
        : 'Upgrade to 👍 Grand via corporate docs or instant bank link';

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
                    Icons.workspace_premium_outlined,
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
                              '👍 Grand',
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
                        style: AppTypography.caption.copyWith(height: 1.4),
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
