import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/market/dublin_districts.dart';
import '../../config/market/market_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/skeleton_placeholder.dart';
import '../../models/listing_creation_field_keys.dart';
import '../../models/listing_creation_form_models.dart';
import '../../models/move_in_timing.dart';
import '../../models/marketplace_space.dart';
import '../../models/seeker_onboarding_enums.dart';
import '../../models/neighborhood_amenity_tag.dart';
import '../../services/neighborhood_amenities_service.dart';
import '../../services/nominatim_forward.dart';
import '../../services/fast_location_service.dart';
import '../../services/eircode_geocoding_service.dart';
import '../../services/eircode_lookup_service.dart';
import '../../services/overpass_amenities_service.dart';
import '../../services/proximity_resolution_cache.dart';
import '../../services/structured_amenities_fallback_service.dart';
import '../../services/transit_extraction_service.dart';
import '../../utils/city_area_match.dart';
import '../../utils/listing_data.dart';
import '../../utils/listing_smart_copy_generator.dart';
import '../../utils/listing_strength_calculator.dart';
import '../../utils/onboarding_language_inference.dart';
import '../../utils/thousands_separator_formatter.dart';
import '../../utils/profile_data.dart';
import '../../utils/proximity_chip_keys.dart';
import '../../utils/proximity_display_builder.dart';
import '../../utils/proximity_phase1_policy.dart';
import '../../utils/target_search_areas.dart';
import '../../screens/auth_screen.dart';
import '../../models/irish_address_suggestion.dart';
import '../../utils/address_privacy.dart';
import '../../utils/irish_address_format.dart';
import '../../utils/listing_area_resolution.dart';
import '../gamified_form_wizard.dart';
import '../listing_media_picker.dart';
import '../onboarding/seeker/seeker_language_selection_section.dart';
import '../shadcn_select.dart';
import 'listing_creation_primitives.dart';
import 'location_pin_field.dart';
import 'unified_proximity_display.dart';

/// Dublin listing creation form — 3-step wizard with validate + buildPayload.
class ListingCreationForm extends StatefulWidget {
  const ListingCreationForm({
    super.key,
    this.initialListing,
    this.saving = false,
    this.onMessage,
    this.onPublish,
    this.onExit,
  });

  final Map<String, dynamic>? initialListing;
  final bool saving;
  final void Function(String message)? onMessage;
  final VoidCallback? onPublish;
  final VoidCallback? onExit;

  @override
  ListingCreationFormState createState() => ListingCreationFormState();
}

class ListingCreationFormState extends State<ListingCreationForm> {
  static const _dublinCenterLat = 53.349805;
  static const _dublinCenterLon = -6.26031;
  static const _standardMaxContentWidth = 720.0;
  static const _locationStepMaxContentWidth = 1140.0;
  static const demoEircodeHint = 'D02 X285';

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();
  final _step4Key = GlobalKey<FormState>();
  final _descriptionFieldKey = GlobalKey();
  late final PageController _pageController;

  int _currentStep = 0;
  bool _optionalEnhancementsExpanded = false;
  bool _photoTipsExpanded = false;
  int _expandedRoomIndex = 0;
  final Map<int, bool> _roomWasComplete = {};
  /// Remounts room text fields after Copy Room 1 (initialValue keys).
  int _roomFieldEpoch = 0;
  /// Rooms step: show inline missing-fields banner after Continue tap.
  bool _roomsStepContinueAttempted = false;
  /// Page 3 multi-room listing wizard — which room's photos/title/description.
  int _listingWizardRoomIndex = 0;

  // Agreement / tenure (shared TenurePreference tokens)
  TenurePreference? _agreementType;
  DateTime? _availableFrom;
  LandlordAvailabilityFlexibility? _availabilityFlexibility;
  final _subletDurationController = TextEditingController();
  SubletDurationUnit _subletDurationUnit = SubletDurationUnit.years;

  // Host identity (Independent Place — collected on listing, not host profile)
  final _hostNameController = TextEditingController();

  // Category
  late String _type;
  ListingPropertySubType? _propertySubType;
  bool? _isFurnished;
  ListingPetsPolicy? _petsPolicy;
  final Set<ListingParkingFeature> _parkingFeatures = {};
  /// Shared Spaces Page 1 only — Parking Available / Not Available.
  bool? _sharedParkingAvailable;
  /// Independent Places Page 1 — Level 1 parking radio (default: no parking).
  bool _ipParkingAvailable = false;

  // Financials
  final _titleController = TextEditingController();
  final _rentController = TextEditingController();
  final _depositController = TextEditingController();
  String? _berRating;

  // Independent layout
  int _bedrooms = 0;
  int _bathrooms = 0;

  // Media
  List<String> _images = [];
  String? _video;

  // Shared dynamics
  int _totalRoomsInProperty = 1;
  int _roomsToShare = 1;
  final List<SharedRoomSlot> _sharedRoomSlots = [SharedRoomSlot()];
  int _housemateCount = 1;
  FlatmateCohort? _householdCohort = FlatmateCohort.mixedCohort;
  final Set<String> _householdLanguages = {};
  String _householdPrimaryLanguage = '';
  final Set<String> _householdSecondaryLanguages = {};
  final Set<SharedHouseRule> _houseRules = {};
  bool _isOwnerOccupier = false;

  /// Multi-room inventory: room profile collected per room (not household).
  bool get _isMultiRoomInventory => _isShare && _roomsToShare > 1;

  /// Shared Spaces: 4 steps. Independent Places: 3 steps.
  int get _stepCount => _isShare ? 4 : 3;

  /// Shared Spaces: location is step 4 (index 3). Entire Place: location is step 2.
  bool get _isLocationWizardStep =>
      _isShare ? _currentStep == 3 : _currentStep == 1;

  List<String> get _wizardStepLabels => _isShare
      ? const ['Property', 'Rooms', 'Household', 'Location']
      : const ['Property', 'Location', 'Listing'];

  SharedRoomSlot? get _primaryRoomSlot =>
      _sharedRoomSlots.isEmpty ? null : _sharedRoomSlots.first;

  bool get _hasSharedBedRoom =>
      _sharedRoomSlots.any((s) => s.isSharedBed);

  static const _cohortSegmentLabels = {
    FlatmateCohort.workingProfessionals: 'Professionals',
    FlatmateCohort.students: 'Students',
    FlatmateCohort.mixedCohort: 'Mixed',
  };

  static final _cohortEmojis = {
    FlatmateCohort.workingProfessionals: '💼',
    FlatmateCohort.students: '🎓',
    FlatmateCohort.mixedCohort: '🔀',
  };

  List<String> get _suggestedHouseholdLanguages =>
      OnboardingLanguageInference.suggestedLanguagesFor(
        _householdPrimaryLanguage,
      );

  void _setTotalRoomsInProperty(int count) {
    final next = count.clamp(1, ListingCreationFormConstants.sharedSpacesMaxRooms);
    setState(() {
      _totalRoomsInProperty = next;
      if (_roomsToShare > next) {
        _applyRoomsToShare(next);
      }
    });
  }

  void _setRoomsToShare(int count) {
    final capped = count.clamp(
      1,
      _totalRoomsInProperty.clamp(
        1,
        ListingCreationFormConstants.sharedSpacesMaxRooms,
      ),
    );
    setState(() => _applyRoomsToShare(capped));
  }

  void _applyRoomsToShare(int next) {
    _roomsToShare = next;
    while (_sharedRoomSlots.length < next) {
      _sharedRoomSlots.add(
        SharedRoomSlot(
          roomProfile: FlatmateCohort.mixedCohort,
        ),
      );
    }
    while (_sharedRoomSlots.length > next) {
      _sharedRoomSlots.removeLast();
    }
    for (final slot in _sharedRoomSlots) {
      // Mixed is a terminal default — no further profile action required.
      slot.roomProfile ??= FlatmateCohort.mixedCohort;
    }
    _roomWasComplete.removeWhere((i, _) => i >= next);
    if (_expandedRoomIndex >= next) {
      _expandedRoomIndex = next - 1;
    }
    if (_listingWizardRoomIndex >= next) {
      _listingWizardRoomIndex = (next - 1).clamp(0, next - 1);
    }
  }

  bool _isRoomSlotComplete(SharedRoomSlot slot) {
    return _validateSharedRoomInventory(slot, index: 0) == null;
  }

  /// Collapse readiness — subset of card fields (not costs). Distinct from
  /// Continue validation so typing rent never mid-collapses the card.
  bool _isRoomCardReadyToCollapse(SharedRoomSlot slot) {
    final rentText = stripThousandsFormatting(slot.monthlyRent.trim());
    if (rentText.isEmpty || !RegExp(r'^\d+$').hasMatch(rentText)) {
      return false;
    }
    if ((int.tryParse(rentText) ?? 0) <= 0) return false;
    final agreement = TenurePreference.fromStorage(slot.agreementTypeToken);
    if (agreement == null || agreement == TenurePreference.flexible) {
      return false;
    }
    if (agreement == TenurePreference.temporary &&
        slot.temporaryDurationValue.trim().isEmpty) {
      return false;
    }
    if (slot.availableFrom == null) return false;
    final flex = LandlordAvailabilityFlexibility.parse(
      slot.availabilityFlexibilityToken,
    );
    if (slot.availabilityFlexibilityToken == null ||
        slot.availabilityFlexibilityToken!.isEmpty ||
        !LandlordAvailabilityFlexibility.sharedSpacesValues.contains(flex)) {
      return false;
    }
    // Suitable for always has a default; Shared Room needs current occupant.
    if (slot.isSharedBed && slot.currentOccupant == null) return false;
    if (slot.roomProfile == null) return false;
    return true;
  }

  void _tryCollapseRoomCard(int index) {
    final slot = _sharedRoomSlots[index];
    final ready = _isRoomCardReadyToCollapse(slot);
    final wasReady = _roomWasComplete[index] ?? false;
    _roomWasComplete[index] = ready;
    if (ready && !wasReady && _expandedRoomIndex == index) {
      var nextIncomplete = -1;
      for (var i = 0; i < _sharedRoomSlots.length; i++) {
        if (i == index) continue;
        if (!_isRoomSlotComplete(_sharedRoomSlots[i])) {
          nextIncomplete = i;
          break;
        }
      }
      _expandedRoomIndex = nextIncomplete;
    }
  }

  /// Chip/date changes may collapse immediately when the card becomes ready.
  void _afterRoomChoiceChanged(int index) {
    _tryCollapseRoomCard(index);
  }

  /// Text fields update state only — collapse on focus leave.
  void _afterRoomTextChanged(int index) {
    final ready = _isRoomCardReadyToCollapse(_sharedRoomSlots[index]);
    if (!ready) _roomWasComplete[index] = false;
  }

  bool get _shouldShowOccupancyWarning {
    if (!_housematesInteractedWith) return false;
    final capacity = _totalRoomsInProperty - _roomsToShare;
    return _housemateCount > capacity;
  }

  /// Visual in-page progress only — does not gate navigation alone.
  double _sharedInPageProgress() {
    if (!_isShare) return 0;
    if (_currentStep == 0) {
      var score = 0.0;
      if (_propertySubType != null) score += 0.35;
      if (_petsPolicy == ListingPetsPolicy.allowed ||
          _petsPolicy == ListingPetsPolicy.notAllowed) {
        score += 0.35;
      }
      if (_sharedParkingAvailable != null) score += 0.1;
      if (_totalRoomsInProperty >= 1) score += 0.1;
      if (_roomsToShare >= 1) score += 0.1;
      return score.clamp(0.0, 1.0);
    }
    if (_currentStep == 1) {
      if (_sharedRoomSlots.isEmpty) return 0.1;
      final complete =
          _sharedRoomSlots.where(_isRoomSlotComplete).length;
      return (complete / _sharedRoomSlots.length).clamp(0.0, 1.0);
    }
    if (_currentStep == 2) {
      var score = 0.0;
      if (_smokingPolicy != null) score += 0.4;
      score += 0.1; // languages optional-ish
      if (_isMultiRoomInventory) {
        final withPhotos =
            _sharedRoomSlots.where((s) => s.images.isNotEmpty).length;
        if (_sharedRoomSlots.isNotEmpty) {
          score += 0.5 * (withPhotos / _sharedRoomSlots.length);
        }
      } else if (_images.isNotEmpty) {
        score += 0.5;
      }
      return score.clamp(0.0, 1.0);
    }
    // Location step — coarse signal from resolvable pin.
    return _hasResolvableLocation() ? 0.7 : 0.15;
  }

  bool get _sharedCurrentStepReady {
    if (!_isShare) return true;
    return switch (_currentStep) {
      0 => _isSharedPropertyStepReady(),
      1 => _isSharedRoomsStepReady(),
      2 => _isSharedHouseholdListingReady(),
      3 => _validateStep2() == null,
      _ => true,
    };
  }

  bool _isSharedPropertyStepReady() {
    if (_propertySubType == null) return false;
    if (_roomsToShare < 1 || _roomsToShare > _totalRoomsInProperty) {
      return false;
    }
    return _sharedPetsParkingReady;
  }

  bool _isSharedRoomsStepReady() {
    if (_sharedRoomSlots.isEmpty) return false;
    return _sharedRoomSlots.every(_isRoomSlotComplete);
  }

  /// Shared Spaces Page 1 — pets required; parking is informational only.
  bool get _sharedPetsParkingReady {
    if (!_isShare) return true;
    return _petsPolicy == ListingPetsPolicy.allowed ||
        _petsPolicy == ListingPetsPolicy.notAllowed;
  }

  bool _isSharedHouseholdListingReady() {
    if (_smokingPolicy == null) return false;
    final minPhotos =
        ListingCreationFormConstants.sharedSpacesMinPhotoCount;
    if (_isMultiRoomInventory) {
      for (final slot in _sharedRoomSlots) {
        if (slot.images.length < minPhotos) return false;
      }
      return true;
    }
    if (_images.length < minPhotos) return false;
    return true;
  }

  String _plainListingDescription(String raw) =>
      ListingSmartCopyGenerator.stripMarkdown(raw);

  void _copyRoom1ToAllRooms() {
    if (_sharedRoomSlots.length < 2) return;
    final source = _sharedRoomSlots.first;
    setState(() {
      _roomFieldEpoch++;
      for (var i = 1; i < _sharedRoomSlots.length; i++) {
        final slot = _sharedRoomSlots[i];
        slot.roomKind = source.roomKind;
        slot.bathroomType = source.bathroomType;
        slot.roomProfile = source.roomProfile;
        slot.requiredOccupant = source.requiredOccupant;
        slot.tenantGender = source.tenantGender;
        slot.occupantType = source.occupantType;
        slot.electricityCost = source.electricityCost;
        slot.binsCost = source.binsCost;
        slot.internetCost = source.internetCost;
        slot.electricityIncluded = source.electricityIncluded;
        slot.binsIncluded = source.binsIncluded;
        slot.internetIncluded = source.internetIncluded;
        slot.agreementTypeToken = source.agreementTypeToken;
        slot.temporaryDurationValue = source.temporaryDurationValue;
        slot.temporaryDurationUnit = source.temporaryDurationUnit;
        slot.availabilityFlexibilityToken =
            source.availabilityFlexibilityToken;
        // Do not copy: monthlyRent, availableFrom, currentOccupant.
        _roomWasComplete[i] = false;
      }
      // Keep first incomplete room expanded so landlord can fill rent/date.
      var expandAt = -1;
      for (var i = 0; i < _sharedRoomSlots.length; i++) {
        if (!_isRoomSlotComplete(_sharedRoomSlots[i])) {
          expandAt = i;
          break;
        }
      }
      _expandedRoomIndex = expandAt;
    });
    _message(
      'Copied Room 1 settings to all rooms. Add rent and available-from for each.',
    );
  }

  List<String> _sharedRoomMissingRequiredKeys(SharedRoomSlot slot) {
    final missing = <String>[];
    final rentText = stripThousandsFormatting(slot.monthlyRent.trim());
    if (rentText.isEmpty ||
        !RegExp(r'^\d+$').hasMatch(rentText) ||
        (int.tryParse(rentText) ?? 0) <= 0) {
      missing.add('rent');
    }
    final agreement = TenurePreference.fromStorage(slot.agreementTypeToken);
    if (agreement == null ||
        agreement == TenurePreference.flexible ||
        (agreement == TenurePreference.temporary &&
            slot.temporaryDurationValue.trim().isEmpty)) {
      missing.add('lease');
    }
    if (slot.availableFrom == null) {
      missing.add('availableFrom');
    }
    final flex = LandlordAvailabilityFlexibility.parse(
      slot.availabilityFlexibilityToken,
    );
    if (slot.availabilityFlexibilityToken == null ||
        slot.availabilityFlexibilityToken!.isEmpty ||
        !LandlordAvailabilityFlexibility.sharedSpacesValues.contains(flex)) {
      missing.add('flexibility');
    }
    return missing;
  }

  int _sharedRoomMissingRequiredCount(SharedRoomSlot slot) =>
      _sharedRoomMissingRequiredKeys(slot).length;

  bool _sharedRoomFieldRequired(SharedRoomSlot slot, String key) =>
      _roomsStepContinueAttempted &&
      _sharedRoomMissingRequiredKeys(slot).contains(key);

