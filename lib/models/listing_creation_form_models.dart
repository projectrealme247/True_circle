import 'neighborhood_amenity_tag.dart';
import '../services/overpass_amenities_service.dart';

/// Extended Dublin listing creation enums and constants.
///
/// Lease / tenure uses [TenurePreference] (seeker_onboarding_enums.dart) —
/// do not reintroduce a parallel agreement-type enum.
enum ListingPropertySubType { apartment, house }

/// Independent Place listing pets policy.
enum ListingPetsPolicy {
  allowed('allowed', 'Allowed'),
  notAllowed('not_allowed', 'Not Allowed'),
  caseByCase('case_by_case', 'Case-by-Case');

  const ListingPetsPolicy(this.storageToken, this.label);
  final String storageToken;
  final String label;

  static const listingKey = 'pets_policy';

  static ListingPetsPolicy? fromStorage(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'allowed' || 'pets_welcome' || 'true' => allowed,
      'not_allowed' || 'no_pets' || 'false' => notAllowed,
      'case_by_case' || 'case-by-case' => caseByCase,
      _ => null,
    };
  }
}

/// Shared Spaces smoking policy — matching field.
enum ListingSmokingPolicy {
  noSmoking('no_smoking', 'No Smoking'),
  outdoorOnly('outdoor_only', 'Outdoor Smoking Only'),
  smokingAllowed('smoking_allowed', 'Smoking Allowed');

  const ListingSmokingPolicy(this.storageToken, this.label);
  final String storageToken;
  final String label;

  static const listingKey = 'smoking_policy';

  static ListingSmokingPolicy? fromStorage(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'no_smoking' || 'false' || 'not_allowed' => noSmoking,
      'outdoor_only' || 'outdoor' => outdoorOnly,
      'smoking_allowed' || 'allowed' || 'true' => smokingAllowed,
      _ => null,
    };
  }

  bool get allowsIndoorSmoking => this == smokingAllowed;
}

/// Multi-select parking features — branched by [ListingPropertySubType].
///
/// Empty selection means no parking available. Legacy single [parking_type]
/// tokens still parse via [fromStorage] / [parseFeatures].
enum ListingParkingFeature {
  onStreet('on_street', 'On Street'),
  driveway('driveway', 'Driveway'),
  garage('garage', 'Garage'),
  bikeParking('bike_parking', 'Secure Bike Parking'),
  residentCar('resident_car', 'Resident Car Parking');

  const ListingParkingFeature(this.storageToken, this.label);
  final String storageToken;
  final String label;

  static const listingKey = 'parking_features';
  static const legacyTypeKey = 'parking_type';

  static List<ListingParkingFeature> optionsFor(ListingPropertySubType subType) {
    return switch (subType) {
      ListingPropertySubType.house => const [
          onStreet,
          driveway,
          garage,
        ],
      ListingPropertySubType.apartment => const [
          bikeParking,
          residentCar,
        ],
    };
  }

  static ListingParkingFeature? fromStorage(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'on_street' || 'paid_on_street_parking' => onStreet,
      'driveway' || 'free_dedicated_parking' => driveway,
      'garage' => garage,
      'bike_parking' || 'secure_bike_parking' => bikeParking,
      'resident_car' || 'resident_car_parking' => residentCar,
      'not_available' || 'no_parking' || '' => null,
      _ => null,
    };
  }

  /// Parses `parking_features` list and/or legacy single `parking_type`.
  static Set<ListingParkingFeature> parseFeatures(Map<String, dynamic> item) {
    final out = <ListingParkingFeature>{};
    final rawList = item[listingKey] ?? item['parking_features'];
    if (rawList is List) {
      for (final entry in rawList) {
        final feature = fromStorage(entry?.toString());
        if (feature != null) out.add(feature);
      }
    }
    if (out.isEmpty) {
      final legacy = fromStorage(item[legacyTypeKey]?.toString());
      if (legacy != null) out.add(legacy);
    }
    return out;
  }

  bool get isBike => this == bikeParking;
}

