/// Extended Dublin listing creation enums and constants.
enum ListingAgreementType { longTerm, temporary }

enum ListingPropertySubType { apartment, house }

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

enum FlatmateCohort {
  workingProfessionals('working_professionals', 'Working Professionals'),
  students('students', 'Students'),
  mixedCohort('mixed_cohort', 'Mixed Household'),
  families('families', 'Families');

  const FlatmateCohort(this.storageValue, this.label);
  final String storageValue;
  final String label;

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

/// One room offered in a shared listing.
class SharedRoomSlot {
  SharedRoomSlot({
    this.architecture = SharedRoomArchitecture.privateSharedBath,
    this.tenantsInRoom = 1,
    this.tenantGender = TargetTenantPreference.noPreference,
    this.bedOccupants = 2,
  });

  SharedRoomArchitecture architecture;
  int tenantsInRoom;
  TargetTenantPreference tenantGender;
  int bedOccupants;

  bool get isSharedBed => architecture == SharedRoomArchitecture.sharedBed;

  Map<String, dynamic> toJson() => {
        'architecture': architecture.storageValue,
        'tenants_in_room': tenantsInRoom,
        'tenant_gender': tenantGender.storageValue,
        if (isSharedBed) 'bed_occupants': bedOccupants,
      };

  static SharedRoomSlot fromJson(Map<String, dynamic> raw) {
    final archRaw = raw['architecture']?.toString() ?? '';
    final arch = SharedRoomArchitecture.values.firstWhere(
      (a) => a.storageValue == archRaw,
      orElse: () => SharedRoomArchitecture.privateSharedBath,
    );
    final genderRaw = raw['tenant_gender']?.toString() ?? '';
    return SharedRoomSlot(
      architecture: arch,
      tenantsInRoom: (raw['tenants_in_room'] as num?)?.toInt().clamp(1, 6) ?? 1,
      tenantGender: TargetTenantPreference.values.firstWhere(
        (g) => g.storageValue == genderRaw,
        orElse: () => TargetTenantPreference.noPreference,
      ),
      bedOccupants: (raw['bed_occupants'] as num?)?.toInt().clamp(1, 6) ?? 2,
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
}

class NeighborhoodProximityDraft {
  NeighborhoodProximityDraft({
    this.transportLine = '',
    this.transportWalkMin = 0,
    this.groceryBrand = '',
    this.groceryWalkMin = 0,
    this.primarySchool = '',
    this.secondarySchool = '',
    this.crecheName = '',
    this.crecheWalkMin = 0,
    this.manualEdit = false,
    List<CustomProximityPoint>? customPoints,
    List<String>? hiddenChipKeys,
    List<String>? pinnedChipKeys,
  })  : customPoints = customPoints ?? [],
        hiddenChipKeys = hiddenChipKeys ?? [],
        pinnedChipKeys = pinnedChipKeys ?? [];

  String transportLine;
  int transportWalkMin;
  String groceryBrand;
  int groceryWalkMin;
  String primarySchool;
  String secondarySchool;
  String crecheName;
  int crecheWalkMin;
  bool manualEdit;
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
        'secondary_school': secondarySchool,
        'creche_name': crecheName,
        'creche_walk_min': crecheWalkMin,
        'manual_edit': manualEdit,
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
      secondarySchool: raw['secondary_school']?.toString() ?? '',
      crecheName: raw['creche_name']?.toString() ?? '',
      crecheWalkMin: (raw['creche_walk_min'] as num?)?.toInt() ?? 0,
      manualEdit: raw['manual_edit'] == true,
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
