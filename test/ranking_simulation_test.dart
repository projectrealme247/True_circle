import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/sample_listings_dublin_v2.dart';
import 'package:true_circle/services/commute_scoring_service.dart';
import 'package:true_circle/utils/commute_profile.dart';
import 'package:true_circle/utils/listing_data.dart';
import 'package:true_circle/utils/listing_match_engine.dart';
import 'package:true_circle/utils/listing_search_intent.dart';
import 'package:true_circle/utils/marketplace_listing_pipeline.dart';
import 'package:true_circle/utils/viewer_profile.dart';
import 'package:true_circle/utils/weighted_listing_matcher.dart';

/// Ranking simulation after filter redesign — Dublin v2 seed, four personas.
void main() {
  test('ranking simulation — Dublin v2 personas (Rent + Share)', () {
    final allListings = SampleListingsDublinV2.items;
    final rentListings = [
      for (final l in allListings)
        if (ListingData.propertyType(l) == 'Rent') l,
    ];
    final shareListings = [
      for (final l in allListings)
        if (ListingData.propertyType(l) == 'Share') l,
    ];

    _printSection('WEIGHT FACTOR TABLES (max points per bucket, sum=100)');

    _printWeightTable('Independent Places (Rent) — default', _rentWeightsDefault);
    _printWeightTable('Independent Places (Rent) — Student', _rentWeightsStudent);
    _printWeightTable(
      'Independent Places (Rent) — Professional',
      _rentWeightsProfessional,
    );
    _printWeightTable('Independent Places (Rent) — Family', _rentWeightsFamily);

    _printWeightTable('Shared Living (Share) — default', _shareWeightsDefault);
    _printWeightTable('Shared Living (Share) — Student', _shareWeightsStudent);
    _printWeightTable(
      'Shared Living (Share) — Professional',
      _shareWeightsProfessional,
    );

    _printSection('POST-SCORE MULTIPLIERS & PENALTIES');
    // ignore: avoid_print
    print('Trust multiplier: avg(hostTrust, seekerTrust) applied to compatibility');
    // ignore: avoid_print
    print('Pre-arrival penalty: ×0.9 when listing prefers all-students track');
    // ignore: avoid_print
    print('Rent pet/smoking soft penalty: -15 when explicit listing conflict');
    // ignore: avoid_print
    print('Budget hard cap (both towers): exclude above 125% max budget');
    // ignore: avoid_print
    print('Budget stretch penalty (soft prefs): -15 above 110% max budget');

    for (final persona in _personas) {
      _runPersonaSimulation(
        persona: persona,
        rentListings: rentListings,
        shareListings: shareListings,
      );
    }

    _printDominanceAnalysis(rentListings, shareListings);
  });
}

// ── Persona definitions ────────────────────────────────────────────────────

class _Persona {
  const _Persona({
    required this.label,
    required this.session,
    required this.rentFilters,
    required this.shareFilters,
  });

  final String label;
  final Map<String, dynamic> session;
  final ListingSearchFilters rentFilters;
  final ListingSearchFilters shareFilters;
}

