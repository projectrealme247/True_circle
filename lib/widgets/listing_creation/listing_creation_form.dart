import 'dart:async';

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
  LandlordAvailabilityFlexibility _availabilityFlexibility =
      LandlordAvailabilityFlexibility.exactDate;
  final _subletDurationController = TextEditingController();
  SubletDurationUnit _subletDurationUnit = SubletDurationUnit.years;

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

  static final _cohortEmojis = {
    for (final c in FlatmateCohort.values) c: c.emoji,
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
  String? _listingAreaKey;
  String _localityLabel = '';
  bool _sharedCostsShowErrors = false;
  bool _rentShowError = false;
  String? _rentErrorText;
  bool _locationShowErrors = false;
  bool _titleShowError = false;
  String? _autoDraftedTitle;
  String? _autoDraftedDescription;
  final _sharedCostsSectionKey = GlobalKey();
  final _rentSectionKey = GlobalKey();
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

  bool _secureBikeStorage = false;

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
    _rentController.text = formatThousandsForInput(
      _stripRentForInput(ListingData.price(item)),
    );
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

    final agreement = ProfileData.text(item['agreement_type']);
    if (agreement == 'temporary') {
      _agreementType = ListingAgreementType.temporary;
    }

    final availableRaw = item['available_from'];
    if (availableRaw is String && availableRaw.isNotEmpty) {
      _availableFrom = DateTime.tryParse(availableRaw);
    }
    _availabilityFlexibility = LandlordAvailabilityFlexibility.fromListing(item);

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
    _secureBikeStorage = ListingData.hasBikeStorage(item);

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
    if (_hideExactAddress) {
      return _publicLocationPreviewLabel();
    }
    final street = _locationIdentifierController.text.trim();
    if (street.isNotEmpty) return street;
    final gpsLabel = _locationController.text.trim();
    if (gpsLabel.isNotEmpty) return gpsLabel;
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
      if (!mounted || generation != _proximityGeneration) return;
      setState(
        () => _applyResolvedAddressSuggestion(cachedGeocode, fromGps: fromGps),
      );
      return;
    }

    final suggestion = await EircodeLookupService.resolveFromCoordinates(
      lat,
      lon,
    );
    if (!mounted || generation != _proximityGeneration) return;
    if (suggestion != null) {
      ProximityResolutionCache.putGeocode(cellKey, suggestion);
      setState(
        () => _applyResolvedAddressSuggestion(suggestion, fromGps: fromGps),
      );
      return;
    }
    final address = await NominatimForward.reverseGeocode(lat, lon);
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

  void _onStepActivated(int step) {
    if (step != 2) return;
    _applyProximityFromControllers();
    _generateSmartListingCopy();
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
      _propertySubType == ListingPropertySubType.house ? 'House' : 'Apartment';

  int _parsedMonthlyRent() {
    final digits = _rentController.text.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(digits) ?? 0;
  }

  String _formatWalkTimeLabel(int minutes) {
    if (minutes <= 0) return '5 min';
    return '$minutes min';
  }

  void _generateSmartListingCopy() {
    final generated = ListingSmartCopyGenerator.generate(
      ListingSmartCopyInput(
        isSharedLiving: _isShare,
        areaName: _smartCopyAreaName(),
        postalDistrict: _smartCopyPostalDistrict(),
        propertyType: _smartCopyPropertyTypeLabel(),
        isFurnished: _isFurnished,
        bedrooms: _bedrooms,
        bathrooms: _bathrooms,
        monthlyRent: _parsedMonthlyRent(),
        closestTransit: _proximityDraft.transportLine,
        transitWalkTime: _formatWalkTimeLabel(_proximityDraft.transportWalkMin),
        closestShop: _proximityDraft.groceryBrand,
        shopWalkTime: _formatWalkTimeLabel(_proximityDraft.groceryWalkMin),
        roomArchitecture: _primaryRoomArchitecture,
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

  String? _validateRent() {
    final text = stripThousandsFormatting(_rentController.text.trim());
    if (text.isEmpty) return 'Enter monthly rent';
    if (!RegExp(r'^\d+$').hasMatch(text)) {
      return 'Enter a valid rent amount';
    }
    return null;
  }

  String? _validateStep2() {
    if (!_hasResolvableLocation()) {
      return 'Drop a pin on the map or use current location.';
    }
    if (_locationIdentifierController.text.trim().length < 3) {
      return 'Confirm the resolved address — edit it if the pin is slightly off.';
    }
    if (_locationController.text.trim().length < 2) {
      return 'Confirm the property area used for seeker matching.';
    }
    return null;
  }

  /// Returns the first validation error for a wizard step, or null when valid.
  String? validateStep(int step) {
    switch (step) {
      case 0:
        if (_isShare) {
          final costError = _validateSharedCosts();
          if (costError != null) {
            setState(() => _sharedCostsShowErrors = true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final ctx = _sharedCostsSectionKey.currentContext;
              if (ctx != null) {
                Scrollable.ensureVisible(
                  ctx,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOut,
                  alignment: 0.2,
                );
              }
            });
            return costError;
          }
          setState(() => _sharedCostsShowErrors = false);
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
        if (_availableFrom == null) {
          return _agreementType == ListingAgreementType.temporary
              ? 'Pick an available-from date for temporary stays.'
              : 'Pick an available-from date for this long-term listing.';
        }
        if (_subletDurationController.text.trim().isEmpty) {
          return _agreementType == ListingAgreementType.temporary
              ? 'Enter an estimated sublet duration.'
              : 'Enter the lease duration in years.';
        }
        if (!_isShare) {
          if (_bedrooms < 1) return 'Enter the number of bedrooms.';
          if (_bathrooms < 1) return 'Enter the number of bathrooms.';
        }
        return null;
      case 1:
        final locationError = _validateStep2();
        if (locationError != null) {
          setState(() => _locationShowErrors = true);
          return locationError;
        }
        setState(() => _locationShowErrors = false);
        return null;
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
        if (_isShare) {
          if (_sharedRoomSlots.isEmpty) {
            return 'Add at least one room to share.';
          }
          if (_householdCohort == null) {
            return 'Select who lives in the household.';
          }
          if (_hasSharedBedRoom && _flatmateCohort == null) {
            return 'Select the shared room cohort profile.';
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
      price: stripThousandsFormatting(_rentController.text.trim()),
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
      'hostCity': _resolvedHostCityForMatching(hostFields),
      if (_listingAreaKey != null) 'listing_area_key': _listingAreaKey,
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
      ListingCreationFieldKeys.secureBikeStorage: _secureBikeStorage,
      'description_is_edited': !_isAutoDraftedDescription(),
      'description_auto_drafted': _isAutoDraftedDescription(),
      'listing_strength_score':
          ListingStrengthCalculator.fromListing(_listingPreviewSnapshot()).scorePercent,
    };

    if (_availableFrom != null &&
        _subletDurationController.text.trim().isNotEmpty) {
      payload['available_from'] = _availableFrom!.toIso8601String();
      payload[ListingCreationFieldKeys.availabilityFlexibility] =
          _availabilityFlexibility.storageToken;
      payload['sublet_duration_value'] = _subletDurationController.text.trim();
      payload['sublet_duration_unit'] =
          _agreementType == ListingAgreementType.longTerm
              ? SubletDurationUnit.years.name
              : _subletDurationUnit.name;
    }

    if (!_isShare) {
      payload['bedrooms'] = '$_bedrooms bed';
      payload['bathrooms'] = '$_bathrooms';
    } else {
      payload.addAll({
        'rooms_to_share': _roomsToShare,
        'shared_rooms': _sharedRoomSlots
            .map((s) {
              s.tenantsInRoom = _housemateCount;
              return s.toJson();
            })
            .toList(),
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

  String _costValue(TextEditingController controller, bool included) {
    if (included) return '0';
    return controller.text.trim();
  }

  bool _isSharedCostResolved(TextEditingController controller, bool included) {
    if (included) return true;
    final raw = controller.text.trim();
    if (raw.isEmpty) return false;
    return int.tryParse(raw.replaceAll(RegExp(r'[^\d]'), '')) != null;
  }

  String? _validateSharedCosts() {
    if (!_isShare) return null;
    final resolved = [
      _isSharedCostResolved(_electricityCostController, _electricityIncluded),
      _isSharedCostResolved(_binsCostController, _binsIncluded),
      _isSharedCostResolved(_internetCostController, _internetIncluded),
    ];
    if (resolved.every((v) => v)) return null;
    return 'Enter monthly shared costs or mark each as included in rent.';
  }

  Map<String, dynamic> _listingPreviewSnapshot() {
    return {
      'title': _titleController.text.trim(),
      'price': _formattedPrice(),
      'location': _effectiveLocationLabel(),
      'description': _descriptionController.text.trim(),
      'description_is_edited': !_isAutoDraftedDescription(),
      'description_auto_drafted': _isAutoDraftedDescription(),
      ListingCreationFieldKeys.secureBikeStorage: _secureBikeStorage,
      'ber_rating': _berRating,
      'images': _images,
      'rtb_registered': false,
      'parking_available': false,
      'furnishing': _isFurnished ? 'Furnished' : 'Unfurnished',
    };
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
    _proximityDraft.secondarySchool = '';
    _proximityDraft.crecheName = '';
    _proximityDraft.crecheWalkMin = 0;
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
    }
    if (resolved.secondarySchool != null) {
      _secondarySchoolController.text = resolved.secondarySchool!;
      _proximityDraft.secondarySchool = resolved.secondarySchool!;
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
    if (resolved.collegeSchool != null) {
      _collegeSchool = resolved.collegeSchool!;
      _collegeWalkMin = resolved.collegeWalkMin;
    }
    if (resolved.gpClinic != null) {
      _gpClinic = resolved.gpClinic!;
      _gpWalkMin = resolved.gpWalkMin;
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

    final cached = ProximityResolutionCache.getProximity(cellKey);
    if (cached != null) {
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

  void _handleNext() {
    if (widget.saving) return;
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
    setState(() => _currentStep = nextStep);
    _onStepActivated(nextStep);
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
            : _rentSectionKey,
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
    setState(() {
      _fetchingLocation = true;
      _locationPrefillLocked = false;
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
    final maxContentWidth = _currentStep == 1
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
                onStepTap: widget.saving ? null : _goToWizardStep,
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: PageView(
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
        _listingTypeSection(),
        const SizedBox(height: listingFieldSpacing),
        _propertyTypeSection(),
        if (!_isShare) ...[
          const SizedBox(height: listingFieldSpacing),
          _bedroomsBathroomsSection(),
        ],
        const SizedBox(height: listingFieldSpacing),
        _monthlyRentSection(),
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

  Widget _step2Content() {
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
          onChanged: (v) => setState(() {
            _agreementType = v;
            if (v == ListingAgreementType.longTerm) {
              _subletDurationUnit = SubletDurationUnit.years;
            }
          }),
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
                      for (final flex in LandlordAvailabilityFlexibility.values)
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
      child: _agreementType == ListingAgreementType.longTerm
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

  String _roomArchDisplayLabel(SharedRoomArchitecture arch) =>
      '${arch.tileEmoji} ${arch.tileLabel}';

  String _roomArchSummary(SharedRoomArchitecture arch) => arch.tileLabel;

  Widget _roomTypeSelector(SharedRoomSlot slot) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 360;
        final options = SharedRoomArchitecture.values;

        Widget tile(SharedRoomArchitecture arch, {bool fullWidth = false}) {
          final child = ListingOutlineChoiceTile(
            label: _roomArchDisplayLabel(arch),
            selected: slot.architecture == arch,
            enabled: !widget.saving,
            height: listingFieldHeight,
            textAlign: TextAlign.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            onTap: () => setState(() => slot.architecture = arch),
          );
          return fullWidth ? child : Expanded(child: child);
        }

        if (!narrow) {
          return Row(
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                tile(options[i]),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                tile(SharedRoomArchitecture.privateSharedBath),
                const SizedBox(width: 8),
                tile(SharedRoomArchitecture.privateEnsuite),
              ],
            ),
            const SizedBox(height: 8),
            tile(SharedRoomArchitecture.sharedBed, fullWidth: true),
          ],
        );
      },
    );
  }

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
                  _roomTypeSelector(slot),
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
                    emojis: const {
                      TargetTenantPreference.femaleOnly: '👩',
                      TargetTenantPreference.maleOnly: '👨',
                      TargetTenantPreference.mixed: '👥',
                    },
                  ),
                  if (slot.isSharedBed) ...[
                    const SizedBox(height: listingFieldSpacing),
                    ListingCompactCounter(
                      label: 'Sharing this room',
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
                    const SizedBox(height: 6),
                    const Text(
                      'How many people will share this room — including the new tenant.',
                      style: listingOptionHintStyle,
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
          required: true,
        ),
        if (_sharedProfilePrefillLocked)
          _inheritedSummaryCard(
            title: 'Household profile inherited',
            subtitle:
                'Using your onboarding host profile as the starting point for this listing.',
            lines: [
              'Total housemates in house: $_housemateCount',
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
            emojis: _cohortEmojis,
            segments: {
              for (final c in FlatmateCohort.values)
                c: _cohortSegmentLabels[c] ?? c.label,
            },
          ),
          const SizedBox(height: listingFieldSpacing),
          ListingCompactCounter(
            label: 'Total housemates in house',
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
          const SizedBox(height: 6),
          const Text(
            'Everyone currently living in the property — set once for the whole household.',
            style: listingOptionHintStyle,
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
          Text('Shared room cohort profile', style: listingFieldLabelStyle),
          const SizedBox(height: 6),
          const Text(
            'Only applies to rooms with a shared room in shared occupancy.',
            style: listingOptionHintStyle,
          ),
          const SizedBox(height: listingLabelSpacing),
          ListingWrapSegmentedControl<FlatmateCohort>(
            enabled: !widget.saving,
            selected: _flatmateCohort ?? FlatmateCohort.mixedCohort,
            onChanged: (v) => setState(() => _flatmateCohort = v),
            emojis: _cohortEmojis,
            segments: {
              for (final c in FlatmateCohort.values)
                c: _cohortSegmentLabels[c] ?? c.label,
            },
          ),
        ],
      ],
    );
  }

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
        else
          ListingDaftRadioChoiceList<bool>(
            enabled: !widget.saving,
            selected: _isShare,
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
        ListingDaftRadioChoiceList<ListingPropertySubType>(
          enabled: !widget.saving,
          selected: _propertySubType,
          onChanged: (v) => setState(() {
            _propertySubType = v;
            if (v == ListingPropertySubType.house) {
              _secureBikeStorage = false;
            }
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
        const SizedBox(width: listingFieldSpacing),
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

  Widget _berRatingSection() {
    return ListingBerRatingField(
      value: _berRating,
      enabled: !widget.saving,
      ratings: ListingCreationFormConstants.berRatings,
      onChanged: (v) => setState(() => _berRating = v),
    );
  }

  Widget _propertyHighlightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListingSectionHeader(
          title: 'Property highlights',
          subtitle: 'Optional features shown on your public listing preview.',
        ),
        if (_propertySubType == ListingPropertySubType.apartment)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _secureBikeStorage,
            onChanged: widget.saving
                ? null
                : (value) => setState(() => _secureBikeStorage = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Secure Bike Parking Available',
              style: listingFieldValueStyle,
            ),
            subtitle: const Text(
              'Shown when your building offers secure bicycle storage.',
              style: listingFormHelperStyle,
            ),
            activeColor: const Color(0xFF4B5563),
            checkColor: Colors.white,
            side: const BorderSide(color: Color(0xFF9CA3AF), width: 1.2),
          ),
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
    final addressInvalid = _locationShowErrors &&
        _locationIdentifierController.text.trim().length < 3;
    // Material (not Container/DecoratedBox fill) so CheckboxListTile ink stays visible.
    return Material(
      key: _locationPanelKey,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: addressInvalid
              ? const Color(0xFFEF4444)
              : const Color(0xFFE5E7EB),
          width: addressInvalid ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          listingFieldLabel('Resolved address', required: true),
          const SizedBox(height: 6),
          const Text(
            'Street or building name for your listing. Seeker area matching uses Property area below.',
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
              hint: 'Street or building address',
            ).copyWith(
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: addressInvalid
                      ? const Color(0xFFEF4444)
                      : listingDaftBorderColor,
                  width: addressInvalid ? 1.5 : listingDaftBorderWidth,
                ),
              ),
            ),
            onChanged: (_) => setState(() {
              if (_locationShowErrors) _locationShowErrors = false;
            }),
          ),
          if (addressInvalid) ...[
            const SizedBox(height: 4),
            const Text(
              'Required — confirm or edit the resolved address.',
              style: TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
            ),
          ],
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
                : (v) => setState(() => _hideExactAddress = v ?? false),
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
          label: _petsAllowed ? 'Pets welcome' : 'No pets',
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
                active: !_petsAllowed,
                enabled: !widget.saving,
                emoji: '🚫',
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
