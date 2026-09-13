import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/onboarding_user_intent.dart';
import '../models/profile_onboarding_models.dart';
import '../screens/auth_screen.dart';
import '../services/auth_service.dart';
import '../services/marketplace_context_notifier.dart';
import '../services/profile_onboarding_repository.dart';
import '../services/profile_storage_service.dart';
import '../utils/applicant_session_sync.dart';
import '../utils/profile_data.dart';
import '../widgets/onboarding/landlord/landlord_onboarding_form.dart';
import '../widgets/onboarding/onboarding_content_shell.dart';
import '../widgets/onboarding/onboarding_design_tokens.dart';
import '../widgets/truecircle_logo.dart';

/// Shared Living host onboarding — name only.
/// Independent Place hosts skip this screen; name is collected on Add Listing.
class LandlordOnboardingScreen extends StatefulWidget {
  const LandlordOnboardingScreen({super.key, this.initialProfile});

  final Map<String, dynamic>? initialProfile;

  @override
  State<LandlordOnboardingScreen> createState() =>
      _LandlordOnboardingScreenState();
}

class _LandlordOnboardingScreenState extends State<LandlordOnboardingScreen> {
  final _nameController = TextEditingController();
  bool _hydrating = true;
  Map<String, dynamic>? _baselineProfile;

  static const _selectedTrack = ProfileOnboardingTrack.landlordSharedSpace;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final loaded =
        widget.initialProfile ?? await ProfileStorageService.load();
    var session = loaded ?? AuthScreen.currentUserSession;
    if (session != null) {
      session = await ProfileOnboardingRepository.ensureLegacyHostTrackPersisted(
        Map<String, dynamic>.from(session),
      );
      _baselineProfile = Map<String, dynamic>.from(session);
      AuthScreen.currentUserSession = _baselineProfile;
      final name = ProfileData.text(session['full_name']);
      if (name.isNotEmpty) _nameController.text = name;
    }
    if (mounted) setState(() => _hydrating = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool _validate() {
    if (_nameController.text.trim().isEmpty) {
      _showMessage('Please enter your full name.');
      return false;
    }
    return true;
  }

  Map<String, dynamic> _buildPayload() {
    final baseline = Map<String, dynamic>.from(
      _baselineProfile ?? AuthScreen.currentUserSession ?? {},
    );
    const listingMode = 'shared_space';
    final fullName = _nameController.text.trim();

    return ApplicantSessionSync.enrich({
      ...baseline,
      'full_name': fullName,
      'onboarding_intent': OnboardingUserIntent.provider.storageToken,
      'profile_onboarding_track': _selectedTrack.storageToken,
      'active_marketplace_space':
          MarketplaceContextNotifier.spaceFromOnboardingTrack(_selectedTrack)
              .storageToken,
      'host_profile_complete': true,
      'listingSeed_listingMode': listingMode,
      'identityProfile': {
        'email': ProfileData.text(baseline['email']),
        'fullName': fullName,
      },
      'listingSeed': {
        'listingMode': listingMode,
      },
    });
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    final synced = await AuthService.persistProfileSession(_buildPayload());
    await marketplaceContextNotifier.syncSpaceFromOnboardingTrack(
      _selectedTrack,
    );
    if (!mounted) return;
    setState(() {
      _baselineProfile = Map<String, dynamic>.from(synced);
    });
    _showMessage('Host profile saved — let\'s create your listing.');
    context.go('/add-listing');
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: OnboardingTokens.canvasBg,
        appBar: AppBar(
          backgroundColor: OnboardingTokens.canvasBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Back',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          titleSpacing: 12,
          title: const Align(
            alignment: Alignment.centerLeft,
            child: TrueCircleHomeLogoButton(markSize: 26),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: OnboardingTokens.inputBorder,
            ),
          ),
        ),
        body: _hydrating
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2B4C7E)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        OnboardingTokens.contentPaddingH,
                        32,
                        OnboardingTokens.contentPaddingH,
                        16,
                      ),
                      child: OnboardingContentShell(
                        child: LandlordOnboardingForm(
                          nameController: _nameController,
                          onNameChanged: () => setState(() {}),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
                      child: Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: OnboardingTokens.contentMaxWidth,
                          ),
                          child: FilledButton(
                            onPressed: _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 14,
                              ),
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Create your listing →',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