const _personas = [
  _Persona(
    label: 'Student',
    session: {
      'full_name': 'Niamh O\'Brien',
      'seeker_persona': 'student',
      'detected_city': 'Dublin',
      'mother_tongue': 'English',
      'spoken_languages': ['English'],
      'food_preference': 'Veg',
      'occupant_type': 'Students',
      'preferred_property_type': 'Share',
      'budget_max': 850,
      'trust_stage': 2,
      'pre_arrival_contact_ready': true,
      'gender_preference': 'girls',
      'commute_method': CommuteMethod.backendPublicTransportWalking,
      'commute_destination_hub_id': 'tcd',
      'commute_destination': 'Trinity College Dublin (TCD)',
      'destination_latitude': 53.3438,
      'destination_longitude': -6.2546,
      'maximum_commute_budget_minutes': 35,
      'earliest_move_in_date': '2026-09-01',
      'schedule_type': 'Day shift',
    },
    rentFilters: ListingSearchFilters(budgetMax: 850),
    shareFilters: ListingSearchFilters(
      budgetMax: 850,
      foodPreference: 'veg',
      occupantType: 'Students',
      genderPreference: 'girls',
    ),
  ),
  _Persona(
    label: 'Professional',
    session: {
      'full_name': 'James Kelly',
      'seeker_persona': 'professional',
      'detected_city': 'Dublin',
      'mother_tongue': 'English',
      'spoken_languages': ['English'],
      'food_preference': 'Veg',
      'occupant_type': 'Working Professionals',
      'preferred_property_type': 'Rent',
      'budget_max': 2200,
      'trust_stage': 3,
      'commute_method': CommuteMethod.backendPublicTransportWalking,
      'commute_destination_hub_id': 'sandyford',
      'commute_destination': 'Sandyford',
      'destination_latitude': 53.2775,
      'destination_longitude': -6.2040,
      'maximum_commute_budget_minutes': 40,
      'earliest_move_in_date': '2026-08-01',
      'schedule_type': 'Day shift',
    },
    rentFilters: ListingSearchFilters(budgetMax: 2200),
    shareFilters: ListingSearchFilters(
      budgetMax: 900,
      foodPreference: 'veg',
      occupantType: 'Working Professionals',
    ),
  ),
  _Persona(
    label: 'Family',
    session: {
      'full_name': 'Priya & Arjun Sharma',
      'seeker_persona': 'family',
      'detected_city': 'Dublin',
      'mother_tongue': 'English',
      'spoken_languages': ['English', 'Hindi'],
      'food_preference': 'Veg',
      'occupant_type': 'Family',
      'family_adults': 2,
      'family_children': 2,
      'preferred_property_type': 'Rent',
      'budget_max': 3200,
      'trust_stage': 2,
      'maximum_commute_budget_minutes': 50,
      'dual_commute_priority': 'balanced',
      'commute_profiles': [
        {
          'id': 'primary',
          'label': 'Southside Tech',
          'commute_method': CommuteMethod.backendPublicTransportWalking,
          'commute_destination_hub_id': 'sandyford',
        },
        {
          'id': 'partner',
          'label': 'Airport shift',
          'commute_method': CommuteMethod.backendPublicTransportWalking,
          'commute_destination_hub_id': 'dublin_airport',
        },
      ],
      'earliest_move_in_date': '2026-09-15',
    },
    rentFilters: ListingSearchFilters(budgetMax: 3200),
    shareFilters: ListingSearchFilters(budgetMax: 3200),
  ),
  _Persona(
    label: 'Relocating Professional',
    session: {
      'full_name': 'Ana Silva',
      'seeker_persona': 'relocating',
      'detected_city': 'Dublin',
      'mother_tongue': 'Portuguese',
      'spoken_languages': ['English', 'Portuguese'],
      'food_preference': 'Non-veg',
      'occupant_type': 'Working Professionals',
      'preferred_property_type': 'Rent',
      'budget_max': 1800,
      'trust_stage': 2,
      'pre_arrival_contact_ready': true,
      'pre_arrival_seeker': true,
      'has_verified_pre_arrival_docs': true,
      'commute_method': CommuteMethod.backendPublicTransportWalking,
      'commute_destination_hub_id': 'ifsc',
      'commute_destination': 'IFSC / Docklands',
      'destination_latitude': 53.3484,
      'destination_longitude': -6.2483,
      'maximum_commute_budget_minutes': 45,
      'earliest_move_in_date': '2026-10-01',
      'schedule_type': 'Flexible',
    },
    rentFilters: ListingSearchFilters(budgetMax: 1800),
    shareFilters: ListingSearchFilters(
      budgetMax: 900,
      occupantType: 'Working Professionals',
    ),
  ),
];

// ── Weight tables (mirrors listing_match_engine.dart _Rent/_ShareTowerWeights) ─

const _rentWeightsDefault = {
  'budget': 25,
  'bed_count': 20,
  'location_commute': 20,
  'timing': 15,
  'language': 10,
  'lifestyle': 10,
};