enum SharedRoomArchitecture {
  privateSharedBath('private_shared_bath', '🛏️ Private Room with Shared Bathroom'),
  privateEnsuite('private_ensuite', '🚿 Private Room with Ensuite'),
  sharedBed('shared_bed', '👥 Shared Room in Shared Occupancy');

  const SharedRoomArchitecture(this.storageValue, this.label);
  final String storageValue;
  final String label;

  String get tileLabel => switch (this) {
        SharedRoomArchitecture.privateSharedBath => 'Private + shared bath',
        SharedRoomArchitecture.privateEnsuite => 'Private ensuite',
        SharedRoomArchitecture.sharedBed => 'Shared room',
      };

  String get tileEmoji => switch (this) {
        SharedRoomArchitecture.privateSharedBath => '🛏️',
        SharedRoomArchitecture.privateEnsuite => '🚿',
        SharedRoomArchitecture.sharedBed => '👥',
      };
}

/// Spec room type — matching input (Private / Shared).
enum SharedRoomKind {
  privateRoom('private_room', 'Private Room'),
  sharedRoom('shared_room', 'Shared Room');

  const SharedRoomKind(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static SharedRoomKind? fromStorage(String? raw) {
    final token = raw?.trim().toLowerCase() ?? '';
    return switch (token) {
      'private_room' || 'private' => privateRoom,
      'shared_room' || 'shared' || 'shared_bed' || 'bed_shared' => sharedRoom,
      _ => null,
    };
  }
}

/// Bathroom type — independent of [SharedRoomKind].
enum SharedBathroomType {
  privateEnsuite('private_ensuite', 'Private Ensuite'),
  sharedBathroom('shared_bathroom', 'Shared Bathroom');

  const SharedBathroomType(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static SharedBathroomType? fromStorage(String? raw) {
    final token = raw?.trim().toLowerCase() ?? '';
    return switch (token) {
      'private_ensuite' || 'ensuite' => privateEnsuite,
      'shared_bathroom' || 'shared_bath' || 'private_shared_bath' ||
      'private_bath' =>
        sharedBathroom,
      _ => null,
    };
  }
}

enum FlatmateCohort {
  workingProfessionals('working_professionals', 'Working Professionals'),
  students('students', 'Students'),
  mixedCohort('mixed_cohort', 'Mixed'),
  /// Legacy — not offered in Shared Spaces landlord onboarding.
  families('families', 'Families');

  const FlatmateCohort(this.storageValue, this.label);
  final String storageValue;
  final String label;

  /// Shared Spaces household / room profile options (no Families).
  static const sharedSpacesValues = <FlatmateCohort>[
    workingProfessionals,
    students,
    mixedCohort,
  ];

  String get emoji => switch (this) {
        FlatmateCohort.workingProfessionals => '💼',
        FlatmateCohort.students => '🎓',
        FlatmateCohort.mixedCohort => '👥',
        FlatmateCohort.families => '👨‍👩‍👧',
      };
}

enum TargetTenantPreference {
  femaleOnly('female_only', 'Female only'),
  maleOnly('male_only', 'Male only'),
  mixed('mixed', 'Mixed'),
  noPreference('no_preference', 'No preference');

  const TargetTenantPreference(this.storageValue, this.label);
  final String storageValue;
  final String label;

  String get emoji => switch (this) {
        TargetTenantPreference.femaleOnly => '👩',
        TargetTenantPreference.maleOnly => '👨',
        TargetTenantPreference.mixed => '👥',
        TargetTenantPreference.noPreference => '🙂',
      };
}

/// Current occupant gender in a shared room (matching context).
enum RoomOccupantGender {
  male('male', 'Male'),
  female('female', 'Female');

  const RoomOccupantGender(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static RoomOccupantGender? fromStorage(String? raw) {
    final token = raw?.trim().toLowerCase() ?? '';
    return switch (token) {
      'male' || 'male_only' || 'boys' => male,
      'female' || 'female_only' || 'girls' => female,
      _ => null,
    };
  }
}

/// Required occupant preference — matching input.
enum RoomRequiredOccupant {
  male('male', 'Male'),
  female('female', 'Female'),
  noPreference('no_preference', 'No Preference');

