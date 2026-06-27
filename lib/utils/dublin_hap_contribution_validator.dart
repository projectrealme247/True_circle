import 'profile_data.dart';

abstract final class DublinHapContributionValidator {
  static const Map<int, double> standardMonthlyCaps = {1: 660, 2: 900, 3: 1100, 4: 1300};
  static const double minUpliftPercent = 0.35;
  static const double maxUpliftPercent = 0.50;
  static int resolveHouseholdSize(Map<String, dynamic> session) {
    final adults = session['family_adults'];
    final children = session['family_children'];
    final group = session['group_size'];
    final adultCount = adults is int ? adults : int.tryParse(ProfileData.text(adults)) ?? 0;
    final childCount = children is int ? children : int.tryParse(ProfileData.text(children)) ?? 0;
    final groupSize = group is int ? group : int.tryParse(ProfileData.text(group)) ?? 0;
    if (adultCount > 0 || childCount > 0) return (adultCount + childCount).clamp(1, 99);
    if (groupSize > 0) return groupSize.clamp(1, 99);
    if (ProfileData.text(session['partner_net_monthly_income']).isNotEmpty) return 2;
    return 1;
  }
  static double standardCapForSession(Map<String, dynamic> session) {
    final size = resolveHouseholdSize(session);
    return standardMonthlyCaps[size >= 4 ? 4 : size] ?? standardMonthlyCaps[1]!;
  }
  static double effectiveCapEur({required Map<String, dynamic> session, required bool upliftApproved, double upliftPercent = minUpliftPercent}) {
    final base = standardCapForSession(session);
    if (!upliftApproved) return base;
    return base * (1 + upliftPercent.clamp(minUpliftPercent, maxUpliftPercent));
  }
  static String? validateContribution({required Map<String, dynamic> session, required double contributionEur, required bool upliftApproved, double upliftPercent = minUpliftPercent}) {
    final safe = contributionEur.clamp(0, double.infinity);
    if (safe <= 0) return 'Enter a positive monthly HAP contribution.';
    final cap = effectiveCapEur(session: session, upliftApproved: upliftApproved, upliftPercent: upliftPercent);
    if (safe > cap) {
      final base = standardCapForSession(session);
      final upliftLabel = upliftApproved ? ' (with approved uplift)' : '';
      return 'HAP contribution cannot exceed EUR ${cap.toStringAsFixed(0)}$upliftLabel for your household size (standard cap EUR ${base.toStringAsFixed(0)}).';
    }
    return null;
  }
}
