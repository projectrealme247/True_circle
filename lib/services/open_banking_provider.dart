/// PSD2 provider identifiers — TrueLayer / GoCardless AIS style routing.
enum IrishOpenBankInstitution {
  aib(
    providerId: 'ie_aib_ais',
    displayName: 'Allied Irish Banks',
    shortLabel: 'AIB',
  ),
  boi(
    providerId: 'ie_boi_ais',
    displayName: 'Bank of Ireland',
    shortLabel: 'BOI',
  ),
  revolut(
    providerId: 'ie_revolut_ais',
    displayName: 'Revolut',
    shortLabel: 'Revolut',
  );

  const IrishOpenBankInstitution({
    required this.providerId,
    required this.displayName,
    required this.shortLabel,
  });

  final String providerId;
  final String displayName;
  final String shortLabel;

  static IrishOpenBankInstitution? fromProviderId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final bank in values) {
      if (bank.providerId == raw) return bank;
    }
    return null;
  }
}

/// Minimal read-once AIS slice — only fields we evaluate (never persisted client-side).
class OpenBankingAisSnapshot {
  const OpenBankingAisSnapshot({
    required this.accountHolderName,
    required this.currentBalanceEur,
    required this.recurringSalaryDetected,
    this.monthlySalaryEur,
    this.institution,
  });

  final String accountHolderName;
  final double? currentBalanceEur;
  final bool recurringSalaryDetected;
  final double? monthlySalaryEur;
  final IrishOpenBankInstitution? institution;

  factory OpenBankingAisSnapshot.fromPayload(Map<String, dynamic> json) {
    final liquidity = json['liquidity'];
    final liquidityMap = liquidity is Map
        ? liquidity.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    return OpenBankingAisSnapshot(
      accountHolderName: json['account_holder_name']?.toString().trim() ?? '',
      currentBalanceEur: _asDouble(liquidityMap['current_balance_eur']),
      recurringSalaryDetected: liquidityMap['recurring_salary_detected'] == true,
      monthlySalaryEur: _asDouble(liquidityMap['monthly_salary_eur']),
      institution: IrishOpenBankInstitution.fromProviderId(
        json['institution']?.toString(),
      ),
    );
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

/// Provider wrapper surface — auth URL construction + callback parsing.
abstract final class OpenBankingProvider {
  static const redirectUri = String.fromEnvironment('OPEN_BANKING_REDIRECT_URI');
  static const apiBase = String.fromEnvironment(
    'OPEN_BANKING_API_BASE',
    defaultValue: 'https://api.truelayer-sandbox.com',
  );

  static String buildAuthorizePath({
    required IrishOpenBankInstitution institution,
    required String state,
    required String redirectUri,
  }) {
    final query = Uri(queryParameters: {
      'response_type': 'code',
      'provider_id': institution.providerId,
      'redirect_uri': redirectUri,
      'state': state,
      'scope': 'accounts balance transactions:read',
    });
    return '$apiBase/connect/authorize${query.query.isEmpty ? '' : '?${query.query}'}';
  }

  static Map<String, String> parseCallback(Uri uri) => {
        'code': uri.queryParameters['code'] ?? '',
        'state': uri.queryParameters['state'] ?? '',
        'error': uri.queryParameters['error'] ?? '',
      };
}
