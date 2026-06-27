import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/high_signal_match.dart';
import 'package:true_circle/utils/transit_duration_formatter.dart';

void main() {
  group('HighSignalMatch', () {
    test('parses RPC row fields', () {
      final match = HighSignalMatch.tryParse({
        'application_id': 'app-1',
        'applicant_user_id': 'user-1',
        'overall_match_score': 88.4,
        'verified_transit_duration_seconds': 2400,
      });

      expect(match, isNotNull);
      expect(match!.overallMatchScore, 88);
      expect(match.verifiedTransitDurationSeconds, 2400);
    });
  });

  group('TransitDurationFormatter', () {
    test('formats commute chip from seconds', () {
      expect(
        TransitDurationFormatter.commuteChipLabel(2400),
        '~40 min commute to their destination',
      );
    });
  });
}