const _rentWeightsStudent = {
  'budget': 30,
  'bed_count': 15,
  'location_commute': 20,
  'timing': 20,
  'language': 10,
  'lifestyle': 5,
};

const _rentWeightsProfessional = {
  'budget': 20,
  'bed_count': 15,
  'location_commute': 25,
  'timing': 15,
  'language': 10,
  'lifestyle': 15,
};

const _rentWeightsFamily = {
  'budget': 25,
  'bed_count': 30,
  'location_commute': 20,
  'timing': 10,
  'language': 5,
  'lifestyle': 10,
};

const _shareWeightsDefault = {
  'language': 25,
  'diet': 20,
  'occupant': 20,
  'budget': 15,
  'lifestyle': 10,
  'timing': 10,
};

const _shareWeightsStudent = {
  'language': 30,
  'lifestyle': 20,
  'occupant': 20,
  'diet': 15,
  'budget': 10,
  'timing': 5,
};

const _shareWeightsProfessional = {
  'budget': 20,
  'occupant': 25,
  'lifestyle': 15,
  'language': 20,
  'diet': 15,
  'timing': 5,
};

Map<String, int> _rentWeightsForSession(Map<String, dynamic> session) {
  final occ = (session['occupant_type']?.toString() ?? '').toLowerCase();
  if (occ.contains('student')) return _rentWeightsStudent;
  if (occ.contains('working') || occ.contains('professional')) {
    return _rentWeightsProfessional;
  }
  if (occ.contains('family')) return _rentWeightsFamily;
  return _rentWeightsDefault;
}

Map<String, int> _shareWeightsForSession(Map<String, dynamic> session) {
  final occ = (session['occupant_type']?.toString() ?? '').toLowerCase();
  if (occ.contains('student')) return _shareWeightsStudent;
  if (occ.contains('working') || occ.contains('professional')) {
    return _shareWeightsProfessional;
  }
  return _shareWeightsDefault;
}

// ── Simulation runner ──────────────────────────────────────────────────────

void _runPersonaSimulation({
  required _Persona persona,
  required List<Map<String, dynamic>> rentListings,
  required List<Map<String, dynamic>> shareListings,
}) {
  _printSection('PERSONA: ${persona.label}');

  _simulateTower(
    persona: persona,
    tower: 'Rent',
    listings: rentListings,
    filters: persona.rentFilters,
  );

  if (persona.label != 'Family') {
    _simulateTower(
      persona: persona,
      tower: 'Share',
      listings: shareListings,
      filters: persona.shareFilters,
    );
  } else {
    // ignore: avoid_print
    print('\nShare tower: skipped (Family hard-excluded from Share inventory)\n');
  }
}

