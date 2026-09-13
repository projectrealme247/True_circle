import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../config/market/dublin_commuter_hubs.dart';
import '../config/market/market_config.dart';
import '../core/theme/app_theme.dart';
import '../models/move_in_timing.dart';
import '../models/seeker_onboarding_enums.dart';
import '../services/auth_service.dart';
import '../services/listings_storage_service.dart';
import '../services/profile_state_notifier.dart';
import '../services/profile_storage_service.dart';
import '../services/trust_service.dart';
import '../utils/listing_media.dart';
import '../utils/profile_data.dart';
import '../utils/profile_progress.dart';
import '../models/onboarding_user_role.dart';
import '../widgets/openstreetmap_attribution.dart';
import '../widgets/onboarding/onboarding_move_in_window_field.dart';
import '../widgets/profile_completion_dialog.dart';
import '../widgets/trust_badge.dart';
import '../widgets/verification_gateway_bottom_sheet.dart';
import 'auth_screen.dart';

/// Read-only profile view; loads persisted signup data from localStorage (web).
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, this.initialSession});

  /// Fresh session passed after profile edit save.
  final Map<String, dynamic>? initialSession;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _session;
  bool _loading = true;
  bool _loadFailed = false;
  int _ownedListingCount = 0;
  bool _completionPromptShown = false;

  @override
  void initState() {
    super.initState();
    authSessionNotifier.addListener(_onAuthSessionChanged);
    profileStateNotifier.addListener(_onProfileStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _enforceSeekerRoleGate();
    });
    final seeded = widget.initialSession ?? profileStateNotifier.session;
    if (seeded != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyLiveSession(seeded, loading: false);
      });
    } else {
      _loadFromStorage();
    }
  }

  void _enforceSeekerRoleGate() {
    final session = _session ??
        widget.initialSession ??
        AuthScreen.currentUserSession;
    if (!AuthService.isSignedIn(session)) {
      context.go('/');
      return;
    }
    final role = UserRole.fromSession(session);
    if (role == UserRole.landlord) {
      context.go('/landlord-dashboard');
      return;
    }
    if (role == UserRole.unassigned) {
      context.go('/');
    }
  }

  @override
  void dispose() {
    authSessionNotifier.removeListener(_onAuthSessionChanged);
    profileStateNotifier.removeListener(_onProfileStateChanged);
    super.dispose();
  }

  void _applyLiveSession(Map<String, dynamic> session, {required bool loading}) {
    AuthScreen.currentUserSession = session;
    profileStateNotifier.commitPersisted(session);
    setState(() {
      _session = Map<String, dynamic>.from(session);
      _loading = loading;
      _loadFailed = false;
    });
    _refreshOwnedListingCount(session);
  }

  void _onAuthSessionChanged() {
    if (!mounted) return;
    final live = profileStateNotifier.session ?? AuthScreen.currentUserSession;
    if (live != null && ProfileData.normalize(live) != null) {
      _applyLiveSession(live, loading: false);
      return;
    }
    _loadFromStorage();
  }

  void _onProfileStateChanged() {
    if (!mounted) return;
    final live = profileStateNotifier.session;
    if (live == null) return;
    setState(() => _session = Map<String, dynamic>.from(live));
  }

  Future<void> _refreshOwnedListingCount(Map<String, dynamic>? session) async {
    final owned = await ListingsStorageService.ownedByCurrentUser(session);
    if (!mounted) return;
    setState(() => _ownedListingCount = owned.length);
  }

  Future<void> _loadFromStorage() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });

    try {
      await AuthService.bootstrap();
      final stored = await ProfileStorageService.load();
      if (!mounted) return;

      final live = AuthScreen.currentUserSession;
      final normalized = ProfileData.normalize(live ?? stored);
      final session = normalized ?? live ?? stored;

      if (AuthService.isAuthenticated &&
          !ProfileData.isMatchingReady(session)) {
        AuthScreen.currentUserSession = session;
        final owned = await ListingsStorageService.ownedByCurrentUser(session);
        if (!mounted) return;
        if (mounted) {
          setState(() {
            _session = session;
            _ownedListingCount = owned.length;
            _loading = false;
          });
          if (!_completionPromptShown) {
            _completionPromptShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ProfileCompletionDialog.show(
                context,
                session: session,
                ownedListingCount: owned.length,
              );
            });
          }
        }
        return;
      }

      final owned = await ListingsStorageService.ownedByCurrentUser(session);
      if (!mounted) return;

      setState(() {
        // Prefer normalized display profile, but never drop a live/stored session
        // that already has seeker content (demo / partial onboarding).
        _session = normalized ?? live ?? stored;
        _ownedListingCount = owned.length;
        _loading = false;
      });

      if (_session != null && AuthScreen.currentUserSession == null) {
        AuthScreen.currentUserSession = _session;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _session = null;
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _openAuth() async {
    final signedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
    if (signedIn == true && mounted) {
      await _loadFromStorage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ProfileTheme.canvas,
      appBar: AppBar(
        backgroundColor: _ProfileTheme.canvas,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ProfileTheme.textPrimary),
          onPressed: () => _goBack(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: _ProfileTheme.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _ProfileTheme.primary),
      );
    }

    if (_loadFailed) {
      return _LoadErrorState(
        onRetry: _loadFromStorage,
        onSignIn: _openAuth,
      );
    }

    if (_session == null) {
      if (AuthService.isAuthenticated) {
        final email = AuthScreen.currentUserSession?['email']?.toString() ??
            AuthService.currentUser?.email ??
            '';
        final missing = ProfileProgress.missingFields(
          AuthScreen.currentUserSession,
          ownedListingCount: _ownedListingCount,
        );
        return _IncompleteProfile(
          email: email,
          percent: ProfileProgress.percent(
            AuthScreen.currentUserSession,
            ownedListingCount: _ownedListingCount,
          ),
          detail: missing.isEmpty
              ? 'Complete your profile to unlock tailored matching.'
              : 'Still needed: ${missing.take(4).join(', ')}.',
          onComplete: () => context.push('/profile/edit'),
        );
      }
      return _EmptyProfile(onSignIn: _openAuth);
    }

    // Full profile when any session data exists. Completion-only shell is for
    // genuinely empty profiles — not "matching essentials" gaps.
    if (!ProfileData.hasRenderableProfileContent(_session)) {
      final missing = ProfileProgress.missingFields(
        _session,
        ownedListingCount: _ownedListingCount,
      );
      return _IncompleteProfile(
        email: ProfileData.text(_session!['email']),
        percent: ProfileProgress.percent(
          _session,
          ownedListingCount: _ownedListingCount,
        ),
        detail: missing.isEmpty
            ? 'Add a few more details to unlock tailored matching.'
            : 'Still needed: ${missing.take(4).join(', ')}.',
        onComplete: () => context.push('/profile/edit', extra: _session),
      );
    }

    return _ProfileBody(session: _session!);
  }
}

