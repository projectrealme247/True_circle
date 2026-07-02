import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/listings_storage_service.dart';
import '../services/profile_onboarding_repository.dart';
import '../services/profile_portal_inheritance_service.dart';
import '../services/profile_storage_service.dart';
import '../services/profile_sync_boundary_service.dart';
import '../services/trust_service.dart';
import '../utils/listing_data.dart';
import '../utils/viewer_profile.dart';
import '../widgets/listing_creation/listing_creation_form.dart';
import 'auth_screen.dart';

/// Multi-step listing creation shell (Dublin market).
class AddListingScreen extends StatefulWidget {
  const AddListingScreen({
    super.key,
    this.editingListing,
    this.draftListing,
  });

  /// Full listing map when editing an existing listing.
  final Map<String, dynamic>? editingListing;

  /// Partial prefill from onboarding (location, eircode, etc.).
  final Map<String, dynamic>? draftListing;

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _formKey = GlobalKey<ListingCreationFormState>();
  bool _saving = false;
  String? _editingListingId;

  Map<String, dynamic>? get _effectiveDraftListing {
    if (widget.draftListing != null) return widget.draftListing;
    if (widget.editingListing != null) return null;
    final profile = AuthScreen.currentUserSession;
    if (profile == null || profile.isEmpty) return null;
    final snapshot = ProfileOnboardingRepository.snapshotFromSession(profile);
    if (!snapshot.track.isLandlord) return null;
    return ProfilePortalInheritanceService.listingPrefill(snapshot).toDraftMap();
  }

  @override
  void initState() {
    super.initState();
    if (widget.editingListing != null) {
      _editingListingId = ListingData.id(
        ListingData.normalizeItem(widget.editingListing!),
      );
    }
  }

  Future<void> _publish() async {
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null) return;

    final error = form.validate();
    if (error != null) {
      _showMessage(error);
      return;
    }

    setState(() => _saving = true);

    try {
      final profile =
          AuthScreen.currentUserSession ?? await ProfileStorageService.load();
      final host = ListingData.hostFieldsFromProfile(profile);
      final payload = await form.buildPayload(host, profile);
      final stamped = TrustService.stampListingTrust(payload);

      final Map<String, dynamic> saved;
      if (_editingListingId != null) {
        saved = await ListingsStorageService.updateListing(
          _editingListingId!,
          stamped,
        );
      } else {
        saved = await ListingsStorageService.addListing(stamped);
      }

      await ProfileSyncBoundaryService.syncFromListingPublish(
        currentProfile: profile,
        listingPayload: stamped,
      );

      if (!mounted) return;

      final stage = TrustService.currentStage();
      if (stage.level < TrustStage.idVerified.level) {
        await _showUpgradeNudge(stage);
        if (!mounted) return;
      }

      context.go(
        _editingListingId != null
            ? '/listing/${saved['id']}'
            : '/?refresh=${saved['id']}',
        extra: _editingListingId == null ? {'listingAdded': saved} : null,
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not save listing. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showUpgradeNudge(TrustStage current) async {
    final isCasual = current == TrustStage.casual;
    final boostPct = isCasual ? '29%' : '11%';
    final nextLabel = isCasual ? 'Verified Pro' : 'ID Verified';
    final nextRoute = isCasual ? '/verify/social' : '/verify/id';
    final nextIcon = isCasual
        ? Icons.workspace_premium_rounded
        : Icons.verified_user_rounded;
    final nextColor = isCasual
        ? const Color(0xFF7C3AED)
        : const Color(0xFF16A34A);

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF16A34A), size: 40),
            const SizedBox(height: 12),
            const Text(
              'Your listing is live!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1E21),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upgrade to $nextLabel to rank $boostPct higher',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF606770),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push(nextRoute);
                },
                icon: Icon(nextIcon, size: 20),
                label: Text('Upgrade to $nextLabel'),
                style: FilledButton.styleFrom(
                  backgroundColor: nextColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Maybe later',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _editingListingId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _saving
              ? null
              : () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(
          isEdit ? 'Edit listing' : 'Create listing',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: ListingCreationForm(
        key: _formKey,
        initialListing: widget.editingListing ?? _effectiveDraftListing,
        saving: _saving,
        onMessage: _showMessage,
        onPublish: _publish,
        onExit: _saving
            ? null
            : () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
      ),
    );
  }
}
