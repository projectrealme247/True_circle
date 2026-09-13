import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../config/market/market_config.dart';
import '../core/theme/app_theme.dart';
import '../navigation/navigate_after_identity.dart';
import '../navigation/space_gateway_navigation.dart';
import '../services/auth_service.dart';
import '../services/demo_auth_service.dart';
import '../services/qa_test_auth_service.dart';
import '../services/user_session_store.dart';
import '../utils/listing_data.dart';
import '../models/spoken_language_entry.dart';
import '../models/financial_support_type.dart';
import '../utils/spoken_language_profile_codec.dart';
import '../widgets/truecircle_logo.dart';
import '../widgets/language_pill_chips.dart';
import '../widgets/shadcn_select.dart';
import 'profile_edit_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  static Map<String, dynamic>? get currentUserSession =>
      UserSessionStore.current;

  static set currentUserSession(Map<String, dynamic>? value) {
    UserSessionStore.current = value;
  }

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoginMode = true;
  final bool _showEmailLogin = true;
  int _signUpStep = 1;
  bool _showAddMore = false;
  bool _authLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();

  String _selectedFoodPref = 'Pure Veg';
  String _selectedMotherTongue = 'English';
  final _commuteDestinationController = TextEditingController();
  String _commuteMethod = ProfileCommuteOptions.methodLabels.first;
  double? _destinationLatitude;
  double? _destinationLongitude;
  bool _fetchingCommuteDestination = false;
  final List<String> _selectedLanguages = [];
  final Map<String, bool> _languageNativeFlags = {};
  String? _selectedAreaKey;
  String? _selectedOccupantType;
  String? _selectedGenderPref;
  String? _selectedFinancialSupportType;
  String preferredArrangement =
      ProfileSeekerPreferences.arrangementOptions.first;
  String? preferredLayout;
  int _familyAdults = 2;
  int _familyChildren = 0;
  List<String> _childrenAges = [];
  int _groupSize = 1;

  static const _childrenAgeOptions = ['Below 5', '5 - 12', '13 - 18'];
  bool _smokingOk = false;
  bool _drinkingOk = false;
  String? _scheduleType;
  String _kitchenUsageTiming = ListingData.kitchenUsageTimingOptions.first;
  bool _detectingLocation = false;
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();

  List<String> get _foodOptions => MarketConfig.current.profileFoodOptions;
  List<String> get _languageOptions =>
      MarketConfig.current.profileLanguageOptions;

  List<String> get _otherLanguageOptions =>
      _languageOptions.where((l) => l != _selectedMotherTongue).toList();
  List<String> get _occupantOptions =>
      MarketConfig.current.profileOccupantOptions;
  List<String> get _genderPrefOptions =>
      MarketConfig.current.profileGenderPrefOptions;
  List<String> get _financialSupportOptions =>
      MarketConfig.current.profileStudentFundingOptions;

  @override
  void initState() {
    super.initState();
    _applyMarketDefaults();
    if (MarketConfig.current.profileExpandOptionalOnSignup) {
      _showAddMore = true;
    }
  }

  void _applyMarketDefaults() {
    final market = MarketConfig.current;
    _selectedMotherTongue = market.defaultMotherTongue;
    _selectedFoodPref = market.defaultFoodPreference;
    _selectedLanguages
      ..clear()
      ..add(market.defaultMotherTongue);
    _languageNativeFlags
      ..clear()
      ..[market.defaultMotherTongue] = true;
    _selectedOccupantType = market.defaultOccupantType;
    if (market.profileUseAreaPicker) {
      _selectedAreaKey = market.defaultAreaKey;
      _locationController.text = market.defaultAreaDisplayName;
    }
  }

  Map<String, dynamic> _buildProfilePayload() {
    const baseline = <String, dynamic>{
      'linkedin_connected': false,
      'facebook_connected': false,
      'social_trust_score': 0,
      'is_aadhaar_verified': false,
      'passkey_public_key': null,
    };

    final payload = {
      ...baseline,
      'email': _emailController.text.trim(),
      'full_name': _nameController.text.trim(),
      'detected_city': _resolvedCity(),
      ..._commutePayloadFields(),
      ..._spokenLanguageSessionFields(),
      ...ProfileSeekerPreferences.persistFields(
        preferredArrangement: preferredArrangement,
        preferredLayout: _resolvedPreferredLayout,
      ),
      if (_selectedOccupantType != null) 'occupant_type': _selectedOccupantType,
      if (_selectedGenderPref != null) 'gender_preference': _selectedGenderPref,
      if (_selectedFinancialSupportType != null)
        FinancialSupportType.storageKey: _selectedFinancialSupportType,
      if (_selectedOccupantType == 'Family') ...{
        'family_adults': _familyAdults,
        'family_children': _familyChildren,
        if (_familyChildren > 0)
          'children_ages': List<String>.from(_childrenAges),
      },
      if (_selectedOccupantType == 'Working Professionals' ||
          _selectedOccupantType == 'Students')
        'group_size': _groupSize,
      if (ProfileSeekerPreferences.isSharedRoom(preferredArrangement)) ...{
        'food_preference':
            ProfileSeekerPreferences.sharedFoodToBackend(_selectedFoodPref),
        'smoking_ok': _smokingOk,
        'drinking_ok': _drinkingOk,
        if (_scheduleType != null) 'schedule_type': _scheduleType,
        'kitchen_usage_timing': _kitchenUsageTiming,
      } else ...{
        'smoking_ok': false,
        'drinking_ok': false,
      },
      if (_budgetMinController.text.trim().isNotEmpty)
        'budget_min': int.tryParse(_budgetMinController.text.trim()),
      if (_budgetMaxController.text.trim().isNotEmpty)
        'budget_max': int.tryParse(_budgetMaxController.text.trim()),
    };

    if (!ProfileSeekerPreferences.isSharedRoom(preferredArrangement)) {
      payload
        ..remove('kitchen_usage_timing')
        ..remove('food_preference')
        ..remove('schedule_type')
        ..remove('preferred_spoken_languages')
        ..remove('preferred_spoken_languages_csv');
    }
    payload.remove('native_place');
    return payload;
  }

  String _resolvedCity() {
    if (MarketConfig.current.profileUseAreaPicker && _selectedAreaKey != null) {
      for (final (key, label) in MarketConfig.current.areaOptions) {
        if (key == _selectedAreaKey) return label;
      }
    }
    return _locationController.text.trim();
  }

  String get _resolvedPreferredLayout => ProfileSeekerPreferences.resolveLayout(
        preferredArrangement,
        preferredLayout,
      );

  bool _validateProfileFields() {
    if (_nameController.text.trim().isEmpty || _resolvedCity().isEmpty) {
      _showNotification('Please fill in your name and area.');
      return false;
    }
    if (_selectedLanguages.isEmpty) {
      _showNotification('Select at least one language.');
      return false;
    }
    if (!_foodOptions.contains(_selectedFoodPref)) {
      _showNotification('Select your food preference.');
      return false;
    }
    return true;
  }

  Map<String, dynamic> _commutePayloadFields() {
    final method =
        ProfileCommuteOptions.methodToBackend[_commuteMethod] ?? _commuteMethod;
    final destination = _commuteDestinationController.text.trim();

    return {
      'commute_method': method,
      if (destination.isNotEmpty) ...{
        'commute_destination': destination,
        'primary_commute_destination': destination,
      },
      if (_destinationLatitude != null)
        'destination_latitude': _destinationLatitude,
      if (_destinationLongitude != null)
        'destination_longitude': _destinationLongitude,
    };
  }

  Future<void> _resolveCommuteDestinationCoordinates() async {
    if (_fetchingCommuteDestination) return;
    setState(() => _fetchingCommuteDestination = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showNotification(
            'Turn on location services to set a commute destination.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showNotification('Location permission is required.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      final parts = <String>[];
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        for (final part in [
          p.street,
          p.locality,
          p.subAdministrativeArea,
          p.administrativeArea,
        ]) {
          if (part != null &&
              part.trim().isNotEmpty &&
              !parts.contains(part.trim())) {
            parts.add(part.trim());
          }
        }
      }

      setState(() {
        _destinationLatitude = position.latitude;
        _destinationLongitude = position.longitude;
        _commuteDestinationController.text = parts.isNotEmpty
            ? parts.join(', ')
            : '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
    } catch (_) {
      _showNotification('Could not resolve commute destination. Try again.');
    } finally {
      if (mounted) setState(() => _fetchingCommuteDestination = false);
    }
  }

  Future<void> _geocodeCommuteDestination() async {
    final query = _commuteDestinationController.text.trim();
    if (query.isEmpty) return;

    try {
      final results = await locationFromAddress(query);
      if (!mounted || results.isEmpty) return;
      final loc = results.first;
      setState(() {
        _destinationLatitude = loc.latitude;
        _destinationLongitude = loc.longitude;
      });
    } catch (_) {
      _showNotification('Could not find coordinates for that address.');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _commuteDestinationController.dispose();
    super.dispose();
  }

  void _syncChildrenAgesList() {
    if (_childrenAges.length < _familyChildren) {
      _childrenAges.addAll(
        List.generate(
          _familyChildren - _childrenAges.length,
          (_) => _childrenAgeOptions.first,
        ),
      );
    } else if (_childrenAges.length > _familyChildren) {
      _childrenAges = _childrenAges.sublist(0, _familyChildren);
    }
  }

  Future<void> _autoDetectWebLocation() async {
    if (_detectingLocation || MarketConfig.current.profileUseAreaPicker) return;
    setState(() => _detectingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        _showNotification(
          'Location permission denied. Pick your area from the list instead.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(const Duration(seconds: 12));

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      final parts = <String>[];
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        for (final part in [
          p.locality,
          p.subAdministrativeArea,
          p.administrativeArea,
        ]) {
          if (part != null &&
              part.trim().isNotEmpty &&
              !parts.contains(part.trim())) {
            parts.add(part.trim());
          }
        }
      }

      setState(() {
        _locationController.text = parts.isNotEmpty
            ? parts.join(', ')
            : '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
      _showNotification('Location detected. You can edit it anytime.');
    } on TimeoutException {
      if (!mounted) return;
      _showNotification(
        'Location detection timed out. Pick your area from the list instead.',
      );
    } catch (_) {
      if (!mounted) return;
      _showNotification(
        'Could not detect location. Pick your area from the list instead.',
      );
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  Future<void> _executeSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showNotification('Enter your email and password.');
      return;
    }

    setState(() => _authLoading = true);
    try {
      await AuthService.signInWithEmail(email: email, password: password);
      if (!mounted) return;
      _showNotification('Signed in successfully.');
      if (context.canPop()) {
        context.pop(true);
      } else {
        await navigateAfterAuth(context);
      }
    } catch (e) {
      if (!mounted) return;
      _showNotification(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  Future<void> _enterAsQaAccount(QaTestAccount account) async {
    if (_authLoading) return;
    setState(() => _authLoading = true);
    final router = GoRouter.of(context);
    try {
      await QaTestAuthService.enter(account);
      final location = account.isLandlord
          ? '/landlord-dashboard'
          : kQaSeekerWelcomeRoute;
      _dismissPushedAuthThenGo(router, location);
    } catch (e) {
      if (!mounted) return;
      _showNotification('Could not enter ${account.id}: $e');
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  /// Pop a Sign-in overlay without triggering [_openSignIn]'s post-pop
  /// [navigateAfterAuth], then [GoRouter.go]. Do not require [mounted] for
  /// [go] — [enter] already refreshed the session and may have unmounted us.
  void _dismissPushedAuthThenGo(GoRouter router, String location) {
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
    router.go(location);
  }

  Future<void> _enterAsNewSeeker() async {
    if (_authLoading) return;
    setState(() => _authLoading = true);
    final router = GoRouter.of(context);
    try {
      await DemoAuthService.enterAsNewSeeker();
      router.go('/profile/edit');
    } catch (e) {
      if (!mounted) return;
      _showNotification('Could not start new seeker flow: $e');
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  Future<void> _enterAsNewLandlord() async {
    if (_authLoading) return;
    setState(() => _authLoading = true);
    final router = GoRouter.of(context);
    try {
      await DemoAuthService.enterAsNewLandlord();
      router.go('/add-listing');
    } catch (e) {
      if (!mounted) return;
      _showNotification('Could not start new landlord flow: $e');
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  Future<void> _executeSignUpAccountStep() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showNotification('Enter your email and password to continue.');
      return;
    }

    setState(() => _authLoading = true);
    try {
      final hasSession = await AuthService.signUpWithEmail(
        email: email,
        password: password,
      );
      if (!mounted) return;
      if (hasSession) {
        setState(() => _signUpStep = 2);
        if (!MarketConfig.current.profileUseAreaPicker) {
          _autoDetectWebLocation();
        }
      } else {
        _showNotification(
          'Account created. Check your email to confirm, then sign in.',
        );
        setState(() => _isLoginMode = true);
      }
    } catch (e) {
      if (!mounted) return;
      _showNotification(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  Future<void> _executeFinalSignUpRegistration() async {
    if (!_validateProfileFields()) return;

    setState(() => _authLoading = true);
    try {
      if (!AuthService.isAuthenticated) {
        final hasSession = await AuthService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (!hasSession) {
          if (!mounted) return;
          _showNotification(
            'Confirm your email, then sign in to finish your profile.',
          );
          setState(() => _isLoginMode = true);
          return;
        }
      }

      await _geocodeCommuteDestination();
      final userProfilePayload = _buildProfilePayload();
      await AuthService.saveProfile(userProfilePayload);

      if (!mounted) return;
      _showNotification('Profile created. Welcome to TrueCircle.');
      await navigateAfterIdentity(context, force: true);
    } catch (e) {
      if (!mounted) return;
      _showNotification(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  void _showNotification(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          backgroundColor: _AuthPalette.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AuthPalette.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 520;
          final horizontalPad = isCompact ? 14.0 : 20.0;
          final verticalPad = isCompact ? 16.0 : 24.0;
          final cardPad = isCompact ? 18.0 : 24.0;

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPad,
                    vertical: verticalPad,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _AuthLayout.maxWidthLg,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(_AuthPalette.radius2xl),
                            boxShadow: _AuthPalette.cardShadow,
                          ),
                          child: Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            color: _AuthPalette.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(_AuthPalette.radius2xl),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(cardPad),
                              child: _isLoginMode
                                  ? _buildLoginLayout()
                                  : _buildSignUpWizardLayout(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoginLayout() {
    return _spacedColumn(
      gap: _AuthLayout.spaceY4,
      children: [
        const TrueCircleLogo(height: 96, width: null),
        Text(
          _showEmailLogin ? 'Sign in to TrueCircle' : 'Try TrueCircle',
          textAlign: TextAlign.center,
          style: _AuthPalette.pageTitle,
        ),
        _buildInput(
          _emailController,
          label: 'Email',
          hint: 'you@company.com',
          textInputAction: TextInputAction.next,
        ),
        _buildInput(
          _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          isObscured: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _executeSignIn(),
        ),
        _buildPrimaryButton(
          label: _authLoading ? 'Signing in…' : 'Sign in',
          onPressed: _authLoading ? null : _executeSignIn,
        ),
        if (kDebugMode) ...[
          const Divider(),
          const Text(
            'DEV ONLY',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
          _buildDemoEntrySection(compact: true),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'New here? ',
              style: TextStyle(color: _AuthPalette.textSecondary, fontSize: 13),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() {
                  _isLoginMode = false;
                  _signUpStep = 1;
                  _showAddMore = false;
                }),
                child: const Text(
                  'Create an account',
                  style: TextStyle(
                    color: _AuthPalette.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _signUpStepLabel(int step) => switch (step) {
        1 => 'Account setup',
        2 => 'Your profile',
        _ => '',
      };

  Map<String, dynamic> _spokenLanguageSessionFields() {
    final entries = [
      for (final language in _selectedLanguages)
        SpokenLanguageEntry(
          language: language,
          isNative: language == _selectedMotherTongue ||
              (_languageNativeFlags[language] ?? false),
        ),
    ];

    return SpokenLanguageProfileCodec.toSessionFields(
      entries: entries,
      motherTongue: _selectedMotherTongue,
    );
  }

  void _syncMotherTongueInLanguages(String previousMotherTongue) {
    if (!_selectedLanguages.contains(_selectedMotherTongue)) {
      _selectedLanguages.add(_selectedMotherTongue);
    }
    if (previousMotherTongue != _selectedMotherTongue &&
        _selectedLanguages.contains(previousMotherTongue)) {
      _selectedLanguages.remove(previousMotherTongue);
    }
    if (previousMotherTongue != _selectedMotherTongue) {
      _languageNativeFlags.remove(previousMotherTongue);
    }
    _languageNativeFlags[_selectedMotherTongue] = true;
  }

  void _onMotherTongueChanged(String value) {
    setState(() {
      final previous = _selectedMotherTongue;
      _selectedMotherTongue = value;
      _syncMotherTongueInLanguages(previous);
    });
  }

  void _clearSharedRoomFilters() {
    _kitchenUsageTiming = ListingData.kitchenUsageTimingOptions.first;
    _smokingOk = false;
    _drinkingOk = false;
    _scheduleType = null;
  }

  void _selectKitchenUsageTiming(String timing) {
    setState(() => _kitchenUsageTiming = timing);
  }

  void _toggleLanguage(String lang) {
    if (lang == _selectedMotherTongue) return;
    setState(() {
      if (_selectedLanguages.contains(lang)) {
        if (_selectedLanguages.length > 1) {
          _selectedLanguages.remove(lang);
          _languageNativeFlags.remove(lang);
        }
      } else {
        _selectedLanguages.add(lang);
      }
    });
  }

  void _toggleLanguageNative(String lang) {
    if (lang == _selectedMotherTongue || !_selectedLanguages.contains(lang)) {
      return;
    }
    setState(() {
      _languageNativeFlags[lang] = !(_languageNativeFlags[lang] ?? false);
    });
  }

  Widget _buildSignUpStepIndicator() {
    final progress = _signUpStep / _AuthLayout.signUpTotalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _AuthPalette.surfaceMuted,
                borderRadius: BorderRadius.circular(_AuthPalette.radiusXl),
                border: Border.all(color: _AuthPalette.borderSoft),
              ),
              child: Text(
                'Step $_signUpStep of ${_AuthLayout.signUpTotalSteps}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _AuthPalette.primary,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            Text(
              _signUpStepLabel(_signUpStep),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _AuthPalette.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 10,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: _AuthPalette.border.withValues(alpha: 0.55),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(_AuthPalette.accent),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSignUpWizardLayout() {
    return _spacedColumn(
      gap: _AuthLayout.spaceY6,
      children: [
        _buildSignUpStepIndicator(),
        switch (_signUpStep) {
          1 => _buildWizardStep1(),
          _ => _buildWizardStep2(),
        },
      ],
    );
  }

  Widget _buildStepHeading({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _AuthPalette.signupTitle),
        const SizedBox(height: 5),
        Text(subtitle, style: _AuthPalette.helper),
      ],
    );
  }

  Widget _buildSectionDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: _AuthPalette.borderSoft,
    );
  }

  Widget _buildFieldGroupCard({
    required String title,
    required List<Widget> fields,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(_AuthLayout.groupCardPad),
      decoration: BoxDecoration(
        color: _AuthPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(_AuthPalette.radius2xl),
        boxShadow: _AuthPalette.shadowSm,
      ),
      child: _spacedColumn(
        gap: _AuthLayout.spaceY4,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _AuthPalette.sectionTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle, style: _AuthPalette.helper),
              ],
            ],
          ),
          ...fields,
        ],
      ),
    );
  }

  Widget _buildSignUpCta({
    required VoidCallback onBack,
    required String primaryLabel,
    required VoidCallback onPrimary,
    Color? primaryColor,
    bool prominent = false,
    String? trustMessage,
  }) {
    final height =
        prominent ? _AuthLayout.ctaProminentHeight : _AuthLayout.buttonHeight;

    return Padding(
      padding: const EdgeInsets.only(top: _AuthLayout.ctaTopSpacing),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: _AuthPalette.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(_AuthPalette.radius2xl),
          border: Border.all(
            color: _AuthPalette.accent.withValues(alpha: 0.18),
          ),
          boxShadow:
              prominent ? _AuthPalette.ctaPanelShadow : _AuthPalette.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (trustMessage != null) ...[
              Text(
                trustMessage,
                textAlign: TextAlign.center,
                style: _AuthPalette.trustNote,
              ),
              const SizedBox(height: 14),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: height,
                  width: height,
                  child: OutlinedButton(
                    onPressed: onBack,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size(height, height),
                      side: const BorderSide(color: _AuthPalette.borderSoft),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(_AuthPalette.radiusXl),
                      ),
                      foregroundColor: _AuthPalette.textSecondary,
                      backgroundColor: _AuthPalette.surface,
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPrimaryButton(
                    label: primaryLabel,
                    backgroundColor: primaryColor ?? _AuthPalette.accent,
                    onPressed: onPrimary,
                    height: height,
                    prominent: prominent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWizardStep1() {
    return _spacedColumn(
      gap: _AuthLayout.spaceY6,
      children: [
        _buildStepHeading(
          title: 'Create your account',
          subtitle: 'Email and password to get started.',
        ),
        _buildFieldGroupCard(
          title: 'Credentials',
          fields: [
            _buildInput(
              _emailController,
              label: 'Email',
              hint: 'you@company.com',
            ),
            _buildInput(
              _passwordController,
              label: 'Password',
              hint: 'Create a password',
              isObscured: true,
            ),
          ],
        ),
        _buildPrimaryButton(
          label: _authLoading ? 'Creating account…' : 'Continue',
          onPressed: _authLoading ? null : _executeSignUpAccountStep,
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 4),
          const Text(
            'Or try a demo without signing up',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _AuthPalette.textSecondary,
              fontSize: 12,
            ),
          ),
          _buildDemoEntrySection(compact: true),
        ],
        Center(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _isLoginMode = true),
              child: const Text(
                'Already have an account? Sign in',
                style:
                    TextStyle(color: _AuthPalette.textSecondary, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoEntrySection({required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) const SizedBox(height: 4),
        const Text(
          'QA ACCOUNTS',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 8),
        for (final account in QaTestAccount.values) ...[
          _buildSecondaryButton(
            label: _authLoading ? 'Loading…' : account.buttonLabel,
            onPressed:
                _authLoading ? null : () => _enterAsQaAccount(account),
            height: compact ? 46 : 52,
          ),
          const SizedBox(height: 8),
        ],
        const Text(
          'FIRST TIME USER',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 8),
        _buildSecondaryButton(
          label: _authLoading ? 'Loading…' : 'New Landlord',
          onPressed: _authLoading ? null : _enterAsNewLandlord,
          height: compact ? 46 : 52,
        ),
        const SizedBox(height: 10),
        _buildSecondaryButton(
          label: _authLoading ? 'Loading…' : 'New Seeker',
          onPressed: _authLoading ? null : _enterAsNewSeeker,
          height: compact ? 46 : 52,
        ),
        if (kDebugMode && QaTestAuthService.isEnabled)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'QA sessions run locally — no password or Supabase sign-in.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _AuthPalette.textSecondary,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildProfileFormSections({required bool includeEmail}) {
    return [
      if (includeEmail)
        _buildFieldGroupCard(
          title: 'Account',
          subtitle: 'Your sign-in email.',
          fields: [
            _buildInput(
              _emailController,
              label: 'Email',
              hint: 'you@company.com',
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
      _buildFieldGroupCard(
        title: 'Essentials',
        subtitle: 'Required for tailored matching.',
        fields: [
          _buildInput(_nameController,
              label: 'Full name', hint: 'As on your ID'),
          if (MarketConfig.current.profileUseAreaPicker)
            ShadcnSelect(
              label: MarketConfig.current.profileCityLabel,
              value: _selectedAreaKey ?? MarketConfig.current.defaultAreaKey,
              options:
                  MarketConfig.current.areaOptions.map((e) => e.$2).toList(),
              onChanged: (label) {
                setState(() {
                  for (final (key, areaLabel)
                      in MarketConfig.current.areaOptions) {
                    if (areaLabel == label) {
                      _selectedAreaKey = key;
                      _locationController.text = areaLabel;
                      break;
                    }
                  }
                });
              },
            )
          else ...[
            _buildInput(
              _locationController,
              label: MarketConfig.current.profileCityLabel,
              hint: 'e.g. ${MarketConfig.current.defaultProfileLocation}',
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Row(
                children: [
                  _detectingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_outlined,
                          size: 16, color: _AuthPalette.primary),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _detectingLocation ? null : _autoDetectWebLocation,
                    child: Text(
                      _detectingLocation
                          ? 'Detecting your location…'
                          : 'Auto-detect my location',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _AuthPalette.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          ShadcnSelect(
            label: 'Food preference',
            value: _selectedFoodPref,
            options: _foodOptions,
            onChanged: (val) => setState(() => _selectedFoodPref = val),
          ),
          ShadcnSelect(
            label: 'Mother tongue',
            value: _selectedMotherTongue,
            options: _languageOptions,
            onChanged: _onMotherTongueChanged,
          ),
          ShadcnSelect(
            label: 'Commute Method',
            value: _commuteMethod,
            options: ProfileCommuteOptions.methodLabels,
            onChanged: (val) => setState(() => _commuteMethod = val),
          ),
          _buildInput(
            _commuteDestinationController,
            label: 'Commute Destination',
            hint: 'e.g. Trinity College, Dublin 2',
            onChanged: (_) => setState(() {
              _destinationLatitude = null;
              _destinationLongitude = null;
            }),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _fetchingCommuteDestination
                  ? null
                  : _resolveCommuteDestinationCoordinates,
              icon: _fetchingCommuteDestination
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.place_outlined, size: 18),
              label: Text(
                _fetchingCommuteDestination
                    ? 'Resolving…'
                    : 'Use current location as destination',
              ),
            ),
          ),
          if (_destinationLatitude != null && _destinationLongitude != null)
            Text(
              'Coordinates: ${_destinationLatitude!.toStringAsFixed(5)}, '
              '${_destinationLongitude!.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 12, color: _AuthPalette.primary),
            ),
          _buildLabeledField(
            label: 'Other languages',
            child: LanguagePillChips(
              options: _otherLanguageOptions,
              selected: _selectedLanguages
                  .where((l) => l != _selectedMotherTongue)
                  .toList(),
              onToggle: _toggleLanguage,
              nativeByLanguage: _languageNativeFlags,
              onToggleNative: _toggleLanguageNative,
              spacing: 8,
              runSpacing: 8,
            ),
          ),
        ],
      ),
      _buildSectionDivider(),
      TextButton.icon(
        onPressed: () => setState(() => _showAddMore = !_showAddMore),
        style: TextButton.styleFrom(
          foregroundColor: _AuthPalette.primary,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(
          _showAddMore ? Icons.expand_less_rounded : Icons.add_rounded,
          size: 18,
        ),
        label: Text(
          _showAddMore ? 'Hide optional' : 'Add optional details',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      if (_showAddMore) ...[
        _buildFieldGroupCard(
          title: 'Budget range',
          subtitle: MarketConfig.current.profileBudgetSubtitle,
          fields: [
            _buildInput(
              _budgetMinController,
              label: 'Minimum budget (${MarketConfig.current.currencySymbol})',
              hint: MarketConfig.current.profileBudgetMinHint,
              keyboardType: TextInputType.number,
            ),
            _buildInput(
              _budgetMaxController,
              label: 'Maximum budget (${MarketConfig.current.currencySymbol})',
              hint: MarketConfig.current.profileBudgetMaxHint,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        _buildFieldGroupCard(
          title: 'I am looking for',
          subtitle: 'Entire place or a room in a shared flat — pick one.',
          fields: [
            ProfileLookingForFields(
              preferredArrangement: preferredArrangement,
              preferredLayout: preferredLayout,
              onArrangementChanged: (val) => setState(() {
                preferredArrangement = val;
                preferredLayout = null;
                if (ProfileSeekerPreferences.isEntirePlace(val)) {
                  _clearSharedRoomFilters();
                }
              }),
              onLayoutChanged: (val) => setState(() => preferredLayout = val),
            ),
            ShadcnSelect(
              label: 'Occupant type',
              value: _selectedOccupantType ?? _occupantOptions.first,
              options: _occupantOptions,
              onChanged: (val) => setState(() {
                _selectedOccupantType = val;
                if (val != 'Students') _selectedFinancialSupportType = null;
                if (val == 'Family') {
                  _selectedGenderPref = null;
                  _groupSize = 1;
                } else {
                  _familyAdults = 2;
                  _familyChildren = 0;
                }
              }),
            ),
            if (_selectedOccupantType == 'Family') ...[
              _buildCounterField(
                label: 'Number of adults',
                value: _familyAdults,
                min: 1,
                max: 10,
                onChanged: (v) => setState(() => _familyAdults = v),
              ),
              _buildCounterField(
                label: 'Number of children',
                value: _familyChildren,
                min: 0,
                max: 8,
                onChanged: (v) => setState(() {
                  _familyChildren = v;
                  _syncChildrenAgesList();
                }),
              ),
              for (var i = 0; i < _familyChildren; i++)
                ShadcnSelect(
                  label: 'Child ${i + 1} age',
                  value: i < _childrenAges.length
                      ? _childrenAges[i]
                      : _childrenAgeOptions.first,
                  options: _childrenAgeOptions,
                  onChanged: (val) => setState(() {
                    if (i < _childrenAges.length) {
                      _childrenAges[i] = val;
                    }
                  }),
                ),
            ],
            if (_selectedOccupantType == 'Working Professionals' ||
                _selectedOccupantType == 'Students') ...[
              ShadcnSelect(
                label: 'Gender preference',
                value: _selectedGenderPref ?? _genderPrefOptions.first,
                options: _genderPrefOptions,
                onChanged: (val) => setState(() => _selectedGenderPref = val),
              ),
              _buildCounterField(
                label: 'How many people',
                value: _groupSize,
                min: 1,
                max: 10,
                onChanged: (v) => setState(() => _groupSize = v),
              ),
            ],
            if (_selectedOccupantType == 'Students')
              ShadcnSelect(
                label: 'Financial Support',
                value: _selectedFinancialSupportType ??
                    _financialSupportOptions.first,
                options: _financialSupportOptions,
                onChanged: (val) =>
                    setState(() => _selectedFinancialSupportType = val),
              ),
          ],
        ),
        if (ProfileSeekerPreferences.isSharedRoom(preferredArrangement) &&
            (_selectedOccupantType == 'Working Professionals' ||
                _selectedOccupantType == 'Students'))
          _buildFieldGroupCard(
            title: 'Shared living preferences',
            subtitle: 'For shared/roommate matching.',
            fields: [
              _buildSwitchField(
                label: 'OK with smoking',
                value: _smokingOk,
                onChanged: (v) => setState(() => _smokingOk = v),
              ),
              _buildSwitchField(
                label: 'OK with drinking',
                value: _drinkingOk,
                onChanged: (v) => setState(() => _drinkingOk = v),
              ),
              ShadcnSelect(
                label: 'Work schedule',
                value: _scheduleType ?? 'Flexible',
                options: const ['Flexible', 'Day shift', 'Night shift'],
                onChanged: (val) => setState(() {
                  _scheduleType = val == 'Flexible' ? null : val;
                }),
              ),
              _buildLabeledField(
                label: 'Preferred kitchen usage times',
                child: LanguagePillChips(
                  options: ListingData.kitchenUsageTimingOptions,
                  selected: [_kitchenUsageTiming],
                  onToggle: _selectKitchenUsageTiming,
                  spacing: 8,
                  runSpacing: 8,
                ),
              ),
            ],
          ),
      ],
    ];
  }

  Widget _buildWizardStep2() {
    return _spacedColumn(
      gap: _AuthLayout.spaceY6,
      children: [
        _buildStepHeading(
          title: 'Personalize your profile',
          subtitle: MarketConfig.current.id == MarketId.dublin
              ? 'Tell us where in Dublin you want to live and how you eat — we rank homes for you.'
              : 'Name, city, and languages.',
        ),
        ..._buildProfileFormSections(includeEmail: false),
        _buildSignUpCta(
          onBack: () => setState(() => _signUpStep = 1),
          primaryLabel: 'Find my matches',
          trustMessage: 'Used only for matching • never shared publicly',
          prominent: true,
          onPrimary: _executeFinalSignUpRegistration,
        ),
      ],
    );
  }

  Widget _spacedColumn({
    required List<Widget> children,
    double gap = _AuthLayout.spaceY4,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }

  Widget _buildLabeledField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _AuthLayout.labelHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(label, style: _AuthPalette.fieldLabel),
          ),
        ),
        const SizedBox(height: _AuthLayout.labelGap),
        child,
      ],
    );
  }

  Widget _buildSwitchField({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _buildLabeledField(
      label: label,
      child: SizedBox(
        height: _AuthLayout.controlHeight,
        child: Row(
          children: [
            Text(
              value ? 'Yes' : 'No',
              style: _AuthPalette.inputText.copyWith(
                color: value ? _AuthPalette.primary : _AuthPalette.gray400,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: _AuthPalette.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterField({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return _buildLabeledField(
      label: label,
      child: Container(
        height: _AuthLayout.controlHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _AuthPalette.inputSurface,
          borderRadius: BorderRadius.circular(_AuthPalette.radiusXl),
          border: Border.all(color: _AuthPalette.borderSoft),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$value',
                style: _AuthPalette.inputText,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_rounded, size: 20),
              onPressed: value > min ? () => onChanged(value - 1) : null,
              color: _AuthPalette.primary,
              disabledColor: _AuthPalette.gray400,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 20),
              onPressed: value < max ? () => onChanged(value + 1) : null,
              color: _AuthPalette.primary,
              disabledColor: _AuthPalette.gray400,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller, {
    required String label,
    String? hint,
    bool isObscured = false,
    Widget? suffix,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
  }) {
    return _buildLabeledField(
      label: label,
      child: _PremiumAuthField(
        controller: controller,
        hint: hint,
        isObscured: isObscured,
        suffix: suffix,
        keyboardType: keyboardType ??
            (label == 'Email'
                ? TextInputType.emailAddress
                : TextInputType.text),
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    Color backgroundColor = _AuthPalette.accent,
    double height = _AuthLayout.buttonHeight,
    bool prominent = false,
  }) {
    Color resolvePressed(Set<WidgetState> states) {
      final isSuccess = backgroundColor == _AuthPalette.success;
      final isAccent = backgroundColor == _AuthPalette.accent;
      final isPrimary = backgroundColor == _AuthPalette.primary;

      if (states.contains(WidgetState.pressed)) {
        if (isSuccess) return const Color(0xFF36A420);
        if (isAccent) return _AuthPalette.accentActive;
        if (isPrimary) return _AuthPalette.primaryActive;
        return backgroundColor;
      }
      if (states.contains(WidgetState.hovered)) {
        if (isSuccess) return const Color(0xFF3BB82E);
        if (isAccent) return _AuthPalette.accentHover;
        if (isPrimary) return _AuthPalette.primaryHover;
        return backgroundColor;
      }
      return backgroundColor;
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return backgroundColor.withValues(alpha: 0.45);
            }
            return resolvePressed(states);
          }),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          elevation: WidgetStatePropertyAll(prominent ? 4 : 0),
          shadowColor: WidgetStatePropertyAll(
            prominent
                ? backgroundColor.withValues(alpha: 0.42)
                : Colors.transparent,
          ),
          overlayColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: 0.14),
          ),
          minimumSize: WidgetStatePropertyAll(Size(double.infinity, height)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: prominent ? 34 : 22,
              vertical: prominent ? 20 : 14,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_AuthPalette.radiusXl),
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: prominent ? 18 : 16,
            letterSpacing: prominent ? 0.2 : 0.1,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback? onPressed,
    double height = _AuthLayout.buttonHeight,
  }) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _AuthPalette.textSecondary.withValues(alpha: 0.55);
            }
            return _AuthPalette.textPrimary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return _AuthPalette.surfaceMuted;
            }
            if (states.contains(WidgetState.hovered)) {
              return _AuthPalette.inputSurface;
            }
            return _AuthPalette.surface;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(
                color: _AuthPalette.borderSoft.withValues(alpha: 0.6),
              );
            }
            return const BorderSide(color: _AuthPalette.borderSoft);
          }),
          overlayColor: WidgetStatePropertyAll(
            _AuthPalette.textPrimary.withValues(alpha: 0.06),
          ),
          minimumSize: WidgetStatePropertyAll(Size(double.infinity, height)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_AuthPalette.radiusXl),
            ),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

abstract final class _AuthLayout {
  static const maxWidthLg = 512.0;
  static const spaceY6 = 20.0;
  static const spaceY4 = 16.0;
  static const controlHeight = 52.0;
  static const labelHeight = 18.0;
  static const labelGap = 6.0;
  static const signUpTotalSteps = 2;
  static const buttonHeight = 50.0;
  static const ctaProminentHeight = 60.0;
  static const ctaTopSpacing = 24.0;
  static const groupCardPad = 14.0;
}

abstract final class _AuthPalette {
  static const primary = Color(0xFF2B4C7E);
  static const primaryHover = Color(0xFF233F6A);
  static const primaryActive = Color(0xFF1C3458);
  static const accent = AppColors.accent;
  static const accentHover = AppColors.accentDark;
  static const accentActive = Color(0xFFC9474B);
  static const success = Color(0xFF15803D);

  static const canvas = Color(0xFFF7F7F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF7F7F7);
  static const border = Color(0xFFE5E7EB);
  static const borderSoft = Color(0xFFE5E7EB);
  static const textPrimary = Color(0xFF111111);
  static const textSecondary = Color(0xFF6B7280);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const inputSurface = Color(0xFFFFFFFF);

  static const pageTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.6,
    height: 1.15,
  );

  static const signupTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.15,
  );

  static const helper = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: gray500,
    height: 1.4,
  );

  static const trustNote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: gray500,
    height: 1.4,
  );

  static const sectionTitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.02,
  );

  static const fieldLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: gray500,
    letterSpacing: 0.1,
    height: 1.2,
  );

  static const inputText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    height: 1.2,
  );

  static const radiusXl = 12.0;
  static const radius2xl = 16.0;

  static List<BoxShadow> get shadowSm => const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get cardShadow => shadowSm;

  static List<BoxShadow> get ctaPanelShadow => const [
        BoxShadow(
          color: Color(0x22F97316),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
        BoxShadow(
          color: Color(0x0C000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ];
}

/// Text field with calm hover and focus border feedback.
class _PremiumAuthField extends StatefulWidget {
  const _PremiumAuthField({
    required this.controller,
    this.hint,
    this.isObscured = false,
    this.suffix,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hint;
  final bool isObscured;
  final Widget? suffix;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<_PremiumAuthField> createState() => _PremiumAuthFieldState();
}

class _PremiumAuthFieldState extends State<_PremiumAuthField> {
  final _focusNode = FocusNode();
  bool _hovering = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: SizedBox(
        height: _AuthLayout.controlHeight,
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          obscureText: widget.isObscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          cursorColor: _AuthPalette.primary,
          style: _AuthPalette.inputText,
          decoration: _decorationForState(),
        ),
      ),
    );
  }

  InputDecoration _decorationForState() {
    final radius = BorderRadius.circular(_AuthPalette.radiusXl);
    final borderColor = _focused
        ? _AuthPalette.primary
        : _hovering
            ? _AuthPalette.primary.withValues(alpha: 0.4)
            : _AuthPalette.borderSoft;
    final borderWidth = _focused ? 1.5 : 1.0;

    return InputDecoration(
      hintText: widget.hint,
      hintStyle: const TextStyle(
        color: _AuthPalette.gray400,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: _hovering && !_focused
          ? _AuthPalette.primary.withValues(alpha: 0.03)
          : _AuthPalette.inputSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 16,
      ),
      constraints: const BoxConstraints(
        minHeight: _AuthLayout.controlHeight,
      ),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: borderColor, width: borderWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: borderColor, width: borderWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: _AuthPalette.primary, width: 1.5),
      ),
      focusColor: _AuthPalette.primary.withValues(alpha: 0.18),
      suffixIcon: widget.suffix,
    );
  }
}
