import '../../models/listing_application.dart';
import '../../utils/seeker_application_pipeline.dart';
import '../../utils/seeker_property_context.dart';

/// Row data for the seeker application queue (column 2).
class SeekerApplicationQueueItem {
  const SeekerApplicationQueueItem({
    required this.application,
    required this.propertyTitle,
    required this.statusLabel,
    required this.appliedLabel,
    required this.activityPreview,
    required this.hostName,
    required this.hostUserId,
    this.locationLabel = '',
    this.rentLabel = '',
    this.propertyKindLabel = '',
    this.unreadCount = 0,
    this.lastFromHost = false,
    this.listingIsActive = true,
  });

  final ListingApplication application;
  final String propertyTitle;
  final String statusLabel;
  final String appliedLabel;
  final String activityPreview;
  final String hostName;
  final String hostUserId;
  final String locationLabel;
  final String rentLabel;
  final String propertyKindLabel;
  final int unreadCount;
  final bool lastFromHost;

  /// False when the listing is inactive (`is_active = false`) or unavailable.
  final bool listingIsActive;

  bool get isArchived => !listingIsActive;

  String get applicationId => application.id;
  String get listingId => application.listingId;
  String get applicantUserId => application.userId;

  String get queueActivityLine {
    if (isArchived) return 'Conversation archived';
    if (unreadCount > 0) {
      return lastFromHost ? '💬 Host replied' : '💬 New message';
    }
    if (activityPreview.isEmpty) return '';
    if (lastFromHost) return '💬 Host replied';
    return activityPreview;
  }

  factory SeekerApplicationQueueItem.fromApplication({
    required ListingApplication application,
    required String propertyTitle,
    required String hostName,
    required String hostUserId,
    Map<String, dynamic>? listing,
    bool? listingIsActive,
  }) {
    final property = SeekerPropertyContext.fromListing(listing);
    final active =
        listingIsActive ?? SeekerApplicationPipeline.isListingActive(listing);

    return SeekerApplicationQueueItem(
      application: application,
      propertyTitle: propertyTitle,
      statusLabel: SeekerApplicationPipeline.workspaceStatusDisplay(
        application,
        listingIsActive: active,
      ),
      appliedLabel:
          'Applied ${SeekerApplicationPipeline.formatAppliedDate(application.createdAt)}',
      activityPreview: SeekerApplicationPipeline.activityPreview(application),
      hostName: hostName,
      hostUserId: hostUserId,
      locationLabel: property.locationLabel,
      rentLabel: property.rentLabel,
      propertyKindLabel: property.propertyKindLabel,
      unreadCount: active
          ? SeekerApplicationPipeline.unreadCount(application)
          : 0,
      lastFromHost: SeekerApplicationPipeline.lastMessageFromHost(application),
      listingIsActive: active,
    );
  }
}
