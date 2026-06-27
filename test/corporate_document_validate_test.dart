import 'package:flutter_test/flutter_test.dart';

/// Mirrors Dublin edge validation heuristics for regression coverage.
void main() {
  const profileName = 'Priya Sharma';
  const validDoc = '''
Employment Offer Letter
Employee: Priya Sharma
Google Ireland Ltd
CRO No. 582045
Effective date: 1 June 2026
Contract period: 2026 to 2027
''';

  group('Corporate document validation heuristics', () {
    test('accepts 2026 contract with name and employer match', () {
      expect(_identityMatches(profileName, validDoc), isTrue);
      expect(_hasActiveContractYear(validDoc), isTrue);
      expect(_hasWhitelistedEntity(validDoc), isTrue);
    });

    test('rejects legacy-only contract year', () {
      const legacy = '''
Employee: Priya Sharma
Deloitte Ireland Limited
Start date: March 2024
''';
      expect(_hasActiveContractYear(legacy), isFalse);
    });

    test('rejects name mismatch', () {
      final mismatch = validDoc.replaceAll('Priya Sharma', 'Alex Murphy');
      expect(_identityMatches(profileName, mismatch), isFalse);
    });
  });
}

bool _identityMatches(String profileName, String text) {
  String normalize(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final tokens = normalize(profileName).split(' ').where((t) => t.length > 1).toList();
  if (tokens.isEmpty) return false;
  final hay = normalize(text);
  final required = tokens.length >= 2 ? [tokens.first, tokens.last] : tokens;
  return required.every(hay.contains);
}

bool _hasActiveContractYear(String text, {int year = 2026}) {
  if (!text.contains('$year')) return false;
  final legacy = RegExp(r'\b202[0-5]\b').hasMatch(text);
  final current = RegExp(r'\b$year\b').hasMatch(text);
  if (legacy && !current) return false;
  return RegExp(
    r'\b(offer|employment|contract|effective)\b[^.\n]{0,72}\b2026\b',
    caseSensitive: false,
  ).hasMatch(text);
}

bool _hasWhitelistedEntity(String text) {
  return RegExp(r'\bCRO\s*(?:No\.?)?\s*\d{5,8}\b', caseSensitive: false).hasMatch(text) ||
      RegExp(r'\bLtd\.?\b', caseSensitive: false).hasMatch(text) ||
      RegExp(r'\bGoogle\b').hasMatch(text);
}