class _IncompleteProfile extends StatelessWidget {
  const _IncompleteProfile({
    required this.email,
    required this.onComplete,
    this.detail,
    this.percent,
  });

  final String email;
  final VoidCallback onComplete;
  final String? detail;
  final int? percent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _ProfileLayout.maxWidthLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline_rounded, size: 56, color: _ProfileTheme.gray400),
              const SizedBox(height: 16),
              const Text('Your Profile', style: _ProfileTheme.pageTitle),
              if (percent != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Profile $percent% complete',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentDark,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                detail ??
                    (email.isNotEmpty
                        ? 'Signed in as $email. Complete your profile to unlock matching.'
                        : 'You are signed in. Complete your profile to unlock matching.'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _ProfileTheme.gray500, height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onComplete,
                style: AppButtonStyles.primaryFilled,
                child: Text(
                  'Complete profile',
                  style: AppTypography.button.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({
    required this.onRetry,
    required this.onSignIn,
  });

  final VoidCallback onRetry;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _ProfileLayout.maxWidthLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: _ProfileTheme.gray400),
              const SizedBox(height: 16),
              const Text('Could not load profile', style: _ProfileTheme.pageTitle),
              const SizedBox(height: 8),
              const Text(
                'Something went wrong reading your saved profile. You can try again or sign in.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _ProfileTheme.gray500, height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRetry,
                style: AppButtonStyles.primaryFilled,
                child: Text(
                  'Try again',
                  style: AppTypography.button.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onSignIn,
                child: const Text('Sign in / Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyProfile extends StatelessWidget {
  const _EmptyProfile({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _ProfileLayout.maxWidthLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline_rounded, size: 56, color: _ProfileTheme.gray400),
              const SizedBox(height: 16),
              const Text('Your Profile', style: _ProfileTheme.pageTitle),
              const SizedBox(height: 8),
              const Text(
                'No saved profile yet. Complete signup to see your details here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _ProfileTheme.gray500, height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onSignIn,
                style: AppButtonStyles.primaryFilled,
                child: Text(
                  'Sign in / Register',
                  style: AppTypography.button.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({required this.session});

  final Map<String, dynamic> session;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  bool _photoUploading = false;

  Map<String, dynamic> get _session => widget.session;

  void _openEdit(BuildContext context) {
    context.push('/profile/edit', extra: _session);
  }

  Future<void> _pickProfilePhoto() async {
    if (_photoUploading) return;

    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    if (bytes.length > ListingMedia.maxBytesPerImage) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo is too large (max 10 MB).')),
      );
      return;
    }

    setState(() => _photoUploading = true);
    try {
      final mime = ListingMedia.guessImageMime(file.extension) ?? 'image/jpeg';
      final updated = Map<String, dynamic>.from(_session)
        ..['profile_photo_url'] = ListingMedia.encodeBytes(bytes, mime: mime);

      AuthScreen.currentUserSession = updated;
      profileStateNotifier.commitPersisted(updated);
      await ProfileStorageService.save(updated);
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  Future<void> _pickMoveInWindow(BuildContext context) async {
    var selected = SeekerMoveInWindow.fromSession(_session);

    final saved = await showModalBottomSheet<SeekerMoveInWindow>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'When do you want to move in?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OnboardingMoveInWindowField(
                      selected: selected,
                      onChanged: (window) =>
                          setModalState(() => selected = window),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: selected == null
                          ? null
                          : () => Navigator.pop(context, selected),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (saved == null) return;

    final updated = Map<String, dynamic>.from(_session)
      ..addAll(MoveInTimingMigration.seekerPayload(saved));

    AuthScreen.currentUserSession = updated;
    profileStateNotifier.commitPersisted(updated);
    await ProfileStorageService.save(updated);
  }

  @override
  Widget build(BuildContext context) {
    final fullName = ProfileData.display(_session['full_name']);
    final persona = SeekerPersona.fromSession(_session);
    final personaLabel = persona?.chipLabel ?? '';
    final photoUrl = ProfileData.text(_session['profile_photo_url']);
    final isVerifiedUser =
        TrustService.meetsContactVerification(_session);

    final budgetLabel = _ProfileDisplay.formatBudget(_session);
    final moveInLabel = _ProfileDisplay.formatMoveInDate(_session);
    final hasMoveIn = moveInLabel.isNotEmpty;
    final commuteLabel = _ProfileDisplay.commuteHubLabel(_session);
    final hasCommute = commuteLabel.isNotEmpty;

    final otherLanguages = ProfileData.displayOtherLanguages(_session);
    final lifestyleChips = _ProfileDisplay.lifestyleChips(_session);

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _ProfileLayout.maxWidthLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PassportHeader(
                fullName: fullName,
                personaLabel: personaLabel,
                photoUrl: photoUrl,
                isVerifiedUser: isVerifiedUser,
                photoUploading: _photoUploading,
                onPhotoTap: photoUrl.isEmpty ? _pickProfilePhoto : null,
              ),
              const SizedBox(height: 12),
              _ProfileBitCard(
                title: 'The Budget Bit',
                icon: Icons.account_balance_wallet_outlined,
                child: Text(
                  budgetLabel,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: budgetLabel == _ProfileDisplay.budgetPlaceholder
                        ? _ProfileTheme.gray400
                        : _ProfileTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ProfileBitCard(
                title: 'The Commute Bit',
                icon: Icons.route_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CommuteDetailRow(
                      label: 'Move-in',
                      child: hasMoveIn
                          ? Text(
                              moveInLabel,
                              style: _ProfileTheme.fieldValue,
                            )
                          : GestureDetector(
                              onTap: () => _pickMoveInWindow(context),
                              child: const Text(
                                '+ Add window',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 14),
                    _CommuteDetailRow(
                      label: 'Daily destination',
                      child: hasCommute
                          ? Text(
                              commuteLabel,
                              style: AppTypography.withEmojiFallback(
                                _ProfileTheme.fieldValue,
                              ),
                            )
                          : GestureDetector(
                              onTap: () => _openEdit(context),
                              child: const Text(
                                '+ Add destination',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ProfileBitCard(
                title: 'The Lifestyle Bit',
                icon: Icons.auto_awesome_outlined,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final chipText in lifestyleChips)
                      _LifestyleChip(text: chipText),
                    if (otherLanguages.isEmpty)
                      _AddLanguageChip(onTap: () => _openEdit(context)),
                  ],
                ),
              ),
              if (!isVerifiedUser) ...[
                const SizedBox(height: 20),
                _TrustUpgradeSection(
                  session: _session,
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _openEdit(context),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text(
                  'Edit Profile',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ProfileTheme.primary,
                  side: const BorderSide(color: _ProfileTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: _ProfileLayout.spaceY6),
              const Text(
                'Used only for matching • never shared publicly',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: _ProfileTheme.gray500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              const OpenStreetMapAttribution(textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassportHeader extends StatelessWidget {
  const _PassportHeader({
    required this.fullName,
    required this.personaLabel,
    required this.photoUrl,
    required this.isVerifiedUser,
    required this.photoUploading,
    this.onPhotoTap,
  });

  final String fullName;
  final String personaLabel;
  final String photoUrl;
  final bool isVerifiedUser;
  final bool photoUploading;
  final VoidCallback? onPhotoTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _ProfileTheme.bitCardDecoration,
      child: Padding(
        padding: _ProfileTheme.bitCardPadding,
        child: Column(
          children: [
            GestureDetector(
              onTap: onPhotoTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _ProfileAvatar(
                      fullName: fullName,
                      photoUrl: photoUrl,
                      radius: 44,
                    ),
                    if (photoUploading)
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (photoUrl.isEmpty && onPhotoTap != null && !photoUploading)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surface, width: 2),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              fullName,
              style: _ProfileTheme.pageTitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (personaLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                personaLabel,
                textAlign: TextAlign.center,
                style: AppTypography.withEmojiFallback(
                  const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _ProfileTheme.gray500,
                    height: 1.3,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            TrustBadge(isVerified: isVerifiedUser, compact: true, outlined: true),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.fullName,
    required this.photoUrl,
    required this.radius,
  });

  final String fullName;
  final String photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = _ProfileDisplay.initials(fullName);
    final bytes = ListingMedia.decodeDataUri(photoUrl);
    final isNetwork = photoUrl.startsWith('http');

    Widget child;
    if (bytes != null) {
      child = ClipOval(
        child: Image.memory(
          bytes,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _initialsAvatar(initials),
        ),
      );
    } else if (isNetwork) {
      child = ClipOval(
        child: Image.network(
          photoUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _initialsAvatar(initials),
        ),
      );
    } else {
      child = _initialsAvatar(initials);
    }

    return child;
  }

  Widget _initialsAvatar(String initials) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _ProfileTheme.primary,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.5,
        ),
      ),
    );
  }
}

class _ProfileBitCard extends StatelessWidget {
  const _ProfileBitCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _ProfileTheme.bitCardDecoration,
      child: Padding(
        padding: _ProfileTheme.bitCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: _ProfileTheme.gray500),
                const SizedBox(width: 8),
                Text(title, style: _ProfileTheme.bitCardTitle),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _CommuteDetailRow extends StatelessWidget {
  const _CommuteDetailRow({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _ProfileTheme.fieldLabel),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _LifestyleChip extends StatelessWidget {
  const _LifestyleChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: _ProfileTheme.outlinePillDecoration,
      child: Text(
        text,
        style: AppTypography.emojiMixedTextStyle(
          color: _ProfileTheme.textPrimary,
        ),
      ),
    );
  }
}

class _AddLanguageChip extends StatelessWidget {
  const _AddLanguageChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: AppColors.accent,
            radius: 999,
            strokeWidth: 1.4,
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              '+ Add language',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustUpgradeSection extends StatelessWidget {
  const _TrustUpgradeSection({
    required this.session,
  });

  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_ProfileLayout.bitCardRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Become a Verified User',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _ProfileTheme.textPrimary,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Complete verification to unlock contact with hosts. '
              'Verified users can connect instantly.',
              style: TextStyle(
                fontSize: 13,
                color: _ProfileTheme.gray500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => VerificationGatewayBottomSheet.show(
                context,
                session: session,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _ProfileTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Verify to become a Verified User',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    const dashWidth = 5.0;
    const dashSpace = 3.5;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth;
}

abstract final class _ProfileDisplay {
  static const budgetPlaceholder = 'Add max budget';

  static String initials(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty || trimmed == ProfileData.notProvided) return '?';
    final tokens = trimmed.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length >= 2) {
      return '${tokens.first[0]}${tokens.last[0]}'.toUpperCase();
    }
    return tokens.first[0].toUpperCase();
  }

  /// Resolves `commute_destination_hub_id` via [ProfileData.commuteHub] →
  /// [DublinCommuterHubs.byId] / [DublinCommuterHubs.resolveFromProfile],
  /// then maps to emoji chip labels from [DublinCommuterHubs.seekerMacroPresets].
  static String commuteHubLabel(Map<String, dynamic> session) {
    final hub = ProfileData.commuteHub(session);
    if (hub != null) {
      for (final preset in DublinCommuterHubs.seekerMacroPresets) {
        if (preset.hub.id == hub.id) return preset.chipLabel;
      }
      return hub.label;
    }
    return ProfileData.text(session['commute_destination']);
  }

  static String formatMoveInDate(Map<String, dynamic> session) {
    final window = SeekerMoveInWindow.fromSession(session);
    if (window != null) return window.label;
    return '';
  }

  static String formatBudget(Map<String, dynamic> session) {
    final raw = session['budget_max'];
    int? value;
    if (raw is num) {
      value = raw.round();
    } else {
      value = int.tryParse(ProfileData.text(raw));
    }
    if (value == null || value <= 0) return budgetPlaceholder;
    final market = MarketConfig.current;
    return '${market.currencySymbol}${NumberFormat('#,###').format(value)}/mo';
  }

  static String foodChipLabel(Map<String, dynamic> session) {
    final food = ProfileData.text(session['food_preference']).toLowerCase();
    if (food.isEmpty) return '';
    return switch (food) {
      'veg' || 'vegetarian' || 'pure veg' => 'Veg',
      'non_veg' || 'non-veg' || 'nonveg' => 'Non-Veg',
      'eggetarian' => 'Eggetarian',
      _ => food[0].toUpperCase() + food.substring(1),
    };
  }

  static List<String> lifestyleChips(Map<String, dynamic> session) {
    final chips = <String>[];

    final food = foodChipLabel(session);
    if (food.isNotEmpty) {
      chips.add('🥗 $food');
    }

    final motherTongue = ProfileData.text(session['mother_tongue']);
    if (motherTongue.isNotEmpty) {
      chips.add('🔤 $motherTongue');
    }

    for (final language in ProfileData.displayOtherLanguages(session)) {
      chips.add('➕ $language');
    }

    if (session.containsKey('smoking_ok')) {
      final smokingOk = session['smoking_ok'] == true;
      chips.add('🚭 ${smokingOk ? 'Smoker' : 'Non-smoker'}');
    }

    if (session.containsKey('household_has_pets') ||
        session.containsKey('pets_allowed')) {
      final hasPets = session['household_has_pets'] == true ||
          session['pets_allowed'] == true;
      chips.add('🐶 ${hasPets ? 'Pet-friendly' : 'No pets'}');
    }

    return chips;
  }
}

abstract final class _ProfileLayout {
  static const maxWidthLg = 512.0;
  static const spaceY6 = 24.0;
  static const bitCardRadius = 13.0;
}

abstract final class _ProfileTheme {
  static const primary = AppColors.accent;
  static const canvas = Color(0xFFF3F4F6);
  static const textPrimary = Color(0xFF1C1E21);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);

  static final outlinePillDecoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: AppColors.divider, width: 1),
  );

  static const bitCardPadding = EdgeInsets.fromLTRB(16, 14, 16, 16);

  static final bitCardDecoration = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(_ProfileLayout.bitCardRadius),
    border: Border.all(color: AppColors.divider, width: 1),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0A000000),
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
    ],
  );

  static const pageTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const bitCardTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.2,
  );

  static const fieldLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: gray500,
    height: 1.2,
  );

  static const fieldValue = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
  );
}
