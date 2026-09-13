import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../data/mock_landlord_data.dart';
import '../models/application_conversation.dart';
import '../models/landlord_engine_models.dart';
import '../utils/profile_data.dart';
import 'application_conversation_screen.dart';
import 'auth_screen.dart';
import '../widgets/landlord_dashboard/landlord_dashboard_theme.dart';
import '../widgets/landlord_dashboard/landlord_dashboard_top_nav.dart';
import '../widgets/landlord_decision_engine/decision_col.dart';
import '../widgets/landlord_decision_engine/listing_col.dart';
import '../widgets/landlord_decision_engine/triage_col.dart';

/// Landlord decision engine — scaffold + fixed 3-column workspace shell.
///
/// Column widgets:
/// - Col 1: [ListingCol]
/// - Col 2: [TriageCol]
/// - Col 3: [DecisionCol]
class LandlordDecisionEngineScreen extends StatefulWidget {
  const LandlordDecisionEngineScreen({
    super.key,
    this.listings,
  });

  /// When null, uses [MockLandlordData.listings].
  final List<Listing>? listings;

  @override
  State<LandlordDecisionEngineScreen> createState() =>
      _LandlordDecisionEngineScreenState();
}

class _LandlordDecisionEngineScreenState
    extends State<LandlordDecisionEngineScreen> {
  int _selectedListingIndex = 0;
  int? _selectedApplicantIndex;

  static const double _maxWorkspaceWidth = 1360;
  static const double _decisionColMaxWidth = 560;

  List<Listing> get _listings => widget.listings ?? MockLandlordData.listings;

  Listing? get _selectedListing {
    if (_listings.isEmpty) return null;
    final i = _selectedListingIndex.clamp(0, _listings.length - 1);
    return _listings[i];
  }

  List<Applicant> get _applicants => _selectedListing?.applicants ?? const [];

  Applicant? get _selectedApplicant {
    final apps = _applicants;
    if (apps.isEmpty) return null;
    final i = (_selectedApplicantIndex ?? 0).clamp(0, apps.length - 1);
    return apps[i];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LandlordDashboardTheme.canvas,
      appBar: const LandlordDashboardTopNav(),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWorkspaceWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: _buildWorkspace(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspace() {
    return Container(
      decoration: BoxDecoration(
        color: LandlordDashboardTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: LandlordDashboardTheme.border),
        boxShadow: [
          BoxShadow(
            color: LandlordDashboardTheme.ink.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 980;
          if (narrow) {
            return _buildNarrowLayout();
          }
          return _buildWideLayout();
        },
      ),
    );
  }

  Widget _buildListingCol() {
    return ListingCol(
      listings: _listings,
      selectedIndex: _listings.isEmpty
          ? 0
          : _selectedListingIndex.clamp(0, _listings.length - 1),
      onSelected: (index) {
        setState(() {
          _selectedListingIndex = index;
          _selectedApplicantIndex = null;
        });
      },
    );
  }

  Widget _buildTriageCol() {
    final listing = _selectedListing;
    return TriageCol(
      listingType: listing?.type ?? ListingType.entirePlace,
      applicants: _applicants,
      selectedId: _selectedApplicant?.id,
      onSelect: (applicant) {
        final idx = _applicants.indexWhere((a) => a.id == applicant.id);
        setState(() => _selectedApplicantIndex = idx >= 0 ? idx : null);
      },
    );
  }

  Widget _buildDecisionCol() {
    final listing = _selectedListing;
    final applicant = _selectedApplicant;
    if (listing == null) {
      return const _EmptyDecisionPane(
        title: 'No listings yet',
        body: 'Add a listing to start deciding who to invite.',
      );
    }
    if (applicant == null) {
      return const _EmptyDecisionPane(
        title: 'No applicants in this queue',
        body:
            'When seekers apply, they appear here so you can invite, review, or dismiss.',
      );
    }
    return DecisionCol(
      applicant: applicant,
      listingType: listing.type,
      onInvite: () {
        final invited = applicant.verdict == DecisionVerdict.viewingInvited;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              invited
                  ? 'Invite resent to ${applicant.name}'
                  : 'Invite sent to ${applicant.name}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onMessage: () {
        context.push(
          ApplicationConversationScreen.locationFor(applicant.id),
          extra: ApplicationConversationRouteArgs(
            listingId: listing.id,
            applicantUserId: '',
            hostUserId: ProfileData.text(
              AuthScreen.currentUserSession?['supabase_user_id'],
            ),
            viewerRole: ApplicationParticipantRole.host,
            listingTitle: listing.title,
            peerName: applicant.name,
          ),
        );
      },
      onDismiss: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${applicant.name} dismissed from this decision.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildListingCol(),
        _buildTriageCol(),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _decisionColMaxWidth),
            child: _buildDecisionCol(),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 160, child: _buildListingCol()),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTriageCol(),
              Expanded(child: _buildDecisionCol()),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyDecisionPane extends StatelessWidget {
  const _EmptyDecisionPane({
    this.title = 'Pick someone from the queue',
    this.body = 'Select an applicant to decide who to invite next.',
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LandlordDashboardTheme.surfaceRaised,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '✨',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                height: 1,
                fontFamily: AppTypography.emojiFontFamily,
                fontFamilyFallback: AppTypography.emojiFontFallback,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: LandlordDashboardTheme.personName(size: 18).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: LandlordDashboardTheme.cardSubtext().copyWith(
                fontSize: 14,
                height: 1.45,
                color: LandlordDashboardTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
