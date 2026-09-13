import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/services/commute_scoring_service.dart';
import 'package:true_circle/utils/commute_profile.dart';
import 'package:true_circle/utils/listing_data.dart';
import 'package:true_circle/utils/listing_match_engine.dart';

void main() {
  test('stress match simulations — print top 3 per scenario', () {
  // ── SCENARIO 1: TCD Student Seeker (Share) ─────────────────────────────
  const studentSession = {
    'full_name': 'Niamh O\'Brien',
    'detected_city': 'Dublin',
    'mother_tongue': 'English',
    'spoken_languages': ['English'],
    'food_preference': 'Veg',
    'occupant_type': 'Students',
    'preferred_property_type': 'Share',
    'budget_max': 850,
    'trust_stage': 2,
    'pre_arrival_contact_ready': true,
    'invite_code_verified': true,
    'commute_method': CommuteMethod.backendPublicTransportWalking,
    'commute_destination_hub_id': 'tcd',
    'commute_destination': 'Trinity College Dublin (TCD)',
    'destination_latitude': 53.3438,
    'destination_longitude': -6.2546,
    'maximum_commute_budget_minutes': 35,
  };

  final scenario1Listings = [
    _shareListing(
      id: 's1-friction-cheap',
      title: 'Bargain room — high lifestyle friction',
      price: '650/month',
      lat: 53.3380,
      lon: -6.2600,
      hostFood: 'Non-veg',
      hostTrust: 2,
      smoking: true,
      lifestyleFlags: ['non_veg_allowed'],
    ),
    _shareListing(
      id: 's1-dart-perfect',
      title: 'Pearse DART — exact budget veg house',
      price: '850/month',
      lat: 53.3433,
      lon: -6.2483,
      hostFood: 'Veg',
      hostTrust: 2,
      transitWalk: 5,
      transitType: 'DART Pearse',
    ),
    _shareListing(
      id: 's1-unverified-host',
      title: 'Temple Bar room — casual host',
      price: '820/month',
      lat: 53.3455,
      lon: -6.2640,
      hostFood: 'Veg',
      hostTrust: 1,
    ),
    _shareListing(
      id: 's1-filler-good',
      title: 'Rathmines student share',
      price: '840/month',
      lat: 53.3260,
      lon: -6.2550,
      hostFood: 'Veg',
      hostTrust: 3,
    ),
    _shareListing(
      id: 's1-over-budget',
      title: 'Premium ensuite — over budget',
      price: '1100/month',
      lat: 53.3419,
      lon: -6.2373,
      hostFood: 'Veg',
      hostTrust: 3,
    ),
  ];

  _runScenario(
    name: 'SCENARIO 1 — TCD Student Seeker (Share, €850, Veg, Pre-arrival)',
    session: studentSession,
    listings: scenario1Listings,
  );

  // ── SCENARIO 2: Sandyford Corporate Seeker (Rent) ──────────────────────
  const corporateSession = {
    'full_name': 'James Kelly',
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
  };

  final scenario2Listings = [
    _rentListing(
      id: 's2-luas-zone-a',
      title: 'Luas Green — Sandyford premium 2-bed',
      price: '2200/month',
      lat: 53.2775,
      lon: -6.2040,
      hostFood: 'Non-veg',
      hostTrust: 3,
      bhk: '2 BHK',
    ),
    _rentListing(
      id: 's2-two-bus-house',
      title: 'Swords house — cheaper, long transfer',
      price: '1950/month',
      lat: 53.4597,
      lon: -6.2181,
      hostFood: 'Non-veg',
      hostTrust: 3,
      bhk: '3 BHK',
    ),
    _rentListing(
      id: 's2-mid-dundrum',
      title: 'Dundrum apartment — mid commute',
      price: '2100/month',
      lat: 53.2890,
      lon: -6.2430,
      hostFood: 'Veg',
      hostTrust: 2,
      bhk: '2 BHK',
    ),
    _rentListing(
      id: 's2-city-centre',
      title: 'City centre 1-bed — poor Sandyford link',
      price: '2000/month',
      lat: 53.3471,
      lon: -6.2561,
      hostFood: 'Veg',
      hostTrust: 3,
      bhk: '1 BHK',
    ),
  ];

  _runScenario(
    name: 'SCENARIO 2 — Sandyford Corporate Seeker (Rent, €2,200, PT)',
    session: corporateSession,
    listings: scenario2Listings,
  );

  // ── SCENARIO 3: Dual-Commute Family (Rent) ─────────────────────────────
  const familySession = {
    'full_name': 'Priya & Arjun Sharma',
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
    'pre_arrival_contact_ready': true,
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
  };

  final scenario3Listings = [
    _rentListing(
      id: 's3-dundrum',
      title: 'Dundrum family home — Luas to Sandyford',
      price: '3100/month',
      lat: 53.2890,
      lon: -6.2430,
      hostFood: 'Veg',
      hostTrust: 3,
      bhk: '3 BHK',
      occupant: 'Family',
    ),
    _rentListing(
      id: 's3-swords',
      title: 'Swords semi-D — airport-friendly',
      price: '2800/month',
      lat: 53.4597,
      lon: -6.2181,
      hostFood: 'Veg',
      hostTrust: 2,
      bhk: '4 BHK',
      occupant: 'Family',
    ),
    _rentListing(
      id: 's3-grand-canal',
      title: 'Grand Canal Dock hub flat',
      price: '3200/month',
      lat: 53.3419,
      lon: -6.2373,
      hostFood: 'Veg',
      hostTrust: 3,
      bhk: '3 BHK',
      occupant: 'Family',
    ),
    _rentListing(
      id: 's3-cherrywood',
      title: 'Cherrywood new build — Sandyford adjacent',
      price: '3000/month',
      lat: 53.2440,
      lon: -6.1465,
      hostFood: 'Veg',
      hostTrust: 3,
      bhk: '3 BHK',
      occupant: 'Family',
    ),
  ];

  _runScenario(
    name: 'SCENARIO 3 — Dual-Commute Family (Rent, €3,200, Balanced 50/50)',
    session: familySession,
    listings: scenario3Listings,
  );
  });
}

