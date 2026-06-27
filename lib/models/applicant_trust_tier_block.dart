import 'applicant_trust_tier.dart';

/// Trust-tier grouped applicant rows for stream table payloads.
class ApplicantTrustTierBlock<T> {
  const ApplicantTrustTierBlock({
    required this.trustTier,
    required this.applicants,
  });

  final ApplicantTrustTier trustTier;
  final List<T> applicants;

  int get count => applicants.length;

  Map<String, dynamic> toMap(Map<String, dynamic> Function(T row) rowMapper) =>
      {
        'trust_tier': trustTier.displayToken,
        'count': count,
        'applicants': applicants.map(rowMapper).toList(),
      };
}
