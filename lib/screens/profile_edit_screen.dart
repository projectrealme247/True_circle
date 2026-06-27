import 'package:flutter/material.dart';
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
import '../utils/listing_data.dart';
import '../models/spoken_language_entry.dart';
import '../utils/profile_data.dart';
import '../utils/spoken_language_profile_codec.dart';
import '../widgets/commute_hub_autocomplete_field.dart';
import '../debug/agent_log.dart';
import '../widgets/gamified_form_wizard.dart';
import '../widgets/language_pill_chips.dart';
import '../widgets/onboarding/live_transit_simulator_panel.dart';
import '../widgets/onboarding/onboarding_design_tokens.dart';
import '../widgets/onboarding/onboarding_grid_shell.dart';
import '../widgets/onboarding/onboarding_premium_field.dart';
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
    'Single Room',
    'Double Room',
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
    final layout = ProfileData.text(profile['preferred_layout']);
    if (layout.isEmpty) return null;
    final options = activeLayoutOptions(preferredArrangement);
    return options.contains(layout) ? layout : null;
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

/// Dublin expat languages for shared-flat roommate matching (no English).
abstract final class ProfileSharedLanguageOptions {
  static const languages = [
    'Hindi',
    'Malayalam',
    'Telugu',
    'Tamil',
    'Gujarati',
    'Kannada',
    'Punjabi',
    'Bengali',
  ];
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
  static const _pageCount = 2;
  int _currentPage = 0;
  bool _hydrating = true;
  Map<String, dynamic>? _baselineProfile;

  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _nativePlaceController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  final _netMonthlyIncomeController = TextEditingController();
  final _partnerNetMonthlyIncomeController = TextEditingController();
  final _hapVoucherContributionController = TextEditingController();
  final _earliestMoveInController = TextEditingController();
  String _selectedMotherTongue = 'English';
  String _kitchenUsageTiming = ListingData.kitchenUsageTimingOptions.first;
  final List<String> _selectedLanguages = [];
  final Map<String, bool> _languageNativeFlags = {};
  final List<_CommuterDraftEntry> _commuterDrafts = [];
  double _maxCommuteBudgetMinutes = 45;
  DualCommutePriority _dualCommutePriority = DualCommutePriority.balanced;
  int? _preferredLeaseMonths;
  bool _hasHapVoucher = false;
  bool _hapUpliftApproved = false;
  bool _hasVerifiedGuarantor = false;
  bool _householdHasPets = false;
  bool _householdSmoker = false;
  final List<String> _preferredSpokenLanguages = [];
  String _sharedFoodPref = 'Veg';
  String? _selectedAreaKey;
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
    if (_familyAdults >= 2 ||
        _groupSize >= 2 ||
        _selectedOccupantType == 'Family') {
      return 2;
    }
    return 1;
  }

  List<String> get _languageOptions => MarketConfig.current.profileLanguageOptions;

  List<String> get _otherLanguageOptions =>
      _languageOptions.where((l) => l != _selectedMotherTongue).toList();
  static const _sharedFoodChipOptions = ['Veg', 'Non-Veg'];
  List<String> get _occupantOptions => MarketConfig.current.profileOccupantOptions;

  String get _resolvedOccupantType =>
      _selectedOccupantType ?? _occupantOptions.first;
  List<String> get _genderPrefOptions =>
      MarketConfig.current.profileGenderPrefOptions;
  List<String> get _studentFundingOptions =>
      MarketConfig.current.profileStudentFundingOptions;

  String get _resolvedPreferredLayout => ProfileSeekerPreferences.resolveLayout(
        preferredArrangement,
        preferredLayout,
      );

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
    _bootstrap();
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
    _selectedLanguages
      ..clear()
      ..add(market.defaultMotherTongue);
    _languageNativeFlags
      ..clear()
      ..[market.defaultMotherTongue] = true;
    if (market.profileUseAreaPicker) {
      _selectedAreaKey = market.defaultAreaKey;
      _locationController.text = market.defaultAreaDisplayName;
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
    if (mother.isNotEmpty && _languageOptions.contains(mother)) {
      _selectedMotherTongue = mother;
    }

    _hydrateCommutersFromProfile(profile);

    final maxCommute = profile['maximum_commute_budget_minutes'];
    if (maxCommute is num && maxCommute > 0) {
      _maxCommuteBudgetMinutes = maxCommute.toDouble();
    }
    _dualCommutePriority = ListingData.dualCommutePriority(profile);

    final preferredLangs = profile['preferred_spoken_languages'];
    if (preferredLangs is List) {
      _preferredSpokenLanguages
        ..clear()
        ..addAll(
          preferredLangs
              .map((e) => e.toString())
              .where(ProfileSharedLanguageOptions.languages.contains),
        );
    }

    final food = ProfileData.text(profile['food_preference']);
    if (food.isNotEmpty) {
      _sharedFoodPref = ProfileSeekerPreferences.sharedFoodFromBackend(food);
    }

    _kitchenUsageTiming = ListingData.hydrateKitchenUsageTiming(profile);

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
  }

  @override
  void dispose() {
    profileStateNotifier.endEditing();
    _emailController.dispose();
    _nameController.dispose();
    _nativePlaceController.dispose();
    _locationController.dispose();
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

  void _clearSharedRoomFilters() {
    _preferredSpokenLanguages.clear();
    _sharedFoodPref = 'Veg';
    _kitchenUsageTiming = ListingData.kitchenUsageTimingOptions.first;
    _smokingOk = false;
    _drinkingOk = false;
    _scheduleType = null;
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
      'dual_commute_priority': switch (_dualCommutePriority) {
        DualCommutePriority.personA => 'person_a',
        DualCommutePriority.personB => 'person_b',
        DualCommutePriority.balanced => 'balanced',
      },
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
      'kitchen_usage_timing': _kitchenUsageTiming,
      if (_preferredSpokenLanguages.isNotEmpty) ...{
        'preferred_spoken_languages':
            List<String>.from(_preferredSpokenLanguages),
        'preferred_spoken_languages_csv':
            _preferredSpokenLanguages.join(', '),
      },
    };
  }

  String _resolvedCity() {
    if (MarketConfig.current.profileUseAreaPicker && _selectedAreaKey != null) {
      for (final (key, label) in MarketConfig.current.areaOptions) {
        if (key == _selectedAreaKey) return label;
      }
    }
    return _formatLocationDisplay(_locationController.text.trim());
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

  void _syncMotherTongueInLanguages(String previousMotherTongue) {
    if (!_selectedLanguages.contains(_selectedMotherTongue)) {
      _selectedLanguages.add(_selectedMotherTongue);
    }
    if (previousMotherTongue != _selectedMotherTongue &&
        _selectedLanguages.contains(previousMotherTongue)) {
      _selectedLanguages.remove(previousMotherTongue);
    }
    if (previousMotherTongue != _selectedMotherTongue) {
      _languageNativeFlags.remove(previousMotherTongue);
    }
    _languageNativeFlags[_selectedMotherTongue] = true;
  }

  void _onMotherTongueChanged(String value) {
    setState(() {
      final previous = _selectedMotherTongue;
      _selectedMotherTongue = value;
      _syncMotherTongueInLanguages(previous);
    });
  }

  void _toggleLanguage(String lang) {
    if (lang == _selectedMotherTongue) return;
    setState(() {
      if (_selectedLanguages.contains(lang)) {
        if (_selectedLanguages.length > 1) {
          _selectedLanguages.remove(lang);
          _languageNativeFlags.remove(lang);
        }
      } else {
        _selectedLanguages.add(lang);
      }
    });
  }

  void _toggleLanguageNative(String lang) {
    if (lang == _selectedMotherTongue || !_selectedLanguages.contains(lang)) {
      return;
    }
    setState(() {
      _languageNativeFlags[lang] = !(_languageNativeFlags[lang] ?? false);
    });
  }

  void _selectKitchenUsageTiming(String timing) {
    setState(() => _kitchenUsageTiming = timing);
  }

  bool _validatePage1() {
    if (_emailController.text.trim().isEmpty) {
      _showMessage('Please enter your email.');
      return false;
    }
    if (_nameController.text.trim().isEmpty || _resolvedCity().isEmpty) {
      _showMessage('Please fill in your name and area.');
      return false;
    }
    if (_selectedLanguages.isEmpty) {
      _showMessage('Select at least one language.');
      return false;
    }
    return true;
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _pageCount) return;
    setState(() => _currentPage = page);
  }

  bool _validate() {
    if (_emailController.text.trim().isEmpty) {
      _showMessage('Please enter your email.');
      return false;
    }
    if (_nameController.text.trim().isEmpty || _resolvedCity().isEmpty) {
      _showMessage('Please fill in your name and area.');
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
    final payload = {
      ...baseline,
      'email': _emailController.text.trim(),
      'full_name': _nameController.text.trim(),
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
    return ApplicantSessionSync.enrich(payload);
  }

  Future<void> _save() async {
    if (!_validate()) return;
    final synced = await AuthService.persistProfileSession(_buildPayload());
    if (!mounted) return;
    setState(() {
      _baselineProfile = Map<String, dynamic>.from(synced);
    });
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

    return Scaffold(
      backgroundColor: OnboardingTokens.canvasBg,
      appBar: AppBar(
        backgroundColor: OnboardingTokens.canvasBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: OnboardingTokens.gridPadding,
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
                      GamifiedFormProgress(current: _currentPage, total: 2),
                      const SizedBox(height: 32),
                      Expanded(
                        child: IndexedStack(
                          index: _currentPage,
                          children: [
                            _buildPage1Grid(),
                            _buildPage2Grid(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildNavBar(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

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
      rightPane: Padding(
        padding: const EdgeInsets.only(
          top: OnboardingTokens.page2SimulatorTopOffset,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: _buildLiveSearchStrategySidebar(),
        ),
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
            if (_currentPage == 0)
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
            if (_currentPage == 1)
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

  Widget _buildPage2LeftStack() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPage2Header(),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        _buildPage2SectionAHousingBudget(),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        if (_commuterDrafts.isNotEmpty) ...[
          _buildPrimaryRouteCard(),
          if (_commuterDrafts.length > 1) ...[
            const SizedBox(height: OnboardingTokens.fieldSpacing),
            _buildSecondaryRouteCard(1),
            const SizedBox(height: OnboardingTokens.fieldSpacing),
            _buildCommutePriorityCheckboxRow(horizontal: true),
          ],
          const SizedBox(height: OnboardingTokens.fieldSpacing),
        ],
        ..._buildPage2LowerSections(),
      ],
    );
  }

  Widget _buildPage2SectionAHousingBudget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Housing goals',
          style: OnboardingTokens.sectionLabelStyle,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: OnboardingTokens.chipSpacing,
          runSpacing: OnboardingTokens.chipSpacing,
          children: ProfileSeekerPreferences.arrangementOptions.map((option) {
            final selected = preferredArrangement == option;
            return FilterChip(
              label: Text(
                option == ProfileSeekerPreferences.entirePlaceLabel
                    ? 'Entire Place'
                    : 'Room in Shared Flat',
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              selected: selected,
              onSelected: (_) => setState(() {
                preferredArrangement = option;
                preferredLayout = null;
                if (ProfileSeekerPreferences.isEntirePlace(option)) {
                  _clearSharedRoomFilters();
                }
                _syncCommuterDraftSlots();
              }),
              selectedColor: const Color(0xFF0F172A),
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xFF334155),
              ),
              backgroundColor: OnboardingTokens.chipUnselected,
              side: BorderSide(
                color: selected
                    ? const Color(0xFF0F172A)
                    : OnboardingTokens.inputBorder,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        const Text(
          'Monthly budget',
          style: OnboardingTokens.sectionLabelStyle,
        ),
        const SizedBox(height: 8),
        Text(
          '${MarketConfig.current.currencySymbol}${_monthlyBudgetDisplay()} / month',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        Slider(
          value: _monthlyBudgetSliderValue(),
          min: _monthlyBudgetSliderMin(),
          max: _monthlyBudgetSliderMax(),
          divisions: 20,
          label:
              '${MarketConfig.current.currencySymbol}${_monthlyBudgetDisplay()}',
          onChanged: (v) => setState(() {
            _budgetMaxController.text = v.round().toString();
            if (_budgetMinController.text.trim().isEmpty ||
                (int.tryParse(_budgetMinController.text) ?? 0) > v) {
              _budgetMinController.text =
                  (v * 0.75).round().toString();
            }
          }),
        ),
      ],
    );
  }

  double _monthlyBudgetSliderMin() =>
      MarketConfig.current.currencySymbol == '€' ? 800.0 : 5000.0;

  double _monthlyBudgetSliderMax() =>
      MarketConfig.current.currencySymbol == '€' ? 5000.0 : 80000.0;

  double _monthlyBudgetSliderValue() {
    final parsed = int.tryParse(_budgetMaxController.text.trim());
    if (parsed == null) return _monthlyBudgetSliderMin();
    return parsed
        .clamp(
          _monthlyBudgetSliderMin().round(),
          _monthlyBudgetSliderMax().round(),
        )
        .toDouble();
  }

  String _monthlyBudgetDisplay() => _monthlyBudgetSliderValue().round().toString();

  Widget _buildPassportPreview() {
    final languages = [
      _selectedMotherTongue,
      ..._selectedLanguages.where((l) => l != _selectedMotherTongue),
    ];
    return PassportPreviewCard(
      displayName: _nameController.text.trim(),
      location: _resolvedPassportLocation(),
      languages: languages,
    );
  }

  String _resolvedPassportLocation() {
    if (MarketConfig.current.profileUseAreaPicker) {
      return _locationSelectValue;
    }
    return _formatLocationDisplay(_locationController.text.trim());
  }

  Widget _buildPage1FormContent() {
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
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        if (MarketConfig.current.profileUseAreaPicker)
          ShadcnSelect(
            label: '🗺️ Your Current Location',
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
            label: '🗺️ Your Current Location',
            hint: 'e.g. ${MarketConfig.current.defaultProfileLocation}',
            onChanged: () => setState(() {
              _locationController.text = _formatLocationDisplay(
                _locationController.text,
              );
            }),
          ),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        ShadcnSelect(
          label: '🗣️ Mother tongue',
          value: _selectedMotherTongue,
          options: _languageOptions,
          onChanged: _onMotherTongueChanged,
        ),
        const SizedBox(height: OnboardingTokens.fieldSpacing),
        const Text(
          '🗣️ Languages spoken',
          style: OnboardingTokens.sectionLabelStyle,
        ),
        const SizedBox(height: 8),
        LanguagePillChips(
          options: _otherLanguageOptions,
          selected:
              _selectedLanguages.where((l) => l != _selectedMotherTongue).toList(),
          onToggle: _toggleLanguage,
          nativeByLanguage: _languageNativeFlags,
          onToggleNative: _toggleLanguageNative,
          spacing: OnboardingTokens.chipSpacing,
          runSpacing: OnboardingTokens.chipSpacing,
          unselectedBackgroundColor: const Color(0xFFF1F5F9),
        ),
      ],
    );
  }

  Widget _buildPage2Header() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search & match preferences',
          style: OnboardingTokens.pageTitleStyle,
        ),
        SizedBox(height: 8),
        Text(
          'Budget, housing goals, and the filters that power your ideal matches.',
          style: OnboardingTokens.pageSubtitleStyle,
        ),
      ],
    );
  }

  List<Widget> _buildPage2LowerSections() {
    return [
          _groupCard(
            title: 'Household details',
            subtitle: 'Layout, occupant type, and household composition.',
            children: [
              if (ProfileSeekerPreferences.isSharedRoom(preferredArrangement))
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
              if (ProfileSeekerPreferences.isEntirePlace(preferredArrangement))
                ShadcnSelect(
                  key: const ValueKey('seeker_property_layout'),
                  label: 'Property Layout',
                  value: ProfileSeekerPreferences.resolveLayout(
                    preferredArrangement,
                    preferredLayout,
                  ),
                  options: ProfileSeekerPreferences.rentPropertyLayoutOptions,
                  onChanged: (val) => setState(() => preferredLayout = val),
                ),
              ShadcnSelect(
                label: 'Occupant type',
                value: _resolvedOccupantType,
                options: _occupantOptions,
                onChanged: (val) => setState(() {
                  _selectedOccupantType = val;
                  if (val != 'Students') _selectedStudentType = null;
                  if (val == 'Family') {
                    _selectedGenderPref = null;
                    _groupSize = 1;
                  } else {
                    _familyAdults = 2;
                    _familyChildren = 0;
                  }
                  _syncCommuterDraftSlots();
                }),
              ),
              if (_selectedOccupantType == 'Family') ...[
                _counterRow(
                  label: 'Number of adults',
                  value: _familyAdults,
                  min: 1,
                  max: 10,
                  onChanged: (v) => setState(() {
                    _familyAdults = v;
                    _syncCommuterDraftSlots();
                  }),
                ),
                _counterRow(
                  label: 'Number of children',
                  value: _familyChildren,
                  min: 0,
                  max: 8,
                  onChanged: (v) => setState(() {
                    _familyChildren = v;
                    _syncChildrenAgesList();
                  }),
                ),
                for (var i = 0; i < _familyChildren; i++)
                  ShadcnSelect(
                    label: 'Child ${i + 1} age',
                    value: i < _childrenAges.length
                        ? _childrenAges[i]
                        : _childrenAgeOptions.first,
                    options: _childrenAgeOptions,
                    onChanged: (val) => setState(() {
                      if (i < _childrenAges.length) {
                        _childrenAges[i] = val;
                      }
                    }),
                  ),
              ],
              if (_selectedOccupantType == 'Working Professionals' ||
                  _selectedOccupantType == 'Students') ...[
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
                  onChanged: (v) => setState(() {
                    _groupSize = v;
                    _syncCommuterDraftSlots();
                  }),
                ),
              ],
              if (_selectedOccupantType == 'Students')
                ShadcnSelect(
                  label: 'Student funding',
                  value: _selectedStudentType ?? _studentFundingOptions.first,
                  options: _studentFundingOptions,
                  onChanged: (v) => setState(() => _selectedStudentType = v),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _groupCard(
            title: 'Roots & trust',
            subtitle: 'Optional extras that boost credibility and roommate fit.',
            children: [
              _textField(
                _nativePlaceController,
                label: 'Native place',
                hint: MarketConfig.current.profileNativePlaceHint,
                onChanged: () => setState(() {}),
              ),
              _GrandVerificationGatewayEntry(
                linkedInVerified:
                    _baselineProfile?['linkedin_verified'] == true,
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
          ),
          if (ProfileSeekerPreferences.isSharedRoom(preferredArrangement)) ...[
            const SizedBox(height: 12),
            _groupCard(
              title: 'Shared flat filters',
              subtitle: 'Roommate language, food, and kitchen rhythm.',
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
                  "Languages you'd like housemates to speak (optional).",
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 8),
                LanguagePillChips(
                  options: ProfileSharedLanguageOptions.languages,
                  selected: _preferredSpokenLanguages,
                  onToggle: _togglePreferredSpokenLanguage,
                  spacing: 8,
                  runSpacing: 8,
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
                const SizedBox(height: 12),
                const Text(
                  'Preferred kitchen usage times',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                LanguagePillChips(
                  options: ListingData.kitchenUsageTimingOptions,
                  selected: [_kitchenUsageTiming],
                  onToggle: _selectKitchenUsageTiming,
                  spacing: 8,
                  runSpacing: 8,
                ),
              ],
            ),
          ],
          if (ProfileSeekerPreferences.isSharedRoom(preferredArrangement) &&
              (_selectedOccupantType == 'Working Professionals' ||
                  _selectedOccupantType == 'Students')) ...[
            const SizedBox(height: 12),
            _groupCard(
              title: 'Shared living preferences',
              subtitle: 'Lifestyle filters for roommate matching.',
              children: [
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
          ],
          if (ProfileSeekerPreferences.isEntirePlace(preferredArrangement)) ...[
            const SizedBox(height: 12),
            _buildLeaseHouseholdSection(),
          ],
    ];
  }

  Widget _buildPrimaryRouteCard() {
    return _condensedRouteCard(
      title: 'Primary Commuter Route',
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
    return _condensedRouteCard(
      title: 'Secondary Commuter Route',
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
          CommuteHubAutocompleteField(
            label: 'Destination',
            selectedHub: draft.hub,
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

  Widget _buildCommutePriorityCheckboxRow({required bool horizontal}) {
    const choices = [
      (DualCommutePriority.personA, 'Commuter 1'),
      (DualCommutePriority.personB, 'Commuter 2'),
      (DualCommutePriority.balanced, 'Balanced'),
    ];

    return _groupCard(
      title: 'Commute Optimization Priority',
      subtitle:
          'If your household has multiple commuters, whose destination anchors the matching score?',
      children: [
        if (!horizontal)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < choices.length; i++) ...[
                if (i > 0) const SizedBox(height: 4),
                _commutePriorityCheckbox(
                  priority: choices[i].$1,
                  label: choices[i].$2,
                ),
              ],
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < choices.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: const Color(0xFFE2E8F0),
                  ),
                Expanded(
                  child: _commutePriorityCheckbox(
                    priority: choices[i].$1,
                    label: choices[i].$2,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _commutePriorityCheckbox({
    required DualCommutePriority priority,
    required String label,
  }) {
    final selected = _dualCommutePriority == priority;

    return InkWell(
      onTap: () => setState(() => _dualCommutePriority = priority),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: selected,
                onChanged: (_) =>
                    setState(() => _dualCommutePriority = priority),
                activeColor: const Color(0xFF2B4C7E),
                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF475569),
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveSearchStrategySidebar() {
    final copy = _liveSearchStrategyCopy();
    final hasDual = _commuterDrafts.length > 1;
    final primary = _commuterDrafts.first;
    final secondary = hasDual ? _commuterDrafts[1] : null;

    return LiveTransitSimulatorPanel(
      headline: copy.headline,
      summary: copy.summary,
      priority: _dualCommutePriority,
      primaryMethod: primary.methodLabel,
      secondaryMethod: secondary?.methodLabel,
      primaryHub: _shortHubLabel(primary.hub?.label ?? 'Primary route'),
      secondaryHub: secondary == null
          ? null
          : _shortHubLabel(secondary.hub?.label ?? 'Secondary route'),
      dualCommuter: hasDual,
    );
  }

  String _shortHubLabel(String label) {
    if (label.length <= 28) return label;
    return '${label.substring(0, 26)}…';
  }

  ({
    String emoji,
    String headline,
    String summary,
    List<String> routeBullets,
  }) _liveSearchStrategyCopy() {
    final primary = _commuterDrafts.first;
    final primaryHub =
        primary.hub?.label ?? 'your primary Dublin destination';
    final primaryMethod = primary.methodLabel;
    final budget = _selectedBudgetTime;
    final marketLabel = MarketConfig.current.profileCityLabel.contains('Dublin')
        ? 'Dublin'
        : MarketConfig.current.appTitle;

    if (_commuterDrafts.length == 1) {
      return (
        emoji: '🏎️',
        headline: 'Single-route optimization',
        summary:
            'Optimizing feed for high-speed $marketLabel transit access to $primaryHub within $budget minutes.',
        routeBullets: [
          'Primary: $primaryMethod → $primaryHub',
          'Household cap: $budget min door-to-door',
        ],
      );
    }

    final secondary = _commuterDrafts[1];
    final secondaryHub =
        secondary.hub?.label ?? 'your secondary destination';

    return switch (_dualCommutePriority) {
      DualCommutePriority.personA => (
          emoji: '🏎️',
          headline: 'Commuter 1 priority',
          summary:
              'Optimizing feed for high-speed $marketLabel transit links to $primaryHub — secondary route still visible but weighted lower.',
          routeBullets: [
            'Anchor: $primaryMethod → $primaryHub',
            'Secondary: ${secondary.methodLabel} → $secondaryHub',
            'Household cap: $budget min',
          ],
        ),
      DualCommutePriority.personB => (
          emoji: '🏎️',
          headline: 'Commuter 2 priority',
          summary:
              'Optimizing feed for transit access to $secondaryHub — primary route still visible but weighted lower.',
          routeBullets: [
            'Anchor: ${secondary.methodLabel} → $secondaryHub',
            'Secondary: $primaryMethod → $primaryHub',
            'Household cap: $budget min',
          ],
        ),
      DualCommutePriority.balanced => (
          emoji: '⚖️',
          headline: 'Balanced optimization',
          summary:
              'Balancing commute scores across both routes with gap mitigation — ideal for dual-income households across $marketLabel.',
          routeBullets: [
            'Route A: $primaryMethod → $primaryHub',
            'Route B: ${secondary.methodLabel} → $secondaryHub',
            'Household cap: $budget min',
          ],
        ),
    };
  }

  Widget _buildLeaseHouseholdSection() {
    final leaseLabels = ApplicantSessionSync.leaseTermOptions
        .map((months) => '$months months')
        .toList();
    final selectedLeaseLabel = _preferredLeaseMonths == null
        ? ''
        : '$_preferredLeaseMonths months';

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
            _preferredLeaseMonths =
                int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
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
