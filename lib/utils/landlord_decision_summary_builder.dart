import '../models/applicant_field_keys.dart';
import '../models/applicant_trust_tier.dart';
import '../models/landlord_decision_summary.dart';
import '../models/move_in_timing.dart';
import '../models/seeker_onboarding_enums.dart';
import '../services/trust_service.dart';
import 'applicant_household.dart';
import 'numeric_bounds.dart';
import 'preferred_layout_match.dart';
import 'profile_data.dart';

/// Builds [LandlordDecisionSummary] from seeker session + listing (no raw income).
abstract final class LandlordDecisionSummaryBuilder {
  LandlordDecisionSummaryBuilder._();

  static LandlordDecisionSummary fromSession({
    required Map<String, dynamic> session,
    required Map<String, dynamic> listing,
    required bool isSharedLiving,
    ApplicantTrustTier? trustTier,
    int? lifestyleMatchPercent,
    List<String> languageOverlap = const [],
    bool? kitchenCultureAligned,
    bool? leaseTermMatch,
    int? preferredLeaseMonths,
    bool? employmentVerified,
    bool? financialVerified,
    String? commuteLabel,
  }) {
    final tier = trustTier ?? ApplicantTrustTier.fromSession(session);

    final layoutMatch = PreferredLayoutMatch.fromSession(
      seekerSession: session,
      listing: listing,
    );
    final timing = MoveInTimingEngine.evaluate(
      seekerSession: session,
      listing: listing,
    );
    final moveInWindow = SeekerMoveInWindow.fromSession(session);

    final adults = session['family_adults'] is int
        ? session['family_adults'] as int
        : null;
    final children = session['family_children'] is int
        ? session['family_children'] as int
        : null;
    final groupSize =
        session['group_size'] is int ? session['group_size'] as int : null;
    final persona = SeekerPersona.fromSession(session);
    final isCouple = _resolveCouple(
      persona: persona,
      groupSize: groupSize,
      adults: adults,
      children: children,
    );

    final emp = employmentVerified ??
        session[ApplicantFieldKeys.employmentVerified] == true;
    final fin = financialVerified ??
        session[ApplicantFieldKeys.financialVerified] == true;
    final idVerified = TrustService.meetsContactVerification(session);

    final multiplier = _affordabilityMultiplier(
      session: session,
      listing: listing,
    );
    final affordabilityVerified = fin ||
        session[ApplicantFieldKeys.affordabilityMultiplier] != null;

    final smokingOk = session['smoking_ok'] == true ||
        session['household_smoker'] == true;
    final listingNoSmoking = listing['smoking_allowed'] == false ||
        ProfileData.text(listing['lifestyle_flags']).toLowerCase().contains(
              'no_smoking',
            );
    final hasPets = session['household_has_pets'] == true ||
        session['has_pets'] == true;

    bool? foodCompatible;
    if (isSharedLiving) {
      foodCompatible = kitchenCultureAligned;
    }

    bool? smokingCompatible;
    if (isSharedLiving) {
      smokingCompatible = listingNoSmoking ? !smokingOk : true;
    }

    return LandlordDecisionSummary(
      isSharedLiving: isSharedLiving,
      affordabilityMultiplier: multiplier,
      affordabilityVerified: affordabilityVerified,
      moveInQuality: timing.quality,
      moveInWindowLabel: moveInWindow?.label ?? '',
      propertyRequirementMatch: layoutMatch.matches,
      propertyRequirementLabel: layoutMatch.seekerLabel.isEmpty
          ? 'Layout not specified'
          : '${layoutMatch.seekerLabel} → ${layoutMatch.listingLabel}'
              '${layoutMatch.matches ? ' · match' : ' · mismatch'}',
      trustTier: tier,
      idVerified: idVerified,
      employmentVerified: emp,
      incomeVerified: fin,
      peerReferenceAvailable: session['peer_reference_verified'] == true,
      familyAdults: adults,
      familyChildren: children,
      groupSize: groupSize,
      isCouple: isCouple,
      householdHasPets: hasPets,
      preferredLeaseMonths: preferredLeaseMonths ??
          (session['preferred_lease_months'] is int
              ? session['preferred_lease_months'] as int
              : int.tryParse(
                  ProfileData.text(session['preferred_lease_months']),
                )),
      leaseTermMatch: leaseTermMatch ?? false,
      guarantorStatus: GuarantorStatus.fromSession(session),
      foodCompatible: foodCompatible,
      smokingCompatible: smokingCompatible,
      languageOverlap: languageOverlap,
      lifestyleMatchPercent: lifestyleMatchPercent,
      commuteLabel: commuteLabel,
    );
  }

  static bool? _resolveCouple({
    required SeekerPersona? persona,
    required int? groupSize,
    required int? adults,
    required int? children,
  }) {
    if (children != null && children > 0) return false;
    if (adults != null) return adults == 2;
    if (groupSize == 2 &&
        (persona == SeekerPersona.professional ||
            persona == SeekerPersona.relocating)) {
      return true;
    }
    return null;
  }

  /// Returns a positive income÷rent multiplier, or `0` when unknown.
  /// Callers must treat `0` as [LandlordDecisionSummary.hasAffordability] == false
  /// — never invent trust-tier placeholders.
  static double _affordabilityMultiplier({
    required Map<String, dynamic> session,
    required Map<String, dynamic> listing,
  }) {
    final explicit = session[ApplicantFieldKeys.affordabilityMultiplier] ??
        session['affordability_multiplier'];
    if (explicit is num && explicit > 0) {
      return NumericBounds.finiteOrZero(
        (explicit.toDouble() * 10).roundToDouble() / 10,
      );
    }

    final rent = _listingMonthlyRent(listing);
    if (rent != null && rent > 0) {
      final pooled = ApplicantHousehold.fromMap(session).pooledNetIncome;
      if (pooled > 0) {
        return NumericBounds.finiteOrZero(
          ((pooled / rent) * 10).roundToDouble() / 10,
        );
      }
      final salaryRaw = session['annual_salary'];
      if (salaryRaw is num && salaryRaw > 0) {
        return NumericBounds.finiteOrZero(
          (((salaryRaw / 12) / rent) * 10).roundToDouble() / 10,
        );
      }
    }

    return 0;
  }

  static double? _listingMonthlyRent(Map<String, dynamic> listing) {
    final price = ProfileData.text(listing['price']);
    if (price.isEmpty) return null;
    final digits = price.replaceAll(RegExp(r'[^\d.]'), '');
    if (digits.isEmpty) return null;
    return double.tryParse(digits);
  }
}
