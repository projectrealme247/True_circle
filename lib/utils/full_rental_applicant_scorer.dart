import 'applicant_household.dart';
import 'listing_data.dart';
import 'numeric_bounds.dart';
import 'profile_data.dart';

class ApplicantGateResult {
  const ApplicantGateResult({
    required this.incomeGatePass,
    required this.commuteGatePass,
  });

  final bool incomeGatePass;
  final bool commuteGatePass;

  bool get hideFromFeed => !incomeGatePass || !commuteGatePass;
}

class ApplicantScoreResult {
  const ApplicantScoreResult({
    required this.finalScore,
    required this.hideFromFeed,
    required this.gates,
  });

  final int finalScore;
  final bool hideFromFeed;
  final ApplicantGateResult gates;
}

abstract final class FullRentalApplicantScorer {
  static bool isEligibleListing(Map<String, dynamic> listing) {
    return ListingData.propertyType(listing) == 'Rent';
  }

  static ApplicantGateResult evaluateGates({
    required ApplicantHousehold household,
    required Map<String, dynamic> listing,
  }) {
    final rent = _monthlyRent(listing);
    final incomePass = household.hasGuarantor ||
        (rent > 0 && household.pooledNetIncome >= rent * 2.5);

    var commutePass = true;
    if (household.commuteProfiles.isNotEmpty) {
      for (final profile in household.commuteProfiles) {
        final maxRaw = profile['max_commute_minutes'];
        final maxMinutes = maxRaw is int
            ? maxRaw
            : int.tryParse(ProfileData.text(maxRaw)) ?? 45;
        final estimated = profile['estimated_commute_minutes'];
        final estimatedMinutes = estimated is int
            ? estimated
            : int.tryParse(ProfileData.text(estimated)) ?? maxMinutes;
        if (estimatedMinutes > maxMinutes) {
          commutePass = false;
          break;
        }
      }
    }

    return ApplicantGateResult(
      incomeGatePass: incomePass,
      commuteGatePass: commutePass,
    );
  }

  static ApplicantScoreResult scoreApplicantGroup({
    required ApplicantHousehold household,
    required Map<String, dynamic> listing,
  }) {
    final gates = evaluateGates(household: household, listing: listing);
    if (gates.hideFromFeed) {
      return ApplicantScoreResult(
        finalScore: 0,
        hideFromFeed: true,
        gates: gates,
      );
    }

    final rent = _monthlyRent(listing);
    var score = 0;
    if (rent > 0 && household.pooledNetIncome > 0) {
      final ratio = rent / household.pooledNetIncome;
      if (ratio <= 0.30) {
        score += 40;
      } else if (ratio <= 0.40) {
        score += 25;
      } else {
        score += 10;
      }
    } else {
      score += 10;
    }

    final leaseMonths = household.coApplicants
        .map((a) => a['preferred_lease_months'])
        .whereType<int>()
        .toList();
    if (leaseMonths.isNotEmpty) score += 10;

    return ApplicantScoreResult(
      finalScore: NumericBounds.clampPercentInt(score),
      hideFromFeed: false,
      gates: gates,
    );
  }

  static List<({ApplicantHousehold household, ApplicantScoreResult score})>
      rankApplicants(
    List<ApplicantHousehold> households,
    Map<String, dynamic> listing,
  ) {
    final ranked = <({ApplicantHousehold household, ApplicantScoreResult score})>[];
    for (final household in households) {
      final score = scoreApplicantGroup(
        household: household,
        listing: listing,
      );
      if (!score.hideFromFeed) {
        ranked.add((household: household, score: score));
      }
    }
    ranked.sort((a, b) => b.score.finalScore.compareTo(a.score.finalScore));
    return ranked;
  }

  static List<({Map<String, dynamic> session, ApplicantScoreResult score})>
      rankApplicantSessions({
    required List<Map<String, dynamic>> sessions,
    required Map<String, dynamic> listing,
  }) {
    final ranked =
        <({Map<String, dynamic> session, ApplicantScoreResult score})>[];
    for (final session in sessions) {
      final household = ApplicantHousehold.fromMap(session);
      final score = scoreApplicantGroup(
        household: household,
        listing: listing,
      );
      if (!score.hideFromFeed) {
        ranked.add((session: session, score: score));
      }
    }
    ranked.sort((a, b) => b.score.finalScore.compareTo(a.score.finalScore));
    return ranked;
  }

  static int countHiddenApplicantSessions({
    required List<Map<String, dynamic>> sessions,
    required Map<String, dynamic> listing,
  }) {
    var hidden = 0;
    for (final session in sessions) {
      final household = ApplicantHousehold.fromMap(session);
      final score = scoreApplicantGroup(
        household: household,
        listing: listing,
      );
      if (score.hideFromFeed) hidden++;
    }
    return hidden;
  }

  static double _monthlyRent(Map<String, dynamic> listing) {
    final raw = ListingData.price(listing);
    final match = RegExp(r'[\d,.]+').firstMatch(raw);
    if (match == null) return 0;
    return double.tryParse(match.group(0)!.replaceAll(',', '')) ?? 0;
  }
}
