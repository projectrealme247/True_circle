/// Lease and budget tracking for independent-places applicant queues.
class IndependentPlacesMatchMetrics {
  const IndependentPlacesMatchMetrics({
    required this.preferredLeaseMonths,
    required this.budgetMin,
    required this.budgetMax,
    required this.earliestMoveInDate,
    required this.leaseAlignmentScore,
    required this.budgetAlignmentScore,
    required this.moveInTimelineScore,
    required this.independentMatchScore,
  });

  final int? preferredLeaseMonths;
  final double? budgetMin;
  final double? budgetMax;
  final String? earliestMoveInDate;
  final int leaseAlignmentScore;
  final int budgetAlignmentScore;
  final int moveInTimelineScore;
  final int independentMatchScore;

  Map<String, dynamic> toMap() => {
        if (preferredLeaseMonths != null)
          'preferred_lease_months': preferredLeaseMonths,
        if (budgetMin != null) 'budget_min': budgetMin,
        if (budgetMax != null) 'budget_max': budgetMax,
        if (earliestMoveInDate != null)
          'earliest_move_in_date': earliestMoveInDate,
        'lease_alignment_score': leaseAlignmentScore,
        'budget_alignment_score': budgetAlignmentScore,
        'move_in_timeline_score': moveInTimelineScore,
        'independent_match_score': independentMatchScore,
      };
}
