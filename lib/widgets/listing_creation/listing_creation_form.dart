import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/market/dublin_districts.dart';
import '../../config/market/market_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/listing_creation_field_keys.dart';
import '../../models/listing_creation_form_models.dart';
import '../../models/marketplace_space.dart';
import '../../models/neighborhood_amenity_tag.dart';
import '../../services/neighborhood_amenities_service.dart';
import '../../services/nominatim_forward.dart';
import '../../services/fast_location_service.dart';
import '../../services/eircode_geocoding_service.dart';
import '../../services/eircode_lookup_service.dart';
import '../../services/overpass_amenities_service.dart';
import '../../services/transit_extraction_service.dart';
import '../../utils/listing_data.dart';
import '../../utils/profile_data.dart';
import '../../screens/auth_screen.dart';
import '../../debug/agent_log.dart';
import '../../models/irish_address_suggestion.dart';
import '../../utils/address_privacy.dart';
import '../gamified_form_wizard.dart';
import '../listing_media_picker.dart';
import 'location_pin_field.dart';
import 'listing_creation_primitives.dart';

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
  static const _maxContentWidth = 720.0;
  static const _stepCount = 3;
  static const demoEircodeHint = 'D02 X285';

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();
  final _descriptionFieldKey = GlobalKey();
  late final PageController _pageController;

  int _currentStep = 0;
  bool _optionalEnhancementsExpanded = false;
  bool _photoTipsExpanded = false;
  int _expandedRoomIndex = 0;

  // Agreement
  ListingAgreementType _agreementType = ListingAgreementType.longTerm;
  DateTime? _availableFrom;
  final _subletDurationController = TextEditingController();
  SubletDurationUnit _subletDurationUnit = SubletDurationUnit.months;

  // Category
  late String _type;
  ListingPropertySubType _propertySubType = ListingPropertySubType.apartment;
  bool _isFurnished = true;

  // Financials
  final _titleController = TextEditingController();
  final _rentController = TextEditingController();
  String? _berRating;

  // Independent layout
  int _bedrooms = 1;
  int _bathrooms = 1;

  // Media
  List<String> _images = [];
  String? _video;

  // Shared dynamics
  int _roomsToShare = 1;
  final List<SharedRoomSlot> _sharedRoomSlots = [SharedRoomSlot()];
  int _housemateCount = 1;
  FlatmateCohort? _householdCohort = FlatmateCohort.mixedCohort;
  FlatmateCohort? _flatmateCohort = FlatmateCohort.mixedCohort;
  final Set<String> _householdLanguages = {};
  bool _isOwnerOccupier = false;

  SharedRoomArchitecture? get _primaryRoomArchitecture =>
      _sharedRoomSlots.isEmpty ? null : _sharedRoomSlots.first.architecture;

  bool get _hasSharedBedRoom =>
      _sharedRoomSlots.any((s) => s.isSharedBed);

  static const _cohortSegmentLabels = {
    FlatmateCohort.workingProfessionals: 'Working Professionals',
    FlatmateCohort.students: 'Students',
    FlatmateCohort.mixedCohort: 'Mixed',
    FlatmateCohort.families: 'Families',
  };

  void _setRoomsToShare(int count) {
    final next = count.clamp(1, 6);
    setState(() {
      _roomsToShare = next;
      while (_sharedRoomSlots.length < next) {
        _sharedRoomSlots.add(SharedRoomSlot());
      }
      while (_sharedRoomSlots.length > next) {
        _sharedRoomSlots.removeLast();
      }
      if (_expandedRoomIndex >= next) {
        _expandedRoomIndex = next - 1;
      }
    });
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
  double? _resolvedLatitude;
  double? _resolvedLongitude;
  String? _reverseGeocodedAddress;
  bool _locationFromGps = false;
  bool _fetchingLocation = false;
  bool _proximityResolving = false;
  bool _proximityResolved = false;
  NeighborhoodProximityDraft _proximityDraft = NeighborhoodProximityDraft();
  final _transportLineController = TextEditingController();
  final _transportWalkController = TextEditingController();
  final _groceryWalkController = TextEditingController();
  final _primarySchoolController = TextEditingController();
  final _secondarySchoolController = TextEditingController();
  final _crecheNameController = TextEditingController();
  final _crecheWalkController = TextEditingController();
  String _groceryBrand = '';
  bool _proximityEditing = false;
  final List<_CustomProximityRowState> _customProximityRows = [];
  List<NeighborhoodAmenityTag> _neighborhoodAmenityTags = [];
  bool _neighborhoodAmenitiesLoading = false;

  // Lifestyle
  bool _smokingAllowed = false;
  bool _petsAllowed = false;
  bool _vegetarianKitchen = false;
  bool _wfhFriendly = false;

  // Description
  final _descriptionController = TextEditingController();
  bool _locationPrefillLocked = false;
  bool _categoryPrefillLocked = false;
  bool _sharedProfilePrefillLocked = false;
  bool _rulesPrefillLocked = false;
  bool _furnishingPrefillLocked = false;

  List<String> get _enabledPropertyTypes => MarketConfig.current.enabledTowers;

  MarketplaceSpace get _activeSpace =>
      MarketplaceSpace.fromTowerPropertyType(_type);

  bool get _isShare => _activeSpace == MarketplaceSpace.sharedSpace;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _type = _enabledPropertyTypes.first;
    if (widget.initialListing != null) {
      _hydrateFromListing(widget.initialListing!);
      _hydrateInheritedPrefill(widget.initialListing!);
      _finalizeProfileDraftLocationSeed();
    } else {
      _locationController.text = MarketConfig.current.defaultProfileLocation;
      _seedHouseholdLanguagesFromProfile();
    }
    if (_proximityDraft.transportLine.isNotEmpty ||
        (_resolvedLatitude != null && _resolvedLongitude != null)) {
      _proximityResolved = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isProfileDraft(widget.initialListing) && !_locationFromGps) {
        if (_eircodeController.text.trim().isNotEmpty ||
            _addressSearchController.text.trim().isNotEmpty) {
          _resolveProximity();
        }
        return;
      }
      if (_eircodeController.text.trim().isNotEmpty ||
          _locationIdentifierController.text.trim().length >= 2 ||
          (_locationFromGps &&
              _locationController.text.trim().length >= 2)) {
        _resolveProximity();
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

  void _finalizeProfileDraftLocationSeed() {
    if (!_isProfileDraft(widget.initialListing)) return;
    _addressSearchController.clear();
    _selectedAddress = null;
    if (_isNearDublinCityCentre(_resolvedLatitude, _resolvedLongitude)) {
      _resolvedLatitude = null;
      _resolvedLongitude = null;
    }
  }

  void _seedHouseholdLanguagesFromProfile() {
    final session = AuthScreen.currentUserSession;
    if (session == null) return;
    final langs = ProfileData.languageList(session['spoken_languages']);
    if (langs.isEmpty) {
      final mother = ProfileData.text(session['mother_tongue']);
      if (mother.isNotEmpty) langs.add(mother);
    }
    if (langs.isNotEmpty) {
      _householdLanguages.addAll(langs);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _subletDurationController.dispose();
    _titleController.dispose();
    _rentController.dispose();
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
    _rentController.text = _stripRentForInput(ListingData.price(item));
    _locationController.text = ListingData.location(item);
    _eircodeController.text = ProfileData.text(
      item[ListingCreationFieldKeys.eircode] ?? item['eircode'],
    );
    _hideExactAddress = item[AddressPrivacy.hideExactAddressKey] == true;
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

    final agreement = ProfileData.text(item['agreement_type']);
    if (agreement == 'temporary') {
      _agreementType = ListingAgreementType.temporary;
    }

    final availableRaw = item['available_from'];
    if (availableRaw is String && availableRaw.isNotEmpty) {
      _availableFrom = DateTime.tryParse(availableRaw);
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
      _roomsToShare = _sharedRoomSlots.length.clamp(1, 6);
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
        _roomsToShare = (item['rooms_to_share'] as num?)?.toInt().clamp(1, 6) ?? 1;
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
    _flatmateCohort = _parseFlatmateCohort(cohortRaw);

    _householdLanguages
      ..clear()
      ..addAll(ProfileData.languageList(item['languages_spoken']));

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
    _syncProximityControllers();
    _loadCustomProximityRows();

    _smokingAllowed = ListingData.smokingAllowed(item);
    _petsAllowed = !_lifestyleFlags(item).contains('no_pets');
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
      _householdLanguages
        ..clear()
        ..addAll(prefillLanguages);
      _sharedProfilePrefillLocked = true;
    }

    final rules = ProfileData.languageList(raw['prefill_house_rules']);
    if (rules.isNotEmpty) {
      _rulesPrefillLocked = true;
      _smokingAllowed = rules.contains('Smoking allowed');
      _petsAllowed = rules.contains('Pets welcome');
      _vegetarianKitchen = rules.contains('Veg kitchen');
      _wfhFriendly = rules.contains('WFH friendly');
    }

    final household = raw['prefill_household_makeup'];
    if (household is Map) {
      final householdMap = Map<String, dynamic>.from(household);
      final occupants = householdMap['group_size'] ?? householdMap['current_occupants'];
      if (occupants is int && occupants > 0) {
        _housemateCount = occupants.clamp(1, 12);
        _sharedProfilePrefillLocked = true;
      }
      final occupantType = ProfileData.text(householdMap['occupant_type']).toLowerCase();
      if (occupantType.contains('student')) {
        _flatmateCohort = FlatmateCohort.students;
      } else if (occupantType.contains('professional') ||
          occupantType.contains('working')) {
        _flatmateCohort = FlatmateCohort.workingProfessionals;
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
    if (_hideExactAddress && _selectedAddress != null) {
      return _selectedAddress!.publicLocationLabel;
    }
    final gpsLabel = _locationController.text.trim();
    if (gpsLabel.isNotEmpty) return gpsLabel;
    return _locationIdentifierController.text.trim();
  }

  void _onMapPinPlaced(double lat, double lon) {
    setState(() {
      _resolvedLatitude = lat;
      _resolvedLongitude = lon;
      _locationFromGps = false;
      _locationPrefillLocked = false;
      _reverseGeocodedAddress = null;
    });
    _resolveProximityFromPin(lat, lon);
  }

  Future<void> _resolveProximityFromPin(double lat, double lon) async {
    // Fire proximity first (Overpass), then reverse geocode (Nominatim) after
    // a short delay to avoid rate-limiting collisions.
    await _resolveProximity();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    final address = await NominatimForward.reverseGeocode(lat, lon);
    if (!mounted) return;
    setState(() {
      _reverseGeocodedAddress = address;
      if (address != null && address.isNotEmpty) {
        _locationIdentifierController.text = address;
        final parts = address.split(',');
        if (parts.length >= 2) {
          _locationController.text = parts[1].trim();
        } else {
          _locationController.text = address;
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

  TargetTenantPreference? _tenantPrefFromLegacy(Map<String, dynamic> item) {
    final bachelor = ProfileData.text(item['bachelorPreference']).toLowerCase();
    if (bachelor.contains('girl') || bachelor.contains('female')) {
      return TargetTenantPreference.femaleOnly;
    }
    if (bachelor.contains('boy') || bachelor.contains('male')) {
      return TargetTenantPreference.maleOnly;
    }
    return TargetTenantPreference.noPreference;
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

  void _addCustomProximityRow() {
    if (widget.saving) return;
    setState(() => _customProximityRows.add(_CustomProximityRowState()));
  }

  void _removeCustomProximityRow(int index) {
    if (widget.saving) return;
    setState(() {
      _customProximityRows[index].dispose();
      _customProximityRows.removeAt(index);
    });
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
  }

  /// Returns the first validation error for a wizard step, or null when valid.
  String? validateStep(int step) {
    switch (step) {
      case 0:
        if (!(_step1Key.currentState?.validate() ?? false)) {
          return 'Fix the highlighted fields before continuing.';
        }
        if (_agreementType == ListingAgreementType.temporary) {
          if (_availableFrom == null) {
            return 'Pick an available-from date for temporary stays.';
          }
          if (_subletDurationController.text.trim().isEmpty) {
            return 'Enter an estimated sublet duration.';
          }
        }
        if (!_isShare) {
          if (_bedrooms < 1) return 'Enter the number of bedrooms.';
          if (_bathrooms < 1) return 'Enter the number of bathrooms.';
        }
        return null;
      case 1:
        if (!(_step2Key.currentState?.validate() ?? false)) {
          return 'Fix the highlighted fields before continuing.';
        }
        if (!_hasResolvableLocation()) {
          return 'Search and select an address, or use current location.';
        }
        return null;
      case 2:
        if (!(_step3Key.currentState?.validate() ?? false)) {
          return 'Fix the highlighted fields before continuing.';
        }
        if (_titleController.text.trim().length < 3) {
          return 'Enter a listing title (at least 3 characters).';
        }
        if (_images.length < ListingCreationFormConstants.minPhotoCount) {
          return 'Add at least ${ListingCreationFormConstants.minPhotoCount} photos before publishing.';
        }
        if (_isShare) {
          if (_sharedRoomSlots.isEmpty) {
            return 'Add at least one room to share.';
          }
          if (_householdCohort == null) {
            return 'Select who lives in the household.';
          }
          if (_hasSharedBedRoom && _flatmateCohort == null) {
            return 'Select the shared-bed cohort profile.';
          }
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

  /// Returns the first validation error, or null when the form is valid.
  String? validate() {
    for (var step = 0; step < _stepCount; step++) {
      final error = validateStep(step);
      if (error != null) return error;
    }

    final baseErrors = ListingData.validateListingForm(
      title: _titleController.text,
      price: _formattedPrice(),
      location: _effectiveLocationLabel(),
      type: _type,
      description: _descriptionController.text,
    );
    if (baseErrors.isNotEmpty) return baseErrors.values.first;

    return null;
  }

  Future<Map<String, dynamic>> buildPayload(
    Map hostFields,
    Map? profile,
  ) async {
    _applyProximityFromControllers();

    final title = _titleController.text.trim();
    final price = _formattedPrice();
    final location = _effectiveLocationLabel();
    final description = _descriptionController.text.trim();
    final coords = await _resolveListingCoordinates(location);

    final proximityData = TransitExtractionService.extractLocally(
      latitude: coords.lat,
      longitude: coords.lon,
    );

    final lifestyleFlags = <String>{};
    if (!_smokingAllowed) lifestyleFlags.add('no_smoking');
    if (!_petsAllowed) lifestyleFlags.add('no_pets');
    if (_vegetarianKitchen) lifestyleFlags.add('vegetarian_household');
    if (_isShare && !_vegetarianKitchen) lifestyleFlags.add('non_veg_allowed');

    final roomMapping = _mapRoomArchitecture(_primaryRoomArchitecture);

    final primarySlot =
        _sharedRoomSlots.isNotEmpty ? _sharedRoomSlots.first : null;

    final payload = <String, dynamic>{
      'title': title,
      'price': price,
      'location': location,
      'type': _type,
      'listing_type': _type,
      'description': description,
      'market': MarketConfig.current.id.name,
      ListingCreationFieldKeys.marketplaceCategory: _activeSpace.storageToken,
      'hostName': ListingData.text(hostFields['hostName']).isEmpty
          ? 'Guest host'
          : ListingData.text(hostFields['hostName']),
      'hostCity': ProfileData.text(hostFields['hostCity']).isNotEmpty
          ? ProfileData.text(hostFields['hostCity'])
          : 'Dublin',
      'hostLanguage': ProfileData.text(hostFields['hostLanguage']),
      'hostMotherTongue': ProfileData.text(hostFields['hostMotherTongue']),
      'hostFoodPreference': ProfileData.text(hostFields['hostFoodPreference']),
      'agreement_type':
          _agreementType == ListingAgreementType.temporary ? 'temporary' : 'long_term',
      'property_sub_type': _propertySubType == ListingPropertySubType.house
          ? 'house'
          : 'apartment',
      'property_category': _propertySubType == ListingPropertySubType.house
          ? 'House'
          : 'Apartment',
      'ber_rating': _berRating,
      'furnishing': _isFurnished ? 'Furnished' : 'Unfurnished',
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
      'smoking_allowed': _smokingAllowed,
      if (_isShare) 'schedule_type': _wfhFriendly ? 'Flexible' : 'Day shift',
      if (_isShare) 'wfh_friendly': _wfhFriendly,
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
    };

    if (_agreementType == ListingAgreementType.temporary) {
      payload['available_from'] = _availableFrom!.toIso8601String();
      payload['sublet_duration_value'] = _subletDurationController.text.trim();
      payload['sublet_duration_unit'] = _subletDurationUnit.name;
    }

    if (!_isShare) {
      payload['bedrooms'] = '$_bedrooms bed';
      payload['bathrooms'] = '$_bathrooms';
    } else {
      payload.addAll({
        'rooms_to_share': _roomsToShare,
        'shared_rooms': _sharedRoomSlots.map((s) => s.toJson()).toList(),
        if (_primaryRoomArchitecture != null)
          'shared_room_architecture': _primaryRoomArchitecture!.storageValue,
        'current_occupants': _housemateCount,
        if (_hasSharedBedRoom)
          'shared_bed_occupants': _sharedRoomSlots
              .firstWhere((s) => s.isSharedBed)
              .bedOccupants,
        if (_householdCohort != null)
          'household_cohort': _householdCohort!.storageValue,
        if (_flatmateCohort != null)
          'flatmate_cohort': _flatmateCohort!.storageValue,
        if (primarySlot != null)
          'target_tenant_preference': primarySlot.tenantGender.storageValue,
        'languages_spoken': _householdLanguages.toList(),
        'monthly_electricity_cost': _costValue(
          _electricityCostController,
          _electricityIncluded,
        ),
        'monthly_bins_cost': _costValue(_binsCostController, _binsIncluded),
        'monthly_internet_cost':
            _costValue(_internetCostController, _internetIncluded),
        'electricity_included': _electricityIncluded,
        'bins_included': _binsIncluded,
        'internet_included': _internetIncluded,
        if (roomMapping != null) ...roomMapping,
        if (_flatmateCohort != null)
          'preferred_tenant_occupant': _flatmateCohort!.label,
        if (_flatmateCohort == FlatmateCohort.students)
          'occupantType': 'Students',
        if (_vegetarianKitchen) 'preferred_tenant_food': 'veg',
        if (primarySlot?.tenantGender == TargetTenantPreference.femaleOnly)
          'bachelorPreference': 'Girls only',
        if (primarySlot?.tenantGender == TargetTenantPreference.maleOnly)
          'bachelorPreference': 'Boys only',
      });
    }

  return _applyAddressPrivacy(payload);
  }

  Map<String, dynamic> _applyAddressPrivacy(Map<String, dynamic> payload) {
    return AddressPrivacy.applyToPayload(
      payload: payload,
      hideExactAddress: _hideExactAddress,
      selected: _selectedAddress,
      area: _locationController.text.trim(),
      county: _selectedAddress?.county ?? 'Dublin',
      streetLine: _locationIdentifierController.text.trim(),
      exactLat: _resolvedLatitude,
      exactLon: _resolvedLongitude,
      exactEircode: _eircodeController.text.trim().isEmpty
          ? null
          : EircodeGeocodingService.normalize(_eircodeController.text),
    );
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

  String _costValue(TextEditingController controller, bool included) {
    if (included) return '0';
    return controller.text.trim();
  }

  String _formattedPrice() {
    final raw = _rentController.text.trim();
    if (raw.isEmpty) return raw;
    final numeric = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (numeric.isEmpty) return raw;
    if (raw.contains('/')) return raw;
    return '€$numeric/month';
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
    _selectedAddress = suggestion;
    _resolvedLatitude = suggestion.latitude;
    _resolvedLongitude = suggestion.longitude;
    _locationController.text = suggestion.area;
    _locationIdentifierController.text = suggestion.streetLine;
    _locationFromGps = fromGps;
    _locationPrefillLocked = false;
    if (suggestion.eircode != null) {
      _eircodeController.text =
          EircodeGeocodingService.normalize(suggestion.eircode!);
    }
    // #region agent log
    agentLog(
      location: 'listing_creation_form.dart:_applyAddressSuggestion',
      message: 'address applied',
      hypothesisId: 'H-D',
      data: {
        'fromGps': fromGps,
        'displayLabel': suggestion.displayLabel,
        'eircode': suggestion.eircode ?? '',
        'area': suggestion.area,
      },
    );
    // #endregion
    // LocationPinField picks up pin coordinates from pinLat/pinLon props.
  }

  void _seedProximityFromTransit(double lat, double lon) {
    if (_proximityEditing) return;
    final extracted = TransitExtractionService.extractLocally(
      latitude: lat,
      longitude: lon,
    );
    if (extracted == null) {
      _transportLineController.clear();
      _transportWalkController.clear();
      _proximityDraft.transportLine = '';
      _proximityDraft.transportWalkMin = 0;
      return;
    }

    final transitType = ProfileData.text(extracted['transit_type']);
    final stopName = ProfileData.text(extracted['nearest_stop_name']);
    final walk = (extracted['walk_minutes'] as num?)?.toInt() ?? 0;

    final line = stopName.isNotEmpty
        ? (transitType.isNotEmpty ? '$transitType · $stopName' : stopName)
        : transitType;

    _proximityDraft.transportLine = line;
    _proximityDraft.transportWalkMin = walk;
    _transportLineController.text = line;
    _transportWalkController.text = walk > 0 ? '$walk' : '';
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
    _proximityDraft.secondarySchool = '';
    _proximityDraft.crecheName = '';
    _proximityDraft.crecheWalkMin = 0;
  }

  /// Populates grocery/schools/crèche fields from an Overpass result.
  void _applyAmenities(NearbyAmenities amenities) {
    _fillEircodeIfEmpty(amenities.eircode);
    if (amenities.transitLine != null) {
      _transportLineController.text = amenities.transitLine!;
      _transportWalkController.text =
          amenities.transitWalkMin != null ? '${amenities.transitWalkMin}' : '';
      _proximityDraft.transportLine = amenities.transitLine!;
      _proximityDraft.transportWalkMin = amenities.transitWalkMin ?? 0;
    }
    if (amenities.supermarketName != null) {
      final brand = _normalisedGroceryBrand(amenities.supermarketName!);
      _groceryBrand = brand;
      _groceryWalkController.text =
          amenities.supermarketWalkMin != null ? '${amenities.supermarketWalkMin}' : '';
      _proximityDraft.groceryBrand = brand;
      _proximityDraft.groceryWalkMin = amenities.supermarketWalkMin ?? 0;
    }
    if (amenities.primarySchool != null) {
      _primarySchoolController.text = amenities.primarySchool!;
      _proximityDraft.primarySchool = amenities.primarySchool!;
    }
    if (amenities.secondarySchool != null) {
      _secondarySchoolController.text = amenities.secondarySchool!;
      _proximityDraft.secondarySchool = amenities.secondarySchool!;
    }
    if (amenities.crecheName != null) {
      _crecheNameController.text = amenities.crecheName!;
      _crecheWalkController.text =
          amenities.crecheWalkMin != null ? '${amenities.crecheWalkMin}' : '';
      _proximityDraft.crecheName = amenities.crecheName!;
      _proximityDraft.crecheWalkMin = amenities.crecheWalkMin ?? 0;
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
      _neighborhoodAmenityTags = [];
      _clearAutoProximityFields();
    });

    try {
      final usedGpsCoords = _locationFromGps &&
          _resolvedLatitude != null &&
          _resolvedLongitude != null;
      final pin = await _resolveProximityCoordinates(location, eircode);
      final lat = pin.lat;
      final lon = pin.lon;

      if (!mounted) return;

      final amenities = await OverpassAmenitiesService.fetchNearby(
        latitude: lat,
        longitude: lon,
      );
      // Prefer live Overpass lifestyle tags; fall back to static catalog when
      // the Overpass query returns nothing useful (e.g. rural / sparse data).
      final overpassLifestyle = amenities?.lifestyleTags ?? [];
      final catalogLifestyle = await NeighborhoodAmenitiesService.resolve(
        latitude: lat,
        longitude: lon,
      );
      final lifestyleTags = overpassLifestyle.isNotEmpty
          ? overpassLifestyle
          : catalogLifestyle;
      if (!mounted || _proximityEditing) return;

      setState(() {
        _resolvedLatitude = lat;
        _resolvedLongitude = lon;
        _neighborhoodAmenityTags = lifestyleTags;
        _neighborhoodAmenitiesLoading = false;
        if (usedGpsCoords) {
          final coordLabel = dublinDistrictLabelFromCoordinates(lat, lon);
          if (coordLabel != null) {
            _locationController.text = coordLabel;
          }
          // Option 1 display is set by _applyAddressSuggestion — do not downgrade
          // a building-level Google/Places address to "district + Eircode" here.
        }
        // Prefer OSM stops (accurate in suburbs); fall back to local Luas/DART
        // graph only when OSM has nothing nearby.
        if (amenities?.transitLine == null) {
          _seedProximityFromTransit(lat, lon);
        }
        if (amenities != null && !amenities.isEmpty) {
          _applyAmenities(amenities);
        }
        _proximityResolving = false;
        _proximityResolved = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _proximityResolving = false;
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
  }

  void _handleNext() {
    if (widget.saving) return;
    final error = validateStep(_currentStep);
    if (error != null) {
      _message(error);
      return;
    }
    if (_currentStep >= _stepCount - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _currentStep += 1);
  }

  void _handlePublish() {
    if (widget.saving) return;
    for (var step = 0; step < _stepCount; step++) {
      final error = validateStep(step);
      if (error != null) {
        _jumpToStepWithError(step, error);
        return;
      }
    }

    final baseErrors = ListingData.validateListingForm(
      title: _titleController.text,
      price: _formattedPrice(),
      location: _effectiveLocationLabel(),
      type: _type,
      description: _descriptionController.text,
    );
    if (baseErrors.isNotEmpty) {
      final entry = baseErrors.entries.first;
      final step = switch (entry.key) {
        'location' => 1,
        'title' || 'description' => 2,
        _ => 0,
      };
      _jumpToStepWithError(step, entry.value);
      return;
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
    }
    switch (step) {
      case 0:
        _step1Key.currentState?.validate();
      case 1:
        _step2Key.currentState?.validate();
      case 2:
        _step3Key.currentState?.validate();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _descriptionFieldKey.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOut,
              alignment: 0.2,
            );
          }
        });
    }
    _message(message);
  }

  Future<void> _useCurrentLocation() async {
    if (_fetchingLocation || widget.saving) return;
    setState(() {
      _fetchingLocation = true;
      _locationPrefillLocked = false;
      if (_isDublinCityCentre(_resolvedLatitude, _resolvedLongitude)) {
        _resolvedLatitude = null;
        _resolvedLongitude = null;
      }
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _handleLocationFailure(
          'Location services are off. Enter your Eircode or search for your address instead.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _handleLocationFailure(
          'Location permission denied. Enter your Eircode or search for your address instead.',
        );
        return;
      }

      final resolved = await FastLocationService.resolveForUserAction();
      // #region agent log
      agentLog(
        location: 'listing_creation_form.dart:_useCurrentLocation',
        message: 'gps resolved',
        hypothesisId: 'H-E',
        data: {
          'gpsHit': resolved != null,
          'lat': resolved?.latitude,
          'lon': resolved?.longitude,
        },
      );
      // #endregion
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

      final suggestion = await EircodeLookupService.resolveFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (suggestion == null) {
        await _handleLocationFailure(
          'Could not resolve your nearest Eircode. Enter it manually instead.',
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _fetchingLocation = false;
        _applyAddressSuggestion(suggestion, fromGps: true);
      });
      unawaited(_resolveProximity());
    } catch (_) {
      if (mounted) setState(() => _fetchingLocation = false);
      await _handleLocationFailure(
        'Could not read GPS. Enter your Eircode or search for your address instead.',
      );
    }
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
        await _resolveProximity();
        _message('$message Using your profile area instead.');
        return;
      }
    }

    if (mounted) _message(message);
  }

  void _selectSpace(MarketplaceSpace space) {
    setState(() => _type = space.towerPropertyType);
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

  Future<void> _promptAddLanguage() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add language'),
        content: TextField(
          controller: controller,
          decoration: listingInputDecoration(label: 'Language'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;
    setState(() => _householdLanguages.add(result));
  }

  void _message(String text) => widget.onMessage?.call(text);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: GamifiedFormProgress(
                current: _currentStep,
                total: _stepCount,
                onStepTap: widget.saving ? null : _goToWizardStep,
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentStep = index),
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
                ],
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
          enabled: !widget.saving,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GamifiedFormPageHeader(
          title: '🏡 Property',
          subtitle: 'Set the basics — rent, type, and furnishing.',
        ),
        const SizedBox(height: listingSectionSpacing),
        _tenureSection(),
        const SizedBox(height: listingFieldSpacing),
        _categorySection(),
        const SizedBox(height: listingFieldSpacing),
        _financialsSection(),
      ],
    );
  }

  Widget _step2Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GamifiedFormPageHeader(
          title: '📍 Location',
          subtitle:
              'Search by Eircode or address — nearby transport and amenities are detected automatically.',
        ),
        const SizedBox(height: listingSectionSpacing),
        _locationSection(),
      ],
    );
  }

  Widget _step3Content() {
    if (_isShare) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GamifiedFormPageHeader(
            title: '✨ Listing',
            subtitle:
                'Introduce your household, show the room, and help seekers understand the fit.',
          ),
          const SizedBox(height: listingSectionSpacing),
          _householdProfileSection(),
          const SizedBox(height: listingSectionSpacing),
          _roomConfigurationSection(),
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

  Widget _tenureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(title: 'Tenure & duration'),
        ListingDaftRadioChoiceList<ListingAgreementType>(
          enabled: !widget.saving,
          selected: _agreementType,
          onChanged: (v) => setState(() => _agreementType = v),
          options: const {
            ListingAgreementType.longTerm: 'Long term',
            ListingAgreementType.temporary: 'Temporary',
          },
          emojis: const {
            ListingAgreementType.longTerm: '📅',
            ListingAgreementType.temporary: '⏳',
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _agreementType == ListingAgreementType.temporary
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _temporaryDurationRow(),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _temporaryDurationRow() {
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
      child: _DurationUnitDropdown(
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

  String _roomArchDisplayLabel(SharedRoomArchitecture arch) {
    final raw = arch.label;
    final spaceIdx = raw.indexOf(' ');
    if (spaceIdx > 0 && spaceIdx <= 3) {
      return raw.substring(spaceIdx + 1);
    }
    return raw;
  }

  String _roomArchSummary(SharedRoomArchitecture arch) =>
      _roomArchDisplayLabel(arch);

  Widget _sharedRoomAccordion(int index) {
    final slot = _sharedRoomSlots[index];
    final expanded = _expandedRoomIndex == index;

    return Container(
      margin: EdgeInsets.only(top: index == 0 ? 0 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: expanded
              ? listingChoiceBorderSelected
              : listingChoiceBorderUnselected,
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
                  : () => setState(
                        () => _expandedRoomIndex = expanded ? -1 : index,
                      ),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(10),
                bottom: expanded ? Radius.zero : const Radius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      expanded
                          ? Icons.expand_more_rounded
                          : Icons.chevron_right_rounded,
                      size: 18,
                      color: const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Room ${index + 1}',
                      style: listingFieldLabelStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    if (!expanded) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _roomArchSummary(slot.architecture),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: listingSubLabelStyle.copyWith(
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
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
                  Text('Room type', style: listingFieldLabelStyle),
                  const SizedBox(height: listingLabelSpacing),
                  ListingOutlineChoiceGrid<SharedRoomArchitecture>(
                    enabled: !widget.saving,
                    selected: slot.architecture,
                    onChanged: (arch) => setState(() => slot.architecture = arch),
                    options: {
                      for (final arch in SharedRoomArchitecture.values)
                        arch: _roomArchDisplayLabel(arch),
                    },
                  ),
                  const SizedBox(height: listingFieldSpacing),
                  ListingCompactCounter(
                    label: 'Occupants',
                    value: slot.tenantsInRoom,
                    min: 1,
                    max: slot.isSharedBed ? 6 : 2,
                    compact: true,
                    onDecrement: widget.saving
                        ? () {}
                        : () => setState(
                              () => slot.tenantsInRoom = (slot.tenantsInRoom - 1)
                                  .clamp(1, slot.isSharedBed ? 6 : 2),
                            ),
                    onIncrement: widget.saving
                        ? () {}
                        : () => setState(
                              () => slot.tenantsInRoom = (slot.tenantsInRoom + 1)
                                  .clamp(1, slot.isSharedBed ? 6 : 2),
                            ),
                  ),
                  const SizedBox(height: listingFieldSpacing),
                  Text('Tenant composition', style: listingFieldLabelStyle),
                  const SizedBox(height: listingLabelSpacing),
                  ListingDaftRadioChoiceList<TargetTenantPreference>(
                    enabled: !widget.saving,
                    selected: slot.tenantGender,
                    horizontal: true,
                    onChanged: (v) => setState(() => slot.tenantGender = v),
                    options: const {
                      TargetTenantPreference.femaleOnly: 'Female',
                      TargetTenantPreference.maleOnly: 'Male',
                      TargetTenantPreference.mixed: 'Mixed',
                    },
                    icons: const {
                      TargetTenantPreference.femaleOnly: Icons.person_outline,
                      TargetTenantPreference.maleOnly: Icons.person_outline,
                      TargetTenantPreference.mixed: Icons.people_outline,
                    },
                  ),
                  if (slot.isSharedBed) ...[
                    const SizedBox(height: listingFieldSpacing),
                    ListingCompactCounter(
                      label: 'Sharing this bed',
                      value: slot.bedOccupants,
                      min: 2,
                      max: 6,
                      compact: true,
                      onDecrement: widget.saving
                          ? () {}
                          : () => setState(
                                () => slot.bedOccupants =
                                    (slot.bedOccupants - 1).clamp(2, 6),
                              ),
                      onIncrement: widget.saving
                          ? () {}
                          : () => setState(
                                () => slot.bedOccupants =
                                    (slot.bedOccupants + 1).clamp(2, 6),
                              ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _householdProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(
          title: '👥 Household profile',
          subtitle: 'Who lives here?',
        ),
        if (_sharedProfilePrefillLocked)
          _inheritedSummaryCard(
            title: 'Household profile inherited',
            subtitle:
                'Using your onboarding host profile as the starting point for this listing.',
            lines: [
              'Total housemates in home: $_housemateCount',
              if (_householdLanguages.isNotEmpty)
                'Languages: ${_householdLanguages.join(', ')}',
              'Owner occupier: ${_isOwnerOccupier ? 'Yes' : 'No'}',
            ],
            actionLabel: 'Edit household',
            onAction: () => setState(() => _sharedProfilePrefillLocked = false),
          )
        else ...[
          ListingWrapSegmentedControl<FlatmateCohort>(
            enabled: !widget.saving,
            selected: _householdCohort ?? FlatmateCohort.mixedCohort,
            onChanged: (v) => setState(() => _householdCohort = v),
            segments: {
              for (final c in FlatmateCohort.values)
                c: _cohortSegmentLabels[c] ?? c.label,
            },
          ),
          const SizedBox(height: listingFieldSpacing),
          ListingCompactCounter(
            label: 'Total housemates in home',
            value: _housemateCount,
            min: 1,
            max: 12,
            compact: true,
            onDecrement: widget.saving
                ? () {}
                : () => setState(
                      () => _housemateCount = (_housemateCount - 1).clamp(1, 12),
                    ),
            onIncrement: widget.saving
                ? () {}
                : () => setState(
                      () => _housemateCount = (_housemateCount + 1).clamp(1, 12),
                    ),
          ),
          const SizedBox(height: listingFieldSpacing),
          Text('Household languages spoken', style: listingFieldLabelStyle),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final lang in _householdLanguages)
                Chip(
                  label: Text(lang),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: widget.saving
                      ? null
                      : () => setState(() => _householdLanguages.remove(lang)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add language'),
                onPressed: widget.saving ? null : _promptAddLanguage,
              ),
              if (_householdLanguages.isEmpty)
                ActionChip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: const Text('From my profile'),
                  onPressed: widget.saving
                      ? null
                      : () {
                          final session = AuthScreen.currentUserSession;
                          final langs = <String>[
                            if (session != null)
                              ...ProfileData.languageList(
                                session['spoken_languages'],
                              ),
                          ];
                          if (langs.isEmpty &&
                              session != null &&
                              ProfileData.text(session['mother_tongue']).isNotEmpty) {
                            langs.add(ProfileData.text(session['mother_tongue']));
                          }
                          if (langs.isEmpty) {
                            _message('No profile languages found to import.');
                            return;
                          }
                          setState(() => _householdLanguages.addAll(langs));
                        },
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _roomConfigurationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(
          title: '🏠 Room configuration',
          subtitle: 'Set the layout and who each room suits.',
        ),
        ListingCompactCounter(
          label: 'Rooms to share',
          value: _roomsToShare,
          min: 1,
          max: 6,
          compact: true,
          onDecrement:
              widget.saving ? () {} : () => _setRoomsToShare(_roomsToShare - 1),
          onIncrement:
              widget.saving ? () {} : () => _setRoomsToShare(_roomsToShare + 1),
        ),
        const SizedBox(height: listingFieldSpacing),
        for (var i = 0; i < _sharedRoomSlots.length; i++)
          _sharedRoomAccordion(i),
        if (_hasSharedBedRoom) ...[
          const SizedBox(height: listingFieldSpacing),
          Text('Shared-bed cohort profile', style: listingFieldLabelStyle),
          const SizedBox(height: 6),
          const Text(
            'Only applies to rooms with a shared bed in shared occupancy.',
            style: listingOptionHintStyle,
          ),
          const SizedBox(height: listingLabelSpacing),
          ListingWrapSegmentedControl<FlatmateCohort>(
            enabled: !widget.saving,
            selected: _flatmateCohort ?? FlatmateCohort.mixedCohort,
            onChanged: (v) => setState(() => _flatmateCohort = v),
            segments: {
              for (final c in FlatmateCohort.values)
                c: _cohortSegmentLabels[c] ?? c.label,
            },
          ),
        ],
      ],
    );
  }

  Widget _categorySection() {
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
              _isShare ? 'Shared room' : 'Entire place',
            ],
            actionLabel: 'Edit category',
            onAction: () => setState(() => _categoryPrefillLocked = false),
          )
        else
          ListingDaftRadioChoiceList<bool>(
            enabled: !widget.saving,
            selected: _isShare,
            onChanged: (isShare) => _selectSpace(
              isShare
                  ? MarketplaceSpace.sharedSpace
                  : MarketplaceSpace.fullRental,
            ),
            options: const {
              false: 'Entire place',
              true: 'Shared room',
            },
            emojis: const {
              false: '🏠',
              true: '🛏️',
            },
          ),
        const SizedBox(height: 12),
        const ListingSectionHeader(title: 'Property type'),
        ListingDaftRadioChoiceList<ListingPropertySubType>(
          enabled: !widget.saving,
          selected: _propertySubType,
          onChanged: (v) => setState(() => _propertySubType = v),
          options: const {
            ListingPropertySubType.apartment: 'Apartment',
            ListingPropertySubType.house: 'House',
          },
          emojis: const {
            ListingPropertySubType.apartment: '🏢',
            ListingPropertySubType.house: '🏡',
          },
        ),
        const SizedBox(height: 12),
        const ListingSectionHeader(title: 'Furnishing'),
        if (_furnishingPrefillLocked)
          _inheritedSummaryCard(
            title: 'Furnishing inherited from profile',
            subtitle:
                'Your onboarding listing defaults already set this preference.',
            lines: [
              'Furnishing: ${_isFurnished ? 'Furnished' : 'Unfurnished'}',
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
        if (!_isShare) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ListingCompactCounter(
                  label: 'Bedrooms',
                  value: _bedrooms,
                  min: 1,
                  max: 6,
                  compact: true,
                  onDecrement: widget.saving
                      ? () {}
                      : () => setState(
                            () => _bedrooms = (_bedrooms - 1).clamp(1, 6),
                          ),
                  onIncrement: widget.saving
                      ? () {}
                      : () => setState(
                            () => _bedrooms = (_bedrooms + 1).clamp(1, 6),
                          ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: ListingCompactCounter(
                  label: 'Bathrooms',
                  value: _bathrooms,
                  min: 1,
                  max: 4,
                  compact: true,
                  onDecrement: widget.saving
                      ? () {}
                      : () => setState(
                            () => _bathrooms = (_bathrooms - 1).clamp(1, 4),
                          ),
                  onIncrement: widget.saving
                      ? () {}
                      : () => setState(
                            () => _bathrooms = (_bathrooms + 1).clamp(1, 4),
                          ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _financialsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(title: '💰 Monthly rent'),
        ListingPremiumRentField(
          controller: _rentController,
          enabled: !widget.saving,
          validator: (v) {
            final text = (v ?? '').trim();
            if (text.isEmpty) return ' ';
            if (!RegExp(r'^\d+$').hasMatch(text)) {
              return ' ';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Landlord reminder: annual management fees, service charges, and '
          'block insurance are included in this base rent where required by '
          'local regulations.',
          style: listingSubLabelStyle,
        ),
        const SizedBox(height: 14),
        ListingBerRatingField(
          value: _berRating,
          enabled: !widget.saving,
          ratings: ListingCreationFormConstants.berRatings,
          onChanged: (v) => setState(() => _berRating = v),
        ),
      ],
    );
  }

  Widget _mediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(
          title: '📸 Photos',
          subtitle: 'Minimum 3 photos · 5+ recommended',
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4B5563),
                ),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(title: 'Monthly shared costs (per person)'),
        Row(
          children: [
            Expanded(
              child: _costBox(
                icon: Icons.bolt_outlined,
                label: 'Gas & electricity',
                controller: _electricityCostController,
                included: _electricityIncluded,
                onIncludedChanged: (v) => setState(() {
                  _electricityIncluded = v;
                  if (v) _electricityCostController.text = '0';
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
                onIncludedChanged: (v) => setState(() {
                  _binsIncluded = v;
                  if (v) _binsCostController.text = '0';
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
                onIncludedChanged: (v) => setState(() {
                  _internetIncluded = v;
                  if (v) _internetCostController.text = '0';
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
  }) {
    return Opacity(
      opacity: included ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: listingDaftBorder(),
        ),
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
              decoration: listingInlineInputDecoration(hint: 'Per month'),
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Drop a pin on the map where your property is located',
          style: listingOptionLabelStyle,
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap the map to place a pin, or use the search box to centre it. '
          'We detect nearby transport & amenities from the pin location.',
          style: listingOptionHintStyle,
        ),
        const SizedBox(height: 12),
        LocationPinField(
          pinLat: _resolvedLatitude,
          pinLon: _resolvedLongitude,
          onPinPlaced: _onMapPinPlaced,
          enabled: !widget.saving,
        ),
        const SizedBox(height: 12),
        if (_reverseGeocodedAddress != null && _reverseGeocodedAddress!.isNotEmpty) ...[
          Text(
            _reverseGeocodedAddress!,
            style: listingFieldValueStyle.copyWith(
              fontSize: 13,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
        ],
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
        const SizedBox(height: 16),
        // Eircode (optional text-only)
        SizedBox(
          height: listingFieldHeight,
          child: TextFormField(
            controller: _eircodeController,
            enabled: !widget.saving,
            style: listingFieldValueStyle,
            decoration: listingInlineInputDecoration(
              hint: 'Eircode (optional, e.g. D15 FT9N)',
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Privacy checkbox
        Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _hideExactAddress,
                onChanged: widget.saving
                    ? null
                    : (v) => setState(() => _hideExactAddress = v ?? false),
                activeColor: const Color(0xFF374151),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'I don\'t want to display the exact address',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _neighborhoodAmenityTagsSection(),
        const SizedBox(height: 20),
        _proximityRevealSection(),
      ],
    );
  }

  Widget _neighborhoodAmenityTagsSection() {
    if (_neighborhoodAmenitiesLoading || _proximityResolving || _fetchingLocation) {
      return const SizedBox.shrink();
    }
    if (_neighborhoodAmenityTags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nearby lifestyle',
          style: listingSectionTitleStyle.copyWith(fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in _neighborhoodAmenityTags)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: listingDaftBorder(),
                ),
                child: Text(
                  tag.displayLabel,
                  style: listingFieldValueStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF374151),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _proximityRevealSection() {
    if (_proximityResolving || _fetchingLocation) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 14),
            Text(
              'Auto-detecting neighborhood amenities…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Neighborhood proximity',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: widget.saving
                  ? null
                  : () => setState(() {
                        _proximityEditing = !_proximityEditing;
                        _proximityDraft.manualEdit = _proximityEditing;
                        if (_proximityEditing) _proximityResolved = true;
                      }),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(
                _proximityEditing ? 'Done editing' : '✏️ Edit Proximity',
              ),
            ),
          ],
        ),
        if (!_proximityEditing) ...[
          const SizedBox(height: 8),
          if (_proximityResolved)
            _proximityReadOnlyChips()
          else if (!_proximityResolving && !_fetchingLocation)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'Tap "Use current location" or type your Eircode to auto-detect, or add manually.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
            ),
        ] else ...[
          const SizedBox(height: 8),
          _proximityEditFields(),
        ],
      ],
    );
  }

  Widget _proximityReadOnlyChips() {
    final chips = <Widget>[];

    final transport = _transportLineController.text.trim();
    final transportWalk = _transportWalkController.text.trim();
    if (transport.isNotEmpty) {
      chips.add(_proximityChip(
        icon: Icons.train_outlined,
        label: transportWalk.isNotEmpty
            ? '$transport • $transportWalk min walk'
            : transport,
      ));
    }

    final groceryWalk = _groceryWalkController.text.trim();
    if (_groceryBrand.isNotEmpty && groceryWalk.isNotEmpty) {
      chips.add(_proximityChip(
        icon: Icons.shopping_bag_outlined,
        label: '$_groceryBrand • $groceryWalk min walk',
      ));
    }

    final primary = _primarySchoolController.text.trim();
    if (primary.isNotEmpty) {
      chips.add(_proximityChip(
        icon: Icons.school_outlined,
        label: 'Primary: $primary',
      ));
    }

    final secondary = _secondarySchoolController.text.trim();
    if (secondary.isNotEmpty) {
      chips.add(_proximityChip(
        icon: Icons.school_outlined,
        label: 'Secondary: $secondary',
      ));
    }

    final creche = _crecheNameController.text.trim();
    final crecheWalk = _crecheWalkController.text.trim();
    if (creche.isNotEmpty) {
      chips.add(_proximityChip(
        icon: Icons.child_care_outlined,
        label: crecheWalk.isNotEmpty
            ? '$creche • $crecheWalk min walk'
            : creche,
      ));
    }

    for (final row in _customProximityRows) {
      final name = row.nameController.text.trim();
      if (name.isEmpty) continue;
      final walk = row.walkController.text.trim();
      chips.add(_proximityChip(
        icon: _proximityCategoryIcon(row.category),
        label: walk.isNotEmpty ? '$name • $walk min walk' : name,
      ));
    }

    if (chips.isEmpty) {
      return Text(
        'No proximity details detected yet — tap ✏️ Edit Proximity to add manually.',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  IconData _proximityCategoryIcon(ProximityPointCategory category) {
    return switch (category) {
      ProximityPointCategory.transport => Icons.train_outlined,
      ProximityPointCategory.grocery => Icons.shopping_bag_outlined,
      ProximityPointCategory.school => Icons.school_outlined,
      ProximityPointCategory.amenity => Icons.place_outlined,
    };
  }

  Widget _proximityChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accentDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _proximityEditFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _proximityChipCard(
          emoji: '🚇',
          title: 'Transport Hub',
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _transportLineController,
                  enabled: !widget.saving,
                  decoration: listingInputDecoration(
                    label: 'Line / stop',
                    hint: 'Luas Green Line',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _transportWalkController,
                  enabled: !widget.saving,
                  keyboardType: TextInputType.number,
                  decoration: listingInputDecoration(
                    label: 'Min walk',
                    hint: '5',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _proximityChipCard(
          emoji: '🛒',
          title: 'Nearest Grocery',
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _groceryBrand.isEmpty ? null : _groceryBrand,
                  decoration: listingInputDecoration(label: 'Brand'),
                  hint: const Text('Select brand'),
                  items: ListingCreationFormConstants.groceryBrands
                      .map(
                        (b) => DropdownMenuItem(value: b, child: Text(b)),
                      )
                      .toList(),
                  onChanged: widget.saving
                      ? null
                      : (v) {
                          if (v != null) setState(() => _groceryBrand = v);
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _groceryWalkController,
                  enabled: !widget.saving,
                  keyboardType: TextInputType.number,
                  decoration: listingInputDecoration(
                    label: 'Min walk',
                    hint: '8',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _proximityChipCard(
          emoji: '🏫',
          title: 'Local Schools',
          child: Column(
            children: [
              TextFormField(
                controller: _primarySchoolController,
                enabled: !widget.saving,
                decoration: listingInputDecoration(
                  label: 'Primary school name',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _secondarySchoolController,
                enabled: !widget.saving,
                decoration: listingInputDecoration(
                  label: 'Secondary school name',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _proximityChipCard(
          emoji: '👶',
          title: 'Childcare / Crèche',
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _crecheNameController,
                  enabled: !widget.saving,
                  decoration: listingInputDecoration(
                    label: 'Crèche name',
                    hint: 'Optional',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _crecheWalkController,
                  enabled: !widget.saving,
                  keyboardType: TextInputType.number,
                  decoration: listingInputDecoration(
                    label: 'Min walk',
                    hint: '10',
                  ),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < _customProximityRows.length; i++) ...[
          const SizedBox(height: 10),
          _customProximityRowEditor(i),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.saving ? null : _addCustomProximityRow,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('➕ Add custom proximity point'),
          ),
        ),
      ],
    );
  }

  Widget _customProximityRowEditor(int index) {
    final row = _customProximityRows[index];
    return _proximityChipCard(
      emoji: row.category.emoji,
      title: 'Custom point',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ProximityPointCategory>(
                  initialValue: row.category,
                  decoration: listingInputDecoration(label: 'Category'),
                  items: ProximityPointCategory.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text('${c.emoji} ${c.label}'),
                        ),
                      )
                      .toList(),
                  onChanged: widget.saving
                      ? null
                      : (v) {
                          if (v != null) {
                            setState(() => row.category = v);
                          }
                        },
                ),
              ),
              if (!widget.saving) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => _removeCustomProximityRow(index),
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: row.nameController,
                  enabled: !widget.saving,
                  decoration: listingInputDecoration(
                    label: 'Place name',
                    hint: 'Phoenix Park',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: row.walkController,
                  enabled: !widget.saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: listingInputDecoration(
                    label: 'Min walk',
                    hint: '5',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _proximityChipCard({
    required String emoji,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$emoji $title',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _lifestyleSection() {
    if (_rulesPrefillLocked) {
      final ruleChips = <Widget>[
        ListingRuleChip(
          icon: Icons.smoke_free_outlined,
          label: _smokingAllowed ? 'Smoking allowed' : 'No smoking',
          active: true,
          expand: true,
        ),
        ListingRuleChip(
          icon: Icons.pets_outlined,
          label: _petsAllowed ? 'Pets welcome' : 'No pets',
          active: true,
          expand: true,
        ),
        if (_isShare)
          ListingRuleChip(
            icon: Icons.restaurant_outlined,
            label: _vegetarianKitchen ? 'Veg kitchen' : 'Open kitchen',
            active: true,
            expand: true,
          ),
        if (_isShare)
          ListingRuleChip(
            icon: Icons.laptop_mac_outlined,
            label: _wfhFriendly ? 'WFH friendly' : 'Commuter',
            active: true,
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
                onChanged: (v) => setState(() => _smokingAllowed = !v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ListingCompactRuleTile(
                offLabel: 'Pets welcome',
                onLabel: 'No pets',
                active: !_petsAllowed,
                enabled: !widget.saving,
                onChanged: (v) => setState(() => _petsAllowed = !v),
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
                  offLabel: 'Non-veg welcome',
                  onLabel: 'Veg kitchen',
                  active: _vegetarianKitchen,
                  enabled: !widget.saving,
                  onChanged: (v) => setState(() => _vegetarianKitchen = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ListingCompactRuleTile(
                  offLabel: 'Commuter',
                  onLabel: 'WFH friendly',
                  active: _wfhFriendly,
                  enabled: !widget.saving,
                  onChanged: (v) => setState(() => _wfhFriendly = v),
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
        const ListingSectionHeader(title: '🏷 Listing title'),
        TextFormField(
          controller: _titleController,
          enabled: !widget.saving,
          style: listingFieldValueStyle,
          decoration: listingInputDecoration(
            label: 'Title',
            hint: _isShare
                ? 'Bright ensuite room in friendly Dublin 8 household'
                : 'Bright 2-bed near Luas Green Line',
          ),
          validator: (v) {
            if ((v ?? '').trim().length < 3) {
              return 'Enter a title (at least 3 characters).';
            }
            return null;
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
        if (_neighborhoodAmenityTags.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('✨ Lifestyle tags', style: listingFieldLabelStyle),
              const SizedBox(height: listingLabelSpacing),
              _neighborhoodAmenityTagsSection(),
            ],
          ),
        if (_isShare) ...[
          _sharedCostsSection(),
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
      ],
    );
  }

  Widget _descriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(
          title: '📝 Description',
          subtitle: 'Optional — tell applicants more about the space or household.',
        ),
        TextFormField(
          key: _descriptionFieldKey,
          controller: _descriptionController,
          enabled: !widget.saving,
          minLines: 6,
          maxLines: 12,
          style: listingFieldValueStyle,
          decoration: listingInputDecoration(
            label: 'Description (optional)',
            hint: _isShare
                ? 'Share the household vibe, routines, and what kind of flatmate fits…'
                : 'Tell applicants about the local vibe, transport links, and what to expect…',
          ),
          validator: (v) {
            final text = (v ?? '').trim();
            if (text.isNotEmpty && text.length < 10) {
              return 'If you add a description, use at least 10 characters.';
            }
            return null;
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
  });

  final SubletDurationUnit value;
  final bool enabled;
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
    if (!widget.enabled) return;
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
            onTap: widget.enabled ? _toggleMenu : null,
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