void _simulateTower({
  required _Persona persona,
  required String tower,
  required List<Map<String, dynamic>> listings,
  required ListingSearchFilters filters,
}) {
  final scoped = filters.scopedForTower(tower);
  final result = MarketplaceListingPipeline.runWithFilters(
    allListings: listings,
    towerPropertyType: tower,
    filters: scoped,
    userSession: persona.session,
  );

  // ignore: avoid_print
  print('\n--- $tower tower ---');
  // ignore: avoid_print
  print(
    'Pool: ${listings.length} seed → ${result.afterTower.length} tower → '
    '${result.afterFilters.length} after hard filters → '
    '${result.ranked.length} ranked',
  );
  // ignore: avoid_print
  print(
    'Active filters: budgetMax=${scoped.budgetMax}, '
    'food=${scoped.foodPreference}, occupant=${scoped.occupantType}, '
    'gender=${scoped.genderPreference}, languages=${scoped.householdLanguages}',
  );
  if (result.isCommuteDivergent) {
    // ignore: avoid_print
    print('⚠ Commute divergence flag: true');
  }

  final top = result.ranked.take(5).toList();
  if (top.isEmpty) {
    // ignore: avoid_print
    print('(no ranked results)');
    return;
  }

  final weights = tower == 'Rent'
      ? _rentWeightsForSession(persona.session)
      : _shareWeightsForSession(persona.session);

  for (var i = 0; i < top.length; i++) {
    final s = top[i];
    final id = s.listing['id'] ?? s.listing['title'];
    final title = ListingData.title(s.listing);
    final price = ListingData.price(s.listing);
    final m = s.match;
    final breakdown = tower == 'Rent'
        ? _estimateRentBreakdown(s.listing, persona.session, weights)
        : _estimateShareBreakdown(s.listing, persona.session, weights);

    // ignore: avoid_print
    print('\n#${i + 1} [$id] $title');
    // ignore: avoid_print
    print('   Price: $price | Final: ${m.score}/${m.maxScore} (${m.percentage.round()}%)');
    // ignore: avoid_print
    print('   Pref score: ${s.preferenceScore.toStringAsFixed(1)}');
    // ignore: avoid_print
    print('   Reasons: ${m.reasons.join(' · ')}');
    // ignore: avoid_print
    print('   Factor breakdown (raw compat, pre-trust):');
    for (final entry in breakdown.entries) {
      if (entry.value != 0) {
        // ignore: avoid_print
        print('     ${entry.key}: ${entry.value.toStringAsFixed(1)}');
      }
    }
    // ignore: avoid_print
    print('     raw_total: ${breakdown.values.fold<double>(0, (a, b) => a + b).toStringAsFixed(1)}');
  }
}

// ── Factor breakdown estimators (mirror listing_match_engine scoring) ──────

Map<String, double> _estimateRentBreakdown(
  Map<String, dynamic> listing,
  Map<String, dynamic> session,
  Map<String, int> weights,
) {
  final viewer = ViewerProfile.fromSession(session)!;
  final price = _parsePrice(ListingData.price(listing));
  final breakdown = <String, double>{};

  final priceFit = _priceFitRentShare(price, viewer);
  breakdown['budget'] = weights['budget']! *
      (priceFit ? 1.0 : _rentBudgetFitFraction(price, viewer.budgetMax));

  if (_bhkMatch(listing, viewer)) {
    breakdown['bed_count'] = weights['bed_count']!.toDouble();
  }

  breakdown['location_commute'] =
      weights['location_commute']! * _rentLocationCommuteFraction(session, listing);

  if (_timingMatch(viewer, listing)) {
    breakdown['timing'] = weights['timing']!.toDouble();
  }

  if (_languageMatch(listing, viewer)) {
    breakdown['language'] = weights['language']!.toDouble();
  }

  var lifestyleMatched = 0.0;
  if (_occupantMatch(listing, viewer)) lifestyleMatched += 1;
  if (_furnishingMatch(listing)) lifestyleMatched += 1;
  breakdown['lifestyle'] = weights['lifestyle']! * (lifestyleMatched / 2);

  if (_rentPetSmokingMismatch(viewer, listing)) {
    breakdown['pet_smoking_penalty'] = -15;
  }

  return breakdown;
}

Map<String, double> _estimateShareBreakdown(
  Map<String, dynamic> listing,
  Map<String, dynamic> session,
  Map<String, int> weights,
) {
  final viewer = ViewerProfile.fromSession(session)!;
  final price = _parsePrice(ListingData.price(listing));
  final breakdown = <String, double>{};

  if (_languageMatch(listing, viewer)) {
    breakdown['language'] = weights['language']!.toDouble();
  }

  if (_dietMatch(listing, viewer)) {
    breakdown['diet'] = weights['diet']!.toDouble();
  }

  if (_occupantMatch(listing, viewer) || _roommateTypeMatch(listing, viewer)) {
    breakdown['occupant'] = weights['occupant']!.toDouble();
  }

  breakdown['budget'] =
      weights['budget']! * _shareBudgetFitFraction(price, viewer.budgetMax);

  breakdown['lifestyle'] =
      weights['lifestyle']! * _shareLifestyleFraction(listing, viewer);

  if (_timingMatch(viewer, listing)) {
    breakdown['timing'] = weights['timing']!.toDouble();
  }

  return breakdown;
}