  const RoomRequiredOccupant(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static RoomRequiredOccupant? fromStorage(String? raw) {
    final token = raw?.trim().toLowerCase() ?? '';
    return switch (token) {
      'male' || 'male_only' => male,
      'female' || 'female_only' => female,
      'no_preference' || 'mixed' || '' => noPreference,
      _ => null,
    };
  }

  TargetTenantPreference get asTargetTenantPreference => switch (this) {
        male => TargetTenantPreference.maleOnly,
        female => TargetTenantPreference.femaleOnly,
        noPreference => TargetTenantPreference.noPreference,
      };
}

/// Occupant type preference — matching input.
enum RoomOccupantType {
  workingProfessional('working_professional', 'Working Professional'),
  student('student', 'Student'),
  noPreference('no_preference', 'No Preference');

  const RoomOccupantType(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static RoomOccupantType? fromStorage(String? raw) {
    final token = raw?.trim().toLowerCase() ?? '';
    return switch (token) {
      'working_professional' ||
      'working_professionals' ||
      'professionals' =>
        workingProfessional,
      'student' || 'students' => student,
      'no_preference' || 'mixed' || 'mixed_cohort' || '' => noPreference,
      _ => null,
    };
  }
}

/// House rules — description generation only (not matching).
enum SharedHouseRule {
  noOvernightGuests('no_overnight_guests', 'No Overnight Guests'),
  quietHours('quiet_hours', 'Quiet Hours'),
  noParties('no_parties', 'No Parties'),
  noAlcohol('no_alcohol', 'No Alcohol'),
  keepSharedAreasClean('keep_shared_areas_clean', 'Keep Shared Areas Clean');

  const SharedHouseRule(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static SharedHouseRule? fromStorage(String? raw) {
    final token = raw?.trim().toLowerCase() ?? '';
    for (final rule in values) {
      if (rule.storageValue == token) return rule;
    }
    return null;
  }
}

/// One room offered in a shared listing (inventory + matching unit).
class SharedRoomSlot {
  SharedRoomSlot({
    SharedRoomKind? roomKind,
    SharedBathroomType? bathroomType,
    SharedRoomArchitecture? architecture,
    this.tenantsInRoom = 1,
    this.tenantGender = TargetTenantPreference.noPreference,
    this.bedOccupants = 2,
    this.roomProfile,
    this.currentOccupant,
    this.requiredOccupant = RoomRequiredOccupant.noPreference,
    this.occupantType = RoomOccupantType.noPreference,
    this.agreementTypeToken,
    this.availableFrom,
    this.availabilityFlexibilityToken,
    this.temporaryDurationValue = '',
    this.temporaryDurationUnit = SubletDurationUnit.months,
    this.electricityIncluded = false,
    this.binsIncluded = false,
    this.internetIncluded = false,
    this.monthlyRent = '',
    this.electricityCost = '',
    this.binsCost = '',
    this.internetCost = '',
    this.title = '',
    this.description = '',
    List<String>? images,
  })  : roomKind = roomKind ??
            _kindFromArchitecture(
              architecture ?? SharedRoomArchitecture.privateSharedBath,
            ),
        bathroomType = bathroomType ??
            _bathFromArchitecture(
              architecture ?? SharedRoomArchitecture.privateSharedBath,
            ),
        images = images ?? [];

