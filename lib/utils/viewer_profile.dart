import 'profile_data.dart';

/// Trust verification stages for the progressive trust funnel.
enum TrustStage {
  anonymous(0, 0.4, 'Anonymous'),
  casual(1, 0.7, 'Casual Browser'),
  socialVerified(2, 0.9, 'Social Verified'),
  idVerified(3, 1.0, 'ID Verified');

  const TrustStage(this.level, this.multiplier, this.label);

  final int level;
  final double multiplier;
  final String label;

  static TrustStage fromLevel(int level) => switch (level) {
        0 => TrustStage.anonymous,
        1 => TrustStage.casual,
        2 => TrustStage.socialVerified,
        3 => TrustStage.idVerified,
        _ => TrustStage.anonymous,
      };
}

/// Normalized viewer profile used for tower-specific matching.
class ViewerProfile {
  const ViewerProfile({
    required this.city,
    required this.nativePlace,
    required this.motherTongue,
    required this.spokenLanguages,
    required this.foodPreference,
    required this.occupantType,
    required this.genderPreference,
    required this.studentType,
    required this.company,
    required this.jobTitle,
    required this.budgetMin,
    required this.budgetMax,
    required this.preferredPropertyType,
    required this.completenessPercent,
    required this.hasCompany,
    required this.trustStage,
    required this.circleMarkers,
    this.linkedinVerified = false,
    this.linkedinCompany = '',
    this.linkedinTitle = '',
    this.aadhaarVerified = false,
    this.passkeyBound = false,
    this.smokingOk = false,
    this.drinkingOk = false,
    this.scheduleType = '',
    this.familyAdults = 0,
    this.familyChildren = 0,
    this.childrenAges = const [],
    this.groupSize = 1,
  });

  final String city;
  final String nativePlace;
  final String motherTongue;
  final List<String> spokenLanguages;
  final String foodPreference;
  final String occupantType;
  final String genderPreference;
  final String studentType;
  final String company;
  final String jobTitle;
  final int? budgetMin;
  final int? budgetMax;
  final String preferredPropertyType;
  final int completenessPercent;
  final bool hasCompany;

  final TrustStage trustStage;
  final List<String> circleMarkers;
  final bool linkedinVerified;
  final String linkedinCompany;
  final String linkedinTitle;
  final bool aadhaarVerified;
  final bool passkeyBound;
  final bool smokingOk;
  final bool drinkingOk;
  final String scheduleType;
  final int familyAdults;
  final int familyChildren;
  final List<String> childrenAges;
  final int groupSize;

  static double trustMultiplierForStage(int stage) =>
      TrustStage.fromLevel(stage).multiplier;

  static ViewerProfile? fromSession(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return null;

    final city = ProfileData.text(raw['detected_city']);
    final nativePlace = ProfileData.text(raw['native_place']);
    final motherTongue = ProfileData.text(raw['mother_tongue']);
    final spoken = ProfileData.languageList(raw['spoken_languages']);
    final food = ProfileData.text(raw['food_preference']);
    final occupant = ProfileData.text(
      raw['occupant_type'] ?? raw['preferred_occupant_type'],
    );
    final gender = ProfileData.text(
      raw['gender_preference'] ?? raw['gender'],
    );
    final student = ProfileData.text(raw['student_type']);
    final company = ProfileData.text(raw['company']);
    final jobTitle = ProfileData.text(raw['job_title']);
    final preferredType = ProfileData.text(raw['preferred_property_type']);

    final budgetMin = _parseInt(raw['budget_min']);
    final budgetMax = _parseInt(raw['budget_max']);

    final completeness = _completenessPercent(raw);

    if (city.isEmpty &&
        motherTongue.isEmpty &&
        food.isEmpty &&
        occupant.isEmpty) {
      return null;
    }

    final trustStage = _resolveTrustStage(raw);
    final circleMarkers = _deriveCircleMarkers(
      motherTongue: motherTongue,
      food: food,
      city: city,
      nativePlace: nativePlace,
    );

    return ViewerProfile(
      city: city,
      nativePlace: nativePlace,
      motherTongue: motherTongue,
      spokenLanguages: spoken,
      foodPreference: food,
      occupantType: occupant,
      genderPreference: gender,
      studentType: student,
      company: company,
      jobTitle: jobTitle,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      preferredPropertyType: preferredType,
      completenessPercent: completeness,
      hasCompany: company.isNotEmpty,
      trustStage: trustStage,
      circleMarkers: circleMarkers,
      linkedinVerified: raw['linkedin_verified'] == true,
      linkedinCompany: ProfileData.text(raw['linkedin_company']),
      linkedinTitle: ProfileData.text(raw['linkedin_title']),
      aadhaarVerified: raw['is_aadhaar_verified'] == true,
      passkeyBound: ProfileData.text(raw['passkey_public_key']).isNotEmpty,
      smokingOk: raw['smoking_ok'] == true,
      drinkingOk: raw['drinking_ok'] == true,
      scheduleType: ProfileData.text(raw['schedule_type']),
      familyAdults: (raw['family_adults'] is int) ? raw['family_adults'] as int : 0,
      familyChildren: (raw['family_children'] is int) ? raw['family_children'] as int : 0,
      childrenAges: _parseChildrenAges(raw),
      groupSize: (raw['group_size'] is int) ? raw['group_size'] as int : 1,
    );
  }