void _printDominanceAnalysis(
  List<Map<String, dynamic>> rentListings,
  List<Map<String, dynamic>> shareListings,
) {
  _printSection('DOMINANCE ANALYSIS (factor activation in top-5 vs pool)');

  for (final tower in ['Rent', 'Share']) {
    final listings = tower == 'Rent' ? rentListings : shareListings;
    final persona = tower == 'Rent' ? _personas[1] : _personas[0]; // Pro / Student
    final filters = tower == 'Rent' ? persona.rentFilters : persona.shareFilters;
    final result = MarketplaceListingPipeline.runWithFilters(
      allListings: listings,
      towerPropertyType: tower,
      filters: filters.scopedForTower(tower),
      userSession: persona.session,
    );
    final top5 = result.ranked.take(5).toList();
    final weights = tower == 'Rent'
        ? _rentWeightsForSession(persona.session)
        : _shareWeightsForSession(persona.session);

    final factorHits = <String, int>{};
    final factorPoints = <String, double>{};

    for (final s in top5) {
      final bd = tower == 'Rent'
          ? _estimateRentBreakdown(s.listing, persona.session, weights)
          : _estimateShareBreakdown(s.listing, persona.session, weights);
      for (final e in bd.entries) {
        if (e.value > 0) {
          factorHits[e.key] = (factorHits[e.key] ?? 0) + 1;
          factorPoints[e.key] = (factorPoints[e.key] ?? 0) + e.value;
        }
      }
    }

    // ignore: avoid_print
    print('\n$tower tower (${persona.label} persona, top-5 factor hits):');
    final sorted = factorPoints.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted) {
      // ignore: avoid_print
      print(
        '  ${e.key}: ${e.value.toStringAsFixed(0)} pts total '
        '(${factorHits[e.key] ?? 0}/5 listings)',
      );
    }
  }
}

void _printWeightTable(String label, Map<String, int> weights) {
  // ignore: avoid_print
  print('\n$label');
  final sorted = weights.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (var i = 0; i < sorted.length; i++) {
    // ignore: avoid_print
    print('  ${i + 1}. ${sorted[i].key}: ${sorted[i].value} pts');
  }
}

void _printSection(String title) {
  // ignore: avoid_print
  print('\n${'=' * 72}');
  // ignore: avoid_print
  print(title);
  // ignore: avoid_print
  print('=' * 72);
}

// ── Match helpers (subset of listing_match_engine private logic) ───────────

int? _parsePrice(String price) {
  final match = RegExp(r'[\d,]+').firstMatch(price);
  if (match == null) return null;
  return int.tryParse(match.group(0)!.replaceAll(',', ''));
}

bool _priceFitRentShare(int? price, ViewerProfile viewer) {
  if (price == null) return false;
  if (viewer.budgetMax != null && price <= viewer.budgetMax!) return true;
  return viewer.budgetMax == null;
}

double _rentBudgetFitFraction(int? price, int? budgetMax) {
  if (price == null || budgetMax == null) return 0;
  if (price <= budgetMax) return 1.0;
  final stretchStart = (budgetMax * 1.10).round();
  if (price <= stretchStart) return 0.5;
  final hardCap = (budgetMax * 1.25).round();
  if (price <= hardCap) return 0.2;
  return 0;
}

double _shareBudgetFitFraction(int? price, int? budgetMax) {
  if (price == null || budgetMax == null) return 0;
  if (price <= budgetMax) return 1.0;
  final stretchStart = (budgetMax * 1.10).round();
  if (price <= stretchStart) return 0.6;
  final hardCap = (budgetMax * 1.25).round();
  if (price <= hardCap) return 0.25;
  return 0;
}