  SharedRoomKind roomKind;
  SharedBathroomType bathroomType;
  int tenantsInRoom;
  TargetTenantPreference tenantGender;
  int bedOccupants;
  FlatmateCohort? roomProfile;
  RoomOccupantGender? currentOccupant;
  RoomRequiredOccupant requiredOccupant;
  RoomOccupantType occupantType;
  // Inventory (used when rooms available > 1; mirrored from listing when = 1)
  String monthlyRent;
  String electricityCost;
  String binsCost;
  String internetCost;
  bool electricityIncluded;
  bool binsIncluded;
  bool internetIncluded;
  /// [TenurePreference.storageToken]
  String? agreementTypeToken;
  DateTime? availableFrom;
  /// [LandlordAvailabilityFlexibility.storageToken]
  String? availabilityFlexibilityToken;
  String temporaryDurationValue;
  SubletDurationUnit temporaryDurationUnit;
  List<String> images;
  String title;
  String description;

  /// Legacy combined architecture derived from kind + bathroom.
  SharedRoomArchitecture get architecture {
    if (roomKind == SharedRoomKind.sharedRoom) {
      return SharedRoomArchitecture.sharedBed;
    }
    return bathroomType == SharedBathroomType.privateEnsuite
        ? SharedRoomArchitecture.privateEnsuite
        : SharedRoomArchitecture.privateSharedBath;
  }

  set architecture(SharedRoomArchitecture value) {
    roomKind = _kindFromArchitecture(value);
    bathroomType = _bathFromArchitecture(value);
  }

  bool get isSharedBed => roomKind == SharedRoomKind.sharedRoom;

  static SharedRoomKind _kindFromArchitecture(SharedRoomArchitecture arch) {
    return arch == SharedRoomArchitecture.sharedBed
        ? SharedRoomKind.sharedRoom
        : SharedRoomKind.privateRoom;
  }

  static SharedBathroomType _bathFromArchitecture(SharedRoomArchitecture arch) {
    return arch == SharedRoomArchitecture.privateEnsuite
        ? SharedBathroomType.privateEnsuite
        : SharedBathroomType.sharedBathroom;
  }

  Map<String, dynamic> toJson() => {
        'architecture': architecture.storageValue,
        'room_type': roomKind.storageValue,
        'bathroom_type': bathroomType.storageValue,
        'tenants_in_room': tenantsInRoom,
        'tenant_gender': requiredOccupant.asTargetTenantPreference.storageValue,
        'required_occupant': requiredOccupant.storageValue,
        'occupant_type': occupantType.storageValue,
        if (currentOccupant != null)
          'current_occupant': currentOccupant!.storageValue,
        if (roomProfile != null) 'room_profile': roomProfile!.storageValue,
        if (isSharedBed) 'bed_occupants': bedOccupants,
        if (monthlyRent.trim().isNotEmpty) 'monthly_rent': monthlyRent.trim(),
        'monthly_electricity_cost':
            electricityIncluded ? '0' : electricityCost.trim(),
        'monthly_bins_cost': binsIncluded ? '0' : binsCost.trim(),
        'monthly_internet_cost': internetIncluded ? '0' : internetCost.trim(),
        'electricity_included': electricityIncluded,
        'bins_included': binsIncluded,
        'internet_included': internetIncluded,
        if (agreementTypeToken != null && agreementTypeToken!.isNotEmpty)
          'agreement_type': agreementTypeToken,
        if (availableFrom != null)
          'available_from': availableFrom!.toIso8601String(),
        if (availabilityFlexibilityToken != null &&
            availabilityFlexibilityToken!.isNotEmpty)
          'availability_flexibility': availabilityFlexibilityToken,
        if (temporaryDurationValue.trim().isNotEmpty) ...{
          'temporary_duration_value': temporaryDurationValue.trim(),
          'sublet_duration_value': temporaryDurationValue.trim(),
          'temporary_duration_unit': temporaryDurationUnit.name,
          'sublet_duration_unit': temporaryDurationUnit.name,
        },
        if (images.isNotEmpty) 'images': images,
        if (title.trim().isNotEmpty) 'title': title.trim(),
        if (description.trim().isNotEmpty) 'description': description.trim(),
      };

