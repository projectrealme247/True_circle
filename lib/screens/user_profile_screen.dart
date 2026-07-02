import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/listings_storage_service.dart';
import '../services/profile_state_notifier.dart';
import '../services/profile_storage_service.dart';
import '../utils/polymorphic_identity.dart';
import '../utils/profile_data.dart';
import '../utils/profile_progress.dart';
import '../utils/target_search_areas.dart';
import '../utils/trust_tier_tooltips.dart';
import '../widgets/profile_completion_dialog.dart';
import '../widgets/profile_trust_section.dart';
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
    final seeded = widget.initialSession ?? profileStateNotifier.session;
    if (seeded != null) {
      _applyLiveSession(seeded, loading: false);
    } else {
      _loadFromStorage();
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
        _session = normalized;
        _ownedListingCount = owned.length;
        _loading = false;
      });

      if (normalized != null &&
          AuthScreen.currentUserSession == null) {
        AuthScreen.currentUserSession = normalized;
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

    if (ProfileData.isProfileIncomplete(_session!)) {
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

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.session});

  final Map<String, dynamic> session;

  void _openEdit(BuildContext context) {
    context.push('/profile/edit', extra: session);
  }

  @override
  Widget build(BuildContext context) {
    final fullName = ProfileData.display(session['full_name']);
    final email = ProfileData.display(session['email']);
    final city = ProfileData.display(session['detected_city']);
    final targetAreas = TargetSearchAreas.displaySummary(
      TargetSearchAreas.hydrateFromSession(session),
    );
    final nativePlace = ProfileData.text(session['native_place']);
    final motherTongue = ProfileData.display(session['mother_tongue']);
    final isSharedRoomSeeker = ProfileData.isSharedRoomSeeker(session);
    final foodPref = ProfileData.display(session['food_preference']);
    final languages = ProfileData.displayOtherLanguages(session);
    final languagesDisplay = languages.isEmpty
        ? ProfileData.notProvided
        : languages.join(', ');
    final kitchenUsage = ProfileData.text(session['kitchen_usage_timing']);

    final emailSubtitle = ProfileData.text(session['email']);

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _ProfileLayout.maxWidthLg),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _ProfileTheme.surface,
              borderRadius: BorderRadius.circular(_ProfileLayout.cardRadius),
              border: Border.all(color: _ProfileTheme.borderSoft),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: _ProfileTheme.primary,
                        child: Text(
                          fullName.trim().isEmpty
                              ? '?'
                              : fullName.trim()[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: _ProfileTheme.pageTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (PolymorphicIdentity.showEnterpriseVerifiedSeekerBadge(
                              session,
                            )) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  PolymorphicIdentity.enterpriseVerifiedLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accentDark,
                                  ),
                                ),
                              ),
                            ],
                            if (emailSubtitle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(emailSubtitle, style: _ProfileTheme.pageSubtitle),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ProfileTrustSection(
                    session: session,
                    actionColor: _ProfileTheme.coralRose,
                    tierTooltipForLabel: TrustTierTooltips.forBadgeLabel,
                  ),
                  const SizedBox(height: _ProfileLayout.spaceY6),
                  const _SectionDivider(),
                  const SizedBox(height: _ProfileLayout.spaceY6),
                  _ProfileSectionBlock(
                    title: 'Basic info',
                    children: [
                      _ProfileField(label: 'Full name', value: fullName),
                      _ProfileField(label: 'Email', value: email),
                      _ProfileField(label: 'Your current location', value: city),
                    ],
                  ),
                  const SizedBox(height: _ProfileLayout.spaceY6),
                  const _SectionDivider(),
                  const SizedBox(height: _ProfileLayout.spaceY6),
                  _ProfileSectionBlock(
                    title: 'Community info',
                    children: [
                      _ProfileField(label: 'Mother tongue', value: motherTongue),
                      _ProfileField(label: 'Other languages', value: languagesDisplay),
                    ],
                  ),
                  if (nativePlace.isNotEmpty) ...[
                    const SizedBox(height: _ProfileLayout.spaceY6),
                    const _SectionDivider(),
                    const SizedBox(height: _ProfileLayout.spaceY6),
                    _ProfileSectionBlock(
                      title: 'About you',
                      subtitle:
                          'Optional — hometown or native place for your bio and icebreakers',
                      children: [
                        _ProfileField(label: 'Native place', value: nativePlace),
                      ],
                    ),
                  ],
                  const SizedBox(height: _ProfileLayout.spaceY6),
                  const _SectionDivider(),
                  const SizedBox(height: _ProfileLayout.spaceY6),
                  _ProfileSectionBlock(
                    title: 'Search preferences',
                    children: [
                      _ProfileField(
                        label: 'Target search areas',
                        value: targetAreas,
                      ),
                      if (isSharedRoomSeeker) ...[
                        _ProfileField(label: 'Food preference', value: foodPref),
                        if (kitchenUsage.isNotEmpty)
                          _ProfileField(
                            label: 'Kitchen usage',
                            value: ProfileData.display(kitchenUsage),
                          ),
                      ],
                    ],
                  ),
                  const SizedBox(height: _ProfileLayout.spaceY6),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSectionBlock extends StatelessWidget {
  const _ProfileSectionBlock({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: _ProfileTheme.sectionHeader),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: _ProfileTheme.pageSubtitle),
        ],
        const SizedBox(height: 16),
        ...children.expand((child) => [child, const SizedBox(height: 20)]).toList()
          ..removeLast(),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isMuted = ProfileData.isNotProvided(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _ProfileTheme.fieldLabel),
        const SizedBox(height: 4),
        Text(
          value,
          style: isMuted ? _ProfileTheme.fieldValueMuted : _ProfileTheme.fieldValue,
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: _ProfileTheme.borderSoft);
  }
}

abstract final class _ProfileLayout {
  static const maxWidthLg = 512.0;
  static const spaceY6 = 24.0;
  static const cardRadius = 16.0;
}

abstract final class _ProfileTheme {
  static const primary = AppColors.accent;
  static const coralRose = AppColors.accent;
  static const canvas = Color(0xFFF3F4F6);
  static const surface = Color(0xFFFFFFFF);
  static const borderSoft = Color(0xFFE5E7EB);
  static const textPrimary = Color(0xFF1C1E21);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);

  static const pageTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const pageSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: gray500,
    height: 1.35,
  );

  static const sectionHeader = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: gray500,
    letterSpacing: 0.6,
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

  static const fieldValueMuted = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: gray400,
    height: 1.3,
  );
}
