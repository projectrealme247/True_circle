import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/profile_storage_service.dart';
import '../utils/profile_data.dart';
import 'auth_screen.dart';

/// Read-only profile view; loads persisted signup data from localStorage (web).
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _session;
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });

    try {
      final stored = await ProfileStorageService.load();
      if (!mounted) return;

      final normalized = ProfileData.normalize(stored);
      setState(() {
        _session = normalized;
        _loading = false;
      });

      if (normalized != null) {
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
      return _EmptyProfile(onSignIn: _openAuth);
    }

    return _ProfileBody(session: _session!);
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
                style: FilledButton.styleFrom(
                  backgroundColor: _ProfileTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                child: const Text('Try again', style: TextStyle(fontWeight: FontWeight.w700)),
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
                style: FilledButton.styleFrom(
                  backgroundColor: _ProfileTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sign in / Register',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
    final nativePlace = ProfileData.display(session['native_place']);
    final motherTongue = ProfileData.display(session['mother_tongue']);
    final foodPref = ProfileData.display(session['food_preference']);
    final languages = ProfileData.displayLanguages(session['spoken_languages']);

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
                            if (emailSubtitle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(emailSubtitle, style: _ProfileTheme.pageSubtitle),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _ProfileLayout.spaceY6),
                  const _SectionDivider(),
                  const SizedBox(height: _ProfileLayout.spaceY6),
                  _ProfileSectionBlock(
                    title: 'Basic info',
                    children: [
                      _ProfileField(label: 'Full name', value: fullName),
                      _ProfileField(label: 'Email', value: email),
                      _ProfileField(label: 'Current city', value: city),
                    ],
                  ),
                  const SizedBox(height: _ProfileLayout.spaceY6),
                  const _SectionDivider(),
                  const SizedBox(height: _ProfileLayout.spaceY6),
                  _ProfileSectionBlock(
                    title: 'Community info',
                    children: [
                      _ProfileField(label: 'Mother tongue', value: motherTongue),
                      _ProfileField(label: 'Other languages', value: languages),
                      _ProfileField(label: 'Native place', value: nativePlace),
                    ],
                  ),
                  const SizedBox(height: _ProfileLayout.spaceY6),
                  const _SectionDivider(),
                  const SizedBox(height: _ProfileLayout.spaceY6),
                  _ProfileSectionBlock(
                    title: 'Preferences',
                    children: [
                      _ProfileField(label: 'Food preference', value: foodPref),
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
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: _ProfileTheme.sectionHeader),
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
  static const primary = Color(0xFF0EA5E9);
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
