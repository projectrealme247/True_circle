/// Host-facing application lifecycle tokens (Phase C Step 3).
enum ApplicantApplicationStatus {
  pending('pending'),
  viewingInvitationSent('viewing_invitation_sent'),
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
      'viewing_invitation_sent' || 'invitation_sent' => viewingInvitationSent,
      'viewing_scheduled' || 'viewed' || 'viewing' => viewingScheduled,
      'accepted' || 'shortlisted' || 'approved' => accepted,
      'declined' || 'rejected' => declined,
      _ => null,
    };
  }

  static ApplicantApplicationStatus parseOrDefault(String? raw) =>
      parse(raw) ?? ApplicantApplicationStatus.pending;
}