  Widget _sharedRequiredFieldWrap({
    required bool showError,
    required Widget child,
  }) {
    if (!showError) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE53935), width: 1.5),
          ),
          child: child,
        ),
        const SizedBox(height: 4),
        const Text(
          'Required',
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: Color(0xFFE53935),
            height: 1.2,
          ),
        ),
      ],
    );
  }

  void _syncHouseholdLanguagesFromSeekerUi() {
    _householdLanguages
      ..clear()
      ..add('English');
    if (_householdPrimaryLanguage.trim().isNotEmpty &&
        _householdPrimaryLanguage.toLowerCase() != 'english') {
      _householdLanguages.add(_householdPrimaryLanguage.trim());
    }
    _householdLanguages.addAll(_householdSecondaryLanguages);
  }

  void _hydrateHouseholdLanguages(Iterable<String> langs) {
    _householdLanguages
      ..clear()
      ..addAll(langs);
    _householdPrimaryLanguage = '';
    _householdSecondaryLanguages.clear();
    for (final lang in langs) {
      final trimmed = lang.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.toLowerCase() == 'english') continue;
      if (_householdPrimaryLanguage.isEmpty) {
        _householdPrimaryLanguage = trimmed;
      } else {
        _householdSecondaryLanguages.add(trimmed);
      }
    }
  }

  // Shared monthly costs (per person)
  final _electricityCostController = TextEditingController();
  final _binsCostController = TextEditingController();
  final _internetCostController = TextEditingController();
  bool _electricityIncluded = false;
  bool _binsIncluded = false;
  bool _internetIncluded = false;

  // Location + proximity
  final _locationController = TextEditingController();
  final _locationIdentifierController = TextEditingController();
  final _eircodeController = TextEditingController();
  final _addressSearchController = TextEditingController();
  IrishAddressSuggestion? _selectedAddress;
  bool _hideExactAddress = false;
  String? _listingAreaKey;
  String _localityLabel = '';
  bool _sharedCostsShowErrors = false;
  bool _rentShowError = false;
  String? _rentErrorText;
  bool _depositShowError = false;
  String? _depositErrorText;
  bool _locationShowErrors = false;
  bool _titleShowError = false;
  String? _autoDraftedTitle;
  String? _autoDraftedDescription;
  final _sharedCostsSectionKey = GlobalKey();
  final _rentSectionKey = GlobalKey();
  final _depositSectionKey = GlobalKey();
  final _locationPanelKey = GlobalKey();
  final _titleFieldKey = GlobalKey();
  double? _resolvedLatitude;
  double? _resolvedLongitude;
  String? _reverseGeocodedAddress;
  bool _locationFromGps = false;
  bool _fetchingLocation = false;
  int _externalLocationEpoch = 0;
  String? _externalLocationLabel;
  bool _proximityResolving = false;
  bool _proximityResolved = false;
  int _proximityGeneration = 0;
  List<NearbyExtraTransit> _extraProximityTransit = [];
  NeighborhoodProximityDraft _proximityDraft = NeighborhoodProximityDraft();
  final _transportLineController = TextEditingController();
  final _transportWalkController = TextEditingController();
  final _groceryWalkController = TextEditingController();
  final _primarySchoolController = TextEditingController();
  final _secondarySchoolController = TextEditingController();
  final _crecheNameController = TextEditingController();
  final _crecheWalkController = TextEditingController();
  String _groceryBrand = '';
  List<NearbyGroceryOption> _profileGroceries = [];
  String _collegeSchool = '';
  int? _collegeWalkMin;
  String _gpClinic = '';
  int? _gpWalkMin;
  bool _proximityEditing = false;
  final List<_CustomProximityRowState> _customProximityRows = [];
  List<NeighborhoodAmenityTag> _neighborhoodAmenityTags = [];
  bool _neighborhoodAmenitiesLoading = false;
  bool _amenitiesEnrichmentInFlight = false;
  bool _showMoreLocalAmenities = false;

  // Lifestyle
  bool _smokingAllowed = false;
  ListingSmokingPolicy? _smokingPolicy = ListingSmokingPolicy.noSmoking;
  bool _vegetarianKitchen = false;
  bool _wfhFriendly = false;
  bool _descriptionEditorExpanded = false;
  bool _titleEditorExpanded = false;
  bool _housematesInteractedWith = false;

  /// Listing Accountability Phase 1 — required before Publish / Save.
  bool _listingAuthorizationConfirmed = false;

  // Description
  final _descriptionController = TextEditingController();
  bool _locationPrefillLocked = false;
  bool _categoryPrefillLocked = false;
  bool _rulesPrefillLocked = false;
  bool _furnishingPrefillLocked = false;

  /// Committed listing type drives the field set. Pending selection only
  /// highlights chips until Continue (Shared room must not navigate immediately).
  String? _pendingListingType;

  List<String> get _enabledPropertyTypes => MarketConfig.current.enabledTowers;

  MarketplaceSpace get _activeSpace =>
      MarketplaceSpace.fromTowerPropertyType(_type);

  bool get _isShare => _activeSpace == MarketplaceSpace.sharedSpace;

  bool get _listingTypeChipIsShare {
    final token = _pendingListingType ?? _type;
    return MarketplaceSpace.fromTowerPropertyType(token) ==
        MarketplaceSpace.sharedSpace;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _type = _enabledPropertyTypes.first;
    _seedHostNameFromProfile();
    if (widget.initialListing != null) {
      _hydrateFromListing(widget.initialListing!);
      // Profile inheritance banners/locks: Shared Living prefill only.
      if (_shouldApplyProfileInheritance(widget.initialListing!)) {
        _hydrateInheritedPrefill(widget.initialListing!);
      }
      _finalizeProfileDraftLocationSeed();
    }
    // Independent Place blank create: no location/language/profile defaults.
    if (_proximityDraft.transportLine.isNotEmpty) {
      _proximityResolved = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isProfileDraft(widget.initialListing) && !_locationFromGps) {
        if (_eircodeController.text.trim().isNotEmpty) {
          _resolveProximity();
        }
        return;
      }
      // Only pre-resolve when editing a listing that already has proximity saved.
      if (widget.initialListing != null &&
          _proximityDraft.transportLine.isNotEmpty) {
        return;
      }
    });
  }

  bool _isProfileDraft(Map<String, dynamic>? raw) {
    if (raw == null) return false;
    return raw.containsKey('prefill_listing_mode') ||
        raw.containsKey('prefill_is_furnished') ||
        raw.containsKey('prefill_house_rules') ||
        raw.containsKey('prefill_household_languages');
  }

  /// Shared Living profile drafts only — never Independent Place inheritance.
  bool _shouldApplyProfileInheritance(Map<String, dynamic> raw) {
    final mode = ProfileData.text(raw['prefill_listing_mode']).toLowerCase();
    return mode == 'shared_space';
  }

  void _finalizeProfileDraftLocationSeed() {
    if (!_isProfileDraft(widget.initialListing)) return;
    _addressSearchController.clear();
    _selectedAddress = null;
    if (_isNearDublinCityCentre(_resolvedLatitude, _resolvedLongitude)) {
      _resolvedLatitude = null;
      _resolvedLongitude = null;
    }
  }

  void _seedHostNameFromProfile() {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;
    final name = ProfileData.text(session['full_name']);
    if (name.isNotEmpty) {
      _hostNameController.text = name;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _subletDurationController.dispose();
    _hostNameController.dispose();
    _titleController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    _electricityCostController.dispose();
    _binsCostController.dispose();
    _internetCostController.dispose();
    _locationController.dispose();
    _locationIdentifierController.dispose();
    _eircodeController.dispose();
    _addressSearchController.dispose();
    _transportLineController.dispose();
    _transportWalkController.dispose();
    _groceryWalkController.dispose();
    _primarySchoolController.dispose();
    _secondarySchoolController.dispose();
    _crecheNameController.dispose();
    _crecheWalkController.dispose();
    _descriptionController.dispose();
    for (final row in _customProximityRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _hydrateFromListing(Map<String, dynamic> raw) {
    final item = ListingData.normalizeItem(raw);

    _titleController.text = ListingData.title(item);
    _rentController.text = formatThousandsForInput(
      _stripRentForInput(ListingData.price(item)),
    );
    final storedDeposit = ListingData.text(item['security_deposit']);
    if (storedDeposit.isNotEmpty) {
      _depositController.text = formatThousandsForInput(
        _stripRentForInput(storedDeposit),
      );
    }
    _locationController.text = ListingData.location(item);
    _eircodeController.text = ProfileData.text(
      item[ListingCreationFieldKeys.eircode] ?? item['eircode'],
    );
    _hideExactAddress = item[AddressPrivacy.hideExactAddressKey] == true;
    final storedAreaKey = ProfileData.text(item['listing_area_key']);
    if (storedAreaKey.isNotEmpty) {
      _listingAreaKey = storedAreaKey;
    } else {
      final blob = '${ListingData.location(item)} ${ListingData.hostCity(item)}';
      _listingAreaKey = CityAreaMatch.listingAreaKeyFromBlob(blob);
    }
    final publicLocation =
        ProfileData.text(item[AddressPrivacy.publicLocationKey]);
    if (publicLocation.isNotEmpty && _hideExactAddress) {
      _localityLabel = publicLocation.split(',').first.trim();
      _locationController.text = publicLocation;
    }
    final identifier = ProfileData.text(item['property_location_identifier']);
    if (identifier.isNotEmpty) {
      _locationIdentifierController.text = identifier;
    }
    _seedAddressSearchFromStoredFields(item);
    _descriptionController.text = ListingData.description(item);

    final propertyType = ListingData.propertyType(item);
    if (_enabledPropertyTypes.contains(propertyType)) {
      _type = propertyType;
    }

    _images = List<String>.from(ListingData.imageDataUris(item));
    _video = ListingData.videoDataUri(item);

    final agreement = TenurePreference.fromListing(item);
    if (agreement != null) {
      // Independent Place listings no longer offer Flexible → Long-Term.
      _agreementType = (!_isShare && agreement == TenurePreference.flexible)
          ? TenurePreference.longTerm
          : agreement;
    }

    final availableRaw = item['available_from'];
    if (availableRaw is String && availableRaw.isNotEmpty) {
      _availableFrom = DateTime.tryParse(availableRaw);
    }
    _availabilityFlexibility = LandlordAvailabilityFlexibility.fromListing(item);
    // Independent Place: legacy Fixed / Exact Date → Flexible.
    if (!_isShare) {
      _availabilityFlexibility =
          LandlordAvailabilityFlexibility.migrateIndependentPlace(
        _availabilityFlexibility!,
      );
    }

    _subletDurationController.text =
        ProfileData.text(item['sublet_duration_value']);
    final unitRaw = ProfileData.text(item['sublet_duration_unit']);
    _subletDurationUnit = _parseSubletUnit(unitRaw);

    final subType = ProfileData.text(item['property_sub_type']);
    if (subType == 'house') {
      _propertySubType = ListingPropertySubType.house;
    } else if (subType == 'apartment') {
      _propertySubType = ListingPropertySubType.apartment;
    } else {
      final category = ListingData.propertyCategory(item).toLowerCase();
      if (category.contains('house')) {
        _propertySubType = ListingPropertySubType.house;
      }
    }

    _berRating = ProfileData.text(item['ber_rating']).isEmpty
        ? null
        : ProfileData.text(item['ber_rating']);
    final furnishing = ListingData.furnishing(item).toLowerCase();
    if (furnishing.isNotEmpty) {
      _isFurnished = !furnishing.contains('unfurnished');
    }

    _bedrooms = _parseBedCount(ListingData.bedrooms(item), fallback: 1);
    _bathrooms = _parseBedCount(ListingData.bathrooms(item), fallback: 1);
    _parkingFeatures
      ..clear()
      ..addAll(ListingParkingFeature.parseFeatures(item));
    if (_parkingFeatures.isEmpty && ListingData.hasBikeStorage(item)) {
      _parkingFeatures.add(ListingParkingFeature.bikeParking);
    }
    if (_isShare) {
      final explicitAvailable = item[ListingCreationFieldKeys.parkingAvailable];
      if (explicitAvailable is bool) {
        _sharedParkingAvailable = explicitAvailable;
      } else {
        _sharedParkingAvailable = _parkingFeatures.isNotEmpty;
      }
      if (_sharedParkingAvailable == false) {
        _parkingFeatures.clear();
      }
    } else {
      _ipParkingAvailable = _parkingFeatures.isNotEmpty;
    }

    final archRaw = ProfileData.text(item['shared_room_architecture']);
    final sharedRoomsRaw = item['shared_rooms'];
    if (sharedRoomsRaw is List && sharedRoomsRaw.isNotEmpty) {
      _sharedRoomSlots
        ..clear()
        ..addAll(
          sharedRoomsRaw
              .whereType<Map>()
              .map((e) => SharedRoomSlot.fromJson(Map<String, dynamic>.from(e))),
        );
      _roomsToShare = _sharedRoomSlots.length.clamp(
        1,
        ListingCreationFormConstants.sharedSpacesMaxRooms,
      );
    } else {
      final legacyArch = _parseRoomArchitecture(archRaw) ??
          _roomArchitectureFromLegacy(item);
      if (legacyArch != null) {
        _sharedRoomSlots
          ..clear()
          ..add(
            SharedRoomSlot(
              architecture: legacyArch,
              bedOccupants: (item['shared_bed_occupants'] as num?)?.toInt() ?? 2,
              tenantGender: _parseTargetTenantPreference(
                    ProfileData.text(item['target_tenant_preference']),
                  ) ??
                  TargetTenantPreference.noPreference,
            ),
          );
        _roomsToShare = (item['rooms_to_share'] as num?)
                ?.toInt()
                .clamp(1, ListingCreationFormConstants.sharedSpacesMaxRooms) ??
            1;
        while (_sharedRoomSlots.length < _roomsToShare) {
          _sharedRoomSlots.add(SharedRoomSlot());
        }
      }
    }

    final householdCohortRaw = ProfileData.text(item['household_cohort']);
    if (householdCohortRaw.isNotEmpty) {
      _householdCohort = _parseFlatmateCohort(householdCohortRaw);
    }

    final occupants = item['current_occupants'];
    if (occupants is num) _housemateCount = occupants.toInt().clamp(1, 12);

    final bedOcc = item['shared_bed_occupants'] ?? item['bed_occupants'];
    if (bedOcc is num) {
      for (final slot in _sharedRoomSlots) {
        if (slot.isSharedBed) {
          slot.bedOccupants = bedOcc.toInt().clamp(1, 6);
        }
      }
    }

    final cohortRaw = ProfileData.text(item['flatmate_cohort']);
    final parsedCohort = _parseFlatmateCohort(cohortRaw);
    if (parsedCohort != null &&
        FlatmateCohort.sharedSpacesValues.contains(parsedCohort)) {
      _householdCohort = parsedCohort;
    }

    _hydrateHouseholdLanguages(ProfileData.languageList(item['languages_spoken']));

    final houseRulesRaw = item['house_rules'] ?? item['house_rule_selections'];
    _houseRules.clear();
    if (houseRulesRaw is List) {
      for (final entry in houseRulesRaw) {
        final rule = SharedHouseRule.fromStorage(entry?.toString());
        if (rule != null) _houseRules.add(rule);
      }
    }

    final totalRooms = item['total_rooms_in_property'] ?? item['total_rooms'];
    if (totalRooms is num) {
      _totalRoomsInProperty = totalRooms
          .toInt()
          .clamp(1, ListingCreationFormConstants.sharedSpacesMaxRooms);
    } else {
      _totalRoomsInProperty = _roomsToShare.clamp(
        1,
        ListingCreationFormConstants.sharedSpacesMaxRooms,
      );
    }
    if (_roomsToShare > _totalRoomsInProperty) {
      _totalRoomsInProperty = _roomsToShare;
    }

    _electricityCostController.text =
        ProfileData.text(item['monthly_electricity_cost']);
    _binsCostController.text = ProfileData.text(item['monthly_bins_cost']);
    _internetCostController.text =
        ProfileData.text(item['monthly_internet_cost']);
    _electricityIncluded = item['electricity_included'] == true;
    _binsIncluded = item['bins_included'] == true;
    _internetIncluded = item['internet_included'] == true;

    final lat = item['latitude'];
    final lon = item['longitude'];
    if (lat is num && lon is num) {
      _resolvedLatitude = lat.toDouble();
      _resolvedLongitude = lon.toDouble();
    }

    _proximityDraft = NeighborhoodProximityDraft.fromJson(
      item['neighborhood_proximity'] is Map
          ? Map<String, dynamic>.from(item['neighborhood_proximity'] as Map)
          : null,
    );
    _proximityEditing = _proximityDraft.manualEdit;
    _hydrateProximitySnapshotFromDraft();
    _syncProximityControllers();
    _loadCustomProximityRows();

    _smokingAllowed = ListingData.smokingAllowed(item);
    _smokingPolicy = ListingSmokingPolicy.fromStorage(
          ProfileData.text(item[ListingSmokingPolicy.listingKey]),
        ) ??
        (_smokingAllowed
            ? ListingSmokingPolicy.smokingAllowed
            : ListingSmokingPolicy.noSmoking);
    _petsPolicy = ListingPetsPolicy.fromStorage(
          ProfileData.text(item[ListingCreationFieldKeys.petsPolicy]),
        ) ??
        (!_lifestyleFlags(item).contains('no_pets') &&
                item['pets_allowed'] != false
            ? ListingPetsPolicy.allowed
            : ListingPetsPolicy.notAllowed);
    if (_isShare && _petsPolicy == ListingPetsPolicy.caseByCase) {
      _petsPolicy = null;
    }
    final hostFromListing = ListingData.hostName(item);
    if (hostFromListing.isNotEmpty && hostFromListing != 'Guest host') {
      _hostNameController.text = hostFromListing;
    }
    _vegetarianKitchen =
        _lifestyleFlags(item).contains('vegetarian_household');
    final schedule = ListingData.scheduleType(item);
    _wfhFriendly = schedule == 'Flexible' || item['wfh_friendly'] == true;
  }

  void _hydrateInheritedPrefill(Map<String, dynamic> raw) {
    final listingMode = ProfileData.text(raw['prefill_listing_mode']).toLowerCase();
    if (listingMode == 'shared_space') {
      _type = MarketplaceSpace.sharedSpace.towerPropertyType;
      _categoryPrefillLocked = true;
    } else if (listingMode == 'entire_place') {
      _type = MarketplaceSpace.fullRental.towerPropertyType;
      _categoryPrefillLocked = true;
    }

    if (raw.containsKey('prefill_is_furnished')) {
      _isFurnished = raw['prefill_is_furnished'] == true;
      _furnishingPrefillLocked = true;
    }
    _isOwnerOccupier = raw['prefill_is_owner_occupier'] == true;

    final prefillLanguages = ProfileData.languageList(
      raw['prefill_household_languages'],
    );
    if (prefillLanguages.isNotEmpty) {
      _hydrateHouseholdLanguages(prefillLanguages);
    }

    final rules = ProfileData.languageList(raw['prefill_house_rules']);
    if (rules.isNotEmpty) {
      _rulesPrefillLocked = true;
      _smokingAllowed = rules.contains('Smoking allowed');
      _smokingPolicy = _smokingAllowed
          ? ListingSmokingPolicy.smokingAllowed
          : ListingSmokingPolicy.noSmoking;
      _petsPolicy = rules.contains('Pets welcome')
          ? ListingPetsPolicy.allowed
          : ListingPetsPolicy.notAllowed;
      _vegetarianKitchen = rules.contains('Veg kitchen');
      // WFH removed from Shared Spaces onboarding — ignore legacy prefill.
    }

    final household = raw['prefill_household_makeup'];
    if (household is Map) {
      final householdMap = Map<String, dynamic>.from(household);
      final occupants = householdMap['group_size'] ?? householdMap['current_occupants'];
      if (occupants is int && occupants > 0) {
        _housemateCount = occupants.clamp(1, 12);
      }
      final occupantType = ProfileData.text(householdMap['occupant_type']).toLowerCase();
      if (occupantType.contains('student')) {
        _householdCohort = FlatmateCohort.students;
      } else if (occupantType.contains('professional') ||
          occupantType.contains('working')) {
        _householdCohort = FlatmateCohort.workingProfessionals;
      }
    }

    final inheritedLocation = ProfileData.text(raw['location']);
    if (inheritedLocation.isNotEmpty) {
      _locationController.text = inheritedLocation;
      _locationPrefillLocked = true;
    }
    final isProfileDraft = raw.containsKey('prefill_listing_mode') ||
        raw.containsKey('prefill_is_furnished') ||
        raw.containsKey('prefill_house_rules') ||
        raw.containsKey('prefill_household_languages');
    if (isProfileDraft) {
      // Eircode is entered on the listing step — never inherited from profile.
      _eircodeController.clear();
    }
  }

  bool _hasResolvableLocation() {
    if (_selectedAddress != null) return true;
    final eircode = _eircodeController.text.trim();
    if (eircode.isNotEmpty && EircodeGeocodingService.isValidFormat(eircode)) {
      return true;
    }
    if (_resolvedLatitude != null && _resolvedLongitude != null) {
      return true;
    }
    if (_locationFromGps &&
        _locationController.text.trim().length >= 2) {
      return true;
    }
    return false;
  }

  void _seedAddressSearchFromStoredFields(Map<String, dynamic> item) {
    if (_isProfileDraft(item)) {
      _addressSearchController.clear();
      return;
    }
    final public = ProfileData.text(item[AddressPrivacy.publicLocationKey]);
    if (public.isNotEmpty && _hideExactAddress) {
      _addressSearchController.text = public;
      return;
    }
    final eircode = _eircodeController.text.trim();
    final location = _locationController.text.trim();
    final street = _locationIdentifierController.text.trim();
    if (street.isNotEmpty && eircode.isNotEmpty) {
      _addressSearchController.text = '$street, $location, $eircode';
    } else if (street.isNotEmpty) {
      _addressSearchController.text = street;
    } else if (eircode.isNotEmpty) {
      _addressSearchController.text = eircode;
    } else if (location.isNotEmpty) {
      _addressSearchController.text = location;
    }

    final lat = item[AddressPrivacy.exactLatitudeKey] ?? item['latitude'];
    final lon = item[AddressPrivacy.exactLongitudeKey] ?? item['longitude'];
    if (lat is num && lon is num && _selectedAddress == null) {
      _selectedAddress = IrishAddressSuggestion(
        displayLabel: _addressSearchController.text,
        streetLine: street,
        area: location.isNotEmpty ? location : 'Dublin',
        county: 'Dublin',
        eircode: eircode.isEmpty ? null : eircode,
        latitude: lat.toDouble(),
        longitude: lon.toDouble(),
      );
    }
  }

  String _effectiveLocationLabel() {
    if (_hideExactAddress) {
      return _publicLocationPreviewLabel();
    }
    // Property Area is the matching source of truth. Optional street text is
    // stored separately as property_location_identifier — never block publish
    // on a partial street value like "9".
    final area = _locationController.text.trim();
    if (area.isNotEmpty) return area;
    final public = _publicLocationPreviewLabel();
    if (public.isNotEmpty) return public;
    final street = _locationIdentifierController.text.trim();
    if (street.length >= 2) return street;
    return _selectedAddress?.displayLabel ?? '';
  }

  String _publicLocationPreviewLabel() {
    final districtShort = _districtShortLabel();
    if (_localityLabel.isNotEmpty && districtShort != null) {
      return '$_localityLabel, $districtShort';
    }
    if (_selectedAddress != null) {
      return _selectedAddress!.publicLocationLabel;
    }
    final area = _locationController.text.trim();
    if (area.isNotEmpty) {
      return AddressPrivacy.publicLocationFrom(
        area: area,
        county: 'Dublin',
        hideExact: true,
      );
    }
    return '';
  }

  String? _districtShortLabel() {
    final label = _listingAreaKey != null
        ? TargetSearchAreas.labelForKey(_listingAreaKey!)
        : _locationController.text.trim();
    final match = RegExp(r'Dublin (\d+[W]?)').firstMatch(label);
    return match?.group(0);
  }

  void _syncListingAreaKey({
    double? lat,
    double? lon,
    String? areaLabel,
  }) {
    final resolved = resolveListingAreaKey(
      eircode: _eircodeController.text,
      lat: lat,
      lon: lon,
      areaLabel: areaLabel,
    );
    if (resolved == null) return;

    _listingAreaKey = resolved;

    if (_locationController.text.trim().isEmpty &&
        lat != null &&
        lon != null) {
      final district = dublinDistrictLabelFromCoordinates(lat, lon);
      if (district != null) {
        _locationController.text = district;
      }
    }
  }

  String _resolvedHostCityForMatching(Map hostFields) {
    if (_listingAreaKey != null) {
      return TargetSearchAreas.labelForKey(_listingAreaKey!);
    }
    final area = _locationController.text.trim();
    if (area.isNotEmpty) return area;
    final hostCity = ProfileData.text(hostFields['hostCity']);
    return hostCity.isNotEmpty ? hostCity : 'Dublin';
  }

  String get _listingAreaSelectValue {
    final key = _listingAreaKey ?? MarketConfig.current.defaultAreaKey;
    for (final (areaKey, label) in MarketConfig.current.areaOptions) {
      if (areaKey == key) return label;
    }
    return _locationController.text.trim();
  }

  String _resolvedStreetLineFromSuggestion(IrishAddressSuggestion suggestion) {
    final street = IrishAddressFormat.sanitizeCommaSeparatedLabel(
      suggestion.streetLine.trim(),
    );
    if (street.isNotEmpty && !_isEircodeOnlyLabel(street)) return street;

    final display = IrishAddressFormat.sanitizeCommaSeparatedLabel(
      suggestion.displayLabel,
    );
    if (display.isEmpty || _isEircodeOnlyLabel(display)) return '';

    final firstSegment = display.split(',').first.trim();
    if (firstSegment.isNotEmpty && !_isEircodeOnlyLabel(firstSegment)) {
      return firstSegment;
    }
    return '';
  }

  bool _isEircodeOnlyLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (EircodeGeocodingService.isValidFormat(trimmed)) return true;
    return RegExp(r'^D\d{2}\s?[A-Z0-9]{4}$', caseSensitive: false)
        .hasMatch(trimmed.replaceAll(' ', ''));
  }

  /// Clears address, area, eircode, and proximity derived from a prior location.
  void _resetLocationDerivedFields({bool clearCoordinates = false}) {
    _proximityGeneration++;
    _selectedAddress = null;
    _reverseGeocodedAddress = null;
    if (clearCoordinates) {
      _resolvedLatitude = null;
      _resolvedLongitude = null;
    }
    _locationFromGps = false;
    _proximityResolving = false;
    _proximityResolved = false;
    _neighborhoodAmenitiesLoading = false;
    _amenitiesEnrichmentInFlight = false;
    _neighborhoodAmenityTags = [];
    _extraProximityTransit = [];
    _locationIdentifierController.clear();
    _eircodeController.clear();
    _localityLabel = '';
    _listingAreaKey = null;
    _locationController.clear();
    _clearAutoProximityFields();
  }

  void _applyResolvedAddressSuggestion(
    IrishAddressSuggestion suggestion, {
    required bool fromGps,
  }) {
    _selectedAddress = suggestion;
    _resolvedLatitude = suggestion.latitude;
    _resolvedLongitude = suggestion.longitude;
    _locationFromGps = fromGps;
    _locationPrefillLocked = false;
    _locationIdentifierController.text = _resolvedStreetLineFromSuggestion(
      suggestion,
    );
    _localityLabel = suggestion.area.trim();
    _eircodeController.clear();
    if (suggestion.eircode != null) {
      _eircodeController.text =
          EircodeGeocodingService.normalize(suggestion.eircode!);
    }
    _syncListingAreaKey(
      lat: suggestion.latitude,
      lon: suggestion.longitude,
      areaLabel: suggestion.county.trim().isNotEmpty ? suggestion.county : null,
    );
    if (_listingAreaKey != null) {
      _locationController.text = TargetSearchAreas.labelForKey(_listingAreaKey!);
    } else if (suggestion.area.isNotEmpty) {
      _locationController.text = suggestion.area;
    }
    _reverseGeocodedAddress = IrishAddressFormat.sanitizeCommaSeparatedLabel(
      suggestion.displayLabel,
    );
    if (fromGps) {
      final label = _reverseGeocodedAddress;
      if (label != null && label.isNotEmpty) {
        _externalLocationLabel = label;
        _externalLocationEpoch++;
      }
    }
  }

  void _onMapPinDraft() {
    setState(() => _resetLocationDerivedFields(clearCoordinates: true));
  }

  void _onMapPinPlaced(double lat, double lon, {bool fromGps = false}) {
    final generation = ++_proximityGeneration;
    setState(() {
      _resolvedLatitude = lat;
      _resolvedLongitude = lon;
      _locationFromGps = fromGps;
      _locationPrefillLocked = false;
      _reverseGeocodedAddress = null;
    });
    unawaited(
      _resolveProximityFromPin(
        lat,
        lon,
        generation: generation,
        fromGps: fromGps,
      ),
    );
  }

  Future<void> _resolveProximityFromPin(
    double lat,
    double lon, {
    required int generation,
    bool fromGps = false,
  }) async {
    unawaited(
      _resolveProximityAt(
        lat,
        lon,
        generation: generation,
        usedGpsCoords: fromGps,
      ),
    );

    final cellKey = ProximityResolutionCache.keyFor(lat, lon);
    final cachedGeocode = ProximityResolutionCache.getGeocode(cellKey);
    if (cachedGeocode != null) {
      _logLocationPerf('reverse_geocode_end', {
        'ms': 0,
        'cacheHit': true,
        'fromGps': fromGps,
      });
      if (!mounted || generation != _proximityGeneration) return;
      setState(
        () => _applyResolvedAddressSuggestion(cachedGeocode, fromGps: fromGps),
      );
      return;
    }

    _logLocationPerf('reverse_geocode_start', {'fromGps': fromGps});
    final swGeo = Stopwatch()..start();
    final suggestion = await EircodeLookupService.resolveFromCoordinates(
      lat,
      lon,
    );
    swGeo.stop();
    if (!mounted || generation != _proximityGeneration) return;
    if (suggestion != null) {
      ProximityResolutionCache.putGeocode(cellKey, suggestion);
      _logLocationPerf('reverse_geocode_end', {
        'ms': swGeo.elapsedMilliseconds,
        'cacheHit': false,
        'source': 'eircode_lookup',
        'fromGps': fromGps,
      });
      setState(
        () => _applyResolvedAddressSuggestion(suggestion, fromGps: fromGps),
      );
      return;
    }
    final address = await NominatimForward.reverseGeocode(lat, lon);
    _logLocationPerf('reverse_geocode_end', {
      'ms': swGeo.elapsedMilliseconds,
      'cacheHit': false,
      'source': 'nominatim_forward_fallback',
      'ok': address != null,
      'fromGps': fromGps,
    });
    if (!mounted || generation != _proximityGeneration) return;
    setState(() {
      final cleaned = address != null
          ? IrishAddressFormat.sanitizeCommaSeparatedLabel(address)
          : null;
      _reverseGeocodedAddress = cleaned;
      if (cleaned != null && cleaned.isNotEmpty) {
        if (!_isEircodeOnlyLabel(cleaned)) {
          final first = cleaned.split(',').first.trim();
          _locationIdentifierController.text =
              _isEircodeOnlyLabel(first) ? '' : first;
        }
        _syncListingAreaKey(lat: lat, lon: lon);
        if (_listingAreaKey != null) {
          _locationController.text =
              TargetSearchAreas.labelForKey(_listingAreaKey!);
        }
        if (fromGps) {
          _externalLocationLabel = cleaned;
          _externalLocationEpoch++;
        }
      }
    });
  }

  SharedRoomArchitecture? _roomArchitectureFromLegacy(Map<String, dynamic> item) {
    final kind = ProfileData.text(item['share_room_kind']);
    final room = ListingData.roomType(item).toLowerCase();
    if (kind == 'ensuite' || room.contains('ensuite')) {
      return SharedRoomArchitecture.privateEnsuite;
    }
    if (kind == 'bed_shared' || room.contains('bed')) {
      return SharedRoomArchitecture.sharedBed;
    }
    if (room.contains('private')) {
      return SharedRoomArchitecture.privateSharedBath;
    }
    return null;
  }

  Set<String> _lifestyleFlags(Map<String, dynamic> item) {
    final raw = item['lifestyle_flags'];
    if (raw is! List) return {};
    return raw.map((e) => ProfileData.text(e)).where((s) => s.isNotEmpty).toSet();
  }

  SubletDurationUnit _parseSubletUnit(String raw) {
    for (final unit in SubletDurationUnit.values) {
      if (unit.name == raw) return unit;
    }
    return SubletDurationUnit.months;
  }

  SharedRoomArchitecture? _parseRoomArchitecture(String raw) {
    if (raw.isEmpty) return null;
    for (final arch in SharedRoomArchitecture.values) {
      if (arch.storageValue == raw) return arch;
    }
    return null;
  }

  FlatmateCohort? _parseFlatmateCohort(String raw) {
    if (raw.isEmpty) return null;
    for (final cohort in FlatmateCohort.values) {
      if (cohort.storageValue == raw) return cohort;
    }
    return null;
  }

  TargetTenantPreference? _parseTargetTenantPreference(String raw) {
    if (raw.isEmpty) return null;
    for (final pref in TargetTenantPreference.values) {
      if (pref.storageValue == raw) return pref;
    }
    return null;
  }

  int _parseBedCount(String raw, {required int fallback}) {
    final match = RegExp(r'\d+').firstMatch(raw);
    if (match == null) return fallback;
    return int.tryParse(match.group(0)!) ?? fallback;
  }

  String _stripRentForInput(String price) {
    return price
        .replaceAll(RegExp(r'[€,\s]'), '')
        .replaceAll(RegExp(r'/.*'), '');
  }

  void _loadCustomProximityRows() {
    for (final row in _customProximityRows) {
      row.dispose();
    }
    _customProximityRows.clear();
    for (final point in _proximityDraft.customPoints) {
      _customProximityRows.add(
        _CustomProximityRowState(
          category: point.category,
          name: point.name,
          walkMin: point.walkMin > 0 ? '${point.walkMin}' : '',
        ),
      );
    }
  }

  void _syncProximityControllers() {
    _transportLineController.text = _proximityDraft.transportLine;
    _transportWalkController.text =
        _proximityDraft.transportWalkMin > 0
            ? '${_proximityDraft.transportWalkMin}'
            : '';
    _groceryBrand = _proximityDraft.groceryBrand;
    _groceryWalkController.text =
        _proximityDraft.groceryWalkMin > 0
            ? '${_proximityDraft.groceryWalkMin}'
            : '';
    _primarySchoolController.text = _proximityDraft.primarySchool;
    _secondarySchoolController.text = _proximityDraft.secondarySchool;
    _crecheNameController.text = _proximityDraft.crecheName;
    _crecheWalkController.text =
        _proximityDraft.crecheWalkMin > 0
            ? '${_proximityDraft.crecheWalkMin}'
            : '';
  }

  /// Restores ephemeral discovery fields from the persisted proximity draft.
  void _hydrateProximitySnapshotFromDraft() {
    _profileGroceries = List<NearbyGroceryOption>.from(_proximityDraft.groceries);
    _extraProximityTransit =
        List<NearbyExtraTransit>.from(_proximityDraft.extraTransit);
    _neighborhoodAmenityTags =
        List<NeighborhoodAmenityTag>.from(_proximityDraft.lifestyleTags);
    _collegeSchool = _proximityDraft.collegeSchool;
    _collegeWalkMin = _proximityDraft.collegeWalkMin > 0
        ? _proximityDraft.collegeWalkMin
        : null;
    _gpClinic = _proximityDraft.gpClinic;
    _gpWalkMin =
        _proximityDraft.gpWalkMin > 0 ? _proximityDraft.gpWalkMin : null;
  }

  void _applyProximityFromControllers() {
    _proximityDraft.transportLine = _transportLineController.text.trim();
    _proximityDraft.transportWalkMin =
        int.tryParse(_transportWalkController.text.trim()) ?? 0;
    _proximityDraft.groceryBrand = _groceryBrand;
    _proximityDraft.groceryWalkMin =
        int.tryParse(_groceryWalkController.text.trim()) ?? 0;
    _proximityDraft.primarySchool = _primarySchoolController.text.trim();
    _proximityDraft.secondarySchool = _secondarySchoolController.text.trim();
    _proximityDraft.crecheName = _crecheNameController.text.trim();
    _proximityDraft.crecheWalkMin =
        int.tryParse(_crecheWalkController.text.trim()) ?? 0;
    _proximityDraft.manualEdit = _proximityEditing;
    _proximityDraft.customPoints = _customProximityRows
        .map((row) => row.toPoint())
        .where((p) => p.name.isNotEmpty)
        .toList();
    _proximityDraft.groceries =
        List<NearbyGroceryOption>.from(_profileGroceries);
    _proximityDraft.extraTransit =
        List<NearbyExtraTransit>.from(_extraProximityTransit);
    _proximityDraft.lifestyleTags =
        List<NeighborhoodAmenityTag>.from(_neighborhoodAmenityTags);
    _proximityDraft.collegeSchool = _collegeSchool.trim();
    _proximityDraft.collegeWalkMin = _collegeWalkMin ?? 0;
    _proximityDraft.gpClinic = _gpClinic.trim();
    _proximityDraft.gpWalkMin = _gpWalkMin ?? 0;
  }

  void _onStepActivated(int step) {
    if (_isShare) {
      // Generate listing copy when entering Household + Listing (step 3).
      if (step == 2) {
        if (_isMultiRoomInventory) {
          _listingWizardRoomIndex =
              _listingWizardRoomIndex.clamp(0, _sharedRoomSlots.length - 1);
        }
        _generateSmartListingCopy();
        if (_isMultiRoomInventory) {
          _syncListingWizardFromSlot(_listingWizardRoomIndex);
        }
      }
      return;
    }
    if (step != 2) return;
    _applyProximityFromControllers();
    _generateSmartListingCopy();
  }

  void _persistListingWizardToSlot(int index) {
    if (!_isShare || !_isMultiRoomInventory) return;
    if (index < 0 || index >= _sharedRoomSlots.length) return;
    final slot = _sharedRoomSlots[index];
    slot.title = _titleController.text.trim();
    slot.description = _descriptionController.text.trim();
  }

  void _syncListingWizardFromSlot(int index) {
    if (!_isShare || index < 0 || index >= _sharedRoomSlots.length) return;
    final slot = _sharedRoomSlots[index];
    _titleController.text = slot.title;
    _descriptionController.text = slot.description;
    _autoDraftedTitle = slot.title.isEmpty ? null : slot.title;
    _autoDraftedDescription =
        slot.description.isEmpty ? null : slot.description;
  }

  void _goListingWizardRoom(int nextIndex) {
    if (!_isMultiRoomInventory || _sharedRoomSlots.isEmpty) return;
    final clamped = nextIndex.clamp(0, _sharedRoomSlots.length - 1);
    setState(() {
      _persistListingWizardToSlot(_listingWizardRoomIndex);
      _listingWizardRoomIndex = clamped;
      _syncListingWizardFromSlot(_listingWizardRoomIndex);
      _titleEditorExpanded = false;
      _descriptionEditorExpanded = false;
    });
  }

  String _listingWizardRoomSummary(SharedRoomSlot slot) {
    final rentDigits = slot.monthlyRent.replaceAll(RegExp(r'[^\d]'), '');
    final bits = <String>[
      slot.roomKind.label,
      slot.bathroomType.label,
      if (rentDigits.isNotEmpty) '€$rentDigits',
    ];
    return bits.join(' · ');
  }

  String _smartCopyAreaName() {
    if (_localityLabel.isNotEmpty) return _localityLabel;
    final location = _locationController.text.trim();
    if (location.isNotEmpty) {
      final districtMatch = RegExp(r'Dublin \d+[W]?').firstMatch(location);
      if (districtMatch != null) {
        final beforeDistrict = location
            .substring(0, districtMatch.start)
            .replaceAll(RegExp(r'[,\s]+$'), '')
            .trim();
        if (beforeDistrict.isNotEmpty) return beforeDistrict;
      }
      final first = location.split(',').first.trim();
      if (first.isNotEmpty && !RegExp(r'^Dublin \d').hasMatch(first)) {
        return first;
      }
    }
    return 'Dublin';
  }

  String _smartCopyPostalDistrict() => _districtShortLabel() ?? 'Dublin';

  bool _isAutoDraftedTitle() =>
      _autoDraftedTitle != null && _titleController.text == _autoDraftedTitle;

  bool _isAutoDraftedDescription() =>
      _autoDraftedDescription != null &&
      _descriptionController.text == _autoDraftedDescription;

  String _smartCopyPropertyTypeLabel() =>
      _propertySubType == ListingPropertySubType.house
          ? 'House'
          : _propertySubType == ListingPropertySubType.apartment
              ? 'Apartment'
              : '';

  int _parsedMonthlyRent() {
    final digits = _rentController.text.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(digits) ?? 0;
  }

  String _formatWalkTimeLabel(int minutes) {
    if (minutes <= 0) return '5 min';
    return '$minutes min';
  }

  void _generateSmartListingCopy() {
    if (_isShare) {
      _generateSharedSmartCopy();
      return;
    }
    final generated = ListingSmartCopyGenerator.generate(
      ListingSmartCopyInput(
        isSharedLiving: false,
        areaName: _smartCopyAreaName(),
        postalDistrict: _smartCopyPostalDistrict(),
        propertyType: _smartCopyPropertyTypeLabel(),
        isFurnished: _isFurnished ?? false,
        bedrooms: _bedrooms,
        bathrooms: _bathrooms,
        monthlyRent: _parsedMonthlyRent(),
        closestTransit: _proximityDraft.transportLine,
        transitWalkTime: _formatWalkTimeLabel(_proximityDraft.transportWalkMin),
        closestShop: _proximityDraft.groceryBrand,
        shopWalkTime: _formatWalkTimeLabel(_proximityDraft.groceryWalkMin),
        existingTitle: _titleController.text,
        existingDescription: _descriptionController.text,
      ),
    );

    var changed = false;
    final title = generated.title;
    if (title != null && title.trim().isNotEmpty) {
      _autoDraftedTitle = title;
      _titleController.text = title;
      changed = true;
    }
    final description = generated.description;
    if (description != null && description.trim().isNotEmpty) {
      _autoDraftedDescription = description;
      _descriptionController.text = description;
      changed = true;
    }
    if (changed) setState(() {});
  }

  void _generateSharedSmartCopy() {
    _syncHouseholdLanguagesFromSeekerUi();
    if (_sharedRoomSlots.isEmpty) return;

    if (_isMultiRoomInventory) {
      var changed = false;
      for (final slot in _sharedRoomSlots) {
        final rentDigits = slot.monthlyRent.replaceAll(RegExp(r'[^\d]'), '');
        final generated = ListingSmartCopyGenerator.generate(
          _sharedSmartCopyInputFor(
            slot: slot,
            monthlyRent: int.tryParse(rentDigits) ?? 0,
            existingTitle: slot.title,
            existingDescription: slot.description,
          ),
        );
        if ((slot.title.trim().isEmpty) &&
            generated.title != null &&
            generated.title!.trim().isNotEmpty) {
          slot.title = generated.title!.trim();
          changed = true;
        }
        if ((slot.description.trim().isEmpty) &&
            generated.description != null &&
            generated.description!.trim().isNotEmpty) {
          slot.description =
              _plainListingDescription(generated.description!);
          changed = true;
        }
      }
      _syncListingWizardFromSlot(_listingWizardRoomIndex);
      if (changed) setState(() {});
      return;
    }

    final primary = _primaryRoomSlot;
    if (primary == null) return;

    final rentDigits = primary.monthlyRent.replaceAll(RegExp(r'[^\d]'), '');
    final generated = ListingSmartCopyGenerator.generate(
      _sharedSmartCopyInputFor(
        slot: primary,
        monthlyRent: int.tryParse(rentDigits) ?? 0,
        existingTitle: _titleController.text,
        existingDescription: _descriptionController.text,
      ),
    );
    var changed = false;
    if (generated.title != null && generated.title!.trim().isNotEmpty) {
      _autoDraftedTitle = generated.title;
      _titleController.text = generated.title!;
      changed = true;
    }
    if (generated.description != null &&
        generated.description!.trim().isNotEmpty) {
      final plain = _plainListingDescription(generated.description!);
      _autoDraftedDescription = plain;
      _descriptionController.text = plain;
      changed = true;
    }
    if (changed) setState(() {});
  }

  ListingSmartCopyInput _sharedSmartCopyInputFor({
    required SharedRoomSlot slot,
    required int monthlyRent,
    required String existingTitle,
    required String existingDescription,
  }) {
    return ListingSmartCopyInput(
      isSharedLiving: true,
      areaName: _smartCopyAreaName(),
      postalDistrict: _smartCopyPostalDistrict(),
      propertyType: _smartCopyPropertyTypeLabel(),
      isFurnished: false,
      bedrooms: _totalRoomsInProperty,
      bathrooms: 1,
      monthlyRent: monthlyRent,
      closestTransit: _proximityDraft.transportLine,
      transitWalkTime: _formatWalkTimeLabel(_proximityDraft.transportWalkMin),
      closestShop: _proximityDraft.groceryBrand,
      shopWalkTime: _formatWalkTimeLabel(_proximityDraft.groceryWalkMin),
      roomArchitecture: slot.architecture,
      roomKind: slot.roomKind,
      bathroomType: slot.bathroomType,
      householdProfile: _householdCohort,
      roomProfile: slot.roomProfile ??
          (_roomsToShare == 1 ? _householdCohort : null),
      petsPolicyLabel: _petsPolicy?.label,
      smokingPolicyLabel: _smokingPolicy?.label,
      parkingLabels: _parkingFeatures.map((f) => f.label).toList(),
      languages: _householdLanguages.toList(),
      houseRules: _houseRules.map((r) => r.label).toList(),
      requiredOccupantLabel: slot.requiredOccupant.label,
      occupantTypeLabel: slot.occupantType.label,
      currentOccupantLabel: slot.isSharedBed ? slot.currentOccupant?.label : null,
      existingTitle: existingTitle,
      existingDescription: existingDescription,
    );
  }

  String? _validateRent() {
    final text = stripThousandsFormatting(_rentController.text.trim());
    if (text.isEmpty) return 'Enter monthly rent';
    if (!RegExp(r'^\d+$').hasMatch(text)) {
      return 'Enter a valid rent amount';
    }
    return null;
  }

  String? _validateDeposit() {
    final text = stripThousandsFormatting(_depositController.text.trim());
    if (text.isEmpty) return 'Enter deposit required';
    if (!RegExp(r'^\d+$').hasMatch(text)) {
      return 'Enter a valid deposit amount';
    }
    return null;
  }

  String? _validateStep2() {
    if (!_hasResolvableLocation()) {
      return 'Drop a pin on the map or use current location.';
    }
    // Property address (street) is optional — pin + Property Area are sources of truth.
    if (_listingAreaKey == null && _locationController.text.trim().length < 2) {
      return 'Confirm the property area used for seeker matching.';
    }
    if (_listingAreaKey == null &&
        MarketConfig.current.profileUseAreaPicker) {
      return 'Confirm the property area used for seeker matching.';
    }
    return null;
  }

  /// Returns the first validation error for a wizard step, or null when valid.
  String? validateStep(int step) {
    if (_isShare) {
      return switch (step) {
        0 => _validateSharedPropertyStep(),
        1 => _validateSharedRoomsStep(),
        2 => _validateSharedHouseholdListingStep(),
        3 => _validateLocationStep(),
        _ => null,
      };
    }
    switch (step) {
      case 0:
        if (_hostNameController.text.trim().isEmpty) {
          return 'Enter the host name shown on this listing.';
        }
        final rentError = _validateRent();
        if (rentError != null) {
          setState(() {
            _rentShowError = true;
            _rentErrorText = rentError;
          });
          return rentError;
        }
        setState(() {
          _rentShowError = false;
          _rentErrorText = null;
        });
        final depositError = _validateDeposit();
        if (depositError != null) {
          setState(() {
            _depositShowError = true;
            _depositErrorText = depositError;
          });
          return depositError;
        }
        setState(() {
          _depositShowError = false;
          _depositErrorText = null;
        });
        if (_propertySubType == null) {
          return 'Select whether this is a house or apartment.';
        }
        if (_isFurnished == null) {
          return 'Select a furnishing option.';
        }
        if (_agreementType == null) {
          return 'Select a lease type.';
        }
        if (_availableFrom == null) {
          return 'Pick an available-from date for this listing.';
        }
        if (_availabilityFlexibility == null) {
          return 'Select availability flexibility.';
        }
        if (!LandlordAvailabilityFlexibility.independentPlaceValues
            .contains(_availabilityFlexibility)) {
          return 'Select availability flexibility.';
        }
        if (_subletDurationController.text.trim().isEmpty) {
          return _agreementType == TenurePreference.longTerm
              ? 'Enter the lease duration in years.'
              : 'Enter an estimated stay duration.';
        }
        if (_bedrooms < 1) return 'Enter the number of bedrooms.';
        if (_bathrooms < 1) return 'Enter the number of bathrooms.';
        if (_petsPolicy == null) return 'Select a pets policy.';
        return null;
      case 1:
        return _validateLocationStep();
      case 2:
        final title = _titleController.text.trim();
        if (title.length < 3) {
          setState(() => _titleShowError = true);
          return 'Enter a listing title (at least 3 characters).';
        }
        setState(() => _titleShowError = false);
        if (_images.length < ListingCreationFormConstants.minPhotoCount) {
          return 'Add at least ${ListingCreationFormConstants.minPhotoCount} photos before publishing.';
        }
        final description = _descriptionController.text.trim();
        if (description.isNotEmpty && description.length < 10) {
          return 'If you add a description, use at least 10 characters.';
        }
        return null;
      default:
        return null;
    }
  }

  String? _validateLocationStep() {
    final locationError = _validateStep2();
    if (locationError != null) {
      setState(() => _locationShowErrors = true);
      return locationError;
    }
    setState(() => _locationShowErrors = false);
    return null;
  }

  String? _validateSharedPropertyStep() {
    if (_hostNameController.text.trim().isEmpty) {
      _seedHostNameFromProfile();
    }
    if (_propertySubType == null) {
      return 'Select whether this is a house or apartment.';
    }
    if (_totalRoomsInProperty < 1 ||
        _totalRoomsInProperty >
            ListingCreationFormConstants.sharedSpacesMaxRooms) {
      return 'Select how many rooms are in the property.';
    }
    if (_roomsToShare < 1 || _roomsToShare > _totalRoomsInProperty) {
      return 'Rooms available cannot exceed total rooms in the property.';
    }
    if (_petsPolicy != ListingPetsPolicy.allowed &&
        _petsPolicy != ListingPetsPolicy.notAllowed) {
      return 'Select whether pets are allowed.';
    }
    return null;
  }

  String? _validateSharedRoomsStep() {
    if (_sharedRoomSlots.isEmpty) {
      return 'Add at least one room to share.';
    }
    for (var i = 0; i < _sharedRoomSlots.length; i++) {
      final error = _validateSharedRoomInventory(
        _sharedRoomSlots[i],
        index: i,
      );
      if (error != null) return error;
    }
    return null;
  }

  String? _validateSharedRoomInventory(SharedRoomSlot slot, {required int index}) {
    final label = 'Room ${index + 1}';
    final rentText = stripThousandsFormatting(slot.monthlyRent.trim());
    if (rentText.isEmpty || !RegExp(r'^\d+$').hasMatch(rentText)) {
      return '$label: enter monthly rent.';
    }
    if ((int.tryParse(rentText) ?? 0) <= 0) {
      return '$label: monthly rent must be greater than 0.';
    }
    if (!_isSlotCostResolved(slot.electricityCost, slot.electricityIncluded) ||
        !_isSlotCostResolved(slot.binsCost, slot.binsIncluded) ||
        !_isSlotCostResolved(slot.internetCost, slot.internetIncluded)) {
      return '$label: enter shared costs or mark each as included.';
    }
    final agreement = TenurePreference.fromStorage(slot.agreementTypeToken);
    if (agreement == null || agreement == TenurePreference.flexible) {
      return '$label: select lease type.';
    }
    if (agreement == TenurePreference.temporary &&
        slot.temporaryDurationValue.trim().isEmpty) {
      return '$label: enter temporary duration.';
    }
    if (slot.availableFrom == null) {
      return '$label: pick available-from date.';
    }
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    if (slot.availableFrom!.isBefore(startOfToday)) {
      return '$label: available-from cannot be in the past.';
    }
    final flex = LandlordAvailabilityFlexibility.parse(
      slot.availabilityFlexibilityToken,
    );
    if (slot.availabilityFlexibilityToken == null ||
        slot.availabilityFlexibilityToken!.isEmpty ||
        !LandlordAvailabilityFlexibility.sharedSpacesValues.contains(flex)) {
      return '$label: select availability flexibility.';
    }
    if (_isShare && slot.roomProfile == null) {
      return '$label: select room profile.';
    }
    if (slot.isSharedBed && slot.currentOccupant == null) {
      return '$label: select current occupant.';
    }
    return null;
  }

  bool _isSlotCostResolved(String cost, bool included) {
    if (included) return true;
    final raw = cost.trim();
    if (raw.isEmpty) return false;
    return int.tryParse(raw.replaceAll(RegExp(r'[^\d]'), '')) != null;
  }

  String? _validateSharedHouseholdListingStep() {
    _syncHouseholdLanguagesFromSeekerUi();
    if (_smokingPolicy == null) {
      return 'Select a smoking policy.';
    }
    final minPhotos =
        ListingCreationFormConstants.sharedSpacesMinPhotoCount;
    if (_isMultiRoomInventory) {
      _persistListingWizardToSlot(_listingWizardRoomIndex);
      for (var i = 0; i < _sharedRoomSlots.length; i++) {
        if (_sharedRoomSlots[i].images.length < minPhotos) {
          return 'Add at least $minPhotos photo for Room ${i + 1}.';
        }
      }
      return null;
    }
    if (_images.length < minPhotos) {
      return 'Add at least $minPhotos photo before publishing.';
    }
    // Occupancy soft warning is UI-only via `_shouldShowOccupancyWarning`.
    return null;
  }

  /// Returns the first validation error, or null when the form is valid.
  String? validate() {
    for (var step = 0; step < _stepCount; step++) {
      final error = validateStep(step);
      if (error != null) return error;
    }

    final baseErrors = ListingData.validateListingForm(
      title: _titleController.text,
      price: _isShare
          ? stripThousandsFormatting(
              (_primaryRoomSlot?.monthlyRent ?? '').trim(),
            )
          : stripThousandsFormatting(_rentController.text.trim()),
      location: _effectiveLocationLabel(),
      type: _type,
      description: _descriptionController.text,
    );
    if (baseErrors.isNotEmpty) return baseErrors.values.first;

    if (!_listingAuthorizationConfirmed) {
      return 'Confirm you are authorised to advertise this listing before publishing.';
    }

    return null;
  }

  Future<Map<String, dynamic>> buildPayload(
    Map hostFields,
    Map? profile,
  ) async {
    _applyProximityFromControllers();

    final title = _titleController.text.trim();
    final price = _formattedPrice();
    final deposit = _formattedDeposit();
    final location = _effectiveLocationLabel();
    final description = _descriptionController.text.trim();
    final coords = await _resolveListingCoordinates(location);

    final proximityData = TransitExtractionService.extractLocally(
      latitude: coords.lat,
      longitude: coords.lon,
    );

    final agreementType = _agreementType ?? TenurePreference.longTerm;
    final propertySubType =
        _propertySubType ?? ListingPropertySubType.apartment;
    final isFurnished = _isFurnished ?? false;
    final petsPolicy = _petsPolicy ?? ListingPetsPolicy.notAllowed;
    final parkingFeatures = Set<ListingParkingFeature>.from(_parkingFeatures);
    if (_isShare && _sharedParkingAvailable == false) {
      parkingFeatures.clear();
    }
    final primaryParking = parkingFeatures.isEmpty
        ? null
        : parkingFeatures.first;
    final parkingAvailable = _isShare
        ? (_sharedParkingAvailable ?? parkingFeatures.isNotEmpty)
        : parkingFeatures.isNotEmpty;

    final lifestyleFlags = <String>{};
    if (_isShare) {
      final smoking =
          _smokingPolicy ?? ListingSmokingPolicy.noSmoking;
      if (smoking == ListingSmokingPolicy.noSmoking) {
        lifestyleFlags.add('no_smoking');
      }
      if (smoking == ListingSmokingPolicy.outdoorOnly) {
        lifestyleFlags.add('outdoor_smoking_only');
      }
    } else if (!_smokingAllowed) {
      lifestyleFlags.add('no_smoking');
    }
    if (petsPolicy == ListingPetsPolicy.notAllowed) {
      lifestyleFlags.add('no_pets');
    }
    if (petsPolicy == ListingPetsPolicy.caseByCase) {
      lifestyleFlags.add('pet_approval_required');
    }
    if (_vegetarianKitchen) lifestyleFlags.add('vegetarian_household');
    if (_isShare && !_vegetarianKitchen) lifestyleFlags.add('non_veg_allowed');

    final hostName = _hostNameController.text.trim().isEmpty
        ? (ListingData.text(hostFields['hostName']).isEmpty
            ? 'Guest host'
            : ListingData.text(hostFields['hostName']))
        : _hostNameController.text.trim();

    final payload = <String, dynamic>{
      'title': title,
      'price': price,
      if (!_isShare && deposit.isNotEmpty)
        ListingCreationFieldKeys.securityDeposit: deposit,
      'location': location,
      'type': _type,
      'listing_type': _type,
      'description': description,
      'market': MarketConfig.current.id.name,
      ListingCreationFieldKeys.marketplaceCategory: _activeSpace.storageToken,
      if (_listingAuthorizationConfirmed)
        ListingCreationFieldKeys.listingAuthorizationConfirmed: true,
      ..._publishedAtPayloadFields(),
      ListingCreationFieldKeys.hostName: hostName,
      'hostCity': _resolvedHostCityForMatching(hostFields),
      if (_listingAreaKey != null) 'listing_area_key': _listingAreaKey,
      'hostLanguage': ProfileData.text(hostFields['hostLanguage']),
      'hostMotherTongue': ProfileData.text(hostFields['hostMotherTongue']),
      'hostFoodPreference': ProfileData.text(hostFields['hostFoodPreference']),
      TenurePreference.listingKey: agreementType.storageToken,
      'property_sub_type':
          propertySubType == ListingPropertySubType.house ? 'house' : 'apartment',
      'property_category':
          propertySubType == ListingPropertySubType.house ? 'House' : 'Apartment',
      'ber_rating': _berRating,
      if (!_isShare) 'furnishing': isFurnished ? 'Furnished' : 'Unfurnished',
      ListingCreationFieldKeys.petsPolicy: petsPolicy.storageToken,
      'pets_allowed': petsPolicy == ListingPetsPolicy.allowed,
      ListingCreationFieldKeys.parkingFeatures:
          parkingFeatures.map((f) => f.storageToken).toList(),
      ListingCreationFieldKeys.parkingType:
          primaryParking?.storageToken ?? 'not_available',
      ListingCreationFieldKeys.parkingAvailable: parkingAvailable,
      ListingCreationFieldKeys.secureBikeStorage:
          parkingFeatures.contains(ListingParkingFeature.bikeParking),
      ListingCreationFieldKeys.eircode: EircodeGeocodingService.normalize(
        _eircodeController.text,
      ),
      'property_location_identifier':
          _locationIdentifierController.text.trim(),
      'latitude': coords.lat,
      'longitude': coords.lon,
      'neighborhood_proximity': _proximityDraft.toJson(),
      if (_neighborhoodAmenityTags.isNotEmpty)
        'neighborhood_lifestyle_tags': _neighborhoodAmenityTags
            .map((t) => t.displayLabel)
            .toList(),
      if (proximityData != null) 'proximity_data': proximityData,
      'smoking_allowed': _isShare
          ? (_smokingPolicy ?? ListingSmokingPolicy.noSmoking)
              .allowsIndoorSmoking
          : _smokingAllowed,
      if (_isShare)
        ListingSmokingPolicy.listingKey:
            (_smokingPolicy ?? ListingSmokingPolicy.noSmoking).storageToken,
      if (!_isShare) 'schedule_type': _wfhFriendly ? 'Flexible' : 'Day shift',
      if (!_isShare) 'wfh_friendly': _wfhFriendly,
      if (lifestyleFlags.isNotEmpty) 'lifestyle_flags': lifestyleFlags.toList(),
      if (_images.isNotEmpty) 'images': _images,
      if (_video != null) 'video': _video,
      if (profile != null) ...{
        'owner_user_id': ProfileData.text(profile['supabase_user_id']),
        'landlord_id': ProfileData.text(profile['supabase_user_id']),
        'owner_email': ProfileData.text(profile['email']),
      },
      if (profile != null)
        'spoken_languages':
            ProfileData.languageList(profile['spoken_languages']),
      'is_owner_occupier': _isOwnerOccupier,
      'description_is_edited': !_isAutoDraftedDescription(),
      'description_auto_drafted': _isAutoDraftedDescription(),
      'listing_strength_score':
          ListingStrengthCalculator.fromListing(_listingPreviewSnapshot()).scorePercent,
    };

    if (!_isShare &&
        _availableFrom != null &&
        _subletDurationController.text.trim().isNotEmpty) {
      payload['available_from'] = _availableFrom!.toIso8601String();
      payload[ListingCreationFieldKeys.availabilityFlexibility] =
          LandlordAvailabilityFlexibility.migrateIndependentPlace(
            _availabilityFlexibility!,
          ).storageToken;
      payload['sublet_duration_value'] = _subletDurationController.text.trim();
      payload['sublet_duration_unit'] =
          agreementType == TenurePreference.longTerm
              ? SubletDurationUnit.years.name
              : _subletDurationUnit.name;
    }

    if (!_isShare) {
      payload['bedrooms'] = '$_bedrooms bed';
      payload['bathrooms'] = '$_bathrooms';
    } else {
      _syncHouseholdLanguagesFromSeekerUi();
      _prepareSharedRoomsForPayload();
      final primary = _primaryRoomSlot;
      final effectiveHouseholdCohort = _roomsToShare == 1
          ? _householdCohort
          : (primary?.roomProfile ?? _householdCohort);
      final roomMapping = _mapRoomArchitecture(primary?.architecture);
      final matchingProfile = primary?.roomProfile ?? effectiveHouseholdCohort;

      // Listing-level mirrors of primary room for backward-compatible consumers.
      if (primary != null) {
        final rentDigits =
            primary.monthlyRent.replaceAll(RegExp(r'[^\d]'), '');
        if (rentDigits.isNotEmpty) {
          payload['price'] = '€$rentDigits/month';
        }
        final agreement =
            TenurePreference.fromStorage(primary.agreementTypeToken);
        if (agreement != null) {
          payload[TenurePreference.listingKey] = agreement.storageToken;
        }
        if (primary.availableFrom != null) {
          payload['available_from'] = primary.availableFrom!.toIso8601String();
        }
        if (primary.availabilityFlexibilityToken != null) {
          payload[ListingCreationFieldKeys.availabilityFlexibility] =
              primary.availabilityFlexibilityToken;
        }
        if (primary.temporaryDurationValue.trim().isNotEmpty) {
          payload['sublet_duration_value'] =
              primary.temporaryDurationValue.trim();
          payload['sublet_duration_unit'] = primary.temporaryDurationUnit.name;
        }
        payload['monthly_electricity_cost'] = primary.electricityIncluded
            ? '0'
            : primary.electricityCost.trim();
        payload['monthly_bins_cost'] =
            primary.binsIncluded ? '0' : primary.binsCost.trim();
        payload['monthly_internet_cost'] =
            primary.internetIncluded ? '0' : primary.internetCost.trim();
        payload['electricity_included'] = primary.electricityIncluded;
        payload['bins_included'] = primary.binsIncluded;
        payload['internet_included'] = primary.internetIncluded;
      }

      payload.addAll({
        'total_rooms_in_property': _totalRoomsInProperty,
        'rooms_to_share': _roomsToShare,
        'room_inventory_mode': 'per_room',
        'shared_rooms': _sharedRoomSlots.map((s) => s.toJson()).toList(),
        if (primary?.architecture != null)
          'shared_room_architecture': primary!.architecture.storageValue,
        'current_occupants': _housemateCount,
        if (_hasSharedBedRoom)
          'shared_bed_occupants': _sharedRoomSlots
              .firstWhere((s) => s.isSharedBed)
              .bedOccupants,
        if (effectiveHouseholdCohort != null)
          'household_cohort': effectiveHouseholdCohort.storageValue,
        if (matchingProfile != null)
          'flatmate_cohort': matchingProfile.storageValue,
        if (matchingProfile != null)
          'cohort_type': matchingProfile == FlatmateCohort.students
              ? 'student_only'
              : matchingProfile == FlatmateCohort.workingProfessionals
                  ? 'professionals_only'
                  : 'open_mixed',
        if (primary != null) ...{
          'room_type_matching': primary.roomKind.storageValue,
          'bathroom_type': primary.bathroomType.storageValue,
          'required_occupant': primary.requiredOccupant.storageValue,
          'occupant_type': primary.occupantType.storageValue,
          'target_tenant_preference':
              primary.requiredOccupant.asTargetTenantPreference.storageValue,
          if (primary.currentOccupant != null)
            'current_occupant': primary.currentOccupant!.storageValue,
          if (primary.roomProfile != null)
            'room_profile': primary.roomProfile!.storageValue,
        },
        'languages_spoken': _householdLanguages.toList(),
        'house_rule_selections':
            _houseRules.map((r) => r.storageValue).toList(),
        if (roomMapping != null) ...roomMapping,
        if (matchingProfile != null)
          'preferred_tenant_occupant': matchingProfile.label,
        if (matchingProfile == FlatmateCohort.students)
          'occupantType': 'Students',
        if (matchingProfile == FlatmateCohort.workingProfessionals)
          'occupantType': 'Working Professionals',
        if (primary?.requiredOccupant == RoomRequiredOccupant.female)
          'bachelorPreference': 'Girls only',
        if (primary?.requiredOccupant == RoomRequiredOccupant.male)
          'bachelorPreference': 'Boys only',
        if (petsPolicy == ListingPetsPolicy.caseByCase)
          'pets_display_note': 'Pet approval required',
      });
    }

  return _applyAddressPrivacy(payload);
  }

  /// First publish stamps [published_at]; edits preserve existing; legacy omits.
  Map<String, dynamic> _publishedAtPayloadFields() {
    final prior = ListingData.text(
      widget.initialListing?[ListingCreationFieldKeys.publishedAt],
    );
    if (prior.isNotEmpty) {
      return {ListingCreationFieldKeys.publishedAt: prior};
    }
    final isExistingListing = widget.initialListing != null &&
        !_isProfileDraft(widget.initialListing) &&
        ListingData.id(widget.initialListing!).isNotEmpty;
    if (isExistingListing) return const {};
    return {
      ListingCreationFieldKeys.publishedAt:
          DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Sync listing media/copy into every room; keep room-level inventory fields.
  void _prepareSharedRoomsForPayload() {
    if (_isMultiRoomInventory) {
      _persistListingWizardToSlot(_listingWizardRoomIndex);
    }
    for (final slot in _sharedRoomSlots) {
      slot.tenantsInRoom = _housemateCount;
      slot.tenantGender = slot.requiredOccupant.asTargetTenantPreference;
      if (_roomsToShare == 1 && slot.roomProfile == null) {
        slot.roomProfile = _householdCohort;
      }
      if (_roomsToShare == 1) {
        slot.images = List<String>.from(_images);
        slot.title = _titleController.text.trim();
        slot.description = _descriptionController.text.trim();
      }
    }
    // Listing-level title/images mirror room 1 for backward-compatible payload.
    if (_isMultiRoomInventory && _sharedRoomSlots.isNotEmpty) {
      final primary = _sharedRoomSlots.first;
      _images = List<String>.from(primary.images);
      if (primary.title.trim().isNotEmpty) {
        _titleController.text = primary.title;
      }
      if (primary.description.trim().isNotEmpty) {
        _descriptionController.text = primary.description;
      }
    }
  }

  Map<String, dynamic> _applyAddressPrivacy(Map<String, dynamic> payload) {
    final result = AddressPrivacy.applyToPayload(
      payload: payload,
      hideExactAddress: _hideExactAddress,
      selected: _selectedAddress,
      area: _localityLabel.isNotEmpty
          ? _localityLabel
          : _locationController.text.trim(),
      county: _districtShortLabel() ?? _selectedAddress?.county ?? 'Dublin',
      streetLine: _locationIdentifierController.text.trim(),
      exactLat: _resolvedLatitude,
      exactLon: _resolvedLongitude,
      exactEircode: _eircodeController.text.trim().isEmpty
          ? null
          : EircodeGeocodingService.normalize(_eircodeController.text),
    );
    if (_hideExactAddress) {
      result['property_location_identifier'] = '';
      result['location'] = _publicLocationPreviewLabel();
      result['public_location'] = _publicLocationPreviewLabel();
    }
    return result;
  }

  Map<String, String>? _mapRoomArchitecture(SharedRoomArchitecture? arch) {
    if (arch == null) return null;
    switch (arch) {
      case SharedRoomArchitecture.privateEnsuite:
        return {
          'room_type': 'Ensuite room',
          'share_room_kind': 'ensuite',
        };
      case SharedRoomArchitecture.sharedBed:
        return {
          'room_type': 'Bed in shared room',
          'share_room_kind': 'bed_shared',
        };
      case SharedRoomArchitecture.privateSharedBath:
        return {
          'room_type': 'Private room',
          'share_room_kind': 'private_bath',
        };
    }
  }

  bool _isSharedCostResolved(TextEditingController controller, bool included) {
    if (included) return true;
    final raw = controller.text.trim();
    if (raw.isEmpty) return false;
    return int.tryParse(raw.replaceAll(RegExp(r'[^\d]'), '')) != null;
  }

  Map<String, dynamic> _listingPreviewSnapshot() {
    return {
      'title': _titleController.text.trim(),
      'price': _formattedPrice(),
      if (!_isShare && _formattedDeposit().isNotEmpty)
        ListingCreationFieldKeys.securityDeposit: _formattedDeposit(),
      'location': _effectiveLocationLabel(),
      'description': _descriptionController.text.trim(),
      'description_is_edited': !_isAutoDraftedDescription(),
      'description_auto_drafted': _isAutoDraftedDescription(),
      ListingCreationFieldKeys.secureBikeStorage:
          _parkingFeatures.contains(ListingParkingFeature.bikeParking),
      if (_parkingFeatures.isNotEmpty)
        ListingCreationFieldKeys.parkingFeatures:
            _parkingFeatures.map((f) => f.storageToken).toList(),
      ListingCreationFieldKeys.parkingType: _parkingFeatures.isEmpty
          ? 'not_available'
          : _parkingFeatures.first.storageToken,
      ListingCreationFieldKeys.parkingAvailable: _parkingFeatures.isNotEmpty,
      if (_petsPolicy != null)
        ListingCreationFieldKeys.petsPolicy: _petsPolicy!.storageToken,
      'pets_allowed': _petsPolicy == ListingPetsPolicy.allowed,
      'ber_rating': _berRating,
      'images': _images,
      if (_isFurnished != null)
        'furnishing': _isFurnished! ? 'Furnished' : 'Unfurnished',
      if (_agreementType != null)
        TenurePreference.listingKey: _agreementType!.storageToken,
      ListingCreationFieldKeys.hostName: _hostNameController.text.trim(),
    };
  }

  String _formattedPrice() {
    if (_isShare) {
      final digits =
          (_primaryRoomSlot?.monthlyRent ?? '').replaceAll(RegExp(r'[^\d]'), '');
      if (digits.isEmpty) return '';
      return '€$digits/month';
    }
    final raw = _rentController.text.trim();
    if (raw.isEmpty) return raw;
    final numeric = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (numeric.isEmpty) return raw;
    if (raw.contains('/')) return raw;
    return '€$numeric/month';
  }

  /// Independent Places deposit — euro integer string, e.g. `€1850`.
  String _formattedDeposit() {
    final raw = _depositController.text.trim();
    if (raw.isEmpty) return '';
    final numeric = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (numeric.isEmpty) return '';
    return '€$numeric';
  }

  bool _isWithinDublinBounds(double lat, double lon) =>
      lat >= 53.20 && lat <= 53.45 && lon >= -6.50 && lon <= -6.00;

  bool _isDublinCityCentre(double? lat, double? lon) =>
      _isNearDublinCityCentre(lat, lon);

  bool _isNearDublinCityCentre(double? lat, double? lon) {
    if (lat == null || lon == null) return false;
    return (lat - _dublinCenterLat).abs() < 0.012 &&
        (lon - _dublinCenterLon).abs() < 0.018;
  }

  Future<({double lat, double lon})> _resolveListingCoordinates(
    String location,
  ) async {
    if (_resolvedLatitude != null && _resolvedLongitude != null) {
      return (lat: _resolvedLatitude!, lon: _resolvedLongitude!);
    }

    final eircode = _eircodeController.text.trim();
    if (eircode.isNotEmpty &&
        EircodeGeocodingService.isValidFormat(eircode)) {
      try {
        final coords =
            await EircodeGeocodingService.resolveCoordinates(eircode);
        if (_isWithinDublinBounds(coords.latitude, coords.longitude)) {
          _resolvedLatitude = coords.latitude;
          _resolvedLongitude = coords.longitude;
          return (lat: coords.latitude, lon: coords.longitude);
        }
      } catch (_) {
        // Fall through to area geocoding.
      }
    }

    final query = location.trim();
    if (query.isEmpty) {
      final identifier = _locationIdentifierController.text.trim();
      if (identifier.isNotEmpty) {
        try {
          final locations = await locationFromAddress('$identifier, Ireland');
          if (locations.isNotEmpty) {
            final first = locations.first;
            if (_isWithinDublinBounds(first.latitude, first.longitude)) {
              return (lat: first.latitude, lon: first.longitude);
            }
          }
        } catch (_) {
          // Fall through to city-centre default.
        }
      }
    } else if (query.isNotEmpty) {
      try {
        final locations = await locationFromAddress('$query, Ireland');
        if (locations.isNotEmpty) {
          final first = locations.first;
          if (_isWithinDublinBounds(first.latitude, first.longitude)) {
            return (lat: first.latitude, lon: first.longitude);
          }
        }
      } catch (_) {
        // Fall through to city-centre default.
      }
    }

    return (lat: _dublinCenterLat, lon: _dublinCenterLon);
  }

  /// Geocode profile area / Eircode without falling back to city centre.
  Future<({double lat, double lon})?> _resolveListingCoordinatesWithoutCityFallback(
    String location,
  ) async {
    if (_resolvedLatitude != null && _resolvedLongitude != null) {
      if (!_isDublinCityCentre(_resolvedLatitude, _resolvedLongitude)) {
        return (lat: _resolvedLatitude!, lon: _resolvedLongitude!);
      }
    }

    final eircode = _eircodeController.text.trim();
    if (eircode.isNotEmpty &&
        EircodeGeocodingService.isValidFormat(eircode)) {
      try {
        final coords =
            await EircodeGeocodingService.resolveCoordinates(eircode);
        if (_isWithinDublinBounds(coords.latitude, coords.longitude)) {
          return (lat: coords.latitude, lon: coords.longitude);
        }
      } catch (_) {
        // Fall through to area geocoding.
      }
    }

    final query = location.trim();
    if (query.isEmpty) {
      final identifier = _locationIdentifierController.text.trim();
      if (identifier.isNotEmpty) {
        try {
          final locations = await locationFromAddress('$identifier, Ireland');
          if (locations.isNotEmpty) {
            final first = locations.first;
            if (_isWithinDublinBounds(first.latitude, first.longitude)) {
              return (lat: first.latitude, lon: first.longitude);
            }
          }
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    try {
      final locations = await locationFromAddress('$query, Ireland');
      if (locations.isNotEmpty) {
        final first = locations.first;
        if (_isWithinDublinBounds(first.latitude, first.longitude)) {
          return (lat: first.latitude, lon: first.longitude);
        }
      }
    } catch (_) {
      return null;
    }

    final centroid = dublinDistrictCentroidFromLabel(query);
    if (centroid != null) {
      return (lat: centroid.lat, lon: centroid.lon);
    }

    return null;
  }

  void _applyAddressSuggestion(
    IrishAddressSuggestion suggestion, {
    required bool fromGps,
  }) {
    _resetLocationDerivedFields();
    if (fromGps) {
      _externalLocationEpoch++;
      _externalLocationLabel = null;
    }
    _onMapPinPlaced(
      suggestion.latitude,
      suggestion.longitude,
      fromGps: fromGps,
    );
  }

  void _applyProximityPayload(
    Map<String, dynamic> extracted, {
    bool phase1Local = false,
  }) {
    if (_proximityEditing) return;
    final transitType = ProfileData.text(extracted['transit_type']);
    final stopName = ProfileData.text(extracted['nearest_stop_name']);
    final walk = (extracted['walk_minutes'] as num?)?.toInt() ?? 0;
    if (phase1Local && !isConfidentProximityPayload(extracted)) {
      return;
    }
    final line = stopName.isNotEmpty
        ? (transitType.isNotEmpty ? '$transitType · $stopName' : stopName)
        : transitType;
    if (line.isEmpty) return;
    _proximityDraft.transportLine = line;
    _proximityDraft.transportWalkMin = walk;
    _transportLineController.text = line;
    _transportWalkController.text = walk > 0 ? '$walk' : '';
  }

  void _seedProximityFromTransit(
    double lat,
    double lon, {
    bool phase1Local = false,
  }) {
    if (_proximityEditing) return;
    final extracted = TransitExtractionService.extractLocally(
      latitude: lat,
      longitude: lon,
    );
    if (extracted == null && !phase1Local) {
      final nearest = TransitExtractionService.extractNearest(
        latitude: lat,
        longitude: lon,
      );
      if (nearest != null && isConfidentProximityPayload(nearest)) {
        _applyProximityPayload(nearest);
        return;
      }
    }
    if (extracted == null) {
      _transportLineController.clear();
      _transportWalkController.clear();
      _proximityDraft.transportLine = '';
      _proximityDraft.transportWalkMin = 0;
      return;
    }
    _applyProximityPayload(extracted, phase1Local: phase1Local);
  }

  void _clearAutoProximityFields() {
    if (_proximityEditing) return;
    _transportLineController.clear();
    _transportWalkController.clear();
    _groceryWalkController.clear();
    _groceryBrand = '';
    _primarySchoolController.clear();
    _secondarySchoolController.clear();
    _crecheNameController.clear();
    _crecheWalkController.clear();
    _proximityDraft.transportLine = '';
    _proximityDraft.transportWalkMin = 0;
    _proximityDraft.groceryBrand = '';
    _proximityDraft.groceryWalkMin = 0;
    _proximityDraft.primarySchool = '';
    _proximityDraft.primarySchoolWalkMin = 0;
    _proximityDraft.secondarySchool = '';
    _proximityDraft.secondarySchoolWalkMin = 0;
    _proximityDraft.collegeSchool = '';
    _proximityDraft.collegeWalkMin = 0;
    _proximityDraft.crecheName = '';
    _proximityDraft.crecheWalkMin = 0;
    _proximityDraft.gpClinic = '';
    _proximityDraft.gpWalkMin = 0;
    _proximityDraft.groceries = [];
    _proximityDraft.extraTransit = [];
    _proximityDraft.lifestyleTags = [];
    _extraProximityTransit = [];
    _profileGroceries = [];
    _collegeSchool = '';
    _collegeWalkMin = null;
    _gpClinic = '';
    _gpWalkMin = null;
    _showMoreLocalAmenities = false;
  }

  /// Populates grocery/schools/crèche fields from an Overpass result.
  void _applyAmenities(
    NearbyAmenities amenities, {
    bool phase1Local = false,
  }) {
    final resolved = phase1Local
        ? filterNearbyAmenitiesForPhase1(amenities)
        : amenities;
    _fillEircodeIfEmpty(resolved.eircode);
    if (resolved.transitLine != null) {
      _transportLineController.text = resolved.transitLine!;
      _transportWalkController.text =
          resolved.transitWalkMin != null ? '${resolved.transitWalkMin}' : '';
      _proximityDraft.transportLine = resolved.transitLine!;
      _proximityDraft.transportWalkMin = resolved.transitWalkMin ?? 0;
    }
    if (resolved.supermarketName != null) {
      final brand = _normalisedGroceryBrand(resolved.supermarketName!);
      _groceryBrand = brand;
      _groceryWalkController.text =
          resolved.supermarketWalkMin != null
              ? '${resolved.supermarketWalkMin}'
              : '';
      _proximityDraft.groceryBrand = brand;
      _proximityDraft.groceryWalkMin = resolved.supermarketWalkMin ?? 0;
    }
    if (resolved.primarySchool != null) {
      _primarySchoolController.text = resolved.primarySchool!;
      _proximityDraft.primarySchool = resolved.primarySchool!;
      _proximityDraft.primarySchoolWalkMin =
          resolved.primarySchoolWalkMin ?? 0;
    }
    if (resolved.secondarySchool != null) {
      _secondarySchoolController.text = resolved.secondarySchool!;
      _proximityDraft.secondarySchool = resolved.secondarySchool!;
      _proximityDraft.secondarySchoolWalkMin =
          resolved.secondarySchoolWalkMin ?? 0;
    }
    if (resolved.crecheName != null) {
      _crecheNameController.text = resolved.crecheName!;
      _crecheWalkController.text =
          resolved.crecheWalkMin != null ? '${resolved.crecheWalkMin}' : '';
      _proximityDraft.crecheName = resolved.crecheName!;
      _proximityDraft.crecheWalkMin = resolved.crecheWalkMin ?? 0;
    }
    if (resolved.extraTransit.isNotEmpty) {
      _extraProximityTransit = List<NearbyExtraTransit>.from(
        resolved.extraTransit,
      );
      _proximityDraft.extraTransit =
          List<NearbyExtraTransit>.from(resolved.extraTransit);
    }
    _profileGroceries = List<NearbyGroceryOption>.from(resolved.groceries);
    if (_profileGroceries.isEmpty && resolved.supermarketName != null) {
      _profileGroceries = [
        NearbyGroceryOption(
          brand: _normalisedGroceryBrand(resolved.supermarketName!),
          walkMin: resolved.supermarketWalkMin ?? 0,
        ),
      ];
    }
    _proximityDraft.groceries =
        List<NearbyGroceryOption>.from(_profileGroceries);
    if (resolved.collegeSchool != null) {
      _collegeSchool = resolved.collegeSchool!;
      _collegeWalkMin = resolved.collegeWalkMin;
      _proximityDraft.collegeSchool = resolved.collegeSchool!;
      _proximityDraft.collegeWalkMin = resolved.collegeWalkMin ?? 0;
    }
    if (resolved.gpClinic != null) {
      _gpClinic = resolved.gpClinic!;
      _gpWalkMin = resolved.gpWalkMin;
      _proximityDraft.gpClinic = resolved.gpClinic!;
      _proximityDraft.gpWalkMin = resolved.gpWalkMin ?? 0;
    }
  }

  void _fillEircodeIfEmpty(String? eircode) {
    if (eircode == null || eircode.trim().isEmpty) return;
    if (_eircodeController.text.trim().isNotEmpty) return;
    final area = _locationController.text.trim();
    if (area.isNotEmpty &&
        !EircodeGeocodingService.matchesDistrict(eircode, area)) {
      return;
    }
    _eircodeController.text = EircodeGeocodingService.normalize(eircode);
  }

  /// Normalises an OSM grocery name to one of the canonical dropdown brands.
  String _normalisedGroceryBrand(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('tesco')) return 'Tesco';
    if (lower.contains('dunnes')) return 'Dunnes';
    if (lower.contains('supervalu') || lower.contains('super valu')) {
      return 'SuperValu';
    }
    if (lower.contains('lidl')) return 'Lidl';
    if (lower.contains('aldi')) return 'Aldi';
    if (lower.contains('spar')) return 'Spar';
    if (lower.contains('centra')) return 'Centra';
    // Unknown brand — keep raw name; chip will show it but dropdown won't match.
    return raw;
  }

  /// Pin used for Overpass proximity — GPS first, then Eircode-specific sources.
  Future<({double lat, double lon})> _resolveProximityCoordinates(
    String location,
    String eircode,
  ) async {
    // Priority 1: GPS coordinates (from "Use current location")
    if (_locationFromGps &&
        _resolvedLatitude != null &&
        _resolvedLongitude != null &&
        !_isNearDublinCityCentre(_resolvedLatitude, _resolvedLongitude)) {
      return (lat: _resolvedLatitude!, lon: _resolvedLongitude!);
    }

    // Priority 2: Coordinates from address selection (Nominatim geocode)
    if (_resolvedLatitude != null &&
        _resolvedLongitude != null &&
        _resolvedLatitude != 0 &&
        _resolvedLongitude != 0 &&
        !_isNearDublinCityCentre(_resolvedLatitude, _resolvedLongitude)) {
      return (lat: _resolvedLatitude!, lon: _resolvedLongitude!);
    }

    // Priority 3: Fall back to area-level geocoding
    final coords = await _resolveListingCoordinates(location);
    return (lat: coords.lat, lon: coords.lon);
  }

  void _applyCachedProximitySnapshot(
    ProximityResolutionSnapshot snapshot,
    double lat,
    double lon, {
    bool usedGpsCoords = false,
  }) {
    _resolvedLatitude = lat;
    _resolvedLongitude = lon;
    _neighborhoodAmenityTags = List<NeighborhoodAmenityTag>.from(
      snapshot.lifestyleTags,
    );
    _neighborhoodAmenitiesLoading = false;
    _amenitiesEnrichmentInFlight = false;
    if (usedGpsCoords) {
      final coordLabel = dublinDistrictLabelFromCoordinates(lat, lon);
      if (coordLabel != null) {
        _locationController.text = coordLabel;
      }
    }
    if (snapshot.amenities != null && !snapshot.amenities!.isEmpty) {
      _applyAmenities(snapshot.amenities!);
    }
    if (snapshot.transitPayload != null) {
      _applyProximityPayload(snapshot.transitPayload!);
    } else if (_transportLineController.text.trim().isEmpty) {
      _seedProximityFromTransit(lat, lon);
    }
    _proximityResolving = false;
    _proximityResolved = true;
  }

  Future<void> _resolveProximityAt(
    double lat,
    double lon, {
    bool usedGpsCoords = false,
    bool showInitialLoading = true,
    int? generation,
  }) async {
    if (_proximityEditing || widget.saving) return;
    final activeGen = generation ?? ++_proximityGeneration;
    final cellKey = ProximityResolutionCache.keyFor(lat, lon);
    _logLocationPerf('proximity_generation_start', {
      'fromGps': usedGpsCoords,
      'cellKey': cellKey,
    });

    final cached = ProximityResolutionCache.getProximity(cellKey);
    if (cached != null) {
      _logLocationPerf('poi_lookup_end', {
        'ms': 0,
        'cacheHit': true,
        'fromGps': usedGpsCoords,
      });
      _logLocationPerf('proximity_generation_end', {
        'ms': 0,
        'cacheHit': true,
        'fromGps': usedGpsCoords,
      });
      if (showInitialLoading) {
        setState(() {
          _proximityResolving = true;
          _proximityResolved = false;
          _neighborhoodAmenitiesLoading = true;
          _neighborhoodAmenityTags = [];
          _clearAutoProximityFields();
        });
      }
      if (!mounted || activeGen != _proximityGeneration || _proximityEditing) {
        return;
      }
      setState(
        () => _applyCachedProximitySnapshot(
          cached,
          lat,
          lon,
          usedGpsCoords: usedGpsCoords,
        ),
      );
      return;
    }

    if (showInitialLoading) {
      setState(() {
        _proximityResolving = true;
        _proximityResolved = false;
        _neighborhoodAmenitiesLoading = true;
        _amenitiesEnrichmentInFlight = false;
        _neighborhoodAmenityTags = [];
        _clearAutoProximityFields();
      });
    }

    final swPoi = Stopwatch()..start();
    _logLocationPerf('poi_lookup_start', {'fromGps': usedGpsCoords});
    final overpassFuture = OverpassAmenitiesService.fetchNearby(
      latitude: lat,
      longitude: lon,
    );
    final edgeTransitFuture = TransitExtractionService.enrichViaEdgeFunction(
      latitude: lat,
      longitude: lon,
    );
    if (mounted && activeGen == _proximityGeneration && !_proximityEditing) {
      setState(() => _amenitiesEnrichmentInFlight = true);
    }

    try {
      final catalogLifestyle = await NeighborhoodAmenitiesService.resolve(
        latitude: lat,
        longitude: lon,
      );
      if (!mounted || activeGen != _proximityGeneration || _proximityEditing) {
        return;
      }

      final structuredFallback = StructuredAmenitiesFallbackService.resolve(
        latitude: lat,
        longitude: lon,
      );
      final phase1LifestyleTags = mergeAmenityTags(
        catalogLifestyle,
        structuredFallback?.lifestyleTags ?? const [],
      );

      _logLocationPerf('poi_lookup_end', {
        'ms': swPoi.elapsedMilliseconds,
        'cacheHit': false,
        'phase': 'preloaded_catalog',
        'fromGps': usedGpsCoords,
      });

      setState(() {
        _resolvedLatitude = lat;
        _resolvedLongitude = lon;
        _neighborhoodAmenityTags = phase1LifestyleTags;
        _neighborhoodAmenitiesLoading = false;
        if (usedGpsCoords) {
          _syncListingAreaKey(lat: lat, lon: lon);
          if (_listingAreaKey != null) {
            _locationController.text =
                TargetSearchAreas.labelForKey(_listingAreaKey!);
          }
        }
        if (structuredFallback != null && !structuredFallback.isEmpty) {
          _applyAmenities(structuredFallback, phase1Local: true);
        }
        if (_transportLineController.text.trim().isEmpty) {
          _seedProximityFromTransit(lat, lon, phase1Local: true);
        }
        _proximityResolving = false;
        _proximityResolved = true;
      });

      final amenities = await overpassFuture;
      if (!mounted || activeGen != _proximityGeneration || _proximityEditing) {
        return;
      }

      final transitPayload = await edgeTransitFuture;
      if (!mounted || activeGen != _proximityGeneration || _proximityEditing) {
        return;
      }

      final overpassLifestyle = amenities?.lifestyleTags ?? [];
      final lifestyleTags = mergeAmenityTags(
        mergeAmenityTags(
          catalogLifestyle,
          structuredFallback?.lifestyleTags ?? const [],
        ),
        overpassLifestyle,
      );

      setState(() {
        _amenitiesEnrichmentInFlight = false;
        _neighborhoodAmenityTags = lifestyleTags;
        if (amenities != null && !amenities.isEmpty) {
          _applyAmenities(amenities);
        }
        if (transitPayload != null) {
          _applyProximityPayload(transitPayload);
        } else if (_transportLineController.text.trim().isEmpty) {
          _seedProximityFromTransit(lat, lon);
        }
      });

      ProximityResolutionCache.putProximity(
        cellKey,
        ProximityResolutionSnapshot(
          lifestyleTags: lifestyleTags,
          amenities: amenities,
          transitPayload: transitPayload,
        ),
      );
      _logLocationPerf('proximity_generation_end', {
        'ms': swPoi.elapsedMilliseconds,
        'cacheHit': false,
        'fromGps': usedGpsCoords,
      });
    } catch (_) {
      if (!mounted || activeGen != _proximityGeneration) return;
      setState(() {
        _amenitiesEnrichmentInFlight = false;
        if (_transportLineController.text.trim().isEmpty) {
          _seedProximityFromTransit(lat, lon, phase1Local: true);
        }
        _neighborhoodAmenitiesLoading = false;
        _proximityResolving = false;
        _proximityResolved = true;
      });
      _logLocationPerf('proximity_generation_end', {
        'ms': swPoi.elapsedMilliseconds,
        'error': true,
        'fromGps': usedGpsCoords,
      });
    }
  }

  Future<void> _resolveProximity() async {
    if (_proximityEditing || widget.saving) return;

    final location = _effectiveLocationLabel();
    final eircodeRaw = _eircodeController.text.trim().isNotEmpty
        ? _eircodeController.text.trim()
        : _addressSearchController.text.trim();
    final eircode = EircodeGeocodingService.isValidFormat(eircodeRaw)
        ? EircodeGeocodingService.normalize(eircodeRaw)
        : '';
    final hasTrigger =
        location.length >= 2 ||
        (eircode.isNotEmpty &&
            EircodeGeocodingService.isValidFormat(eircode)) ||
        (_resolvedLatitude != null && _resolvedLongitude != null);

    if (!hasTrigger) {
      setState(() {
        _proximityResolved = false;
        _proximityResolving = false;
      });
      return;
    }

    setState(() {
      _proximityResolving = true;
      _proximityResolved = false;
      _neighborhoodAmenitiesLoading = true;
      _amenitiesEnrichmentInFlight = false;
      _neighborhoodAmenityTags = [];
      _clearAutoProximityFields();
    });

    try {
      final usedGpsCoords = _locationFromGps &&
          _resolvedLatitude != null &&
          _resolvedLongitude != null;
      final pin = await _resolveProximityCoordinates(location, eircode);
      if (!mounted) return;
      final gen = ++_proximityGeneration;
      await _resolveProximityAt(
        pin.lat,
        pin.lon,
        usedGpsCoords: usedGpsCoords,
        showInitialLoading: false,
        generation: gen,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _proximityResolving = false;
        _neighborhoodAmenitiesLoading = false;
        _proximityResolved = false;
      });
    }
  }

  void _handleBack() {
    if (widget.saving) return;
    if (_currentStep <= 0) {
      widget.onExit?.call();
      return;
    }
    // Leaving Rooms step clears Continue validation chrome until next attempt.
    if (_isShare && _currentStep == 1) {
      _roomsStepContinueAttempted = false;
    }
    _goToWizardStep(_currentStep - 1);
  }

  void _goToWizardStep(int step) {
    if (widget.saving || step < 0 || step >= _stepCount) return;
    if (step == _currentStep) return;

    if (step > _currentStep) {
      for (var i = _currentStep; i < step; i++) {
        final error = validateStep(i);
        if (error != null) {
          _message(error);
          return;
        }
      }
    }

    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _currentStep = step);
    _onStepActivated(step);
  }

  void _handlePublish() {
    if (widget.saving) return;
    if (!_listingAuthorizationConfirmed) return;
    for (var step = 0; step < _stepCount; step++) {
      final error = validateStep(step);
      if (error != null) {
        _jumpToStepWithError(step, error);
        return;
      }
    }
    widget.onPublish?.call();
  }

  void _jumpToStepWithError(int step, String message) {
    if (_currentStep != step) {
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep = step);
      _onStepActivated(step);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final GlobalKey? scrollKey = switch (step) {
        0 => _sharedCostsShowErrors
            ? _sharedCostsSectionKey
            : (_depositShowError ? _depositSectionKey : _rentSectionKey),
        1 => _locationPanelKey,
        2 => _titleShowError ? _titleFieldKey : null,
        _ => null,
      };
      final ctx = scrollKey?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
          alignment: 0.15,
        );
      }
    });
    _message(message);
  }

  Future<void> _useCurrentLocation() async {
    if (_fetchingLocation || widget.saving) return;
    final swTotal = Stopwatch()..start();
    _logLocationPerf('location_acquisition_start', {});
    // TEMP DEBUG
    void gpsLog(String phase, [Map<String, Object?> data = const {}]) {
      if (!kDebugMode) return;
      debugPrint('[GPS] $phase $data');
    }

    setState(() {
      _fetchingLocation = true;
      _locationPrefillLocked = false;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      gpsLog('permissions', {
        'serviceEnabled': serviceEnabled,
      });
      if (!serviceEnabled) {
        await _handleLocationFailure(
          'Location services are off. Enter your Eircode or search for your address instead.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      gpsLog('permissions', {
        'checkPermission': permission.name,
      });
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        gpsLog('permissions', {
          'requestPermission': permission.name,
        });
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _handleLocationFailure(
          'Location permission denied. Enter your Eircode or search for your address instead.',
        );
        return;
      }

      final swGps = Stopwatch()..start();
      final resolved = await FastLocationService.resolveForUserAction();
      swGps.stop();
      _logLocationPerf('location_acquisition_end', {
        'ms': swGps.elapsedMilliseconds,
        'source': resolved?.source.name,
        'ok': resolved != null,
      });
      gpsLog('resolveForUserAction_result', {
        'ms': swGps.elapsedMilliseconds,
        'ok': resolved != null,
        'source': resolved?.source.name,
        'lat': resolved?.latitude,
        'lon': resolved?.longitude,
      });
      if (resolved == null) {
        await _handleLocationFailure(
          'Could not read your location. Enter your Eircode or search for your address instead.',
        );
        return;
      }

      final position = (
        latitude: resolved.latitude,
        longitude: resolved.longitude,
      );

      if (!_isWithinDublinBounds(position.latitude, position.longitude)) {
        await _handleLocationFailure(
          'Your location is outside Dublin. Enter your Dublin address or Eircode instead.',
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _fetchingLocation = false;
        _resetLocationDerivedFields();
        _externalLocationEpoch++;
        _externalLocationLabel = null;
      });
      _onMapPinPlaced(
        position.latitude,
        position.longitude,
        fromGps: true,
      );
      _logLocationPerf('current_location_pipeline_kicked', {
        'totalMs': swTotal.elapsedMilliseconds,
      });
    } catch (e, st) {
      gpsLog('exception', {
        'phase': '_useCurrentLocation',
        'error': e.toString(),
        'type': e.runtimeType.toString(),
        'stack': st.toString(),
        'totalMs': swTotal.elapsedMilliseconds,
      });
      if (mounted) setState(() => _fetchingLocation = false);
      await _handleLocationFailure(
        'Could not read GPS. Enter your Eircode or search for your address instead.',
      );
    }
  }

  void _logLocationPerf(String message, Map<String, Object?> data) {
    if (!kDebugMode) return;
    debugPrint('[LocationPerf] $message $data');
  }

  Future<void> _handleLocationFailure(String message) async {
    final location = _effectiveLocationLabel();
    final fallback =
        await _resolveListingCoordinatesWithoutCityFallback(location);

    if (fallback != null && mounted) {
      final suggestion = await EircodeLookupService.resolveFromCoordinates(
        fallback.lat,
        fallback.lon,
      );
      if (!mounted) return;
      if (suggestion != null) {
        setState(() {
          _applyAddressSuggestion(suggestion, fromGps: false);
        });
        _message('$message Using your profile area instead.');
        return;
      }
    }

    if (mounted) _message(message);
  }

  void _selectSpace(MarketplaceSpace space) {
    // Both listing types commit `_type` immediately so `_isShare` / Page 1
    // content switch in place (no step navigation on chip tap).
    setState(() {
      if (space == MarketplaceSpace.sharedSpace) {
        _pendingListingType = null;
        _type = space.towerPropertyType;
        _seedHostNameFromProfile();
        _petsPolicy ??= ListingPetsPolicy.notAllowed;
        _sharedParkingAvailable ??= false;
        if (_sharedRoomSlots.isEmpty) {
          _applyRoomsToShare(1);
        }
        _expandedRoomIndex = 0;
        if (_currentStep >= _stepCount) _currentStep = 0;
      } else {
        // Commit IP immediately so `_isShare` flips false and Page 1 IP
        // fields render. Pending-only left `_type` on Shared → blank page.
        _pendingListingType = null;
        _type = space.towerPropertyType;
        if (_currentStep >= _stepCount) _currentStep = 0;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      final page = _currentStep.clamp(0, _stepCount - 1);
      if (_pageController.page?.round() != page) {
        _pageController.jumpToPage(page);
      }
    });
  }

  bool _commitPendingListingTypeIfNeeded() {
    final pending = _pendingListingType;
    if (pending == null || pending == _type) return false;
    final switchingToShare =
        MarketplaceSpace.fromTowerPropertyType(pending) ==
            MarketplaceSpace.sharedSpace;
    setState(() {
      _type = pending;
      _pendingListingType = null;
      if (switchingToShare) {
        _seedHostNameFromProfile();
        if (_sharedRoomSlots.isEmpty) {
          _applyRoomsToShare(1);
        } else {
          _applyRoomsToShare(_roomsToShare.clamp(1, _totalRoomsInProperty));
        }
        _expandedRoomIndex = 0;
      }
    });
    return switchingToShare;
  }

  void _handleNext() {
    if (widget.saving) return;
    // Pending Entire Place (or rare pending Shared) commits on Continue.
    if (_currentStep == 0 && _commitPendingListingTypeIfNeeded()) {
      // Switched into Shared Spaces — stay on Property step (fields already inline).
      return;
    }
    // Rooms step: keep Continue tappable when incomplete — show inline banner.
    if (_isShare && _currentStep == 1 && !_isSharedRoomsStepReady()) {
      setState(() => _roomsStepContinueAttempted = true);
      return;
    }
    if (_isShare && _currentStep == 2 && _isMultiRoomInventory) {
      _persistListingWizardToSlot(_listingWizardRoomIndex);
    }
    final error = validateStep(_currentStep);
    if (error != null) {
      _message(error);
      return;
    }
    if (_currentStep >= _stepCount - 1) return;
    final nextStep = _currentStep + 1;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
    );
    setState(() {
      _currentStep = nextStep;
      _roomsStepContinueAttempted = false;
    });
    _onStepActivated(nextStep);
  }

  Future<void> _pickAvailableFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _availableFrom ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _availableFrom = picked);
  }

  void _message(String text) => widget.onMessage?.call(text);

  @override
  Widget build(BuildContext context) {
    final maxContentWidth = _isLocationWizardStep
        ? _locationStepMaxContentWidth
        : _standardMaxContentWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: GamifiedFormProgress(
                current: _currentStep,
                total: _stepCount,
                stepLabels: _wizardStepLabels,
                onStepTap: widget.saving ? null : _goToWizardStep,
              ),
            ),
          ),
        ),
        if (_isShare)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: _sharedInPageProgress(),
                    minHeight: 3,
                    backgroundColor: const Color(0xFFE5E7EB),
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: PageView(
                key: ValueKey('wizard-pages-$_stepCount'),
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentStep = index);
                  _onStepActivated(index);
                },
                children: [
                  _stepScroll(
                    Form(key: _step1Key, child: _step1Content()),
                  ),
                  _stepScroll(
                    Form(key: _step2Key, child: _step2Content()),
                  ),
                  _stepScroll(
                    Form(key: _step3Key, child: _step3Content()),
                  ),
                  if (_isShare)
                    _stepScroll(
                      Form(key: _step4Key, child: _step4Content()),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_currentStep == _stepCount - 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: CheckboxListTile(
                  value: _listingAuthorizationConfirmed,
                  onChanged: widget.saving
                      ? null
                      : (value) {
                          setState(() {
                            _listingAuthorizationConfirmed = value ?? false;
                          });
                        },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    ListingData.listingAuthorizationDeclaration,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
        GamifiedFormNavBar(
          floating: true,
          showBack: true,
          showNext: _currentStep < _stepCount - 1,
          showSubmit: _currentStep == _stepCount - 1,
          nextLabel: 'Continue →',
          submitLabel: widget.initialListing != null
              ? 'Save changes'
              : 'Publish Listing 🚀',
          isSubmitting: widget.saving,
          // Rooms step stays tappable when incomplete so Continue can show
          // field-level required hints (no toast/modal).
          enabled: !widget.saving &&
              (!_isShare ||
                  _sharedCurrentStepReady ||
                  _currentStep == 1),
          submitEnabled: !widget.saving &&
              (!_isShare || _sharedCurrentStepReady) &&
              _listingAuthorizationConfirmed,
          onBack: _handleBack,
          onNext: _handleNext,
          onSubmit: _handlePublish,
        ),
      ],
    );
  }

  Widget _stepScroll(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 900 ? 32.0 : 24.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24),
          child: child,
        );
      },
    );
  }

  Widget _step1Content() {
    if (_isShare) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GamifiedFormPageHeader(
            title: '🏠 Your Property',
            subtitle: "List what's available — we'll handle the rest.",
          ),
          const SizedBox(height: listingSectionSpacing),
          _hostNameSection(),
          const SizedBox(height: listingFieldSpacing),
          _listingTypeSection(),
          // Shared room chip selects inline — fields render below, no navigation.
          if (_listingTypeChipIsShare) ...[
            const SizedBox(height: 12),
            _propertyTypeSection(),
            const SizedBox(height: 12),
            _sharedPage1PetsParkingSection(),
            const SizedBox(height: 16),
            ListingCompactCounter(
              label: 'Total rooms in property',
              value: _totalRoomsInProperty,
              min: 1,
              max: ListingCreationFormConstants.sharedSpacesMaxRooms,
              compact: true,
              onDecrement: widget.saving || _totalRoomsInProperty <= 1
                  ? () {}
                  : () => _setTotalRoomsInProperty(_totalRoomsInProperty - 1),
              onIncrement: widget.saving ||
                      _totalRoomsInProperty >=
                          ListingCreationFormConstants.sharedSpacesMaxRooms
                  ? () {}
                  : () =>
                      _setTotalRoomsInProperty(_totalRoomsInProperty + 1),
            ),
            const SizedBox(height: 12),
            ListingCompactCounter(
              label: 'Rooms available',
              value: _roomsToShare,
              min: 1,
              max: _totalRoomsInProperty.clamp(
                1,
                ListingCreationFormConstants.sharedSpacesMaxRooms,
              ),
              compact: true,
              onDecrement: widget.saving || _roomsToShare <= 1
                  ? () {}
                  : () => _setRoomsToShare(_roomsToShare - 1),
              onIncrement: widget.saving ||
                      _roomsToShare >= _totalRoomsInProperty
                  ? () {}
                  : () => _setRoomsToShare(_roomsToShare + 1),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GamifiedFormPageHeader(
          title: '🏡 Property',
          subtitle: 'Set the basics — rent, type, and furnishing.',
        ),
        const SizedBox(height: listingSectionSpacing),
        _hostNameSection(),
        const SizedBox(height: listingFieldSpacing),
        _listingTypeSection(),
        const SizedBox(height: listingFieldSpacing),
        _propertyTypeSection(),
        const SizedBox(height: listingFieldSpacing),
        _bedroomsBathroomsSection(),
        const SizedBox(height: listingFieldSpacing),
        _monthlyRentSection(),
        const SizedBox(height: listingFieldSpacing),
        _depositRequiredSection(),
        const SizedBox(height: listingFieldSpacing),
        _furnishingSection(),
        const SizedBox(height: listingFieldSpacing),
        _tenureSection(),
        const SizedBox(height: listingFieldSpacing),
        _propertyHighlightsSection(),
        const SizedBox(height: listingFieldSpacing),
        _berRatingSection(),
      ],
    );
  }

  /// Location page body — reused as-is for sequencing only.
  Widget _locationPageBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GamifiedFormPageHeader(
          title: '📍 Location',
          subtitle:
              'Search by location or address, drop a pin on the map, then confirm — nearby transport and amenities load after you confirm.',
        ),
        const SizedBox(height: listingSectionSpacing),
        _locationSection(),
      ],
    );
  }

  Widget _sharedRoomsStepContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GamifiedFormPageHeader(
          title: '🛏️ Rooms',
          subtitle: 'One card per available room.',
        ),
        const SizedBox(height: listingSectionSpacing),
        const ListingSectionHeader(
          title: '🛏️ Room Inventory',
          subtitle: 'Configure each room you are offering.',
          required: true,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final anyExpanded = _expandedRoomIndex >= 0;
            final twoCol = constraints.maxWidth >= 720 &&
                _sharedRoomSlots.length > 1 &&
                !anyExpanded;
            if (!twoCol) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _sharedRoomSlots.length; i++) ...[
                    _sharedRoomInventoryCard(i),
                    if (i < _sharedRoomSlots.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              );
            }
            return Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _sharedRoomSlots.length; i++)
                  SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: _sharedRoomInventoryCard(i),
                  ),
              ],
            );
          },
        ),
        if (_isMultiRoomInventory)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.saving ? null : _copyRoom1ToAllRooms,
              icon: const Icon(Icons.copy_all_outlined, size: 18),
              label: const Text('Copy Room 1 to all rooms'),
            ),
          ),
      ],
    );
  }

  Widget _step2Content() {
    if (_isShare) {
      return _sharedRoomsStepContent();
    }
    return _locationPageBody();
  }

  Widget _step3Content() {
    if (_isShare) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GamifiedFormPageHeader(
            title: '🏡 Household & listing',
            subtitle: 'Context once — then publish-ready copy.',
          ),
          const SizedBox(height: listingSectionSpacing),
          _sharedHouseholdSection(),
          const SizedBox(height: listingSectionSpacing),
          _sharedListingContentSection(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GamifiedFormPageHeader(
          title: '✨ Listing',
          subtitle:
              'Show the space with great photos and a clear title — publish when you are ready.',
        ),
        const SizedBox(height: listingSectionSpacing),
        _mediaSection(),
        const SizedBox(height: listingSectionSpacing),
        _titleSection(),
        const SizedBox(height: listingFieldSpacing),
        _descriptionSection(),
        const SizedBox(height: listingSectionSpacing),
        _optionalEnhancementsSection(),
      ],
    );
  }

  Widget _step4Content() {
    // Shared Spaces step 4 — existing location body only.
    return _locationPageBody();
  }

  Widget _tenureSection() {
    final leaseOptions = _isShare
        ? TenurePreference.values
        : TenurePreference.independentPlaceListingValues;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(title: 'Lease type'),
        ListingDaftRadioChoiceList<TenurePreference>(
          enabled: !widget.saving,
          selected: _agreementType,
          onChanged: (v) => setState(() {
            _agreementType = v;
            if (v == TenurePreference.longTerm) {
              _subletDurationUnit = SubletDurationUnit.years;
            }
          }),
          options: {
            for (final t in leaseOptions) t: t.label,
          },
          emojis: {
            TenurePreference.temporary: '⏳',
            TenurePreference.longTerm: '📅',
            if (_isShare) TenurePreference.flexible: '🔄',
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _tenureDurationRow(),
                const SizedBox(height: 12),
                ListingLabeledField(
                  label: 'Availability flexibility',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final flex in (_isShare
                          ? LandlordAvailabilityFlexibility.values
                          : LandlordAvailabilityFlexibility
                              .independentPlaceValues))
                        ListingOutlineChoiceTile(
                          label: flex.label,
                          selected: _availabilityFlexibility == flex,
                          enabled: !widget.saving,
                          height: listingFieldHeight,
                          textAlign: TextAlign.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          onTap: () => setState(
                            () => _availabilityFlexibility = flex,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tenureDurationRow() {
    final availableFrom = ListingLabeledField(
      label: 'Available from',
      child: ListingDateInputField(
        externalLabel: true,
        value: _availableFrom,
        enabled: !widget.saving,
        onTap: _pickAvailableFrom,
      ),
    );

    final duration = ListingLabeledField(
      label: 'Duration',
      child: SizedBox(
        height: listingFieldHeight,
        child: TextFormField(
          controller: _subletDurationController,
          enabled: !widget.saving,
          keyboardType: TextInputType.number,
          style: listingFieldValueStyle,
          decoration: listingInlineInputDecoration(hint: 'e.g. 3'),
        ),
      ),
    );

    final unit = ListingLabeledField(
      label: 'Unit',
      child: _agreementType == TenurePreference.longTerm
          ? const _DurationUnitDropdown(
              value: SubletDurationUnit.years,
              enabled: false,
              locked: true,
              onChanged: _noopDurationUnit,
            )
          : _DurationUnitDropdown(
              value: _subletDurationUnit,
              enabled: !widget.saving,
              onChanged: (v) => setState(() => _subletDurationUnit = v),
            ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              availableFrom,
              const SizedBox(height: 12),
              duration,
              const SizedBox(height: 12),
              unit,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: availableFrom),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: duration),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: unit),
          ],
        );
      },
    );
  }

  static void _noopDurationUnit(SubletDurationUnit _) {}

  Widget _hostNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(
          title: 'Host name',
          subtitle: 'Shown on your public listing.',
          required: true,
        ),
        ListingLabeledField(
          label: 'Full name',
          child: TextFormField(
            controller: _hostNameController,
            enabled: !widget.saving,
            textInputAction: TextInputAction.next,
            style: listingFieldValueStyle,
            decoration: listingInlineInputDecoration(hint: 'As on your ID'),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _sharedHouseholdSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(
          title: '🗣️ Languages',
          subtitle: 'Helps match compatible housemates.',
        ),
        SeekerLanguageSelectionSection(
          key: ValueKey(
            'landlord-lang-$_householdPrimaryLanguage-'
            '${_suggestedHouseholdLanguages.join('|')}-'
            '${_householdSecondaryLanguages.join('|')}',
          ),
          additionalPrimaryLabel: 'Additional Languages',
          primaryLanguage: _householdPrimaryLanguage,
          onPrimaryLanguageChanged: (lang) => setState(() {
            _householdPrimaryLanguage = lang;
            _householdSecondaryLanguages.removeWhere(
              (s) => s.toLowerCase() == lang.toLowerCase(),
            );
            _syncHouseholdLanguagesFromSeekerUi();
          }),
          suggestedLanguages: List<String>.from(_suggestedHouseholdLanguages),
          selectedSecondaryLanguages: _householdSecondaryLanguages,
          onToggleSecondaryLanguage: (lang) => setState(() {
            if (_householdSecondaryLanguages.any(
              (s) => s.toLowerCase() == lang.toLowerCase(),
            )) {
              _householdSecondaryLanguages.removeWhere(
                (s) => s.toLowerCase() == lang.toLowerCase(),
              );
            } else {
              _householdSecondaryLanguages.add(lang);
            }
            _syncHouseholdLanguagesFromSeekerUi();
          }),
          onAddSecondaryLanguage: (lang) => setState(() {
            _householdSecondaryLanguages.add(lang);
            _syncHouseholdLanguagesFromSeekerUi();
          }),
        ),
        const SizedBox(height: listingSectionSpacing),
        const ListingSectionHeader(
          title: '🏠 Current housemates',
          subtitle: 'Tell us about who lives here.',
        ),
        ListingCompactCounter(
          label: 'Current housemates',
          value: _housemateCount,
          min: 0,
          max: 12,
          compact: true,
          onDecrement: widget.saving
              ? () {}
              : () => setState(() {
                    _housematesInteractedWith = true;
                    _housemateCount = (_housemateCount - 1).clamp(0, 12);
                  }),
          onIncrement: widget.saving
              ? () {}
              : () => setState(() {
                    _housematesInteractedWith = true;
                    _housemateCount = (_housemateCount + 1).clamp(0, 12);
                  }),
        ),
        const SizedBox(height: 6),
        Text(
          _shouldShowOccupancyWarning
              ? 'Please verify occupancy details.'
              : 'Informational only — not used for matching.',
          style: listingOptionHintStyle.copyWith(
            color: _shouldShowOccupancyWarning
                ? const Color(0xFFB45309)
                : null,
          ),
        ),
        const SizedBox(height: listingSectionSpacing),
        const ListingSectionHeader(
          title: '🚭 Smoking Policy',
          subtitle: 'Sets expectations for all tenants.',
          required: true,
        ),
        _sharedChoiceRow<ListingSmokingPolicy>(
          selected: _smokingPolicy,
          onChanged: (v) => setState(() {
            _smokingPolicy = v;
            _smokingAllowed = v.allowsIndoorSmoking;
          }),
          options: const {
            ListingSmokingPolicy.noSmoking: 'No Smoking',
            ListingSmokingPolicy.outdoorOnly: 'Outdoor Only',
            ListingSmokingPolicy.smokingAllowed: 'Smoking Allowed',
          },
          emojis: const {
            ListingSmokingPolicy.noSmoking: '🚫',
            ListingSmokingPolicy.outdoorOnly: '🌿',
            ListingSmokingPolicy.smokingAllowed: '🚬',
          },
        ),
        const SizedBox(height: listingSectionSpacing),
        const ListingSectionHeader(
          title: '📋 House Rules',
          subtitle: 'Optional but helpful for self-selection.',
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final rule in SharedHouseRule.values)
                if (rule != SharedHouseRule.keepSharedAreasClean) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: widget.saving
                            ? null
                            : () => setState(() {
                                  if (_houseRules.contains(rule)) {
                                    _houseRules.remove(rule);
                                  } else {
                                    _houseRules.add(rule);
                                  }
                                }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _houseRules.contains(rule)
                                  ? _sharedChipBorderOn
                                  : _sharedChipBorderOff,
                              width: _houseRules.contains(rule) ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            rule.label,
                            style: TextStyle(
                              color: _houseRules.contains(rule)
                                  ? _sharedChipLabelOn
                                  : _sharedChipLabelOff,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }

  /// Shared Spaces Page 1 only — pets + parking (+ conditional parking type).
  Widget _sharedPage1PetsParkingSection() {
    if (!_isShare) return const SizedBox.shrink();
    final subtype = _propertySubType;
    final parkingTypes = subtype == null
        ? const <(ListingParkingFeature, String)>[]
        : _sharedParkingTypeEntriesFor(subtype);
    final petsOn = _petsPolicy == ListingPetsPolicy.allowed;
    final parkingOn = _sharedParkingAvailable == true;

    Widget petsParkingBox({
      required String label,
      required VoidCallback onTap,
    }) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: widget.saving ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            height: listingFieldHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _sharedChipBorderOn, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: listingFieldValueStyle.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _sharedChipLabelOn,
                    ),
                  ),
                ),
                const Text(
                  '↺',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF999999),
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: petsParkingBox(
                label: petsOn ? '🐾 Pets allowed' : '🚫 No pets',
                onTap: () => setState(() {
                  _petsPolicy = petsOn
                      ? ListingPetsPolicy.notAllowed
                      : ListingPetsPolicy.allowed;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: petsParkingBox(
                label: parkingOn ? '🚗 Parking available' : '🚫 No parking',
                onTap: () => setState(() {
                  final next = !parkingOn;
                  _sharedParkingAvailable = next;
                  if (!next) _parkingFeatures.clear();
                }),
              ),
            ),
          ],
        ),
        if (parkingOn) ...[
          const SizedBox(height: 10),
          if (subtype == null)
            Text(
              'Select a property type first.',
              style: listingFormHelperStyle,
            )
          else
            Row(
              children: [
                for (var i = 0; i < parkingTypes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _sharedParkingTypeChip(
                      label: parkingTypes[i].$2,
                      selected:
                          _parkingFeatures.contains(parkingTypes[i].$1),
                      onTap: () => setState(() {
                        final feature = parkingTypes[i].$1;
                        if (_parkingFeatures.contains(feature)) {
                          _parkingFeatures.remove(feature);
                        } else {
                          _parkingFeatures.add(feature);
                        }
                      }),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ],
    );
  }

  List<ListingParkingFeature> _sharedParkingTypeOptionsFor(
    ListingPropertySubType subtype,
  ) {
    return _sharedParkingTypeEntriesFor(subtype).map((e) => e.$1).toList();
  }

  List<(ListingParkingFeature, String)> _sharedParkingTypeEntriesFor(
    ListingPropertySubType subtype,
  ) {
    return switch (subtype) {
      ListingPropertySubType.apartment => const [
          (ListingParkingFeature.bikeParking, '🚲 Secure Bike'),
          (ListingParkingFeature.residentCar, '🚗 Car Parking'),
        ],
      ListingPropertySubType.house => const [
          (ListingParkingFeature.driveway, '🏠 Private Driveway'),
          (ListingParkingFeature.onStreet, '🛣️ Street Parking'),
        ],
    };
  }

  // Shared Spaces chip chrome — black border only, no checkmark, no fill.
  static const Color _sharedChipBorderOn = Color(0xFF1A1A1A);
  static const Color _sharedChipBorderOff = Color(0xFFE0E0E0);
  static const Color _sharedChipLabelOn = Color(0xFF374151);
  static const Color _sharedChipLabelOff = Color(0xFF6B7280);

  Widget _sharedChoiceBrick({
    required String label,
    String? emoji,
    required bool selected,
    required VoidCallback onTap,
    double fontSize = 13,
    TextAlign textAlign = TextAlign.left,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: widget.saving ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: listingFieldHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _sharedChipBorderOn : _sharedChipBorderOff,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (emoji != null && emoji.isNotEmpty) ...[
                Text(emoji, style: const TextStyle(fontSize: 16, height: 1)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  textAlign: textAlign,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: listingFieldValueStyle.copyWith(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: selected ? _sharedChipLabelOn : _sharedChipLabelOff,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sharedChoiceRow<T extends Object>({
    required Map<T, String> options,
    Map<T, String> emojis = const {},
    required T? selected,
    required ValueChanged<T> onChanged,
    double fontSize = 13,
  }) {
    final entries = options.entries.toList();
    return Row(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _sharedChoiceBrick(
              label: entries[i].value,
              emoji: emojis[entries[i].key],
              selected: entries[i].key == selected,
              fontSize: fontSize,
              onTap: () => onChanged(entries[i].key),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sharedParkingTypeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return _sharedChoiceBrick(
      label: label,
      selected: selected,
      textAlign: TextAlign.center,
      onTap: onTap,
    );
  }

  Widget _sharedListingContentSection() {
    if (!_isMultiRoomInventory) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ListingSectionHeader(
            title: '📸 Your Listings',
            subtitle: 'Add photos and details for each room.',
            required: true,
          ),
          ListingMediaPicker(
            images: _images,
            video: _video,
            enabled: !widget.saving,
            minPhotosRequired: 0,
            previewHeight: 100,
            useDropzoneStyle: true,
            showRequirementLabel: false,
            showVideoControls: false,
            requirementHint: 'Min 1 · Recommended 3+ · Max 5',
            onMessage: _message,
            onImagesChanged: (next) => setState(() => _images = next),
            onVideoChanged: (v) => setState(() => _video = v),
          ),
          const SizedBox(height: listingFieldSpacing),
          _sharedEditableTitleSection(),
          const SizedBox(height: listingFieldSpacing),
          _sharedCollapsedDescriptionSection(),
        ],
      );
    }

    final roomCount = _sharedRoomSlots.length;
    final index = _listingWizardRoomIndex.clamp(0, roomCount - 1);
    final slot = _sharedRoomSlots[index];
    final summary = _listingWizardRoomSummary(slot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(
          title: '📸 Your Listings',
          subtitle: 'Add photos and details for each room.',
          required: true,
        ),
        Text(
          '📸 Room ${index + 1} of $roomCount',
          style: listingFieldLabelStyle.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            summary,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
              height: 1.3,
            ),
          ),
        ],
        const SizedBox(height: listingFieldSpacing),
        ListingMediaPicker(
          key: ValueKey('listing-photos-$index'),
          images: slot.images,
          video: null,
          enabled: !widget.saving,
          minPhotosRequired: 0,
          previewHeight: 100,
          useDropzoneStyle: true,
          showRequirementLabel: false,
          showVideoControls: false,
          requirementHint: 'Min 1 · Recommended 3+ · Max 5',
          onMessage: _message,
          onImagesChanged: (next) => setState(() {
            slot.images = List<String>.from(next);
          }),
          onVideoChanged: (_) {},
        ),
        const SizedBox(height: listingFieldSpacing),
        _sharedEditableTitleSection(),
        const SizedBox(height: listingFieldSpacing),
        _sharedCollapsedDescriptionSection(),
        const SizedBox(height: listingFieldSpacing),
        Row(
          children: [
            OutlinedButton(
              onPressed: widget.saving || index <= 0
                  ? null
                  : () => _goListingWizardRoom(index - 1),
              child: const Text('← Previous room'),
            ),
            const Spacer(),
            if (index < roomCount - 1)
              FilledButton(
                onPressed: widget.saving
                    ? null
                    : () => _goListingWizardRoom(index + 1),
                child: const Text('Next room →'),
              )
            else
              Text(
                'All rooms covered',
                style: listingOptionHintStyle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _sharedEditableTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Title', style: listingFieldLabelStyle),
            ),
            InkWell(
              onTap: widget.saving
                  ? null
                  : () => setState(
                        () => _titleEditorExpanded = !_titleEditorExpanded,
                      ),
              child: const ListingAutoDraftBadge(visible: true),
            ),
          ],
        ),
        const SizedBox(height: listingLabelSpacing),
        if (!_titleEditorExpanded)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              _titleController.text.trim().isEmpty
                  ? 'Auto-generated title'
                  : _titleController.text.trim(),
              style: listingFieldValueStyle.copyWith(
                color: _titleController.text.trim().isEmpty
                    ? const Color(0xFF9CA3AF)
                    : null,
              ),
            ),
          )
        else
          TextFormField(
            controller: _titleController,
            enabled: !widget.saving,
            style: listingFieldValueStyle,
            decoration: listingInlineInputDecoration(
              hint: 'Bright private room in Dublin household',
            ),
            onChanged: (_) => setState(() {
              if (_titleShowError) _titleShowError = false;
              if (_isMultiRoomInventory) {
                _persistListingWizardToSlot(_listingWizardRoomIndex);
              }
            }),
          ),
        if (_titleShowError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Enter a title (at least 3 characters).',
              style: listingOptionHintStyle.copyWith(
                color: const Color(0xFFEF4444),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sharedCollapsedDescriptionSection() {
    final preview = _plainListingDescription(_descriptionController.text);
    final previewLine = preview.isEmpty
        ? 'Auto-generated from your answers.'
        : (preview.length > 160 ? '${preview.substring(0, 160)}…' : preview);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Description', style: listingFieldLabelStyle),
            ),
            InkWell(
              onTap: widget.saving
                  ? null
                  : () => setState(
                        () => _descriptionEditorExpanded =
                            !_descriptionEditorExpanded,
                      ),
              child: const ListingAutoDraftBadge(visible: true),
            ),
          ],
        ),
        const SizedBox(height: listingLabelSpacing),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: !_descriptionEditorExpanded
              ? Text(previewLine, style: listingOptionHintStyle)
              : TextFormField(
                  controller: _descriptionController,
                  enabled: !widget.saving,
                  maxLines: 8,
                  style: listingFieldValueStyle,
                  decoration: listingInlineInputDecoration(
                    hint: 'Edit your listing description',
                  ),
                  onChanged: (_) => setState(() {
                    if (_isMultiRoomInventory) {
                      _persistListingWizardToSlot(_listingWizardRoomIndex);
                    }
                  }),
                ),
        ),
      ],
    );
  }
  LandlordAvailabilityFlexibility? _flexibilityForToken(String? token) {
    if (token == null || token.isEmpty) return null;
    for (final flex
        in LandlordAvailabilityFlexibility.sharedSpacesValues) {
      if (flex.storageToken == token) return flex;
    }
    return null;
  }

  static const double _roomLabelGap = 6;
  static const double _roomFieldGap = 12;

  Widget _roomCoreFields(
    SharedRoomSlot slot, {
    required int index,
    required bool showRoomProfile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Room type', style: listingFieldLabelStyle),
        const SizedBox(height: _roomLabelGap),
        _sharedChoiceRow<SharedRoomKind>(
          selected: slot.roomKind,
          onChanged: (v) => setState(() {
            slot.roomKind = v;
            _afterRoomChoiceChanged(index);
          }),
          options: const {
            SharedRoomKind.privateRoom: 'Private Room',
            SharedRoomKind.sharedRoom: 'Shared Room',
          },
          emojis: const {
            SharedRoomKind.privateRoom: '🚪',
            SharedRoomKind.sharedRoom: '🤝',
          },
        ),
        const SizedBox(height: _roomFieldGap),
        _roomOccupantMatchingFields(slot, index: index),
        const SizedBox(height: _roomFieldGap),
        Text('Bathroom', style: listingFieldLabelStyle),
        const SizedBox(height: _roomLabelGap),
        _sharedChoiceRow<SharedBathroomType>(
          selected: slot.bathroomType,
          onChanged: (v) => setState(() {
            slot.bathroomType = v;
            _afterRoomChoiceChanged(index);
          }),
          options: const {
            SharedBathroomType.privateEnsuite: 'Private Ensuite',
            SharedBathroomType.sharedBathroom: 'Shared Bathroom',
          },
          emojis: const {
            SharedBathroomType.privateEnsuite: '🛁',
            SharedBathroomType.sharedBathroom: '🚿',
          },
        ),
        if (showRoomProfile) ...[
          const SizedBox(height: _roomFieldGap),
          Text('Who suits this room?', style: listingFieldLabelStyle),
          const SizedBox(height: _roomLabelGap),
          _sharedChoiceRow<FlatmateCohort>(
            selected: slot.roomProfile ?? FlatmateCohort.mixedCohort,
            onChanged: (v) => setState(() {
              slot.roomProfile = v;
              _afterRoomChoiceChanged(index);
            }),
            emojis: _cohortEmojis,
            options: {
              for (final c in FlatmateCohort.sharedSpacesValues)
                c: _cohortSegmentLabels[c] ?? c.label,
            },
          ),
        ],
      ],
    );
  }

  Widget _roomOccupantMatchingFields(SharedRoomSlot slot, {required int index}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (slot.isSharedBed) ...[
          Text('Current occupant', style: listingFieldLabelStyle),
          const SizedBox(height: _roomLabelGap),
          _sharedChoiceRow<RoomOccupantGender>(
            selected: slot.currentOccupant,
            onChanged: (v) => setState(() {
              slot.currentOccupant = v;
              _afterRoomChoiceChanged(index);
            }),
            options: const {
              RoomOccupantGender.male: 'Male',
              RoomOccupantGender.female: 'Female',
            },
            emojis: const {
              RoomOccupantGender.male: '♂️',
              RoomOccupantGender.female: '♀️',
            },
          ),
          const SizedBox(height: _roomFieldGap),
        ],
        Text('Suitable for', style: listingFieldLabelStyle),
        const SizedBox(height: _roomLabelGap),
        _sharedChoiceRow<RoomRequiredOccupant>(
          selected: slot.requiredOccupant,
          onChanged: (v) => setState(() {
            slot.requiredOccupant = v;
            slot.tenantGender = v.asTargetTenantPreference;
            _afterRoomChoiceChanged(index);
          }),
          options: const {
            RoomRequiredOccupant.male: 'Male',
            RoomRequiredOccupant.female: 'Female',
            RoomRequiredOccupant.noPreference: 'No Preference',
          },
          emojis: const {
            RoomRequiredOccupant.male: '♂️',
            RoomRequiredOccupant.female: '♀️',
            RoomRequiredOccupant.noPreference: '◎',
          },
        ),
        const SizedBox(height: _roomFieldGap),
        Text('Occupant type', style: listingFieldLabelStyle),
        const SizedBox(height: _roomLabelGap),
        _sharedChoiceRow<RoomOccupantType>(
          selected: slot.occupantType,
          onChanged: (v) => setState(() {
            slot.occupantType = v;
            _afterRoomChoiceChanged(index);
          }),
          options: const {
            // Display-only shorten — enum value unchanged.
            RoomOccupantType.workingProfessional: 'Professional',
            RoomOccupantType.student: 'Student',
            RoomOccupantType.noPreference: 'No Preference',
          },
          emojis: const {
            RoomOccupantType.workingProfessional: '💼',
            RoomOccupantType.student: '🎓',
            RoomOccupantType.noPreference: '◎',
          },
        ),
      ],
    );
  }

  Widget _sharedRoomInventoryCard(int index) {
    final slot = _sharedRoomSlots[index];
    // Keep Mixed as a real terminal selection (not only a visual default).
    slot.roomProfile ??= FlatmateCohort.mixedCohort;
    final collapseReady = _isRoomCardReadyToCollapse(slot);
    final roomComplete = _isRoomSlotComplete(slot);
    final missingRequiredCount = _sharedRoomMissingRequiredCount(slot);
    final showRoomValidation =
        _roomsStepContinueAttempted && missingRequiredCount > 0;
    final expanded = _expandedRoomIndex == index;
    final agreement = TenurePreference.fromStorage(slot.agreementTypeToken);
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final rentDigits = slot.monthlyRent.replaceAll(RegExp(r'[^\d]'), '');
    final summaryBits = <String>[
      slot.roomKind.label,
      slot.bathroomType.label,
      if (rentDigits.isNotEmpty) '€$rentDigits',
    ];
    final summaryLine = summaryBits.isEmpty
        ? 'Tap to configure'
        : 'Room ${index + 1} · ${summaryBits.join(' · ')}';
    final outlineColor = expanded
        ? listingChoiceBorderSelected
        : listingChoiceBorderUnselected;

    return ClipRRect(
      // Stable key — do not include roomKind or the header remounts on Shared Room.
      key: ValueKey('room-card-$index-$_roomFieldEpoch'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          // Non-uniform left accent cannot use borderRadius on same BoxDecoration.
          border: Border(
            left: BorderSide(
              color: roomComplete ? outlineColor : const Color(0xFFE53935),
              width: roomComplete ? 1 : 3,
            ),
            top: BorderSide(color: outlineColor),
            right: BorderSide(color: outlineColor),
            bottom: BorderSide(color: outlineColor),
          ),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.saving
                  ? null
                  : () => setState(() {
                        // Incomplete rooms stay expanded until required fields filled.
                        if (expanded && !roomComplete) return;
                        _expandedRoomIndex = expanded ? -1 : index;
                      }),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(10),
                bottom: expanded ? Radius.zero : const Radius.circular(10),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      expanded
                          ? Icons.expand_more_rounded
                          : (collapseReady
                              ? Icons.check_circle
                              : Icons.chevron_right_rounded),
                      size: 18,
                      color: collapseReady && !expanded
                          ? const Color(0xFF059669)
                          : const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: expanded
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Room ${index + 1}',
                                  style: listingFieldLabelStyle.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  summaryBits.isEmpty
                                      ? 'Tap to configure'
                                      : summaryBits.join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: listingSubLabelStyle.copyWith(
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              summaryLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: listingFieldLabelStyle.copyWith(
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                    ),
                    if (!expanded)
                      showRoomValidation
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE53935),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$missingRequiredCount to complete',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFE53935),
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            )
                          : const Text('✏️', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _roomCoreFields(
                    slot,
                    index: index,
                    showRoomProfile: true,
                  ),
                  const SizedBox(height: _roomFieldGap),
                  Text('Monthly rent (€)', style: listingFieldLabelStyle),
                  const SizedBox(height: _roomLabelGap),
                  _sharedRequiredFieldWrap(
                    showError: _sharedRoomFieldRequired(slot, 'rent'),
                    child: Focus(
                      onFocusChange: (hasFocus) {
                        if (!hasFocus) {
                          setState(() => _tryCollapseRoomCard(index));
                        }
                      },
                      child: TextFormField(
                        key: ValueKey('rent-$index-$_roomFieldEpoch'),
                        initialValue: slot.monthlyRent,
                        enabled: !widget.saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: listingFieldValueStyle,
                        decoration:
                            listingInlineInputDecoration(hint: 'e.g. 850'),
                        onChanged: (v) => setState(() {
                          slot.monthlyRent = v;
                          _afterRoomTextChanged(index);
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: _roomFieldGap),
                  Text(
                    'Shared costs — monthly contribution per tenant',
                    style: listingFieldLabelStyle,
                  ),
                  const SizedBox(height: _roomLabelGap),
                  _slotCostRow(slot, index: index),
                  const SizedBox(height: _roomFieldGap),
                  Text('Lease type', style: listingFieldLabelStyle),
                  const SizedBox(height: _roomLabelGap),
                  _sharedRequiredFieldWrap(
                    showError: _sharedRoomFieldRequired(slot, 'lease'),
                    child: _sharedChoiceRow<TenurePreference>(
                      selected: agreement == TenurePreference.flexible
                          ? null
                          : agreement,
                      onChanged: (v) => setState(() {
                        slot.agreementTypeToken = v.storageToken;
                        if (v == TenurePreference.temporary) {
                          slot.temporaryDurationUnit =
                              SubletDurationUnit.months;
                        }
                        _afterRoomChoiceChanged(index);
                      }),
                      options: const {
                        TenurePreference.longTerm: 'Long-Term',
                        TenurePreference.temporary: 'Temporary',
                      },
                      emojis: const {
                        TenurePreference.longTerm: '📅',
                        TenurePreference.temporary: '⏳',
                      },
                    ),
                  ),
                  if (agreement == TenurePreference.temporary) ...[
                    const SizedBox(height: _roomFieldGap),
                    Text('Duration (months)', style: listingFieldLabelStyle),
                    const SizedBox(height: _roomLabelGap),
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (!hasFocus) {
                          setState(() => _tryCollapseRoomCard(index));
                        }
                      },
                      child: TextFormField(
                        key: ValueKey('temp-duration-$index-$_roomFieldEpoch'),
                        initialValue: slot.temporaryDurationValue,
                        enabled: !widget.saving,
                        keyboardType: TextInputType.number,
                        style: listingFieldValueStyle,
                        decoration:
                            listingInlineInputDecoration(hint: 'e.g. 3'),
                        onChanged: (v) => setState(() {
                          slot.temporaryDurationValue = v;
                          slot.temporaryDurationUnit =
                              SubletDurationUnit.months;
                          _afterRoomTextChanged(index);
                        }),
                      ),
                    ),
                  ],
                  const SizedBox(height: _roomFieldGap),
                  ListingLabeledField(
                    label: 'Available from',
                    child: _sharedRequiredFieldWrap(
                      showError:
                          _sharedRoomFieldRequired(slot, 'availableFrom'),
                      child: ListingDateInputField(
                        externalLabel: true,
                        value: slot.availableFrom,
                        enabled: !widget.saving,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: slot.availableFrom != null &&
                                    !slot.availableFrom!
                                        .isBefore(startOfToday)
                                ? slot.availableFrom!
                                : startOfToday,
                            firstDate: startOfToday,
                            lastDate: startOfToday
                                .add(const Duration(days: 365 * 3)),
                          );
                          if (picked != null) {
                            setState(() {
                              slot.availableFrom = picked;
                              _afterRoomChoiceChanged(index);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: _roomFieldGap),
                  Text(
                    'Availability flexibility',
                    style: listingFieldLabelStyle,
                  ),
                  const SizedBox(height: _roomLabelGap),
                  _sharedRequiredFieldWrap(
                    showError: _sharedRoomFieldRequired(slot, 'flexibility'),
                    child: _sharedChoiceRow<LandlordAvailabilityFlexibility>(
                      selected: _flexibilityForToken(
                        slot.availabilityFlexibilityToken,
                      ),
                      onChanged: (v) => setState(() {
                        slot.availabilityFlexibilityToken = v.storageToken;
                        _afterRoomChoiceChanged(index);
                      }),
                      options: const {
                        LandlordAvailabilityFlexibility.plus1Month:
                            'Within 1 Month',
                        LandlordAvailabilityFlexibility.flexible: 'Flexible',
                      },
                      emojis: const {
                        LandlordAvailabilityFlexibility.plus1Month: '📆',
                        LandlordAvailabilityFlexibility.flexible: '🗓️',
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _slotCostRow(SharedRoomSlot slot, {required int index}) {
    Widget costCol({
      required String label,
      required String value,
      required bool included,
      required ValueChanged<String> onValue,
      required ValueChanged<bool> onIncluded,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: listingSectionTitleStyle.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: listingFieldHeight,
            child: TextFormField(
              key: ValueKey('cost-$index-$label-$included-$_roomFieldEpoch'),
              initialValue: included ? '' : value,
              enabled: !widget.saving && !included,
              keyboardType: TextInputType.number,
              style: listingFieldValueStyle.copyWith(
                color: included ? const Color(0xFF9CA3AF) : null,
              ),
              decoration: listingInlineInputDecoration(
                hint: included ? 'Included' : '0',
              ).copyWith(
                prefixText: included ? null : '€ ',
                prefixStyle: listingFieldValueStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151),
                ),
              ),
              onChanged: onValue,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: included,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: widget.saving
                      ? null
                      : (v) => onIncluded(v ?? false),
                ),
              ),
              const SizedBox(width: 4),
              const Flexible(
                child: Text(
                  'Included in rent',
                  style: listingOptionHintStyle,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 520;
        final cols = [
          costCol(
            label: '⚡ Gas & Elec',
            value: slot.electricityCost,
            included: slot.electricityIncluded,
            onValue: (v) => setState(() {
              slot.electricityCost = v;
              _afterRoomTextChanged(index);
            }),
            onIncluded: (v) => setState(() {
              slot.electricityIncluded = v;
              if (v) slot.electricityCost = '0';
              _afterRoomChoiceChanged(index);
            }),
          ),
          costCol(
            label: '🌐 Internet',
            value: slot.internetCost,
            included: slot.internetIncluded,
            onValue: (v) => setState(() {
              slot.internetCost = v;
              _afterRoomTextChanged(index);
            }),
            onIncluded: (v) => setState(() {
              slot.internetIncluded = v;
              if (v) slot.internetCost = '0';
              _afterRoomChoiceChanged(index);
            }),
          ),
          costCol(
            label: '🗑️ Bins',
            value: slot.binsCost,
            included: slot.binsIncluded,
            onValue: (v) => setState(() {
              slot.binsCost = v;
              _afterRoomTextChanged(index);
            }),
            onIncluded: (v) => setState(() {
              slot.binsIncluded = v;
              if (v) slot.binsCost = '0';
              _afterRoomChoiceChanged(index);
            }),
          ),
        ];
        if (stack) {
          return Column(
            children: [
              for (var i = 0; i < cols.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                cols[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cols[0]),
            const SizedBox(width: 8),
            Expanded(child: cols[1]),
            const SizedBox(width: 8),
            Expanded(child: cols[2]),
          ],
        );
      },
    );
  }

  // Legacy display helpers no longer used by Shared Spaces room cards.

  Widget _listingTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(title: 'Listing type'),
        if (_categoryPrefillLocked)
          _inheritedSummaryCard(
            title: 'Listing category inherited from profile',
            subtitle:
                'Your onboarding listing defaults already set this preference.',
            lines: [
              _isShare
                  ? 'Shared room'
                  : MarketplaceSpace.fullRental.option2Title,
            ],
            actionLabel: 'Edit category',
            onAction: () => setState(() => _categoryPrefillLocked = false),
          )
        else if (_isShare)
          _sharedChoiceRow<bool>(
            selected: _listingTypeChipIsShare,
            onChanged: (isShare) => _selectSpace(
              isShare
                  ? MarketplaceSpace.sharedSpace
                  : MarketplaceSpace.fullRental,
            ),
            options: {
              false: MarketplaceSpace.fullRental.option2Title,
              true: 'Shared room',
            },
            emojis: const {
              false: '🏡',
              true: '🛏️',
            },
          )
        else
          ListingDaftRadioChoiceList<bool>(
            enabled: !widget.saving,
            selected: _listingTypeChipIsShare,
            onChanged: (isShare) => _selectSpace(
              isShare
                  ? MarketplaceSpace.sharedSpace
                  : MarketplaceSpace.fullRental,
            ),
            options: {
              false: MarketplaceSpace.fullRental.option2Title,
              true: 'Shared room',
            },
            emojis: const {
              false: '🏡',
              true: '🛏️',
            },
          ),
      ],
    );
  }

  Widget _propertyTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(title: 'Property type'),
        if (_isShare)
          _sharedChoiceRow<ListingPropertySubType>(
            selected: _propertySubType,
            onChanged: (v) => setState(() {
              _propertySubType = v;
              final allowed = _sharedParkingTypeOptionsFor(v);
              _parkingFeatures.removeWhere((f) => !allowed.contains(f));
            }),
            options: const {
              ListingPropertySubType.apartment: 'Apartment',
              ListingPropertySubType.house: 'House',
            },
            emojis: const {
              ListingPropertySubType.apartment: '🏢',
              ListingPropertySubType.house: '🏡',
            },
          )
        else
          _sharedChoiceRow<ListingPropertySubType>(
            selected: _propertySubType,
            onChanged: (v) => setState(() {
              _propertySubType = v;
              final allowed = ListingParkingFeature.optionsFor(v);
              _parkingFeatures.removeWhere((f) => !allowed.contains(f));
            }),
            options: const {
              ListingPropertySubType.apartment: 'Apartment',
              ListingPropertySubType.house: 'House',
            },
            emojis: const {
              ListingPropertySubType.apartment: '🏢',
              ListingPropertySubType.house: '🏡',
            },
          ),
      ],
    );
  }

  Widget _bedroomsBathroomsSection() {
    return Row(
      children: [
        Expanded(
          child: ListingCompactCounter(
            label: 'Bedrooms',
            value: _bedrooms,
            min: 0,
            max: 6,
            compact: true,
            onDecrement: widget.saving
                ? () {}
                : () => setState(
                      () => _bedrooms = (_bedrooms - 1).clamp(0, 6),
                    ),
            onIncrement: widget.saving
                ? () {}
                : () => setState(
                      () => _bedrooms = (_bedrooms + 1).clamp(0, 6),
                    ),
          ),
        ),
        const SizedBox(width: listingFieldSpacing),
        Expanded(
          child: ListingCompactCounter(
            label: 'Bathrooms',
            value: _bathrooms,
            min: 0,
            max: 4,
            compact: true,
            onDecrement: widget.saving
                ? () {}
                : () => setState(
                      () => _bathrooms = (_bathrooms - 1).clamp(0, 4),
                    ),
            onIncrement: widget.saving
                ? () {}
                : () => setState(
                      () => _bathrooms = (_bathrooms + 1).clamp(0, 4),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _furnishingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(title: 'Furnishing'),
        if (_furnishingPrefillLocked)
          _inheritedSummaryCard(
            title: 'Furnishing inherited from profile',
            subtitle:
                'Your onboarding listing defaults already set this preference.',
            lines: [
              'Furnishing: ${_isFurnished == true ? 'Furnished' : 'Unfurnished'}',
            ],
            actionLabel: 'Edit furnishing',
            onAction: () => setState(() => _furnishingPrefillLocked = false),
          )
        else
          ListingDaftRadioChoiceList<bool>(
            enabled: !widget.saving,
            selected: _isFurnished,
            onChanged: (value) => setState(() => _isFurnished = value),
            options: const {
              true: 'Furnished',
              false: 'Unfurnished',
            },
            emojis: const {
              true: '🛋️',
              false: '📦',
            },
          ),
      ],
    );
  }

  Widget _monthlyRentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(
          title: 'Monthly rent',
          required: true,
        ),
        ListingPremiumRentField(
          key: _rentSectionKey,
          controller: _rentController,
          enabled: !widget.saving,
          showLabel: false,
          showError: _rentShowError,
          errorText: _rentErrorText,
          onChanged: (_) {
            if (_rentShowError) {
              setState(() {
                _rentShowError = false;
                _rentErrorText = null;
              });
            }
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Landlord reminder: annual management fees, service charges, and '
          'block insurance are included in this base rent where required by '
          'local regulations.',
          style: listingFormHelperStyle,
        ),
        if (_isShare) ...[
          const SizedBox(height: listingSectionSpacing),
          _sharedCostsSection(),
        ],
      ],
    );
  }

  Widget _depositRequiredSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(
          title: 'Deposit required',
          required: true,
        ),
        ListingPremiumRentField(
          key: _depositSectionKey,
          controller: _depositController,
          enabled: !widget.saving,
          showLabel: false,
          showError: _depositShowError,
          errorText: _depositErrorText,
          onChanged: (_) {
            if (_depositShowError) {
              setState(() {
                _depositShowError = false;
                _depositErrorText = null;
              });
            }
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Security deposit amount tenants must pay before move-in.',
          style: listingFormHelperStyle,
        ),
      ],
    );
  }

  Widget _berRatingSection() {
    return ListingBerRatingField(
      value: _berRating,
      enabled: !widget.saving,
      ratings: ListingCreationFormConstants.berRatings,
      onChanged: (v) => setState(() => _berRating = v),
    );
  }

  Widget _propertyHighlightsSection() {
    // Independent Places only — Shared Spaces has its own pets/parking section.
    final petsOn = _petsPolicy == ListingPetsPolicy.allowed;

    Widget ipToggleBox({
      required String label,
      required bool selected,
      required VoidCallback onTap,
      bool alwaysEmphasizedBorder = false,
    }) {
      final borderOn = alwaysEmphasizedBorder || selected;
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: widget.saving ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            height: listingFieldHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: borderOn
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFFE0E0E0),
                width: borderOn ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: listingFieldValueStyle.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: borderOn
                          ? const Color(0xFF374151)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
                const Text(
                  '↺',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF999999),
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget ipParkingTypeChip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: widget.saving ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: listingFieldHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFFE0E0E0),
                width: selected ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: listingFieldValueStyle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFF374151)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      );
    }

    void toggleParkingFeature(ListingParkingFeature feature) {
      setState(() {
        if (_parkingFeatures.contains(feature)) {
          _parkingFeatures.remove(feature);
        } else {
          _parkingFeatures.add(feature);
        }
      });
    }

    Widget parkingLevel2(ListingPropertySubType subtype) {
      if (subtype == ListingPropertySubType.apartment) {
        return Row(
          children: [
            Expanded(
              child: ipParkingTypeChip(
                label: '🚲 Secure Bike Parking',
                selected: _parkingFeatures
                    .contains(ListingParkingFeature.bikeParking),
                onTap: () =>
                    toggleParkingFeature(ListingParkingFeature.bikeParking),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ipParkingTypeChip(
                label: '🚗 Car Parking',
                selected: _parkingFeatures
                    .contains(ListingParkingFeature.residentCar),
                onTap: () =>
                    toggleParkingFeature(ListingParkingFeature.residentCar),
              ),
            ),
          ],
        );
      }
      // House: 2-col grid — driveway/street, then garage left-aligned.
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ipParkingTypeChip(
                  label: '🏠 Private Driveway',
                  selected: _parkingFeatures
                      .contains(ListingParkingFeature.driveway),
                  onTap: () =>
                      toggleParkingFeature(ListingParkingFeature.driveway),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ipParkingTypeChip(
                  label: '🛣️ Street Parking',
                  selected: _parkingFeatures
                      .contains(ListingParkingFeature.onStreet),
                  onTap: () =>
                      toggleParkingFeature(ListingParkingFeature.onStreet),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ipParkingTypeChip(
                  label: '🏗️ Garage',
                  selected:
                      _parkingFeatures.contains(ListingParkingFeature.garage),
                  onTap: () =>
                      toggleParkingFeature(ListingParkingFeature.garage),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
      );
    }

    // Read live — do not close over a stale local for Level 2 gating.
    final propertyType = _propertySubType;
    final parkingAvailable = _ipParkingAvailable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(
          title: 'Pets & parking',
          subtitle: 'Shown on your public listing.',
        ),
        Row(
          children: [
            Expanded(
              child: ipToggleBox(
                label: petsOn ? '🐾 Pets allowed' : '🚫 No pets',
                selected: true,
                alwaysEmphasizedBorder: true,
                onTap: () => setState(() {
                  _petsPolicy = petsOn
                      ? ListingPetsPolicy.notAllowed
                      : ListingPetsPolicy.allowed;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ipToggleBox(
                label: parkingAvailable
                    ? '🚗 Parking available'
                    : '🚫 No parking',
                selected: true,
                alwaysEmphasizedBorder: true,
                onTap: () => setState(() {
                  final next = !parkingAvailable;
                  _ipParkingAvailable = next;
                  if (!next) _parkingFeatures.clear();
                }),
              ),
            ),
          ],
        ),
        if (parkingAvailable) ...[
          const SizedBox(height: 8),
          if (propertyType == null)
            Text(
              'Select a property type first.',
              style: listingFormHelperStyle,
            )
          else
            parkingLevel2(propertyType),
        ],
      ],
    );
  }

  Widget _mediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(
          title: 'Photos',
          subtitle: 'Minimum 3 photos · 5+ recommended',
          required: true,
        ),
        ListingMediaPicker(
          images: _images,
          video: _video,
          enabled: !widget.saving,
          minPhotosRequired: 0,
          previewHeight: 100,
          useDropzoneStyle: true,
          showRequirementLabel: false,
          showVideoControls: false,
          onMessage: _message,
          onImagesChanged: (next) => setState(() => _images = next),
          onVideoChanged: (v) => setState(() => _video = v),
        ),
        const SizedBox(height: listingFieldSpacing),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Good photos receive more enquiries.',
                style: listingFieldValueStyle,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: widget.saving
                      ? null
                      : () => setState(
                            () => _photoTipsExpanded = !_photoTipsExpanded,
                          ),
                  child: Text(
                    _photoTipsExpanded ? 'Hide photo tips' : 'View photo tips',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_photoTipsExpanded) ...[
                const SizedBox(height: 8),
                Text(
                  '☀ Use natural lighting\n'
                  '📏 1200px+ wide images recommended\n'
                  '📱 Upload original camera photos where possible\n'
                  '🏡 Show key rooms and shared spaces\n'
                  '📸 Landscape photos generally work best\n\n'
                  'Supported formats: JPG, PNG, HEIC\n'
                  'Maximum file size: 10 MB per photo\n'
                  'Minimum: 3 photos required\n'
                  'Recommended: 5+ photos',
                  style: listingSubLabelStyle.copyWith(
                    color: const Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sharedCostsSection() {
    return Column(
      key: _sharedCostsSectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(
          title: 'Monthly shared costs (per person)',
          subtitle: 'Required — enter an amount or mark each as included in rent.',
          required: true,
        ),
        Row(
          children: [
            Expanded(
              child: _costBox(
                icon: Icons.bolt_outlined,
                label: 'Gas & electricity',
                controller: _electricityCostController,
                included: _electricityIncluded,
                showError: _sharedCostsShowErrors &&
                    !_isSharedCostResolved(
                      _electricityCostController,
                      _electricityIncluded,
                    ),
                onIncludedChanged: (v) => setState(() {
                  _electricityIncluded = v;
                  if (v) _electricityCostController.text = '0';
                  _sharedCostsShowErrors = false;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _costBox(
                icon: Icons.delete_outline,
                label: 'Bin collection',
                controller: _binsCostController,
                included: _binsIncluded,
                showError: _sharedCostsShowErrors &&
                    !_isSharedCostResolved(
                      _binsCostController,
                      _binsIncluded,
                    ),
                onIncludedChanged: (v) => setState(() {
                  _binsIncluded = v;
                  if (v) _binsCostController.text = '0';
                  _sharedCostsShowErrors = false;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _costBox(
                icon: Icons.wifi,
                label: 'Internet / broadband',
                controller: _internetCostController,
                included: _internetIncluded,
                showError: _sharedCostsShowErrors &&
                    !_isSharedCostResolved(
                      _internetCostController,
                      _internetIncluded,
                    ),
                onIncludedChanged: (v) => setState(() {
                  _internetIncluded = v;
                  if (v) _internetCostController.text = '0';
                  _sharedCostsShowErrors = false;
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _costBox({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool included,
    required ValueChanged<bool> onIncludedChanged,
    bool showError = false,
  }) {
    // Material parent required: CheckboxListTile ink is invisible under a
    // painted Container/DecoratedBox surface.
    return Opacity(
      opacity: included ? 0.45 : 1,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: showError
                ? const Color(0xFFEF4444)
                : listingDaftBorderColor,
            width: showError ? 1.5 : listingDaftBorderWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: const Color(0xFF6B7280)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$label (€)',
                      style: listingSectionTitleStyle.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: controller,
                enabled: !widget.saving && !included,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (_sharedCostsShowErrors) {
                    setState(() => _sharedCostsShowErrors = false);
                  }
                },
                decoration: listingInlineInputDecoration(hint: 'Per month'),
              ),
              if (showError) ...[
                const SizedBox(height: 4),
                const Text(
                  'Required',
                  style: TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
                ),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: included,
                onChanged: widget.saving
                    ? null
                    : (v) => onIncludedChanged(v ?? false),
                title: const Text(
                  'Included in rent',
                  style: TextStyle(fontSize: 11),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationSection() {
    if (_locationPrefillLocked) {
      return _inheritedSummaryCard(
        title: 'Location inherited from profile',
        subtitle:
            'Area resolved from your host profile — confirm the exact address below.',
        lines: [
          if (_locationController.text.trim().isNotEmpty)
            'Area: ${_locationController.text.trim()}',
        ],
        actionLabel: 'Edit location',
        onAction: () => setState(() {
          _locationPrefillLocked = false;
          _addressSearchController.clear();
          _selectedAddress = null;
          if (_isNearDublinCityCentre(_resolvedLatitude, _resolvedLongitude)) {
            _resolvedLatitude = null;
            _resolvedLongitude = null;
          }
        }),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 560;
        final mapHeight = sideBySide ? 400.0 : 260.0;

        final mapField = LocationPinField(
          pinLat: _resolvedLatitude,
          pinLon: _resolvedLongitude,
          externalLocationEpoch: _externalLocationEpoch,
          externalLocationLabel: _externalLocationLabel,
          onPinPlaced: _onMapPinPlaced,
          onPinDraft: _onMapPinDraft,
          enabled: !widget.saving,
          mapHeight: mapHeight,
        );

        final pinConfirmed = _hasResolvableLocation();

        final locationDetails = pinConfirmed
            ? _resolvedAddressPanel()
            : (_locationShowErrors
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: const Text(
                      'Confirm your pin on the map or use current location to continue.',
                      style: TextStyle(fontSize: 13, color: Color(0xFFB91C1C)),
                    ),
                  )
                : null);

        // Left: search + map + address/area/eircode (below fold for Nearby avoided).
        final leftColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            mapField,
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.saving || _fetchingLocation
                  ? null
                  : _useCurrentLocation,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF374151),
                side: BorderSide(color: listingDaftBorderColor, width: 1),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: _fetchingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_outlined, size: 18),
              label: const Text('Use current location'),
            ),
            if (locationDetails != null) ...[
              const SizedBox(height: 12),
              locationDetails,
            ],
          ],
        );

        // Right: What's Nearby + Edit Proximity only (top-aligned beside map).
        final nearbyColumn =
            pinConfirmed ? _nearbyDiscoverySection() : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            listingFieldLabel(
              'Drop a pin on the map where your property is located',
              required: true,
              style: listingOptionLabelStyle,
            ),
            const SizedBox(height: 4),
            const Text(
              'Search to centre the map or tap to drop a pin, then tap Confirm on the map. '
              'Nearby transport and amenities load only after you confirm.',
              style: listingOptionHintStyle,
            ),
            const SizedBox(height: 12),
            if (sideBySide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: leftColumn),
                  if (nearbyColumn != null) ...[
                    const SizedBox(width: 16),
                    Expanded(child: nearbyColumn),
                  ],
                ],
              )
            else ...[
              leftColumn,
              if (nearbyColumn != null) ...[
                const SizedBox(height: 12),
                nearbyColumn,
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _resolvedAddressPanel() {
    final previewLabel = _publicLocationPreviewLabel();
    // Material (not Container/DecoratedBox fill) so CheckboxListTile ink stays visible.
    return Material(
      key: _locationPanelKey,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          listingFieldLabel('Property Address (Optional)'),
          const SizedBox(height: 6),
          const Text(
            'Street or building name for your records. Matching and neighbourhood information are based on your map pin and Property Area.',
            style: listingOptionHintStyle,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _locationIdentifierController,
            enabled: !widget.saving,
            minLines: 1,
            maxLines: 2,
            style: listingFieldValueStyle,
            decoration: listingInlineInputDecoration(
              hint: 'Street or building name',
            ),
            onChanged: (_) => setState(() {
              if (_locationShowErrors) _locationShowErrors = false;
            }),
          ),
          const SizedBox(height: 12),
          if (MarketConfig.current.profileUseAreaPicker) ...[
            // Options: dublin_districts via MarketConfig.areaOptions (full labels).
            // Stored key remains listing_area_key (e.g. dublin15). Macros are
            // seeker-only (homepage / Area filter) via dublin_macro_areas.
            ShadcnSelect(
              label: 'Property area (for matching) *',
              value: _listingAreaSelectValue,
              options: MarketConfig.current.areaOptions.map((e) => e.$2).toList(),
              onChanged: widget.saving
                  ? (_) {}
                  : (label) {
                      setState(() {
                        for (final (key, areaLabel)
                            in MarketConfig.current.areaOptions) {
                          if (areaLabel == label) {
                            _listingAreaKey = key;
                            _locationController.text = areaLabel;
                            break;
                          }
                        }
                      });
                    },
            ),
          ] else ...[
            listingFieldLabel('Property area', required: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _locationController,
              enabled: !widget.saving,
              style: listingFieldValueStyle,
              decoration: listingInlineInputDecoration(
                hint: 'Neighbourhood or district',
              ),
              onChanged: (v) => setState(
                () => _syncListingAreaKey(areaLabel: v),
              ),
            ),
          ],
          const SizedBox(height: 12),
          listingFieldLabel('Eircode (Optional)'),
          const SizedBox(height: 6),
          const Text(
            'Auto-filled when available. Used to help identify the property location. Not used by renters for search.',
            style: listingOptionHintStyle,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: listingFieldHeight,
            child: TextFormField(
              controller: _eircodeController,
              enabled: !widget.saving,
              style: listingFieldValueStyle.copyWith(
                color: const Color(0xFF374151),
              ),
              decoration: listingInlineInputDecoration(
                hint: 'e.g. D24 KV89',
              ),
            ),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _hideExactAddress,
            onChanged: widget.saving
                ? null
                : (v) => setState(() {
                      _hideExactAddress = v ?? false;
                      if (_hideExactAddress && _locationShowErrors) {
                        _locationShowErrors = false;
                      }
                    }),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              "I don't want to display the exact address",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            activeColor: const Color(0xFF4B5563),
            checkColor: Colors.white,
            side: const BorderSide(color: Color(0xFF9CA3AF), width: 1.2),
          ),
          if (_hideExactAddress) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Public preview',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_localityLabel.isNotEmpty)
                    _locationPreviewRow('Locality', _localityLabel),
                  if (_listingAreaKey != null) ...[
                    const SizedBox(height: 6),
                    _locationPreviewRow(
                      'District',
                      TargetSearchAreas.labelForKey(_listingAreaKey!),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    previewLabel.isNotEmpty
                        ? previewLabel
                        : 'Area will appear here once resolved',
                    style: listingFieldValueStyle.copyWith(
                      fontSize: 13,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],
          ],
        ),
      ),
    );
  }

  Widget _locationPreviewRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }

  bool get _isProximityLoading =>
      _proximityResolving || _neighborhoodAmenitiesLoading || _fetchingLocation;

  Widget _nearbyDiscoverySection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isProximityLoading)
            const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "What's nearby",
                        style: listingFormSectionHeaderStyle,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: widget.saving || _isProximityLoading
                          ? null
                          : () => setState(() {
                                _proximityEditing = !_proximityEditing;
                                _proximityDraft.manualEdit = _proximityEditing;
                                if (_proximityEditing) {
                                  _proximityResolved = true;
                                } else {
                                  _applyProximityFromControllers();
                                }
                              }),
                      icon: Icon(
                        _proximityEditing
                            ? Icons.check_outlined
                            : Icons.edit_outlined,
                        size: 16,
                      ),
                      label: Text(
                        _proximityEditing ? 'Done editing' : '✏️ Edit Proximity',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isProximityLoading)
                  const SkeletonAmenityChipWrap()
                else
                  UnifiedProximityDisplay(
                    input: _proximityDisplayInput(),
                    showTier4: _showMoreLocalAmenities,
                    onToggleTier4: () => setState(
                      () => _showMoreLocalAmenities = !_showMoreLocalAmenities,
                    ),
                    enrichmentInFlight: _amenitiesEnrichmentInFlight,
                    resolved: _proximityResolved,
                    editing: _proximityEditing,
                    onToggleHide: _proximityEditing
                        ? (key) => setState(() {
                              _proximityDraft.toggleHiddenKey(key);
                            })
                        : null,
                    onTogglePin: _proximityEditing
                        ? (key) => setState(() {
                              _proximityDraft.togglePinnedKey(key);
                            })
                        : null,
                    onAddCustom:
                        _proximityEditing ? _showAddCustomProximityDialog : null,
                    onRemoveCustom: _proximityEditing
                        ? (key) => _removeCustomProximityByKey(key)
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ProximityDisplayInput _proximityDisplayInput() {
    int? walkFromText(String text) {
      final value = int.tryParse(text.trim());
      if (value == null || value <= 0) return null;
      return value;
    }

    return ProximityDisplayInput(
      transportLine: _transportLineController.text.trim(),
      transportWalkMin: walkFromText(_transportWalkController.text),
      groceryBrand: _groceryBrand,
      groceryWalkMin: walkFromText(_groceryWalkController.text),
      groceries: _profileGroceries,
      primarySchool: _primarySchoolController.text.trim(),
      secondarySchool: _secondarySchoolController.text.trim(),
      collegeSchool: _collegeSchool,
      collegeWalkMin: _collegeWalkMin,
      crecheName: _crecheNameController.text.trim(),
      crecheWalkMin: walkFromText(_crecheWalkController.text),
      gpClinic: _gpClinic,
      gpWalkMin: _gpWalkMin,
      extraTransit: _extraProximityTransit,
      lifestyleTags: _neighborhoodAmenityTags,
      customPoints: _customProximityRows
          .map(
            (row) => CustomProximityPoint(
              category: row.category,
              name: row.nameController.text.trim(),
              walkMin: int.tryParse(row.walkController.text.trim()) ?? 0,
            ),
          )
          .where((point) => point.name.isNotEmpty)
          .toList(),
      hiddenChipKeys: List<String>.from(_proximityDraft.hiddenChipKeys),
      pinnedChipKeys: List<String>.from(_proximityDraft.pinnedChipKeys),
      includeHidden: _proximityEditing,
    );
  }

  Future<void> _showAddCustomProximityDialog() async {
    if (widget.saving) return;
    var category = ProximityPointCategory.amenity;
    final nameController = TextEditingController();
    final walkController = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Add custom proximity'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<ProximityPointCategory>(
                    initialValue: category,
                    decoration: listingInputDecoration(label: 'Category'),
                    items: ProximityPointCategory.values
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text('${c.emoji} ${c.label}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() => category = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    decoration: listingInputDecoration(
                      label: 'Place name',
                      hint: 'Phoenix Park',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: walkController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: listingInputDecoration(
                      label: 'Min walk',
                      hint: '5',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) return;
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (added == true && mounted) {
      setState(() {
        _customProximityRows.add(
          _CustomProximityRowState(
            category: category,
            name: nameController.text.trim(),
            walkMin: walkController.text.trim(),
          ),
        );
        _applyProximityFromControllers();
      });
    }
    nameController.dispose();
    walkController.dispose();
  }

  void _removeCustomProximityByKey(String preferenceKey) {
    if (widget.saving) return;
    setState(() {
      final remaining = <_CustomProximityRowState>[];
      for (final row in _customProximityRows) {
        final name = row.nameController.text.trim();
        final key = name.isEmpty
            ? ''
            : ProximityChipKeys.build(ProximityChipKeys.custom, name);
        if (key == preferenceKey) {
          row.dispose();
        } else {
          remaining.add(row);
        }
      }
      _customProximityRows
        ..clear()
        ..addAll(remaining);
      _proximityDraft.hiddenChipKeys =
          List<String>.from(_proximityDraft.hiddenChipKeys)
            ..remove(preferenceKey);
      _proximityDraft.pinnedChipKeys =
          List<String>.from(_proximityDraft.pinnedChipKeys)
            ..remove(preferenceKey);
      _applyProximityFromControllers();
    });
  }

  // Controllers remain for enrich sync + backward-compatible draft storage.

  Widget _lifestyleSection() {
    if (_rulesPrefillLocked) {
      final ruleChips = <Widget>[
        ListingRuleChip(
          emoji: '🚭',
          label: _smokingAllowed ? 'Smoking allowed' : 'No smoking',
          active: true,
          expand: true,
        ),
        ListingRuleChip(
          emoji: '🚫',
          label: switch (_petsPolicy) {
            ListingPetsPolicy.allowed => 'Pets welcome',
            ListingPetsPolicy.notAllowed => 'No pets',
            ListingPetsPolicy.caseByCase => 'Pets case-by-case',
            null => 'Pets not set',
          },
          active: true,
          expand: true,
        ),
        if (_isShare)
          ListingRuleChip(
            emoji: '🥦',
            label: _vegetarianKitchen ? 'Veg kitchen' : 'Non-veg kitchen',
            active: true,
            expand: true,
          ),
        if (_isShare)
          ListingRuleChip(
            emoji: '🧑‍💻',
            label: _wfhFriendly
                ? 'Work from home friendly'
                : 'Not WFH friendly',
            active: _wfhFriendly,
            expand: true,
          ),
      ];

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'House rules inherited from profile',
              style: listingSectionTitleStyle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 6),
            const Text(
              'These defaults came from your onboarding host profile and can be unlocked if needed.',
              style: listingOptionHintStyle,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < ruleChips.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: ruleChips[i]),
                ],
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.saving
                    ? null
                    : () => setState(() => _rulesPrefillLocked = false),
                child: const Text('Edit rules'),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(title: 'Lifestyle & house rules'),
        Row(
          children: [
            Expanded(
              child: ListingCompactRuleTile(
                offLabel: 'Smoking allowed',
                onLabel: 'No smoking',
                active: !_smokingAllowed,
                enabled: !widget.saving,
                emoji: '🚭',
                activeIcon: Icons.smoke_free_outlined,
                inactiveIcon: Icons.smoking_rooms_outlined,
                activeIconColor: const Color(0xFF0EA5E9),
                onChanged: (v) => setState(() => _smokingAllowed = !v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ListingCompactRuleTile(
                offLabel: 'Pets welcome',
                onLabel: 'No pets',
                active: _petsPolicy == ListingPetsPolicy.notAllowed,
                enabled: !widget.saving,
                emoji: '🚫',
                onChanged: (v) => setState(() {
                  _petsPolicy = v
                      ? ListingPetsPolicy.notAllowed
                      : ListingPetsPolicy.allowed;
                }),
              ),
            ),
          ],
        ),
        if (_isShare) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ListingCompactRuleTile(
                  offLabel: 'Non-veg kitchen',
                  onLabel: 'Veg kitchen',
                  active: _vegetarianKitchen,
                  enabled: !widget.saving,
                  emoji: _vegetarianKitchen ? '🥦' : '🍖',
                  onChanged: (v) => setState(() => _vegetarianKitchen = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ListingAnimatedRuleChip(
                  label: 'Work from home friendly',
                  active: _wfhFriendly,
                  enabled: !widget.saving,
                  emoji: '🧑‍💻',
                  onTap: widget.saving
                      ? () {}
                      : () => setState(() => _wfhFriendly = !_wfhFriendly),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _inheritedSummaryCard({
    required String title,
    required String subtitle,
    required List<String> lines,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: listingDaftBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          for (final line in lines) ...[
            Text(
              line,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.saving ? null : onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListingSectionHeader(
          title: '🏷 Listing title',
          required: true,
          trailing: ListingAutoDraftBadge(visible: _isAutoDraftedTitle()),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _titleController,
          builder: (context, value, _) {
            return TextFormField(
              key: _titleFieldKey,
              controller: _titleController,
              enabled: !widget.saving,
              style: listingSmartCopyFieldStyle(
                base: listingFieldValueStyle,
                isAutoDrafted: _isAutoDraftedTitle(),
              ),
              decoration: listingInputDecoration(
                label: 'Title',
                hint: _isShare
                    ? 'Bright ensuite room in friendly Dublin 8 household'
                    : 'Bright & Modern 2-Bed House | Rathmines, Dublin 6',
              ).copyWith(
                errorText: _titleShowError
                    ? 'Enter a title (at least 3 characters).'
                    : null,
              ),
              onChanged: (_) {
                setState(() {
                  if (_titleShowError) _titleShowError = false;
                });
              },
            );
          },
        ),
      ],
    );
  }

  Widget _optionalEnhancementsSection() {
    return ListingCollapsibleSection(
      title: '✨ Optional Enhancements',
      subtitle: 'Video, house rules, and lifestyle details — expand if you want to add more.',
      expanded: _optionalEnhancementsExpanded,
      onExpandedChanged: (v) => setState(() => _optionalEnhancementsExpanded = v),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('🎥 Video tour', style: listingFieldLabelStyle),
            const SizedBox(height: listingLabelSpacing),
            ListingMediaPicker(
              images: const [],
              video: _video,
              enabled: !widget.saving,
              showPhotoUpload: false,
              showVideoControls: true,
              useDropzoneStyle: false,
              showRequirementLabel: false,
              onMessage: _message,
              onImagesChanged: (_) {},
              onVideoChanged: (v) => setState(() => _video = v),
            ),
          ],
        ),
        _lifestyleSection(),
        if (_isShare)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'I live in this property',
              style: listingFieldLabelStyle,
            ),
            subtitle: const Text(
              'Owner-occupier households often appeal to certain seekers.',
              style: listingOptionHintStyle,
            ),
            value: _isOwnerOccupier,
            onChanged: widget.saving
                ? null
                : (v) => setState(() => _isOwnerOccupier = v),
          ),
      ],
    );
  }

  Widget _descriptionSection() {
    final guidance = _isShare
        ? 'Describe the household vibe and daily routines\n'
            'Mention what is included in the room\n'
            'Say who would fit well as a flatmate\n'
            'Note house rules and shared spaces'
        : 'Highlight transport links and the local area\n'
            'Describe layout, light, and standout features\n'
            'Mention who the home suits best\n'
            'Be honest about any trade-offs';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListingSectionHeader(
          title: '📝 Description',
          subtitle:
              'Optional — tell applicants more about the space or household.',
          trailing: ListingAutoDraftBadge(
            visible: _isAutoDraftedDescription(),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _descriptionController,
          builder: (context, value, _) {
            final showGuidance = value.text.trim().isEmpty;
            return Stack(
              children: [
                TextFormField(
                  key: _descriptionFieldKey,
                  controller: _descriptionController,
                  enabled: !widget.saving,
                  minLines: 6,
                  maxLines: 12,
                  textAlignVertical: TextAlignVertical.top,
                  style: listingSmartCopyFieldStyle(
                    base: listingFieldValueStyle,
                    isAutoDrafted: _isAutoDraftedDescription(),
                  ),
                  decoration: listingInlineInputDecoration().copyWith(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final text = (v ?? '').trim();
                    if (text.isNotEmpty && text.length < 10) {
                      return 'If you add a description, use at least 10 characters.';
                    }
                    return null;
                  },
                ),
                if (showGuidance)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            guidance,
                            textAlign: TextAlign.center,
                            style: listingFieldLabelStyle.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 1.55,
                              color: const Color(0xFFD1D5DB),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CustomProximityRowState {
  _CustomProximityRowState({
    ProximityPointCategory? category,
    String? name,
    String? walkMin,
  })  : category = category ?? ProximityPointCategory.amenity,
        nameController = TextEditingController(text: name ?? ''),
        walkController = TextEditingController(text: walkMin ?? '');

  ProximityPointCategory category;
  final TextEditingController nameController;
  final TextEditingController walkController;

  void dispose() {
    nameController.dispose();
    walkController.dispose();
  }

  CustomProximityPoint toPoint() => CustomProximityPoint(
        category: category,
        name: nameController.text.trim(),
        walkMin: int.tryParse(walkController.text.trim()) ?? 0,
      );
}

/// Duration unit picker using a custom overlay (renders downward like BER).
class _DurationUnitDropdown extends StatefulWidget {
  const _DurationUnitDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.locked = false,
  });

  final SubletDurationUnit value;
  final bool enabled;
  final bool locked;
  final ValueChanged<SubletDurationUnit> onChanged;

  @override
  State<_DurationUnitDropdown> createState() => _DurationUnitDropdownState();
}

class _DurationUnitDropdownState extends State<_DurationUnitDropdown> {
  final _layerLink = LayerLink();
  final _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _open = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  void didUpdateWidget(_DurationUnitDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _open) _closeMenu();
  }

  void _toggleMenu() {
    if (!widget.enabled || widget.locked) return;
    _open ? _closeMenu() : _openMenu();
  }

  void _openMenu() {
    _removeOverlay();
    final renderBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? 200.0;
    final height = renderBox?.size.height ?? listingFieldHeight;

    _overlayEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeMenu,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, height + 4),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: listingChoiceBorderSelected,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final unit in SubletDurationUnit.values)
                          InkWell(
                            onTap: () {
                              widget.onChanged(unit);
                              _closeMenu();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      unit.name[0].toUpperCase() +
                                          unit.name.substring(1),
                                      style: listingFieldValueStyle.copyWith(
                                        fontSize: 14,
                                        fontWeight: unit == widget.value
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (unit == widget.value)
                                    Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: listingChoiceCheckColor,
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _open = true);
  }

  void _closeMenu() {
    _removeOverlay();
    setState(() => _open = false);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final label =
        widget.value.name[0].toUpperCase() + widget.value.name.substring(1);

    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        key: _fieldKey,
        height: listingFieldHeight,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: widget.enabled && !widget.locked ? _toggleMenu : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _open
                      ? listingChoiceBorderSelected
                      : listingDaftBorderColor,
                  width: listingDaftBorderWidth,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: listingFieldValueStyle),
                  ),
                  if (!widget.locked)
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: widget.enabled
                          ? const Color(0xFF374151)
                          : const Color(0xFFD1D5DB),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
