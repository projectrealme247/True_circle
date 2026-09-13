import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/data/mock_applicant_seeder.dart';
import 'package:true_circle/models/applicant_trust_tier.dart';
import 'package:true_circle/models/spoken_language_entry.dart';
import 'package:true_circle/utils/spoken_language_profile_codec.dart';

void main() {
  group('SpokenLanguageProfileCodec', () {
    test('sanitizes labels and preserves is_native flags', () {
      final fields = SpokenLanguageProfileCodec.toSessionFields(
        entries: const [
          SpokenLanguageEntry(language: 'english', isNative: false),
          SpokenLanguageEntry(language: ' English ', isNative: true),
          SpokenLanguageEntry(language: 'Spanish', isNative: true),
        ],
        motherTongue: 'English',
      );

      expect(fields['spoken_languages'], ['English', 'Spanish']);
      final entries = fields['spoken_language_entries'] as List;
      expect(entries, hasLength(2));
      expect(entries.first['language'], 'English');
      expect(entries.first['is_native'], isTrue);
    });
  });

  group('MockApplicantSeeder', () {
    test('shared living stream is flat with mixed verification states', () {
      final stream = MockApplicantSeeder.sharedLivingStream();
      expect(stream.blocks, hasLength(1));
      expect(
        stream.flattenedApplicants.map((a) => a.trustTier).toSet(),
        containsAll([
          ApplicantTrustTier.sound,
          ApplicantTrustTier.grand,
          ApplicantTrustTier.justLanded,
        ]),
      );
      expect(
        stream.flattenedApplicants.first.customBioPitch,
        isNotEmpty,
      );
    });

    test('independent stream exposes verification and lease fields', () {
      final stream = MockApplicantSeeder.independentPlacesStream();
      final grand = stream.flattenedApplicants
          .firstWhere((row) => row.trustTier == ApplicantTrustTier.grand);
      expect(grand.corporateDocumentVerified, isTrue);
      expect(grand.leaseTermMatch, isTrue);
    });
  });
}
