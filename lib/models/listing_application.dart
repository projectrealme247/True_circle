enum ListingApplicationStatus { pending }

class ListingApplication {
  const ListingApplication({
    required this.id,
    required this.listingId,
    required this.userId,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String listingId;
  final String userId;
  final DateTime createdAt;
  final ListingApplicationStatus status;

  factory ListingApplication.fromMap(Map<String, dynamic> map) {
    final statusRaw = map['status']?.toString() ?? 'pending';
    final status = switch (statusRaw) {
      'pending' || 'submitted' => ListingApplicationStatus.pending,
      _ => ListingApplicationStatus.pending,
    };

    return ListingApplication(
      id: map['id']?.toString() ?? '',
      listingId:
          map['listing_id']?.toString() ?? map['listingId']?.toString() ?? '',
      userId: map['user_id']?.toString() ??
          map['applicant_user_id']?.toString() ??
          '',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
              DateTime.now(),
      status: status,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'listing_id': listingId,
        'user_id': userId,
        'applicant_user_id': userId,
        'created_at': createdAt.toIso8601String(),
        'status': status.name,
      };
}
