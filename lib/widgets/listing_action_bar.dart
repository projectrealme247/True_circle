import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart' show AppButtonStyles;
import '../debug/agent_log.dart';
import '../theme/app_typography.dart';
import '../models/marketplace_space.dart';
import '../services/listings_storage_service.dart';
import '../services/replacement_workflow_service.dart';
import '../utils/listing_data.dart';
import '../utils/profile_data.dart';

enum ListingViewerRelation { viewer, owner, replacingOwner }

/// Owner vs viewer CTAs on listing detail.
class ListingActionBar extends StatelessWidget {
  const ListingActionBar({
    super.key,
    required this.listing,
    required this.session,
    required this.space,
    required this.hasApplied,
    required this.onApply,
    required this.onManage,
    required this.onStartReplacement,
    required this.onVerifyToApply,
  });

  final Map<String, dynamic> listing;
  final Map<String, dynamic>? session;
  final MarketplaceSpace space;
  final bool hasApplied;
  final VoidCallback onApply;
  final VoidCallback onManage;
  final VoidCallback onStartReplacement;
  final VoidCallback onVerifyToApply;

  static Future<ListingViewerRelation> resolveRelation({
    required Map<String, dynamic> listing,
    required Map<String, dynamic>? session,
  }) async {
    if (session == null) return ListingViewerRelation.viewer;
    final userId = ProfileData.text(session['supabase_user_id']);
    final fullName = ProfileData.text(session['full_name']).toLowerCase();
    for (final key in ['owner_user_id', 'user_id', 'landlord_id']) {
      if (ProfileData.text(listing[key]) == userId && userId.isNotEmpty) {
        final replacement = await ReplacementWorkflowService.activeForUser(
          session,
        );
        if (replacement != null &&
            replacement.listingId == ListingData.id(listing)) {
          return ListingViewerRelation.replacingOwner;
        }
        return ListingViewerRelation.owner;
      }
    }
    final host = ListingData.hostName(listing).trim().toLowerCase();
    if (fullName.isNotEmpty && host == fullName) {
      return ListingViewerRelation.owner;
    }
    return ListingViewerRelation.viewer;
  }

  static bool isOwnedListing(
    Map<String, dynamic> listing,
    Map<String, dynamic>? session,
  ) {
    final owned = ListingsStorageService.isOwnedBySession(listing, session);
    // #region agent log
    agentLog(
      location: 'listing_action_bar.dart:isOwnedListing',
      message: 'Ownership resolution',
      hypothesisId: 'H4',
      data: {
        'owned': owned,
        'sessionUserId': ProfileData.text(session?['supabase_user_id']),
        'sessionEmail': ProfileData.text(session?['email']),
        'sessionName': ProfileData.text(session?['full_name']),
        'ownerUserId': ProfileData.text(listing['owner_user_id']),
        'landlordId': ProfileData.text(listing['landlord_id']),
        'ownerEmail': ProfileData.text(listing['owner_email']),
        'hostName': ListingData.hostName(listing),
        'listingId': ListingData.id(listing),
      },
    );
    // #endregion
    return owned;
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = isOwnedListing(listing, session);
    final isShare = space == MarketplaceSpace.sharedSpace;
    final applyLabel = isShare ? 'Apply for room' : 'Apply';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isOwner) ...[
          _primaryCta(
            onPressed: onManage,
            icon: const Icon(Icons.groups_outlined, size: 20),
            label: Text(
              isShare ? 'View matches' : 'View applicants',
              style: AppTypography.button(),
            ),
          ),
          if (isShare) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onStartReplacement,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Start lease replacement'),
            ),
          ],
        ] else if (hasApplied) ...[
          _primaryCta(
            onPressed: null,
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: const Text('Application sent'),
          ),
        ] else ...[
          _primaryCta(
            onPressed: session == null ? onVerifyToApply : onApply,
            icon: Icon(
              session == null ? Icons.login_rounded : Icons.send_rounded,
              size: 20,
            ),
            label: Text(session == null ? 'Sign in to apply' : applyLabel),
          ),
          if (session != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Your profile and match score are shared with this landlord. '
              'Contact details stay private until they shortlist you.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ],
    );
  }

  Widget _primaryCta({
    required VoidCallback? onPressed,
    required Widget icon,
    required Widget label,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: AppButtonStyles.primaryFilled,
        icon: icon,
        label: label,
      ),
    );
  }
}