  static SharedRoomSlot fromJson(Map<String, dynamic> raw) {
    final archRaw = raw['architecture']?.toString() ?? '';
    final arch = SharedRoomArchitecture.values.firstWhere(
      (a) => a.storageValue == archRaw,
      orElse: () => SharedRoomArchitecture.privateSharedBath,
    );
    final kind = SharedRoomKind.fromStorage(raw['room_type']?.toString()) ??
        _kindFromArchitecture(arch);
    final bath =
        SharedBathroomType.fromStorage(raw['bathroom_type']?.toString()) ??
            _bathFromArchitecture(arch);
    final genderRaw = raw['tenant_gender']?.toString() ?? '';
    final required = RoomRequiredOccupant.fromStorage(
          raw['required_occupant']?.toString(),
        ) ??
        _requiredFromLegacyGender(genderRaw);
    final profileRaw = raw['room_profile']?.toString() ?? '';
    FlatmateCohort? profile;
    for (final c in FlatmateCohort.sharedSpacesValues) {
      if (c.storageValue == profileRaw) {
        profile = c;
        break;
      }
    }
    final availableRaw = raw['available_from']?.toString();
    final imagesRaw = raw['images'];
    return SharedRoomSlot(
      roomKind: kind,
      bathroomType: bath,
      tenantsInRoom: (raw['tenants_in_room'] as num?)?.toInt().clamp(1, 6) ?? 1,
      tenantGender: TargetTenantPreference.values.firstWhere(
        (g) => g.storageValue == genderRaw,
        orElse: () => required.asTargetTenantPreference,
      ),
      bedOccupants: (raw['bed_occupants'] as num?)?.toInt().clamp(1, 6) ?? 2,
      roomProfile: profile,
      currentOccupant:
          RoomOccupantGender.fromStorage(raw['current_occupant']?.toString()),
      requiredOccupant: required,
      occupantType: RoomOccupantType.fromStorage(
            raw['occupant_type']?.toString(),
          ) ??
          RoomOccupantType.noPreference,
      agreementTypeToken: raw['agreement_type']?.toString(),
      availableFrom: availableRaw != null && availableRaw.isNotEmpty
          ? DateTime.tryParse(availableRaw)
          : null,
      availabilityFlexibilityToken:
          raw['availability_flexibility']?.toString(),
      temporaryDurationValue: (raw['temporary_duration_value'] ??
              raw['sublet_duration_value'])
          ?.toString() ??
          '',
      temporaryDurationUnit: _parseDurationUnit(
        (raw['temporary_duration_unit'] ?? raw['sublet_duration_unit'])
            ?.toString(),
      ),
      electricityIncluded: raw['electricity_included'] == true,
      binsIncluded: raw['bins_included'] == true,
      internetIncluded: raw['internet_included'] == true,
      monthlyRent: raw['monthly_rent']?.toString() ?? '',
      electricityCost: raw['monthly_electricity_cost']?.toString() ?? '',
      binsCost: raw['monthly_bins_cost']?.toString() ?? '',
      internetCost: raw['monthly_internet_cost']?.toString() ?? '',
      title: raw['title']?.toString() ?? '',
      description: raw['description']?.toString() ?? '',
      images: imagesRaw is List
          ? imagesRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : [],
    );
  }

  static RoomRequiredOccupant _requiredFromLegacyGender(String genderRaw) {
    return switch (genderRaw) {
      'male_only' => RoomRequiredOccupant.male,
      'female_only' => RoomRequiredOccupant.female,
      _ => RoomRequiredOccupant.noPreference,
    };
  }

  static SubletDurationUnit _parseDurationUnit(String? raw) {
    final token = raw?.trim().toLowerCase() ?? '';
    return SubletDurationUnit.values.firstWhere(
      (u) => u.name == token,
      orElse: () => SubletDurationUnit.months,
    );
  }
}

enum SubletDurationUnit { days, weeks, months, years }

enum ProximityPointCategory {
  transport('Transport', '🚇'),
  grocery('Grocery', '🛒'),
  school('School', '🏫'),
  amenity('Amenity', '📍');

  const ProximityPointCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}

class CustomProximityPoint {
  CustomProximityPoint({
    this.category = ProximityPointCategory.amenity,
    this.name = '',
    this.walkMin = 0,
  });

