import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart' show AppColors, AppButtonStyles;
import '../models/marketplace_space.dart';
import '../services/listing_applications_service.dart';
import '../services/listings_storage_service.dart';
import '../theme/app_typography.dart';
import '../theme/home_marketplace_theme.dart';
import '../utils/full_rental_applicant_scorer.dart';
import '../utils/listing_data.dart';
import '../utils/numeric_bounds.dart';
import '../utils/profile_data.dart';
import '../utils/shared_space_compatibility_scorer.dart';
import '../widgets/tenant_profile_card.dart';

class ListingManageScreen extends StatefulWidget {
  const ListingManageScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<ListingManageScreen> createState() => _ListingManageScreenState();
}

class _ListingManageScreenState extends State<ListingManageScreen> {
  Map<String, dynamic>? _listing;
  List<Map<String, dynamic>> _applications = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final listing = await ListingsStorageService.getById(widget.listingId);
    final applications =
        await ListingApplicationsService.forListing(widget.listingId);
    if (!mounted) return;
    setState(() {
      _listing = listing;
      _applications = applications;
      _loading = false;
    });
  }

  List<({Map<String, dynamic> session, int score})> get _rankedApplicants {
    final listing = _listing;
    if (listing == null) return const [];

    final isShare = ListingData.propertyType(listing) == 'Share';
    final sessions = _applications
        .map((a) => a['payload'])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    if (isShare) {
      return [
        for (final session in sessions)
          (
            session: session,
            score: SharedSpaceCompatibilityScorer.calculateCompatibility(
              seekerSession: session,
              listing: listing,
            ),
          ),
      ]..sort((a, b) => b.score.compareTo(a.score));
    }

    final ranked = FullRentalApplicantScorer.rankApplicantSessions(
      sessions: sessions,
      listing: listing,
    );
    return [
      for (final row in ranked)
        (session: row.session, score: row.score.finalScore),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeMarketplaceTheme.canvas,
      appBar: AppBar(
        backgroundColor: HomeMarketplaceTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(
          'Manage listing',
          style: AppTypography.sectionTitle().copyWith(fontSize: 18),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _listing == null
              ? const Center(child: Text('Listing not found'))
              : _buildBody(_listing!),
    );
  }

  Widget _buildBody(Map<String, dynamic> listing) {
    final isShare = ListingData.propertyType(listing) == 'Share';
    final ranked = _rankedApplicants;
    final hidden = isShare
        ? 0
        : FullRentalApplicantScorer.countHiddenApplicantSessions(
            sessions: _applications
                .map((a) => a['payload'])
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList(),
            listing: listing,
          );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(ListingData.title(listing), style: AppTypography.sectionTitle()),
        const SizedBox(height: 4),
        Text(
          '${ListingData.price(listing)} · ${ListingData.location(listing)}',
          style: AppTypography.detail(),
        ),
        const SizedBox(height: 16),
        Text(
          isShare ? 'Room match queue' : 'Applicant queue',
          style: AppTypography.cardTitle(),
        ),
        if (hidden > 0) ...[
          const SizedBox(height: 8),
          Text(
            '$hidden applicants hidden — did not pass income or commute gates',
            style: AppTypography.detail(),
          ),
        ],
        const SizedBox(height: 16),
        if (ranked.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HomeMarketplaceTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HomeMarketplaceTheme.border),
            ),
            child: Text(
              'No applications yet.',
              style: AppTypography.detail(),
            ),
          )
        else
          for (final row in ranked)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TenantProfileCard(
                name: ProfileData.text(row.session['full_name']).isEmpty
                    ? 'Applicant'
                    : ProfileData.text(row.session['full_name']),
                subtitle: ProfileData.text(row.session['detected_city']),
                checklistScore: NumericBounds.clampPercentInt(row.score),
                scoreLabel: isShare ? null : '${row.score}/100 checklist',
              ),
            ),
      ],
    );
  }
}
