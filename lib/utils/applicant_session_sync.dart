import 'profile_data.dart';

abstract final class ApplicantSessionSync {
  static const defaultMaxCommuteMinutes = 45;
  static const leaseTermOptions = [6, 9, 12];
  static const leaseBeyondTwelveMonths = 99;

  static List<String> get leaseTermLabels => [
        for (final months in leaseTermOptions) '$months months',
        '> 12 months',
      ];

  static int? leaseMonthsFromLabel(String label) {
    final trimmed = label.trim();
    if (trimmed == '> 12 months') return leaseBeyondTwelveMonths;
    return int.tryParse(trimmed.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  static String leaseLabelForMonths(int? months) {
    if (months == null) return '';
    if (months == leaseBeyondTwelveMonths || months > 12) {
      return '> 12 months';
    }
    return '$months months';
  }

  static Map<String, dynamic> enrich(Map<String, dynamic> session) {
    final payload = Map<String, dynamic>.from(session);
    payload['commute_profiles'] = normalizeCommuteProfiles(payload);
    payload['co_applicants'] = buildCoApplicants(payload);
    return payload;
  }

  static List<Map<String, dynamic>> normalizeCommuteProfiles(
    Map<String, dynamic> session,
  ) {
    final fallback = maximumCommuteBudgetMinutes(session) ?? defaultMaxCommuteMinutes;
    final raw = session['commute_profiles'];
    if (raw is! List) return const [];

    return [
      for (final entry in raw)
        if (entry is Map)
          {
            ...Map<String, dynamic>.from(entry),
            'max_commute_minutes': entry['max_commute_minutes'] is int
                ? entry['max_commute_minutes'] as int
                : int.tryParse(ProfileData.text(entry['max_commute_minutes'])) ??
                    fallback,
          },
    ];
  }

  static int? maximumCommuteBudgetMinutes(Map<String, dynamic> session) {
    final raw = session['maximum_commute_budget_minutes'];
    if (raw is int) return raw;
    return int.tryParse(ProfileData.text(raw));
  }

  static List<Map<String, dynamic>> buildCoApplicants(
    Map<String, dynamic> session,
  ) {
    final primary = _applicantFromSession(session, id: 'primary', label: 'You');
    final applicants = <Map<String, dynamic>>[primary];

    final partnerIncome = session['partner_net_monthly_income'];
    final partnerValue = partnerIncome is num
        ? partnerIncome.toDouble()
        : double.tryParse(ProfileData.text(partnerIncome));
    if (partnerValue != null && partnerValue > 0) {
      applicants.add(
        _applicantFromSession(
          {
            ...session,
            'net_monthly_income': partnerValue,
          },
          id: 'partner',
          label: 'Partner',
        ),
      );
    }
    return applicants;
  }

  static Map<String, dynamic> _applicantFromSession(
    Map<String, dynamic> session, {
    required String id,
    required String label,
  }) {
    final incomeRaw = session['net_monthly_income'];
    final income = incomeRaw is num
        ? incomeRaw.toDouble()
        : double.tryParse(ProfileData.text(incomeRaw)) ?? 0.0;

    final trustTier = ProfileData.text(session['trust_tier']).toLowerCase();
    final grand = trustTier.contains('grand') || session['employment_verified'] == true;

    final chips = <String>[];
    if (session['household_smoker'] == true) chips.add('Smoker');
    if (session['household_has_pets'] == true) chips.add('Pet owner');
    if (chips.isEmpty) chips.add('Non-smoker');

    return {
      'id': id,
      'label': label,
      'net_monthly_income': income,
      'has_verified_grand_badge': grand,
      'has_verified_corporate_email': session['employment_verified'] == true,
      if (session['preferred_lease_months'] != null)
        'preferred_lease_months': session['preferred_lease_months'],
      if (ProfileData.text(session['earliest_move_in_date']).isNotEmpty)
        'earliest_move_in_date': ProfileData.text(session['earliest_move_in_date']),
      'lifestyle_display_chips': chips,
    };
  }
}