  ProximityPointCategory category;
  String name;
  int walkMin;

  Map<String, dynamic> toJson() => {
        'category': category.name,
        'name': name,
        'walk_min': walkMin,
      };

  static CustomProximityPoint fromJson(Map<String, dynamic> raw) {
    final categoryName = raw['category']?.toString() ?? '';
    return CustomProximityPoint(
      category: ProximityPointCategory.values.firstWhere(
        (c) => c.name == categoryName,
        orElse: () => ProximityPointCategory.amenity,
      ),
      name: raw['name']?.toString() ?? '',
      walkMin: (raw['walk_min'] as num?)?.toInt() ?? 0,
    );
  }
}

abstract final class ListingCreationFormConstants {
  static const berRatings = [
    'A1', 'A2', 'A3', 'B1', 'B2', 'B3', 'C1', 'C2', 'C3', 'D1', 'D2', 'E1', 'E2', 'F', 'G', 'Exempt',
  ];

  static const groceryBrands = [
    'Tesco', 'Dunnes', 'SuperValu', 'Lidl', 'Aldi', 'Spar', 'Centra',
  ];

  static const minPhotoCount = 3;
  static const sharedSpacesMinPhotoCount = 1;
  static const sharedSpacesMaxRooms = 10;
}

class NeighborhoodProximityDraft {
  NeighborhoodProximityDraft({
    this.transportLine = '',
    this.transportWalkMin = 0,
    this.groceryBrand = '',
    this.groceryWalkMin = 0,
    this.primarySchool = '',
    this.primarySchoolWalkMin = 0,
    this.secondarySchool = '',
    this.secondarySchoolWalkMin = 0,
    this.collegeSchool = '',
    this.collegeWalkMin = 0,
    this.crecheName = '',
    this.crecheWalkMin = 0,
    this.gpClinic = '',
    this.gpWalkMin = 0,
    this.manualEdit = false,
    List<NearbyGroceryOption>? groceries,
    List<NearbyExtraTransit>? extraTransit,
    List<NeighborhoodAmenityTag>? lifestyleTags,
    List<CustomProximityPoint>? customPoints,
    List<String>? hiddenChipKeys,
    List<String>? pinnedChipKeys,
  })  : groceries = groceries ?? [],
        extraTransit = extraTransit ?? [],
        lifestyleTags = lifestyleTags ?? [],
        customPoints = customPoints ?? [],
        hiddenChipKeys = hiddenChipKeys ?? [],
        pinnedChipKeys = pinnedChipKeys ?? [];

  String transportLine;
  int transportWalkMin;
  String groceryBrand;
  int groceryWalkMin;
  String primarySchool;
  int primarySchoolWalkMin;
  String secondarySchool;
  int secondarySchoolWalkMin;
  String collegeSchool;
  int collegeWalkMin;
  String crecheName;
  int crecheWalkMin;
  String gpClinic;
  int gpWalkMin;
  bool manualEdit;
  List<NearbyGroceryOption> groceries;
  List<NearbyExtraTransit> extraTransit;
  List<NeighborhoodAmenityTag> lifestyleTags;
  List<CustomProximityPoint> customPoints;

  /// Stable keys (`category|normalizedName`) for chips hidden from public display.
  List<String> hiddenChipKeys;

  /// Stable keys for chips pinned to the front of their section.
  List<String> pinnedChipKeys;

  Map<String, dynamic> toJson() => {
        'transport_line': transportLine,
        'transport_walk_min': transportWalkMin,
        'grocery_brand': groceryBrand,
        'grocery_walk_min': groceryWalkMin,
        'primary_school': primarySchool,
        'primary_school_walk_min': primarySchoolWalkMin,
        'secondary_school': secondarySchool,
        'secondary_school_walk_min': secondarySchoolWalkMin,
        'college_school': collegeSchool,
        'college_walk_min': collegeWalkMin,
        'creche_name': crecheName,
        'creche_walk_min': crecheWalkMin,
        'gp_clinic': gpClinic,
        'gp_walk_min': gpWalkMin,
        'manual_edit': manualEdit,
        'groceries': groceries.map((g) => g.toJson()).toList(),
        'extra_transit': extraTransit.map((t) => t.toJson()).toList(),
        'lifestyle_tags': lifestyleTags.map((t) => t.toJson()).toList(),
        'custom_points': customPoints.map((p) => p.toJson()).toList(),
        'hidden_chip_keys': hiddenChipKeys,
        'pinned_chip_keys': pinnedChipKeys,
      };

