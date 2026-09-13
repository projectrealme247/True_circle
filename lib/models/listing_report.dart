/// Reasons a seeker can select when reporting a listing (Trust & Safety Phase 1).
enum ListingReportReason {
  scamOrSuspicious('Scam or suspicious'),
  alreadyRented('Already rented'),
  duplicateListing('Duplicate listing'),
  incorrectInformation('Incorrect information'),
  inappropriateContent('Inappropriate content'),
  other('Other');

  const ListingReportReason(this.label);

  final String label;

  static ListingReportReason? fromStorage(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    for (final value in ListingReportReason.values) {
      if (value.name == trimmed || value.label == trimmed) return value;
    }
    return null;
  }
}

/// Captured listing report for future admin review (no auto-actions in Phase 1).
class ListingReport {
  const ListingReport({
    required this.id,
    required this.listingId,
    required this.reporterId,
    required this.reason,
    required this.details,
    required this.status,
    required this.createdAt,
    this.reportType = 'listing',
  });

  final String id;
  final String reportType;
  final String listingId;
  final String reporterId;
  final ListingReportReason reason;
  final String details;
  final String status;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'report_type': reportType,
        'listing_id': listingId,
        'reporter_id': reporterId,
        'reason': reason.name,
        'reason_label': reason.label,
        'details': details,
        'status': status,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory ListingReport.fromMap(Map<String, dynamic> raw) {
    final reason = ListingReportReason.fromStorage(raw['reason']?.toString()) ??
        ListingReportReason.fromStorage(raw['reason_label']?.toString()) ??
        ListingReportReason.other;
    return ListingReport(
      id: raw['id']?.toString() ?? '',
      reportType: raw['report_type']?.toString() ?? 'listing',
      listingId: raw['listing_id']?.toString() ?? '',
      reporterId: raw['reporter_id']?.toString() ?? '',
      reason: reason,
      details: raw['details']?.toString() ?? '',
      status: raw['status']?.toString() ?? 'open',
      createdAt: DateTime.tryParse(raw['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
