import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../services/profile_storage_service.dart';
import '../utils/profile_data.dart';
import '../widgets/circlekey_logo.dart';
import '../widgets/language_pill_chips.dart';
import '../widgets/shadcn_select.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.isEditMode = false,
    this.initialProfile,
  });

  /// When true, shows the profile edit form (pre-filled from storage).
  final bool isEditMode;

  /// Optional profile map; otherwise loaded from localStorage on open.
  final Map<String, dynamic>? initialProfile;

  static Map<String, dynamic>? currentUserSession;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoginMode = true;
  int _signUpStep = 1;
  bool _showAddMore = false;
  bool _editHydrating = false;
  Map<String, dynamic>? _editBaselineProfile;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _nativePlaceController = TextEditingController();
  final _locationController = TextEditingController();

  String _selectedFoodPref = 'Pure Veg';
  String _selectedMotherTongue = 'Telugu';
  final List<String> _selectedLanguages = ['Telugu'];
  String? _selectedOccupantType;
  String? _selectedGenderPref;
  String? _selectedStudentType;
  int _familyAdults = 2;
  int _familyChildren = 0;
  List<String> _childrenAges = [];
  int _groupSize = 1;

  final List<String> _foodOptions = ['Pure Veg', 'Non-Veg'];
  final List<String> _languageOptions = [
    'Telugu',
    'English',
    'Hindi',
    'Tamil',
    'Kannada',
  ];
  static const _occupantOptions = ['Family', 'Working Professionals', 'Students'];
  static const _genderPrefOptions = ['Boys and Girls', 'Boys only', 'Girls only'];
  static const _studentFundingOptions = [
    'Family supported',
    'Education loan (bank financed)',
  ];
  static const _childrenAgeOptions = ['Below 5', '5 - 12', '13 - 18'];
  bool _smokingOk = false;
  bool _drinkingOk = false;
  String? _scheduleType;
  bool _detectingLocation = false;
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode) {
      _editHydrating = true;
      _bootstrapEditMode();
    }
  }

  Future<void> _bootstrapEditMode() async {
    final profile =
        widget.initialProfile ?? await ProfileStorageService.load();

    if (!mounted) return;

    if (profile != null) {
      _editBaselineProfile = Map<String, dynamic>.from(profile);
      _hydrateFromProfile(profile);
    }

    setState(() => _editHydrating = false);
  }

  void _hydrateFromProfile(Map<String, dynamic> profile) {
    _isLoginMode = false;
    _signUpStep = 2;

    _emailController.text = ProfileData.text(profile['email']);
    _nameController.text = ProfileData.text(profile['full_name']);
    _locationController.text = ProfileData.text(profile['detected_city']);
    _nativePlaceController.text = ProfileData.text(profile['native_place']);

    final mother = ProfileData.text(profile['mother_tongue']);
    if (mother.isNotEmpty && _languageOptions.contains(mother)) {
      _selectedMotherTongue = mother;
    }

    final food = ProfileData.text(profile['food_preference']);
    if (food.isNotEmpty && _foodOptions.contains(food)) {
      _selectedFoodPref = food;
    }

    _selectedLanguages
      ..clear()
      ..addAll(ProfileData.languageList(profile['spoken_languages']));
    if (_selectedLanguages.isEmpty) {
      _selectedLanguages.add(_languageOptions.first);
    }

    final occupant = ProfileData.text(profile['occupant_type']);
    if (occupant.isNotEmpty && _occupantOptions.contains(occupant)) {
      _selectedOccupantType = occupant;
    }

    final genderPref = ProfileData.text(profile['gender_preference']);
    if (genderPref.isNotEmpty && _genderPrefOptions.contains(genderPref)) {
      _selectedGenderPref = genderPref;
    }

    final student = ProfileData.text(profile['student_type']);
    if (student.isNotEmpty && _studentFundingOptions.contains(student)) {
      _selectedStudentType = student;
    }

    final adults = profile['family_adults'];
    if (adults is int) _familyAdults = adults;
    final children = profile['family_children'];
    if (children is int) _familyChildren = children;

    final rawAges = profile['children_ages'];
    if (rawAges is List) {
      _childrenAges = rawAges.map((e) => e.toString()).toList();
    } else {
      final legacyAge = ProfileData.text(profile['children_age_range']);
      _childrenAges = List.generate(
        _familyChildren,
        (_) => legacyAge.isNotEmpty ? legacyAge : _childrenAgeOptions.first,
      );
    }

    final group = profile['group_size'];
    if (group is int) _groupSize = group;

    _smokingOk = profile['smoking_ok'] == true;
    _drinkingOk = profile['drinking_ok'] == true;
    final schedule = ProfileData.text(profile['schedule_type']);
    if (schedule.isNotEmpty) _scheduleType = schedule;

    final budgetMin = profile['budget_min'];
    if (budgetMin != null) _budgetMinController.text = budgetMin.toString();
    final budgetMax = profile['budget_max'];
    if (budgetMax != null) _budgetMaxController.text = budgetMax.toString();

    final native = ProfileData.text(profile['native_place']);
    final foodPref = ProfileData.text(profile['food_preference']);
    _showAddMore = native.isNotEmpty || foodPref.isNotEmpty ||
        occupant.isNotEmpty || genderPref.isNotEmpty;
  }

  Map<String, dynamic> _buildProfilePayload() {
    final baseline = widget.isEditMode
        ? (_editBaselineProfile ?? <String, dynamic>{})
        : <String, dynamic>{
            'linkedin_connected': false,
            'facebook_connected': false,
            'social_trust_score': 0,
            'is_aadhaar_verified': false,
            'passkey_public_key': null,
            'identity_trust_tier': 'Casual_Browser',
          };

    return {
      ...baseline,
      'email': _emailController.text.trim(),
      'full_name': _nameController.text.trim(),
      'detected_city': _locationController.text.trim(),
      'food_preference': _selectedFoodPref,
      'native_place': _nativePlaceController.text.trim(),
      'mother_tongue': _selectedMotherTongue,
      'spoken_languages': List<String>.from(_selectedLanguages),
      if (_selectedOccupantType != null) 'occupant_type': _selectedOccupantType,
      if (_selectedGenderPref != null) 'gender_preference': _selectedGenderPref,
      if (_selectedStudentType != null) 'student_type': _selectedStudentType,
      if (_selectedOccupantType == 'Family') ...{
        'family_adults': _familyAdults,
        'family_children': _familyChildren,
        if (_familyChildren > 0)
          'children_ages': List<String>.from(_childrenAges),
      },
      if (_selectedOccupantType == 'Working Professionals' ||
          _selectedOccupantType == 'Students')
        'group_size': _groupSize,
      'smoking_ok': _smokingOk,
      'drinking_ok': _drinkingOk,
      if (_scheduleType != null) 'schedule_type': _scheduleType,
      if (_budgetMinController.text.trim().isNotEmpty)
        'budget_min': int.tryParse(_budgetMinController.text.trim()),
      if (_budgetMaxController.text.trim().isNotEmpty)
        'budget_max': int.tryParse(_budgetMaxController.text.trim()),
      'trust_stage': 1,
      'identity_trust_tier': 'Casual_Browser',
    };
  }

  bool _validateProfileFields() {
    if (_emailController.text.trim().isEmpty) {
      _showNotification('Please enter your email.');
      return false;
    }
    if (_nameController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty) {
      _showNotification('Please fill in your name and city.');
      return false;
    }
    if (_selectedLanguages.isEmpty) {
      _showNotification('Select at least one language.');
      return false;
    }
    return true;
  }

  Future<void> _saveProfileUpdate() async {
    if (!_validateProfileFields()) return;

    final payload = _buildProfilePayload();
    AuthScreen.currentUserSession = payload;
    await ProfileStorageService.save(payload);

    if (!mounted) return;
    _showNotification('Profile updated.');
    context.go('/profile');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _nativePlaceController.dispose();
    _locationController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
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
    if (_detectingLocation) return;
    setState(() => _detectingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        _showNotification('Location permission is required. You can type it manually.');
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
    } catch (_) {
      if (!mounted) return;
      _showNotification('Could not detect location. Please type it manually.');
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  Future<void> _executeDemoSignIn() async {
    final session = {
      'email': _emailController.text.isNotEmpty
          ? _emailController.text
          : 'demo@circlekey.com',
      'full_name': 'Srinivas Kumar',
      'detected_city': 'Hyderabad, Telangana',
      'food_preference': 'Pure Veg',
      'native_place': 'Vijayawada',
      'mother_tongue': 'Telugu',
      'spoken_languages': ['Telugu', 'English'],
      'occupant_type': 'Family',
      'family_adults': 2,
      'family_children': 1,
      'children_ages': ['Below 5'],
      'trust_stage': 1,
      'identity_trust_tier': 'Casual_Browser',
      'is_aadhaar_verified': false,
      'linkedin_verified': false,
    };
    AuthScreen.currentUserSession = session;
    await ProfileStorageService.save(session);
    if (!mounted) return;
    _showNotification('Signed in successfully.');
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/');
    }
  }

  Future<void> _executeFinalSignUpRegistration() async {
    if (!_validateProfileFields()) return;

    final userProfilePayload = _buildProfilePayload();
    AuthScreen.currentUserSession = userProfilePayload;
    await ProfileStorageService.save(userProfilePayload);

    if (!mounted) return;
    _showNotification('Profile created. Welcome to CircleKey.');
    context.go('/profile');
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.of(context).canPop() && !widget.isEditMode;

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
                        if (canGoBack)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded, size: 18),
                              label: const Text('Back to listings'),
                              style: TextButton.styleFrom(
                                foregroundColor: _AuthPalette.textSecondary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                              ),
                            ),
                          ),
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
                          child: widget.isEditMode
                              ? (_editHydrating
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 48),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: _AuthPalette.primary,
                                        ),
                                      ),
                                    )
                                  : _buildEditProfileLayout())
                              : (_isLoginMode
                                  ? _buildLoginLayout()
                                  : _buildSignUpWizardLayout()),
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
        const CircleKeyLogo(size: 56),
        const Text(
          'Sign in to CircleKey',
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
          onSubmitted: (_) => _executeDemoSignIn(),
        ),
        _buildPrimaryButton(
          label: 'Sign in',
          onPressed: _executeDemoSignIn,
        ),
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

  void _toggleLanguage(String lang) {
    setState(() {
      if (_selectedLanguages.contains(lang)) {
        if (_selectedLanguages.length > 1) {
          _selectedLanguages.remove(lang);
        }
      } else {
        _selectedLanguages.add(lang);
      }
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
                color: _AuthPalette.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(_AuthPalette.radiusXl),
                boxShadow: _AuthPalette.shadowSm,
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
          boxShadow: prominent ? _AuthPalette.ctaPanelShadow : _AuthPalette.shadowSm,
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
                    backgroundColor: primaryColor ?? _AuthPalette.primary,
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
          label: 'Continue',
          onPressed: () {
            if (_emailController.text.isEmpty ||
                _passwordController.text.isEmpty) {
              _showNotification('Enter your email and password to continue.');
              return;
            }
            setState(() => _signUpStep = 2);
            _autoDetectWebLocation();
          },
        ),
        Center(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _isLoginMode = true),
              child: const Text(
                'Already have an account? Sign in',
                style: TextStyle(color: _AuthPalette.textSecondary, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditProfileLayout() {
    return _spacedColumn(
      gap: _AuthLayout.spaceY6,
      children: [
        _buildStepHeading(
          title: 'Edit your profile',
          subtitle: 'Update your details for better matching.',
        ),
        ..._buildProfileFormSections(includeEmail: true),
        _buildSignUpCta(
          onBack: () => context.go('/profile'),
          primaryLabel: 'Save changes',
          trustMessage: 'Used only for matching • never shared publicly',
          prominent: true,
          onPrimary: _saveProfileUpdate,
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
        subtitle: 'Required for matching.',
        fields: [
          _buildInput(_nameController, label: 'Full name', hint: 'As on your ID'),
          _buildInput(
            _locationController,
            label: 'Current city',
            hint: 'e.g. Hyderabad, Telangana',
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
          ShadcnSelect(
            label: 'Mother tongue',
            value: _selectedMotherTongue,
            options: _languageOptions,
            onChanged: (val) => setState(() => _selectedMotherTongue = val),
          ),
          _buildLabeledField(
            label: 'Other languages',
            child: LanguagePillChips(
              options: _languageOptions,
              selected: _selectedLanguages,
              onToggle: _toggleLanguage,
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
          title: 'Lifestyle & preferences',
          subtitle: 'Helps us find compatible matches.',
          fields: [
            _buildInput(
              _nativePlaceController,
              label: 'Native place',
              hint: 'e.g. Vijayawada',
            ),
            ShadcnSelect(
              label: 'Food preference',
              value: _selectedFoodPref,
              options: _foodOptions,
              onChanged: (val) => setState(() => _selectedFoodPref = val),
            ),
          ],
        ),
        _buildFieldGroupCard(
          title: 'Budget range',
          subtitle: 'Monthly rent or purchase budget (INR).',
          fields: [
            _buildInput(
              _budgetMinController,
              label: 'Minimum budget',
              hint: 'e.g. 8000',
              keyboardType: TextInputType.number,
            ),
            _buildInput(
              _budgetMaxController,
              label: 'Maximum budget',
              hint: 'e.g. 25000',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        _buildFieldGroupCard(
          title: 'I am looking for',
          subtitle: 'Type of accommodation you need.',
          fields: [
            ShadcnSelect(
              label: 'Occupant type',
              value: _selectedOccupantType ?? _occupantOptions.first,
              options: _occupantOptions,
              onChanged: (val) => setState(() {
                _selectedOccupantType = val;
                if (val != 'Students') _selectedStudentType = null;
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
                label: 'Student funding',
                value: _selectedStudentType ?? _studentFundingOptions.first,
                options: _studentFundingOptions,
                onChanged: (val) => setState(() => _selectedStudentType = val),
              ),
          ],
        ),
        if (_selectedOccupantType == 'Working Professionals' ||
            _selectedOccupantType == 'Students')
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
          subtitle: 'Name, city, and languages.',
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
              activeColor: _AuthPalette.primary,
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
  }) {
    return _buildLabeledField(
      label: label,
      child: _PremiumAuthField(
        controller: controller,
        hint: hint,
        isObscured: isObscured,
        suffix: suffix,
        keyboardType: keyboardType ??
            (label == 'Email' ? TextInputType.emailAddress : TextInputType.text),
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
    Color backgroundColor = _AuthPalette.accent,
    double height = _AuthLayout.buttonHeight,
    bool prominent = false,
  }) {
    Color resolvePressed(Set<WidgetState> states) {
      if (states.contains(WidgetState.pressed)) {
        return backgroundColor == _AuthPalette.success
            ? const Color(0xFF36A420)
            : _AuthPalette.accentActive;
      }
      if (states.contains(WidgetState.hovered)) {
        return backgroundColor == _AuthPalette.success
            ? const Color(0xFF3BB82E)
            : _AuthPalette.accentHover;
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
  static const primary = Color(0xFF0EA5E9);
  static const primaryHover = Color(0xFF0284C7);
  static const primaryActive = Color(0xFF0369A1);
  static const accent = Color(0xFFF97316);
  static const accentHover = Color(0xFFEA580C);
  static const accentActive = Color(0xFFC2410C);
  static const success = Color(0xFF42B72A);

  static const canvas = Color(0xFFF3F4F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF9FAFB);
  static const border = Color(0xFFE5E7EB);
  static const borderSoft = Color(0xFFE5E7EB);
  static const textPrimary = Color(0xFF1C1E21);
  static const textSecondary = Color(0xFF606770);
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
  });

  final TextEditingController controller;
  final String? hint;
  final bool isObscured;
  final Widget? suffix;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

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