double _rentLocationCommuteFraction(
  Map<String, dynamic> session,
  Map<String, dynamic> listing,
) {
  final viewer = ViewerProfile.fromSession(session);
  if (viewer == null || viewer.city.isEmpty) return 0;
  final loc = ListingData.location(listing).toLowerCase();
  final hostCity = ListingData.hostCity(listing).toLowerCase();
  final city = viewer.city.toLowerCase();
  final cityOk = loc.contains(city) || hostCity.contains(city);
  if (!cityOk) return 0;

  final hasCommute = session['maximum_commute_budget_minutes'] != null ||
      CommuteProfileRegistry.fromSession(session).isNotEmpty;
  if (!hasCommute) return 1.0;

  final penalty = _commuteOverBudgetPenalty(session, listing);
  if (penalty == 0) return 1.0;
  if (penalty >= 12) return 0.5;
  return 1.0;
}

int _commuteOverBudgetPenalty(
  Map<String, dynamic>? session,
  Map<String, dynamic> listing,
) {
  final property = ListingData.listingCoordinates(listing);
  if (property == null || session == null) return 0;

  final profiles = CommuteProfileRegistry.fromSession(session);
  if (profiles.length >= 2) {
    final payload = CommuteScoringService.calculateMultiCommuteMinutes(
      propertyLoc: property,
      profiles: profiles,
      parkingAvailable: ListingData.parkingAvailable(listing),
      dualCommutePriority: ListingData.dualCommutePriority(session),
      budgetForProfile: (profile, index) =>
          ListingData.commuteBudgetMinutesForProfile(profile, session),
    );
    final combined = payload.combinedCompatibilityScore;
    if (combined != null) return (100.0 - combined).round().clamp(0, 100);
  }

  final budget = session['maximum_commute_budget_minutes'] as int?;
  if (budget == null) return 0;
  final minutes = CommuteScoringService.calculateCommuteMinutesToHub(
    property,
    CommuteProfileRegistry.fromSession(session).first.hub,
    CommuteProfileRegistry.fromSession(session).first.method,
  );
  return CommuteScoringService.overBudgetScorePenalty(
    doorToDoorMinutes: minutes,
    budgetMinutes: budget,
  );
}

bool _bhkMatch(Map<String, dynamic> listing, ViewerProfile viewer) {
  final raw = listing['bedrooms'] ?? listing['bhk'];
  final listingBhk = raw?.toString().toLowerCase().trim() ?? '';
  if (listingBhk.isEmpty) return false;
  final occ = viewer.occupantType.toLowerCase();
  if (occ.contains('family')) {
    return listingBhk.contains('2') ||
        listingBhk.contains('3') ||
        listingBhk.contains('4');
  }
  if (occ.contains('student') ||
      occ.contains('working') ||
      occ.contains('bachelor')) {
    return listingBhk.contains('1') || listingBhk.contains('rk');
  }
  return true;
}

bool _furnishingMatch(Map<String, dynamic> listing) {
  final f = ListingData.furnishing(listing).toLowerCase();
  return f.contains('furnished') && !f.contains('unfurnished');
}

bool _languageMatch(Map<String, dynamic> listing, ViewerProfile viewer) {
  if (viewer.motherTongue.isEmpty) return false;
  final hostMother = ListingData.hostMotherTongue(listing).toLowerCase();
  final hostLang = ListingData.hostLanguage(listing).toLowerCase();
  final mother = viewer.motherTongue.toLowerCase();
  if (hostMother == mother) return true;
  if (hostLang.contains(mother)) return true;
  for (final lang in viewer.spokenLanguages) {
    final token = lang.toLowerCase();
    if (hostMother.contains(token) || hostLang.contains(token)) return true;
  }
  return false;
}

bool _occupantMatch(Map<String, dynamic> listing, ViewerProfile viewer) {
  if (viewer.occupantType.isEmpty) return false;
  return ListingData.matchesOccupantType(listing, viewer.occupantType);
}

bool _roommateTypeMatch(Map<String, dynamic> listing, ViewerProfile viewer) {
  final listingOccupant = ListingData.occupantType(listing);
  final bachelor = ListingData.bachelorPreference(listing);
  return _occupantMatch(listing, viewer) ||
      (listingOccupant == 'Bachelors' && bachelor.isNotEmpty) ||
      (listingOccupant == 'Working Professionals' && bachelor.isNotEmpty);
}

