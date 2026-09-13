import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/models/financial_support_type.dart';

void main() {
  group('FinancialSupportType', () {
    test('normalizes legacy education loan label', () {
      expect(
        FinancialSupportType.normalize('Education loan (bank financed)'),
        FinancialSupportType.educationLoan,
      );
    });

    test('reads new key over legacy student_type', () {
      final value = FinancialSupportType.fromSession({
        FinancialSupportType.storageKey: 'Self funded',
        FinancialSupportType.legacyStorageKey: 'Family supported',
      });
      expect(value, 'Self funded');
    });

    test('falls back to legacy student_type', () {
      final value = FinancialSupportType.fromSession({
        'student_type': 'Family supported',
      });
      expect(value, 'Family supported');
    });

    test('ignores undergraduate mock labels', () {
      expect(FinancialSupportType.normalize('undergraduate'), isNull);
      expect(
        FinancialSupportType.fromSession({'student_type': 'postgraduate'}),
        isNull,
      );
    });
  });
}