Map<String, dynamic> _shareListing({
  required String id,
  required String title,
  required String price,
  required double lat,
  required double lon,
  required String hostFood,
  required int hostTrust,
  bool smoking = false,
  List<String> lifestyleFlags = const [],
  int? transitWalk,
  String? transitType,
}) {
  return {
    'id': id,
    'title': title,
    'price': price,
    'location': title,
    'type': 'Share',
    'occupantType': 'Students',
    'hostFoodPreference': hostFood,
    'host_trust_stage': hostTrust,
    'tenant_track_preference': 'both',
    'latitude': lat,
    'longitude': lon,
    'hostMotherTongue': 'English',
    'hostLanguage': 'English',
    'smokingAllowed': smoking,
    'lifestyle_flags': lifestyleFlags,
    if (transitWalk != null) 'transit_walk_minutes': transitWalk,
    if (transitType != null) 'transit_type': transitType,
  };
}

Map<String, dynamic> _rentListing({
  required String id,
  required String title,
  required String price,
  required double lat,
  required double lon,
  required String hostFood,
  required int hostTrust,
  String bachelorPref = '',
  String bhk = '2 BHK',
  String occupant = 'Working Professionals',
}) {
  return {
    'id': id,
    'title': title,
    'price': price,
    'location': title,
    'type': 'Rent',
    'occupantType': occupant,
    'hostFoodPreference': hostFood,
    'host_trust_stage': hostTrust,
    'bachelorPreference': bachelorPref,
    'bhk': bhk,
    'furnishing': 'Fully furnished',
    'latitude': lat,
    'longitude': lon,
    'hostMotherTongue': 'English',
    'hostLanguage': 'English',
  };
}