bool _dietMatch(Map<String, dynamic> listing, ViewerProfile viewer) {
  final listingFood = ListingData.foodPreferenceToken(listing);
  final viewerFood = _normFood(viewer.foodPreference);
  if (viewerFood.isNotEmpty &&
      listingFood.isNotEmpty &&
      viewerFood == listingFood) {
    return true;
  }
  return _lifestyleOk(viewer, listing);
}

bool _lifestyleOk(ViewerProfile viewer, Map<String, dynamic> listing) {
  final viewerFood = _normFood(viewer.foodPreference);
  final hostFood = _normFood(ListingData.hostFoodPreference(listing));
  if (viewerFood.isNotEmpty && hostFood.isNotEmpty && viewerFood == hostFood) {
    return true;
  }
  final lifestyle =
      ListingData.lifestylePreferences(listing).map((e) => e.toLowerCase()).toSet();
  if (viewerFood == 'veg' && lifestyle.contains('non-veg')) return false;
  return true;
}

double _shareLifestyleFraction(
  Map<String, dynamic> listing,
  ViewerProfile viewer,
) {
  var matched = 0;
  var signals = 0;
  signals++;
  if (_lifestyleOk(viewer, listing)) matched++;

  final flags = ListingData.lifestyleFlags(listing);
  if (flags.contains('quiet_hours_preferred')) {
    signals++;
    final schedule = viewer.scheduleType.toLowerCase();
    if (schedule.isEmpty ||
        schedule == 'flexible' ||
        schedule.contains('day')) {
      matched++;
    }
  }

  if (viewer.scheduleType.isNotEmpty ||
      ListingData.scheduleType(listing).isNotEmpty) {
    signals++;
    if (_scheduleCompatible(viewer, listing)) matched++;
  }

  if (signals == 0) return 0;
  return matched / signals;
}

bool _scheduleCompatible(ViewerProfile viewer, Map<String, dynamic> listing) {
  final listingSchedule = ListingData.scheduleType(listing).toLowerCase();
  if (listingSchedule.isEmpty || listingSchedule == 'flexible') return true;
  final viewerSchedule = viewer.scheduleType.toLowerCase();
  if (viewerSchedule.isEmpty || viewerSchedule == 'flexible') return true;
  return viewerSchedule == listingSchedule;
}

bool _timingMatch(ViewerProfile viewer, Map<String, dynamic> listing) {
  final hasSchedule = viewer.scheduleType.isNotEmpty ||
      ListingData.scheduleType(listing).isNotEmpty;
  final hasMoveIn = viewer.earliestMoveInDate.isNotEmpty ||
      ListingData.text(listing['available_from']).isNotEmpty;
  if (!hasSchedule && !hasMoveIn) return false;

  final scheduleOk = _scheduleCompatible(viewer, listing);
  final moveInOk = _moveInAligned(viewer.earliestMoveInDate, listing);
  if (hasMoveIn && hasSchedule) return scheduleOk && moveInOk;
  if (hasMoveIn) return moveInOk;
  return scheduleOk;
}

bool _moveInAligned(String seekerDateRaw, Map<String, dynamic> listing) {
  final seekerDate = DateTime.tryParse(seekerDateRaw);
  if (seekerDate == null) return true;
  final available =
      DateTime.tryParse(ListingData.text(listing['available_from']));
  if (available == null) return true;
  return seekerDate.difference(available).inDays.abs() <= 14;
}

bool _rentPetSmokingMismatch(ViewerProfile viewer, Map<String, dynamic> listing) {
  if (listing.containsKey('smoking_allowed') &&
      listing['smoking_allowed'] != true &&
      viewer.smokingOk) {
    return true;
  }
  if (listing.containsKey('pets_allowed') &&
      listing['pets_allowed'] != true &&
      viewer.householdHasPets) {
    return true;
  }
  return false;
}

String _normFood(String value) {
  final v = value.toLowerCase();
  if (v.contains('veg') && !v.contains('non')) return 'veg';
  if (v.contains('non')) return 'non-veg';
  return v;
}
