import 'package:flutter/material.dart';

import '../screens/auth_screen.dart';
import '../services/auth_service.dart';
import '../utils/listing_commute_display.dart';
import '../widgets/commute_score_badge.dart';
import 'listing_detail_tokens.dart';

/// Async Dublin transit block for listing detail — label only when content exists.
class ListingDetailCommuteSection extends StatefulWidget {
  const ListingDetailCommuteSection({
    super.key,
    required this.listing,
    required this.userSession,
  });

  final Map<String, dynamic> listing;
  final Map<String, dynamic>? userSession;

  @override
  State<ListingDetailCommuteSection> createState() =>
      _ListingDetailCommuteSectionState();
}

class _ListingDetailCommuteSectionState extends State<ListingDetailCommuteSection> {
  Future<MultiCommuteDisplayModel?>? _commuteFuture;

  @override
  void initState() {
    super.initState();
    authSessionNotifier.addListener(_onSessionChanged);
    _refreshCommuteFuture();
  }

  @override
  void didUpdateWidget(covariant ListingDetailCommuteSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listing['id'] != widget.listing['id'] ||
        oldWidget.userSession != widget.userSession) {
      _refreshCommuteFuture();
    }
  }

  @override
  void dispose() {
    authSessionNotifier.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(_refreshCommuteFuture);
  }

  void _refreshCommuteFuture() {
    final session = widget.userSession ?? AuthScreen.currentUserSession;
    _commuteFuture = ListingCommuteDisplay.resolveAsync(
      listing: widget.listing,
      viewerSession: session,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MultiCommuteDisplayModel?>(
      future: _commuteFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final display = snapshot.data;
        if (display == null || display.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'TRANSIT & COMMUTE',
              style: ListingDetailTokens.sectionLabel,
            ),
            const SizedBox(height: 8),
            CommuteScoreBadge(display: display),
          ],
        );
      },
    );
  }
}
