import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/listing_creation_payload_builder.dart';
import '../services/listing_creation_supabase_service.dart';
import '../services/listings_storage_service.dart';
import '../services/profile_onboarding_repository.dart';
import '../services/profile_portal_inheritance_service.dart';
import '../services/profile_storage_service.dart';
import '../services/profile_sync_boundary_service.dart';
import '../services/trust_service.dart';
import '../utils/listing_data.dart';
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
    if (widget.draftListing != null) {
      // Drop Independent Place profile-prefill maps; keep real drafts + Shared Living.
      if (_isIndependentPlaceProfilePrefill(widget.draftListing!)) {
        return null;
      }
      return widget.draftListing;
    }
    if (widget.editingListing != null) return null;
    final profile = AuthScreen.currentUserSession;
    if (profile == null || profile.isEmpty) return null;
    final snapshot = ProfileOnboardingRepository.snapshotFromSession(profile);
    if (!snapshot.track.isLandlord) return null;
    // Independent Place: blank Add Listing — no profile prefill inheritance.
    // Shared Living keeps listingPrefill() behavior.
    if (!snapshot.track.isSharedSpace) return null;
    return ProfilePortalInheritanceService.listingPrefill(snapshot).toDraftMap();
  }

  /// Profile onboarding seed for entire-place landlords (not a saved listing draft).
  bool _isIndependentPlaceProfilePrefill(Map<String, dynamic> raw) {
    if (!raw.containsKey('prefill_listing_mode')) return false;
    final mode = ListingData.text(raw['prefill_listing_mode']).toLowerCase();
    return mode.isNotEmpty && mode != 'shared_space';
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
      if (AuthService.isAuthenticated) {
        saved = await _publishRemote(stamped);
      } else if (_editingListingId != null) {
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

      context.go(
        _editingListingId != null
            ? '/listing/${saved['id']}'
            : '/?refresh=${saved['id']}',
        extra: _editingListingId == null ? {'listingAdded': saved} : null,
      );
    } on ListingCreationTransactionException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Could not save listing. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Map<String, dynamic>> _publishRemote(
    Map<String, dynamic> stamped,
  ) async {
    final editingId = _editingListingId;
    final Map<String, dynamic> remote;
    if (ListingCreationPayloadBuilder.isUuid(editingId)) {
      remote = await ListingCreationSupabaseService.updateListing(
        editingId!,
        stamped,
      );
    } else {
      remote = await ListingCreationSupabaseService.insertListing(stamped);
    }

    final remoteId = remote['id']?.toString() ?? '';
    final withRemoteId = {...stamped, 'id': remoteId};

    if (editingId != null &&
        editingId.isNotEmpty &&
        editingId != remoteId) {
      await ListingsStorageService.deleteListing(editingId);
      return ListingsStorageService.addListing(withRemoteId);
    }
    if (editingId != null) {
      return ListingsStorageService.updateListing(editingId, withRemoteId);
    }
    return ListingsStorageService.addListing(withRemoteId);
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
