import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/listing_creation_form_models.dart';
import 'package:true_circle/models/neighborhood_amenity_tag.dart';
import 'package:true_circle/services/overpass_amenities_service.dart';
import 'package:true_circle/utils/proximity_chip_keys.dart';
import 'package:true_circle/utils/proximity_display_builder.dart';

void main() {
  group('ProximityChipKeys', () {
    test('builds stable category|name keys and strips walk / emoji', () {
      expect(
        ProximityChipKeys.build('groceries', 'Spar • 4 min walk'),
        'groceries|spar',
      );
      expect(
        ProximityChipKeys.normalizeName('🏧 Bank ATM • 3 min walk'),
        'bank atm',
      );
    });
  });

  group('chip-based proximity preferences', () {
    final base = ProximityDisplayInput(
      groceries: const [
        NearbyGroceryOption(brand: 'Spar', walkMin: 4),
        NearbyGroceryOption(brand: 'Centra', walkMin: 6),
        NearbyGroceryOption(brand: 'Lidl', walkMin: 8),
      ],
      lifestyleTags: const [
        NeighborhoodAmenityTag(
          category: NeighborhoodAmenityCategory.atms,
          name: 'Bank ATM',
          distanceKm: 0.2,
          emoji: '🏧',
        ),
      ],
      gpClinic: 'Main Street Clinic',
      gpWalkMin: 9,
      customPoints: [
        CustomProximityPoint(
          category: ProximityPointCategory.amenity,
          name: 'Phoenix Park',
          walkMin: 12,
        ),
      ],
    );

    test('hide removes chips in read mode and keeps them in edit mode', () {
      final sparKey = ProximityChipKeys.build(ProximityChipKeys.groceries, 'Spar');
      final hidden = ProximityDisplayInput(
        groceries: base.groceries,
        lifestyleTags: base.lifestyleTags,
        gpClinic: base.gpClinic,
        gpWalkMin: base.gpWalkMin,
        customPoints: base.customPoints,
        hiddenChipKeys: [sparKey],
      );

      final groceries = ProximityDisplayBuilder.buildProfile(hidden)
          .firstWhere((s) => s.title == 'Groceries');
      expect(groceries.chips.any((c) => c.matchName == 'Spar'), isFalse);

      final editing = ProximityDisplayInput(
        groceries: base.groceries,
        lifestyleTags: base.lifestyleTags,
        gpClinic: base.gpClinic,
        gpWalkMin: base.gpWalkMin,
        customPoints: base.customPoints,
        hiddenChipKeys: [sparKey],
        includeHidden: true,
      );
      final editGroceries = ProximityDisplayBuilder.buildProfile(editing)
          .firstWhere((s) => s.title == 'Groceries');
      final spar = editGroceries.chips.firstWhere((c) => c.matchName == 'Spar');
      expect(spar.isHidden, isTrue);
    });

    test('pin sorts chips first within a section', () {
      final lidlKey = ProximityChipKeys.build(ProximityChipKeys.groceries, 'Lidl');
      final pinned = ProximityDisplayInput(
        groceries: base.groceries,
        pinnedChipKeys: [lidlKey],
      );
      final groceries = ProximityDisplayBuilder.buildProfile(pinned)
          .firstWhere((s) => s.title == 'Groceries');
      expect(groceries.chips.first.matchName, 'Lidl');
      expect(groceries.chips.first.isPinned, isTrue);
    });

    test('custom points appear in Custom section immediately', () {
      final profile = ProximityDisplayBuilder.buildProfile(base);
      final custom = profile.firstWhere((s) => s.title == 'Custom');
      expect(custom.chips.single.matchName, 'Phoenix Park');
    });

    test('hide/pin keys survive draft round-trip', () {
      final draft = NeighborhoodProximityDraft(
        hiddenChipKeys: ['groceries|spar'],
        pinnedChipKeys: ['healthcare|gp · main street clinic'],
        customPoints: const [],
      );
      final restored = NeighborhoodProximityDraft.fromJson(draft.toJson());
      expect(restored.hiddenChipKeys, ['groceries|spar']);
      expect(restored.pinnedChipKeys, ['healthcare|gp · main street clinic']);
    });

    test('legacy draft fields remain after prefs serialize', () {
      final draft = NeighborhoodProximityDraft(
        transportLine: 'Luas · Cookstown',
        transportWalkMin: 8,
        groceryBrand: 'Tesco',
        primarySchool: 'St Mary',
        hiddenChipKeys: ['lifestyle|bank atm'],
      );
      final json = draft.toJson();
      expect(json['transport_line'], 'Luas · Cookstown');
      expect(json['grocery_brand'], 'Tesco');
      expect(json['hidden_chip_keys'], ['lifestyle|bank atm']);
      expect(json.containsKey('pinned_chip_keys'), isTrue);
    });
  });
}