void _runScenario({
  required String name,
  required Map<String, dynamic> session,
  required List<Map<String, dynamic>> listings,
}) {
  // ignore: avoid_print
  print('\n${'=' * 72}');
  // ignore: avoid_print
  print(name);
  // ignore: avoid_print
  print('=' * 72);

  final outcome = ListingMatchEngine.rank(listings, session);
  final top = outcome.ranked.take(3).toList();

  // ignore: avoid_print
  print('Commute divergent flag: ${outcome.isCommuteDivergent}');
  // ignore: avoid_print
  print('Pool: ${listings.length} listings → ${outcome.ranked.length} ranked '
      '(${listings.length - outcome.ranked.length} hard-excluded)\n');

  for (final listing in listings) {
    final id = listing['id'];
    final eval = ListingMatchEngine.evaluate(
      listing,
      null,
      viewerSession: session,
    );
    if (eval.excluded) {
      // ignore: avoid_print
      print('  [EXCLUDED] $id — hard-filtered or track conflict');
    } else {
      final coords = ListingData.listingCoordinates(listing);
      if (coords != null) {
        final profiles = CommuteProfileRegistry.fromSession(session);
        if (profiles.isNotEmpty) {
          final payload = CommuteScoringService.calculateMultiCommuteMinutes(
            propertyLoc: coords,
            profiles: profiles,
            dualCommutePriority: ListingData.dualCommutePriority(session),
            budgetForProfile: (profile, index) =>
                ListingData.commuteBudgetMinutesForProfile(profile, session),
          );
          final mins = payload.results.map((r) => '${r.profileLabel}:${r.minutes}m').join(', ');
          final comb = payload.combinedCompatibilityScore?.toStringAsFixed(1) ?? 'n/a';
          // ignore: avoid_print
          print('  [scored] $id → raw ${eval.score}/${eval.maxScore} | commute $mins | combined=$comb');
        }
      }
    }
  }

  if (top.isEmpty) {
    // ignore: avoid_print
    print('  (no ranked results)');
    return;
  }

  for (var i = 0; i < top.length; i++) {
    final s = top[i];
    final id = s.listing['id'];
    final m = s.match;
    final coords = ListingData.listingCoordinates(s.listing);
    var commuteNote = '';
    if (coords != null) {
      final profiles = CommuteProfileRegistry.fromSession(session);
      if (profiles.isNotEmpty) {
        final payload = CommuteScoringService.calculateMultiCommuteMinutes(
          propertyLoc: coords,
          profiles: profiles,
          dualCommutePriority: ListingData.dualCommutePriority(session),
          budgetForProfile: (profile, index) =>
              ListingData.commuteBudgetMinutesForProfile(profile, session),
        );
        final parts = <String>[];
        for (final r in payload.results) {
          parts.add('${r.profileLabel}: ${r.minutes}min');
        }
        if (payload.combinedCompatibilityScore != null) {
          parts.add(
            'combined=${payload.combinedCompatibilityScore!.toStringAsFixed(1)}',
          );
        }
        commuteNote = parts.join(', ');
      } else {
        final hub = CommuteProfileRegistry.fromSession(session).firstOrNull;
        if (hub != null) {
          final mins = CommuteScoringService.calculateCommuteMinutesToHub(
            coords,
            hub.hub,
            hub.method,
          );
          commuteNote = 'door-to-door≈${mins}min';
        }
      }
    }

    // ignore: avoid_print
    print(
      '#${i + 1} [$id] ${s.listing['title']}\n'
      '     Score: ${m.score}/${m.maxScore} (${m.percentage.round()}%) — ${m.label}\n'
      '     Commute: ${commuteNote.isEmpty ? 'n/a' : commuteNote}\n'
      '     Reasons: ${m.reasons.join(' · ')}',
    );
  }
}