  static List<String> _parseChildrenAges(Map<String, dynamic> raw) {
    final ages = raw['children_ages'];
    if (ages is List) return ages.map((e) => e.toString()).toList();
    final legacy = ProfileData.text(raw['children_age_range']);
    if (legacy.isEmpty) return const [];
    final count = (raw['family_children'] is int) ? raw['family_children'] as int : 1;
    return List.generate(count, (_) => legacy);
  }

  static TrustStage _resolveTrustStage(Map<String, dynamic> raw) {
    final explicit = raw['trust_stage'];
    if (explicit is int) return TrustStage.fromLevel(explicit);

    final tier = ProfileData.text(raw['identity_trust_tier']).toLowerCase();
    if (tier.contains('id_verified')) return TrustStage.idVerified;
    if (tier.contains('social_verified')) return TrustStage.socialVerified;
    if (tier.contains('casual')) return TrustStage.casual;

    final hasProfile = ProfileData.text(raw['full_name']).isNotEmpty &&
        ProfileData.text(raw['detected_city']).isNotEmpty;
    return hasProfile ? TrustStage.casual : TrustStage.anonymous;
  }

  /// Derive cultural markers for circle membership checks.
  static List<String> _deriveCircleMarkers({
    required String motherTongue,
    required String food,
    required String city,
    required String nativePlace,
  }) {
    final markers = <String>[];
    final mt = motherTongue.trim().toLowerCase();
    if (mt.isNotEmpty) markers.add(mt);

    final f = food.trim().toLowerCase();
    if (f.contains('veg') && !f.contains('non')) {
      markers.add('veg');
    } else if (f.contains('non')) {
      markers.add('non-veg');
    }

    final c = city.trim().toLowerCase().split(',').first.trim();
    if (c.isNotEmpty) markers.add(c);

    final np = nativePlace.trim().toLowerCase();
    if (np.isNotEmpty && np != c) markers.add(np);

    return markers;
  }

  /// Compute circle markers for a listing host from listing data.
  static List<String> circleMarkersForListing(Map<String, dynamic> listing) {
    final raw = listing['host_circle_markers'];
    if (raw is List) {
      return raw.map((e) => e.toString().trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
    }

    final motherTongue = ProfileData.text(
      listing['hostMotherTongue'] ?? listing['owner_mother_tongue'],
    );
    final food = ProfileData.text(
      listing['hostFoodPreference'] ?? listing['foodPreference'] ?? listing['owner_food_pref'],
    );
    final city = ProfileData.text(
      listing['hostCity'] ?? listing['owner_city'] ?? listing['location'],
    );

    return _deriveCircleMarkers(
      motherTongue: motherTongue,
      food: food,
      city: city,
      nativePlace: '',
    );
  }

  /// Check if a listing host is "in your circle":
  /// same trust level or higher AND shares at least one cultural marker.
  bool isInCircle(Map<String, dynamic> listing) {
    final hostTrust = _hostTrustStage(listing);
    if (hostTrust.level < trustStage.level) return false;

    final hostMarkers = circleMarkersForListing(listing);
    return circleMarkers.any((m) => hostMarkers.contains(m));
  }

  static TrustStage _hostTrustStage(Map<String, dynamic> listing) {
    final explicit = listing['host_trust_stage'];
    if (explicit is int) return TrustStage.fromLevel(explicit);
    if (listing['host_verified_badge'] == true) return TrustStage.idVerified;
    if (listing['host_linkedin_badge'] != null) return TrustStage.socialVerified;
    return TrustStage.casual;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    final digits = RegExp(r'\d+').stringMatch(value.toString().replaceAll(',', ''));
    if (digits == null) return null;
    return int.tryParse(digits);
  }

  static int _completenessPercent(Map<String, dynamic> raw) {
    const keys = [
      'full_name',
      'email',
      'detected_city',
      'native_place',
      'mother_tongue',
      'food_preference',
      'spoken_languages',
      'occupant_type',
      'gender_preference',
      'student_type',
      'company',
    ];
    var filled = 0;
    for (final key in keys) {
      final value = raw[key];
      if (value is List && value.isNotEmpty) {
        filled++;
      } else if (ProfileData.text(value).isNotEmpty) {
        filled++;
      }
    }
    return ((filled / keys.length) * 100).round();
  }
}
