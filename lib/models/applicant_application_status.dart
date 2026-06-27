/// Host-facing application lifecycle tokens (Phase C Step 3).
enum ApplicantApplicationStatus {
  pending('pending'),
  viewingScheduled('viewing_scheduled'),
  accepted('accepted'),
  declined('declined');

  const ApplicantApplicationStatus(this.storageToken);

  final String storageToken;

  bool get isTerminal =>
      this == ApplicantApplicationStatus.accepted ||
      this == ApplicantApplicationStatus.declined;

  static ApplicantApplicationStatus? parse(String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? '';
    return switch (normalized) {
      'pending' || 'submitted' => pending,
      'viewing_scheduled' || 'viewed' || 'viewing' => viewingScheduled,
      'accepted' || 'shortlisted' || 'approved' => accepted,
      'declined' || 'rejected' => declined,
      _ => null,
    };
  }

  static ApplicantApplicationStatus parseOrDefault(String? raw) =>
      parse(raw) ?? ApplicantApplicationStatus.pending;
}
