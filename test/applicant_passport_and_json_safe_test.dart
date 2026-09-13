import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/mock_landlord_data.dart';
import 'package:true_circle/models/landlord_engine_models.dart';
import 'package:true_circle/utils/json_safe.dart';
import 'package:true_circle/widgets/landlord_decision_engine/applicant_passport.dart';

void main() {
  group('JsonSafe', () {
    test('strips Infinity and NaN from nested maps before encode', () {
      final sanitized = JsonSafe.encodeMap({
        'ok': 1.5,
        'badInf': double.infinity,
        'badNeg': double.negativeInfinity,
        'badNan': double.nan,
        'nested': {
          'maxH': double.infinity,
          'list': [1.0, double.nan],
        },
      });

      expect(sanitized['ok'], 1.5);
      expect(sanitized['badInf'], isNull);
      expect(sanitized['badNeg'], isNull);
      expect(sanitized['badNan'], isNull);
      final nested = sanitized['nested'] as Map<String, dynamic>;
      expect(nested['maxH'], isNull);
      expect(nested['list'], [1.0, null]);
      expect(JsonSafe.finiteOrZero(double.infinity), 0.0);
      expect(JsonSafe.finiteOrNull(double.nan), isNull);
    });
  });

  group('ApplicantPassport', () {
    testWidgets('renders SharedLiving applicant without error', (tester) async {
      final listing = MockLandlordData.listings
          .firstWhere((l) => l.type == ListingType.sharedLiving);
      final applicant = listing.applicants.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApplicantPassport(
              applicant: applicant,
              listingType: ListingType.sharedLiving,
              compact: false,
            ),
          ),
        ),
      );

      expect(find.text('Applicant Passport'), findsOneWidget);
      expect(find.textContaining(applicant.trustTier.displayToken), findsOneWidget);
      if (applicant.languages.isNotEmpty) {
        expect(find.textContaining('Languages:'), findsOneWidget);
      }
      if (applicant.householdLabel != null &&
          applicant.householdLabel!.trim().isNotEmpty) {
        expect(find.textContaining(applicant.householdLabel!.trim()), findsOneWidget);
      }
      if (applicant.commuteLabel != null &&
          applicant.commuteLabel!.trim().isNotEmpty) {
        expect(find.textContaining('Commute:'), findsOneWidget);
      }
    });

    testWidgets('renders EntirePlace applicant without error', (tester) async {
      final listing = MockLandlordData.listings
          .firstWhere((l) => l.type == ListingType.entirePlace);
      final applicant = listing.applicants.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApplicantPassport(
              applicant: applicant,
              listingType: ListingType.entirePlace,
              compact: false,
            ),
          ),
        ),
      );

      expect(find.text('Applicant Passport'), findsOneWidget);
      expect(find.textContaining(applicant.trustTier.displayToken), findsOneWidget);
      if (applicant.householdLabel != null &&
          applicant.householdLabel!.trim().isNotEmpty) {
        expect(
          find.textContaining('Household: ${applicant.householdLabel!.trim()}'),
          findsOneWidget,
        );
      }
      if (applicant.stabilityBullet != null &&
          applicant.stabilityBullet!.trim().isNotEmpty) {
        expect(
          find.textContaining(applicant.stabilityBullet!.trim()),
          findsOneWidget,
        );
      }
      // Shared-only commute row must not appear for entire place.
      expect(find.textContaining('Commute:'), findsNothing);
    });
  });
}
