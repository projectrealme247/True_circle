/// Lightweight E.164 phone helpers — no external phone library.
abstract final class PhoneE164 {
  static const defaultCountryCode = '+353';

  static const commonCountryCodes = [
    '+353', // Ireland
    '+44', // UK
    '+91', // India
    '+48', // Poland
    '+34', // Spain
    '+33', // France
    '+49', // Germany
    '+1', // US/CA
  ];

  static String digitsOnly(String raw) =>
      raw.replaceAll(RegExp(r'[^\d]'), '');

  static String? compose({
    required String countryCode,
    required String national,
  }) {
    final codeDigits = digitsOnly(countryCode);
    var nationalDigits = digitsOnly(national);
    if (codeDigits.isEmpty || nationalDigits.isEmpty) return null;

    if (nationalDigits.startsWith('0')) {
      nationalDigits = nationalDigits.substring(1);
    }
    if (nationalDigits.isEmpty) return null;

    return '+$codeDigits$nationalDigits';
  }

  static ({String countryCode, String national})? split(String? e164) {
    final trimmed = (e164 ?? '').trim();
    if (trimmed.isEmpty) return null;

    final normalized = trimmed.startsWith('+') ? trimmed : '+$trimmed';
    for (final code in commonCountryCodes) {
      if (normalized.startsWith(code)) {
        return (
          countryCode: code,
          national: normalized.substring(code.length),
        );
      }
    }

    final match = RegExp(r'^\+(\d{1,3})(\d+)$').firstMatch(normalized);
    if (match == null) return null;
    return (
      countryCode: '+${match.group(1)}',
      national: match.group(2) ?? '',
    );
  }

  static String whatsAppUrl(String? e164, {String? message}) {
    final digits = digitsOnly(e164 ?? '');
    if (digits.isEmpty) return '';
    final base = 'https://wa.me/$digits';
    if (message == null || message.trim().isEmpty) return base;
    return '$base?text=${Uri.encodeComponent(message.trim())}';
  }
}