  static NeighborhoodProximityDraft fromJson(Map<String, dynamic>? raw) {
    if (raw == null) return NeighborhoodProximityDraft();
    return NeighborhoodProximityDraft(
      transportLine: raw['transport_line']?.toString() ?? '',
      transportWalkMin: (raw['transport_walk_min'] as num?)?.toInt() ?? 0,
      groceryBrand: raw['grocery_brand']?.toString() ?? 'Tesco',
      groceryWalkMin: (raw['grocery_walk_min'] as num?)?.toInt() ?? 0,
      primarySchool: raw['primary_school']?.toString() ?? '',
      primarySchoolWalkMin:
          (raw['primary_school_walk_min'] as num?)?.toInt() ?? 0,
      secondarySchool: raw['secondary_school']?.toString() ?? '',
      secondarySchoolWalkMin:
          (raw['secondary_school_walk_min'] as num?)?.toInt() ?? 0,
      collegeSchool: raw['college_school']?.toString() ??
          raw['college']?.toString() ??
          '',
      collegeWalkMin: (raw['college_walk_min'] as num?)?.toInt() ?? 0,
      crecheName: raw['creche_name']?.toString() ?? '',
      crecheWalkMin: (raw['creche_walk_min'] as num?)?.toInt() ?? 0,
      gpClinic: raw['gp_clinic']?.toString() ?? '',
      gpWalkMin: (raw['gp_walk_min'] as num?)?.toInt() ?? 0,
      manualEdit: raw['manual_edit'] == true,
      groceries: _groceries(raw['groceries']),
      extraTransit: _extraTransit(raw['extra_transit']),
      lifestyleTags: _lifestyleTags(raw['lifestyle_tags']),
      customPoints: (raw['custom_points'] as List?)
              ?.whereType<Map>()
              .map((e) => CustomProximityPoint.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList() ??
          [],
      hiddenChipKeys: _stringList(raw['hidden_chip_keys']),
      pinnedChipKeys: _stringList(raw['pinned_chip_keys']),
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return [];
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static List<NearbyGroceryOption> _groceries(Object? raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => NearbyGroceryOption.fromJson(Map<String, dynamic>.from(e)))
        .whereType<NearbyGroceryOption>()
        .toList();
  }

  static List<NearbyExtraTransit> _extraTransit(Object? raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => NearbyExtraTransit.fromJson(Map<String, dynamic>.from(e)))
        .whereType<NearbyExtraTransit>()
        .toList();
  }

  static List<NeighborhoodAmenityTag> _lifestyleTags(Object? raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map(
          (e) => NeighborhoodAmenityTag.fromJson(Map<String, dynamic>.from(e)),
        )
        .whereType<NeighborhoodAmenityTag>()
        .toList();
  }

  void toggleHiddenKey(String key) {
    if (key.isEmpty) return;
    if (hiddenChipKeys.contains(key)) {
      hiddenChipKeys = List<String>.from(hiddenChipKeys)..remove(key);
    } else {
      hiddenChipKeys = List<String>.from(hiddenChipKeys)..add(key);
    }
  }

  void togglePinnedKey(String key) {
    if (key.isEmpty) return;
    if (pinnedChipKeys.contains(key)) {
      pinnedChipKeys = List<String>.from(pinnedChipKeys)..remove(key);
    } else {
      pinnedChipKeys = List<String>.from(pinnedChipKeys)..add(key);
    }
  }
}
